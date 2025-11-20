const express = require('express');
const app = express();
const db = require('./db');
const con = db; // `db` is the connection object; db.connect() is available to wait for readiness
const bcrypt = require('bcrypt');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const secretKey = process.env.JWT_SECRET || 'My_Secret_Key_1234';

// FRONTEND / BACKEND
// FRONTEND: Flutter app (in ./lib/) calls these HTTP endpoints.
// BACKEND: This file implements the API (Express + MySQL). Keep comments short.


// Middleware
app.use(cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
    allowedHeaders: ["Content-Type"],
}));

// Allow cross-origin requests from Flutter app
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// --- Auth middleware (JWT) ---
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'] || req.headers['Authorization'];
    if (!authHeader) return res.status(401).json({ error: 'Missing Authorization header' });

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') return res.status(401).json({ error: 'Malformed Authorization header' });

    const token = parts[1];
    jwt.verify(token, secretKey, (err, payload) => {
        if (err) return res.status(401).json({ error: 'Invalid or expired token' });
        // attach user info to request
        req.user = payload;
        next();
    });
}

function authorizeRole(requiredRole) {
    return (req, res, next) => {
        if (!req.user || !req.user.role) return res.status(403).json({ error: 'Forbidden' });
        if (req.user.role !== requiredRole) return res.status(403).json({ error: 'Access restricted to ' + requiredRole });
        next();
    };
}

// --- Server-Sent Events (SSE) for realtime notifications ---
const sseClients = new Set();

/* --- API ROUTES START --- */
app.get('/events', (req, res) => {
    // Keep connection open for SSE
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders && res.flushHeaders();

    // send a comment to keep the connection alive initially
    res.write(': connected\n\n');

    sseClients.add(res);

    req.on('close', () => {
        sseClients.delete(res);
    });
});

function broadcastEvent(eventName, payload) {
    const data = `event: ${eventName}\ndata: ${JSON.stringify(payload)}\n\n`;
    for (const client of sseClients) {
        try {
            client.write(data);
        } catch (e) {
            // ignore write errors and remove client
            sseClients.delete(client);
        }
    }
}

// --- Authenticated: show current logged-in user's role/info ---
app.get('/me', authenticateToken, (req, res) => {
    const payload = req.user || {};
    const userId = payload.userId;
    const role = payload.role;

    if (!userId) return res.status(400).json({ error: 'Invalid token payload' });

    // Attempt to return user record from DB for extra context (name, role)
    const sql = 'SELECT user_id, name, role FROM users WHERE user_id = ?';
    con.query(sql, [userId], (err, results) => {
        if (err) {
            console.error('DB error (/me):', err);
            return res.status(500).json({ error: 'Database error' });
        }
        if (results.length === 0) {
            // Token had a userId but DB doesn't have it
            return res.json({ userId, role });
        }
        const user = results[0];
        return res.json({ user, token: { userId, role } });
    });
});

// Public (used by frontend): test/discovery endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'Mobile App Server is running!',
        database: 'mobi_app',
        server: 'Connected to mobi_app MySQL database',
        endpoints: [
            'GET / - This test endpoint',
            'GET /test-db - Test database connection',
            'POST /init-db - Initialize database from mobi_app.sql',
            'POST /login - User authentication',
            'POST /register - User registration',
            'GET /user/:id - Get user profile',
            'GET /rooms - Get available rooms (Simple)',
            'POST /book-room - Book a room (Updated for time slots)',
            'GET /user/:id/bookings - Get user bookings (Updated for history)',
            'DELETE /booking/:id - Cancel a booking (Student action)',
            '--- NEW LECTURER/STAFF ENDPOINTS ---',
            'GET /dashboard/stats - Get stats for Lecturer Dashboard',
            'GET /rooms/slots - Get rooms with time slot status (For Lecturer)',
            'GET /bookings/pending - Get pending bookings (For Lecturer "Check Request")',
            'PUT /booking/:id/status - Approve/Reject a booking (For Lecturer "Check Request")',
            'GET /bookings/history - Get completed history (For Lecturer "History" Page)'
        ]
    });
});

/**
 * GET /test-db
 * Public. Quick DB connectivity check used by the frontend to verify server+DB.
 * Response: { database, status, test_result }
 */
app.get('/test-db', async (req, res) => {
    try {
        // gather simple counts for main tables
        const [usersRows] = await con.promise().query('SELECT COUNT(*) as count FROM users');
        const [roomsRows] = await con.promise().query('SELECT COUNT(*) as count FROM rooms');
        const [bookingsRows] = await con.promise().query('SELECT COUNT(*) as count FROM bookings');

        // latest booking date (if any)
        const [latestBooking] = await con.promise().query("SELECT MAX(booking_date) as latest_booking_date FROM bookings");

        res.json({
            database: 'mobi_app',
            status: 'Connected successfully',
            counts: {
                users: usersRows[0].count || 0,
                rooms: roomsRows[0].count || 0,
                bookings: bookingsRows[0].count || 0
            },
            latest_booking_date: latestBooking[0].latest_booking_date || null
        });
    } catch (err) {
        console.error('Database connection test failed:', err);
        return res.status(500).json({
            error: "Database connection failed",
            database: "mobi_app",
            details: err.message
        });
    }
});

/**
 * POST /init-db
 * Admin: Trigger initial DB population from mobi_app.sql (one-time use).
 * No body. Responds with a message when initialization is started.
 */
app.post('/init-db', (req, res) => {
    try {
        db.initializeDatabase();
        res.json({
            message: "Database initialization triggered",
            database: "mobi_app",
            source: "mobi_app.sql"
        });
    } catch (err) {
        console.error('Database initialization failed:', err);
        res.status(500).json({
            error: "Database initialization failed",
            details: err.message
        });
    }
});

/**
 * GET /password/:pass
 * Utility (dev-only). Returns bcrypt hash for given password param.
 * Not used by production frontend.
 */
app.get('/password/:pass', (req, res) => {
    const password = req.params.pass;
    bcrypt.hash(password, 10, function (err, hash) {
        if (err) {
            return res.status(500).send('Hashing error');
        }
        res.send(hash);
    });
});

/**
 * POST /register
 * Public. Create a new user (defaults to role 'student').
 * Body: { username, password, email? }
 * Response: 201 { message, userId } or error.
 */
app.post('/register', (req, res) => {
    const { username, password, email } = req.body;

    if (!username || !password) {
        return res.status(400).json({ error: 'Username and password are required' });
    }

    // Check if user already exists
    const checkSql = "SELECT user_id FROM users WHERE name = ?";
    con.query(checkSql, [username], function (err, results) {
        if (err) {
            return res.status(500).json({ error: "Database server error" });
        }
        if (results.length > 0) {
            return res.status(409).json({ error: "Username already exists" });
        }

        // Hash password and create user
        bcrypt.hash(password, 10, function (err, hash) {
            if (err) {
                return res.status(500).json({ error: 'Hashing error' });
            }

            // หมายเหตุ: ข้อกำหนดกล่าวถึง 'staff' และ 'lecturer' แต่โค้ดนี้ลงทะเบียนเป็น 'student' เสมอ
            const insertSql = "INSERT INTO users (name, password_hash, role) VALUES (?, ?, 'student')";
            con.query(insertSql, [username, hash], function (err, result) {
                if (err) {
                    return res.status(500).json({ error: "Database insert error" });
                }
                res.status(201).json({
                    message: "User registered successfully",
                    userId: result.insertId
                });
            });
        });
    });
});

/**
 * POST /login
 * Public. Authenticate user and return JWT token.
 * Body: { username, password }
 * Response: { token, userId, role }
 */
app.post('/login', (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ error: 'Username and password are required' });
    }

    const sql = "SELECT user_id, password_hash, role FROM users WHERE name = ?";
    con.query(sql, [username], function (err, results) {
        if (err) {
            return res.status(500).json({ error: "Database server error" });
        }
        if (results.length != 1) {
            // ตามข้อกำหนด ID, name, username และ password ของ staff และ lecturer
            // มีให้ในฐานข้อมูล ดังนั้นการค้นหาไม่พบอาจหมายถึงชื่อผู้ใช้ผิด
            return res.status(401).json({ error: "Wrong username" });
        }
        // compare passwords
        bcrypt.compare(password, results[0].password_hash, function (err, same) {
            if (err) {
                return res.status(500).json({ error: "Hashing error" });
            }
            if (same) {
                const user = results[0];

                const token = jwt.sign(
                    { userId: user.user_id, role: user.role },
                    secretKey,
                    { expiresIn: '24h' } // Token หมดอายุใน 24 ชม.
                );

                return res.json({
                    message: "Login successful",
                    userId: user.user_id,
                    role: user.role,
                    token: token,
                    success: true
                });
            }
            return res.status(401).json({ error: "Wrong password" });
        });
    })
});

/**
 * GET /user/:id
 * Public. Retrieve basic user profile (user_id, name, role).
 * Params: id (user_id)
 */
app.get('/user/:id', (req, res) => {
    const userId = req.params.id;
    const sql = "SELECT user_id, name, role FROM users WHERE user_id = ?";
    con.query(sql, [userId], function (err, results) {
        if (err) {
            return res.status(500).json({ error: "Database server error" });
        }
        if (results.length != 1) {
            return res.status(404).json({ error: "User not found" });
        }
        res.json(results[0]);
    });
});

/**
 * GET /rooms
 * Public. Return list of rooms with basic metadata.
 * Response: { message, rooms }
 */
app.get('/rooms', (_req, res) => {
    const sql = "SELECT r.room_id, r.name, r.description, r.capacity, r.is_available FROM rooms r ORDER BY r.room_id";
    con.query(sql, function (err, results) {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: "Database server error" });
        }
        res.json({
            message: "Rooms retrieved from mobi_app database",
            rooms: results
        });
    })
});

// STAFF-ONLY (backend): room management endpoints — called by staff UI only
// Requires Authorization: Bearer <token> (role must be 'staff')
/**
 * POST /staff/rooms
 * Staff-only. Create a room.
 * Auth: Bearer token (role: staff)
 * Body: { name, description?, capacity, is_available? }
 */
app.post('/staff/rooms', authenticateToken, authorizeRole('staff'), (req, res) => {
    const { name, description, capacity, is_available } = req.body;

    if (!name || typeof capacity === 'undefined') {
        return res.status(400).json({ error: 'Missing required fields: name and capacity' });
    }

    const avail = (typeof is_available === 'undefined') ? 1 : (is_available ? 1 : 0);
    const insertSql = 'INSERT INTO rooms (name, description, capacity, is_available) VALUES (?, ?, ?, ?)';
    con.query(insertSql, [name, description || null, capacity, avail], (err, result) => {
        if (err) {
            console.error('DB error (insert room):', err);
            return res.status(500).json({ error: 'Database error while adding room' });
        }
        const roomId = result.insertId;
        res.status(201).json({ message: 'Room added', roomId });
        // notify SSE subscribers about room creation
        broadcastEvent('room_changed', { action: 'created', roomId, name, capacity, is_available: avail });
    });
});

/**
 * PUT /staff/rooms/:id
 * Staff-only. Update room fields (partial allowed).
 * Auth: Bearer token (role: staff)
 * Body: any of { name, description, capacity, is_available }
 */
app.put('/staff/rooms/:id', authenticateToken, authorizeRole('staff'), (req, res) => {
    const roomId = req.params.id;
    const { name, description, capacity, is_available } = req.body;

    // Build dynamic update
    const updates = [];
    const params = [];
    if (typeof name !== 'undefined') { updates.push('name = ?'); params.push(name); }
    if (typeof description !== 'undefined') { updates.push('description = ?'); params.push(description); }
    if (typeof capacity !== 'undefined') { updates.push('capacity = ?'); params.push(capacity); }
    if (typeof is_available !== 'undefined') { updates.push('is_available = ?'); params.push(is_available ? 1 : 0); }

    if (updates.length === 0) return res.status(400).json({ error: 'No fields to update' });

    const sql = `UPDATE rooms SET ${updates.join(', ')} WHERE room_id = ?`;
    params.push(roomId);

    con.query(sql, params, (err, result) => {
        if (err) {
            console.error('DB error (update room):', err);
            return res.status(500).json({ error: 'Database error while updating room' });
        }
        if (result.affectedRows === 0) return res.status(404).json({ error: 'Room not found' });
        res.json({ message: 'Room updated', roomId: Number(roomId) });
        // notify SSE subscribers about room update
        broadcastEvent('room_changed', { action: 'updated', roomId: Number(roomId), updates: updates });
    });
});

/**
 * DELETE /staff/rooms/:id
 * Staff-only. Delete a room by id.
 * Auth: Bearer token (role: staff)
 */
app.delete('/staff/rooms/:id', authenticateToken, authorizeRole('staff'), (req, res) => {
    const roomId = req.params.id;

    const sql = 'DELETE FROM rooms WHERE room_id = ?';
    con.query(sql, [roomId], (err, result) => {
        if (err) {
            console.error('DB error (delete room):', err);
            return res.status(500).json({ error: 'Database error while deleting room' });
        }
        if (result.affectedRows === 0) return res.status(404).json({ error: 'Room not found' });
        res.json({ message: 'Room deleted', roomId: Number(roomId) });
        // notify SSE subscribers about room deletion
        broadcastEvent('room_changed', { action: 'deleted', roomId: Number(roomId) });
    });
});

// --- ⬇️ NEW/MODIFIED ENDPOINTS BASED ON REQUIREMENTS ⬇️ ---

/**
 * GET /dashboard/stats
 * Lecturer/Staff. Return aggregated counts for dashboard (pending/reserved/disabled/free slots).
 * Response: { pending_slots, reserved_slots, disabled_rooms, free_slots }
 */
app.get('/dashboard/stats', async (req, res) => {
    // กำหนดว่ามี 4 slots ต่อห้อง
    const SLOTS_PER_ROOM = 4;

    try {
        // 1. ดึงข้อมูลที่จำเป็นทั้งหมดพร้อมกัน
        const [
            [disabledRoomsResult],
            [availableRoomsResult],
            [pendingSlotsResult],
            [reservedSlotsResult]
        ] = await Promise.all([
            // 1. นับ "Disabled Rooms" (ตามที่คุณขอ)
            con.promise().query("SELECT COUNT(*) as count FROM rooms WHERE is_available = 0"),

            // 2. นับ "Available Rooms" (ห้องที่เปิดใช้งาน)
            con.promise().query("SELECT COUNT(*) as count FROM rooms WHERE is_available = 1"),

            // 3. นับ "Pending Slots" (ของวันนี้)
            con.promise().query("SELECT COUNT(*) as count FROM bookings WHERE status = 'pending' AND booking_date = CURDATE()"),

            // 4. นับ "Reserved Slots" (ของวันนี้)
            con.promise().query("SELECT COUNT(*) as count FROM bookings WHERE status = 'approved' AND booking_date = CURDATE()")
        ]);

        // 2. แยกตัวแปร
        const disabledRoomCount = disabledRoomsResult[0].count;
        const availableRoomCount = availableRoomsResult[0].count;
        const pendingSlotCount = pendingSlotsResult[0].count;
        const reservedSlotCount = reservedSlotsResult[0].count;

        // 3. คำนวณ "Free Slots"
        const totalFreeSlots = (availableRoomCount * SLOTS_PER_ROOM) - pendingSlotCount - reservedSlotCount;

        // 4. ส่งข้อมูลกลับไป (ใช้ Key เหล่านี้เท่านั้น!)
        res.json({
            message: "Dashboard stats retrieved",
            pending_slots: pendingSlotCount,
            reserved_slots: reservedSlotCount,
            disabled_rooms: disabledRoomCount, 
            free_slots: totalFreeSlots       
        });

    } catch (err) {
        console.error('Database error in /dashboard/stats:', err);
        res.status(500).json({ error: "DB error", details: err.message });
    }
});

/**
 * GET /rooms/slots
 * Public/Lecturer. Return each room with today's time slots and slot status (free/pending/reserved/disabled).
 * Response: { message, rooms: [{ room_id, name, time_slots: [{time, status}] }] }
 */
app.get('/rooms/slots', (req, res) => {
    const roomsSql = "SELECT room_id, name, capacity, is_available FROM rooms";
    // สมมติว่า 'bookings' มีคอลัมน์ 'booking_date' และ 'time_slot'
    const bookingsSql = "SELECT room_id, time_slot, status FROM bookings WHERE booking_date = CURDATE() AND (status = 'pending' OR status = 'approved')";

    con.query(roomsSql, (err, rooms) => {
        if (err) return res.status(500).json({ error: "DB error (rooms)" });
        con.query(bookingsSql, (err, bookings) => {
            if (err) return res.status(500).json({ error: "DB error (bookings)" });

            // สร้าง time slots ตามข้อกำหนด
            const timeSlotsTemplate = ["08:00-10:00", "10:00-12:00", "13:00-15:00", "15:00-17:00"];

            const results = rooms.map(room => {
                const slots = timeSlotsTemplate.map(slot => {
                    let status = "free";

                    if (room.is_available === 0) {
                        status = "disabled";
                    } else {
                        // ค้นหาการจองสำหรับห้องนี้และสล็อตเวลานี้
                        const booking = bookings.find(b => b.room_id === room.room_id && b.time_slot === slot);
                        if (booking) {
                            if (booking.status === 'pending') {
                                status = 'pending';
                            } else if (booking.status === 'approved') {
                                status = 'reserved'; // 'approved' คือ 'reserved'
                            }
                        }
                    }

                    return { time: slot, status: status };
                });

                return {
                    room_id: room.room_id,
                    name: room.name,
                    capacity: room.capacity,
                    status: room.is_available === 1 ? 'available' : 'disabled',
                    time_slots: slots
                };
            });

            res.json({ message: "Rooms with time slots retrieved", rooms: results });
        });
    });
});

/**
 * GET /bookings/pending
 * Lecturer. List pending booking requests (includes room and student info, image_url if present).
 * Response: { message, requests: [...] }
 */
app.get('/bookings/pending', (req, res) => {
    // อัปเดต SQL: เพิ่ม image_url และ LEFT JOIN roomimages
    const sql = `
        SELECT 
            b.booking_id, b.booking_date, b.time_slot, b.reason,
            r.room_id, r.name as room_name, r.capacity,
            u.user_id as student_id, u.name as student_name,
            ri.image_url 
        FROM bookings b
        JOIN rooms r ON b.room_id = r.room_id
        JOIN users u ON b.user_id = u.user_id
        LEFT JOIN roomimages ri ON r.room_id = ri.room_id
        WHERE b.status = 'pending'
        GROUP BY b.booking_id 
        ORDER BY b.booking_date, b.time_slot
    `;
    // (ใช้ GROUP BY b.booking_id เพื่อป้องกันการซ้ำซ้อนหากห้องมีหลายรูป)

    con.query(sql, (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: "Database server error" });
        }

        const formattedRequests = results.map(item => ({
            booking_id: item.booking_id,
            room_name: item.room_name,
            capacity: item.capacity,
            date: new Date(item.booking_date).toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
                year: 'numeric'
            }),
            time_slot: item.time_slot,
            reason: item.reason,
            student_name: item.student_name,
            image_url: item.image_url // ส่ง URL รูปภาพไปให้แอป
        }));

        res.json({
            message: "Pending bookings retrieved",
            requests: formattedRequests
        });
    });
});

/**
 * GET /bookings/history
 * Lecturer/Staff. Return completed bookings (approved or rejected) for history view.
 * Response: { message, bookings: [...] }
 */
app.get('/bookings/history', (req, res) => {
    // ดึงข้อมูลทั้งหมดที่ status ไม่ใช่ 'pending' หรือ 'cancelled'
    const sql = `
        SELECT
            b.booking_id, b.user_id, b.room_id, b.status,
            b.booking_date, b.time_slot, b.reason,
            b.rejection_reason, 
            r.name as room_name, r.description, r.capacity,
            u_student.name as reserved_by,
            u_approver.name as approved_by
        FROM bookings b
        JOIN rooms r ON b.room_id = r.room_id
        JOIN users u_student ON b.user_id = u_student.user_id
        LEFT JOIN users u_approver ON b.approver_id = u_approver.user_id
        WHERE b.status IN ('approved', 'rejected')
        ORDER BY b.booking_date DESC, b.time_slot DESC
    `;

    con.query(sql, (err, results) => {
        if (err) {
            console.error('Database error in /bookings/history:', err);
            return res.status(500).json({ error: "Database server error" });
        }

        // (ใช้การจัดรูปแบบข้อมูลแบบเดียวกับ API ของ Student)
        const formattedBookings = results.map(item => ({
            booking_id: item.booking_id,
            user_id: item.user_id,
            room_id: item.room_id,
            status: item.status.charAt(0).toUpperCase() + item.status.slice(1),
            room: item.room_name,
            capacity: `${item.capacity} People`,
            date: new Date(item.booking_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
            time: item.time_slot,
            reason: item.reason,
            reserved: item.reserved_by,
            approved: item.approved_by || 'N/A', // ถ้ายังไม่มีคน approve (ซึ่งไม่ควรเกิด)
            rejection_reason: item.rejection_reason
        }));

        res.json({
            message: "Completed bookings history retrieved",
            bookings: formattedBookings
        });
    });
});

/**
 * PUT /booking/:id/status
 * Lecturer. Approve or reject a pending booking. Records approver and optional rejection_reason.
 * Body: { status: 'approved'|'rejected', approverId, rejection_reason? }
 */
app.put('/booking/:id/status', (req, res) => {
    const bookingId = req.params.id;
    // ดึง rejection_reason ที่ส่งมาจาก Pop-up
    const { status, approverId, rejection_reason } = req.body;

    if (!status || !approverId) {
        return res.status(400).json({ error: "Status (approved/rejected) and approverId are required" });
    }
    if (status !== 'approved' && status !== 'rejected') {
        return res.status(400).json({ error: "Invalid status. Must be 'approved' or 'rejected'" });
    }

    // อัปเดต SQL Query ให้บันทึกเหตุผลด้วย
    // (ถ้า status เป็น 'approved', ค่า reason จะเป็น null ซึ่งถูกต้อง)
    const sql = "UPDATE bookings SET status = ?, approver_id = ?, rejection_reason = ? WHERE booking_id = ? AND status = 'pending'";

    con.query(sql, [status, approverId, rejection_reason || null, bookingId], (err, result) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: "Database server error" });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ error: "Pending booking not found or already processed" });
        }
        res.json({
            message: `Booking ${bookingId} has been ${status}`,
            bookingId: bookingId,
            newStatus: status
        });
        // notify SSE subscribers about booking status change
        broadcastEvent('booking_updated', { bookingId, status, approverId, rejection_reason });
    });
});

/**
 * POST /book-room
 * Student. Request a booking for a single time slot on a given day (status starts as 'pending').
 * Body: { userId, roomId, booking_date (YYYY-MM-DD), time_slot }
 * Response: 201 { message, bookingId } or 4xx/5xx errors.
 */
app.post('/book-room', (req, res) => {
    // สมมติว่า client ส่ง 'booking_date' (YYYY-MM-DD) และ 'time_slot' (เช่น '08:00-10:00')
    // และ 'reason' จาก history_page
    const { userId, roomId, booking_date, time_slot, reason } = req.body;

    if (!userId || !roomId || !booking_date || !time_slot) {
        return res.status(400).json({ error: 'User ID, Room ID, Booking Date, and Time Slot are required' });
    }

    // 1. ตรวจสอบ "A student can only book a single slot in one day."
    const checkUserSql = "SELECT booking_id FROM bookings WHERE user_id = ? AND booking_date = ? AND status != 'rejected' AND status != 'cancelled'";
    con.query(checkUserSql, [userId, booking_date], function (err, userBookings) {
        if (err) return res.status(500).json({ error: "DB error (checking user)" });
        if (userBookings.length > 0) {
            return res.status(409).json({ error: "You have already booked a slot for this day." });
        }

        // 2. ตรวจสอบว่า "If a room's time slot is booked, its status is pending. No other booking is allowed."
        const checkSlotSql = "SELECT room_id FROM rooms WHERE room_id = ? AND is_available = 1";
        con.query(checkSlotSql, [roomId], function (err, room) {
            if (err) return res.status(500).json({ error: "DB error (checking room)" });
            if (room.length === 0) {
                return res.status(404).json({ error: "Room not found or is disabled" });
            }

            // 3. ตรวจสอบว่าสล็อตเวลานี้ว่างหรือไม่
            const checkTimeSql = "SELECT booking_id FROM bookings WHERE room_id = ? AND booking_date = ? AND time_slot = ? AND (status = 'pending' OR status = 'approved')";
            con.query(checkTimeSql, [roomId, booking_date, time_slot], function (err, slotBookings) {
                if (err) return res.status(500).json({ error: "DB error (checking slot)" });
                if (slotBookings.length > 0) {
                    return res.status(409).json({ error: "This time slot is already booked or pending." });
                }

                // 4. สร้างการจอง (สถานะเริ่มต้นคือ 'pending')
                const insertSql = "INSERT INTO bookings (user_id, room_id, status, booking_date, time_slot, reason) VALUES (?, ?, 'pending', ?, ?, ?)";
                con.query(insertSql, [userId, roomId, booking_date, time_slot, reason || null], function (err, result) {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ error: "Database booking error" });
                    }
                    const bookingId = result.insertId;
                    res.status(201).json({
                        message: "Room booking request submitted successfully. Status is pending.",
                        bookingId: bookingId
                    });
                    // notify SSE subscribers about new booking
                    broadcastEvent('booking_created', { bookingId, userId, roomId, booking_date, time_slot });
                });
            });
        });
    });
});

/**
 * GET /user/:id/bookings
 * Public. Return booking history for a user (includes approver info when available).
 * Params: id (user_id)
 */
app.get('/user/:id/bookings', (req, res) => {
    const userId = req.params.id;
    // สมมติว่า 'bookings' มี 'booking_date', 'time_slot', 'reason', และ 'approver_id'
    const sql = `
SELECT
b.booking_id, b.user_id, b.room_id, b.status,
    b.booking_date, b.time_slot, b.reason,
    r.name as room_name, r.description, r.capacity,
    u_student.name as reserved_by,
    u_approver.name as approved_by
        FROM bookings b 
        JOIN rooms r ON b.room_id = r.room_id
        JOIN users u_student ON b.user_id = u_student.user_id
        LEFT JOIN users u_approver ON b.approver_id = u_approver.user_id
        WHERE b.user_id = ?
    ORDER BY b.booking_date DESC, b.time_slot DESC
    `;

    con.query(sql, [userId], function (err, results) {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: "Database server error" });
        }

        // แปลงข้อมูลให้ตรงกับที่ history_page.dart คาดหวัง
        const formattedBookings = results.map(item => ({
            booking_id: item.booking_id,
            user_id: item.user_id,
            room_id: item.room_id,
            status: item.status.charAt(0).toUpperCase() + item.status.slice(1), // เช่น 'pending' -> 'Pending'
            room: item.room_name,
            capacity: `${item.capacity} People`,
            date: new Date(item.booking_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }), // "Oct 5, 2025"
            time: item.time_slot,
            reason: item.reason,
            reserved: item.reserved_by,
            approved: item.approved_by || 'N/A' // ถ้ายังไม่มีคน approve
        }));

        res.json({
            message: "Bookings retrieved from mobi_app database",
            bookings: formattedBookings // ส่งข้อมูลที่จัดรูปแบบแล้ว
        });
    });
});


/**
 * DELETE /booking/:id
 * Student. Cancel their booking (marks status = 'cancelled').
 * Params: id (booking_id)
 */
app.delete('/booking/:id', (req, res) => {
    const bookingId = req.params.id;

    // อัปเดตสถานะเป็น 'cancelled' (นักเรียนยกเลิกเอง)
    const sql = "UPDATE bookings SET status = 'cancelled' WHERE booking_id = ?";

    con.query(sql, [bookingId], function (err, result) {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: "Database server error" });
        }

        if (result.affectedRows === 0) {
            return res.status(404).json({ error: "Booking not found" });
        }

        res.json({
            message: "Booking cancelled successfully",
            bookingId: bookingId
        });
    });
});

// --- ⬆️ END OF NEW/MODIFIED ENDPOINTS ⬆️ ---
/* --- API ROUTES END --- */

// Start server after DB connection succeeds
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0'; // Listen on all network interfaces

// Start server and attempt DB connection; if DB is unavailable, start the
// HTTP server so mobile emulator can still reach endpoints (they will return
// DB errors for DB-backed routes). Meanwhile attempt DB reconnects in background.
function startHttpServer() {
    app.listen(PORT, HOST, () => {
        console.log(`🚀 Mobile app Server running on ${HOST}:${PORT}`);
        console.log(`🌐 Test the connection at: http://localhost:${PORT}`);
        console.log(`🌐 Emulator can connect at: http://10.0.2.2:${PORT}`);
        console.log(`🔍 Test database at: http://localhost:${PORT}/test-db`);
    });
}

async function attemptDbConnect(retryIntervalSeconds = 10) {
    try {
        await db.ensureConnect();
        console.log("📁 Connected to 'mobi_app' MySQL database");
    } catch (err) {
        console.error('Initial DB connection failed:', err.message || err);
        console.log(`Will retry DB connection every ${retryIntervalSeconds}s`);
        // Retry loop
        const iv = setInterval(async () => {
            try {
                await db.ensureConnect();
                console.log("📁 Reconnected to 'mobi_app' MySQL database");
                clearInterval(iv);
            } catch (e) {
                console.warn('DB reconnect failed:', e.message || e);
            }
        }, retryIntervalSeconds * 1000);
    }
}

startHttpServer();
attemptDbConnect();
