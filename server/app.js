const express = require('express');
const app = express();
const db = require('./db');
const con = db; // `db` is the connection object; db.connect() is available to wait for readiness
const bcrypt = require('bcrypt');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const secretKey = process.env.JWT_SECRET || 'My_Secret_Key_1234';
const os = require('os');

// FRONTEND / BACKEND
// FRONTEND: Flutter app (in ./lib/) calls these HTTP endpoints.
// BACKEND: This file implements the API (Express + MySQL). Keep comments short.

// Middleware - Allow all origins for easy device connectivity
app.use(cors({
    origin: "*", // Allow all origins (any device can connect)
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With"],
    credentials: false, // Set to false when using origin: "*"
    preflightContinue: false,
    optionsSuccessStatus: 204
}));

// Allow cross-origin requests from any device
// Increase body size limit for image uploads (50MB)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Log all incoming requests for debugging connectivity
app.use((req, res, next) => {
    const clientIP = req.ip || req.connection.remoteAddress;
    console.log(`📱 ${req.method} ${req.path} from ${clientIP}`);
    next();
});

// Helper function to get local IP address
function getLocalIPAddress() {
    const interfaces = os.networkInterfaces();
    const addresses = [];
    
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            // Skip internal (loopback) and non-IPv4 addresses
            if (iface.family === 'IPv4' && !iface.internal) {
                addresses.push(iface.address);
            }
        }
    }
    
    // Prefer non-VPN addresses (typically 192.168.x.x or 10.x.x.x)
    const preferred = addresses.find(addr => 
        addr.startsWith('192.168.') || addr.startsWith('10.')
    );
    
    return preferred || addresses[0] || '0.0.0.0';
}

// Get server IP endpoint (for auto-configuration)
app.get('/server-ip', (req, res) => {
    const localIP = getLocalIPAddress();
    res.json({
        ip: localIP,
        port: PORT,
        url: `http://${localIP}:${PORT}`
    });
});

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
+
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
    const localIP = getLocalIPAddress();
    res.json({
        message: 'Mobile App Server is running!',
        database: 'mobi_app',
        server: 'Connected to mobi_app MySQL database',
        serverIP: localIP,
        serverURL: `http://${localIP}:${PORT}`,
        endpoints: [
            'GET / - This test endpoint',
            'GET /server-ip - Get server IP address',
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
    const sql = "SELECT r.room_id, r.name, r.description, r.capacity, r.is_available, r.image FROM rooms r ORDER BY r.room_id";
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

// Add new room (for staff)
app.post('/rooms', (req, res) => {
    const { name, description, capacity, is_available, image } = req.body;

    // Validate required fields
    if (!name || !capacity) {
        return res.status(400).json({ error: "Name and capacity are required" });
    }

    // Convert boolean to integer for database
    const availableValue = is_available ? 1 : 0;

    // If image is provided as base64, store it; otherwise use null
    const sql = "INSERT INTO rooms (name, description, capacity, is_available, image) VALUES (?, ?, ?, ?, ?)";
    const values = [
        name,
        description || '',
        parseInt(capacity) || 1,
        availableValue,
        image || null
    ];

    con.query(sql, values, function (err, result) {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: "Database server error", details: err.message });
        }

        res.status(201).json({
            message: "Room added successfully",
            roomId: result.insertId
        });
    });
});

// Update room (for staff to edit room details including image)
app.put('/rooms/:id', (req, res) => {
    const roomId = req.params.id;
    const { name, description, capacity, is_available, image } = req.body;

    // Check if it's a status-only update (for toggle switch)
    if (is_available !== undefined && !name && !description && !capacity) {
        // Status-only update
        const availableValue = is_available ? 1 : 0;
        const sql = "UPDATE rooms SET is_available = ? WHERE room_id = ?";
        con.query(sql, [availableValue, roomId], function (err, result) {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: "Database server error" });
            }

            if (result.affectedRows === 0) {
                return res.status(404).json({ error: "Room not found" });
            }

            res.json({
                message: "Room status updated successfully",
                roomId: roomId,
                is_available: availableValue
            });
        });
    } else {
        // Full room update (including image)
        const updates = [];
        const values = [];

        if (name !== undefined) {
            updates.push("name = ?");
            values.push(name);
        }
        if (description !== undefined) {
            updates.push("description = ?");
            values.push(description);
        }
        if (capacity !== undefined) {
            updates.push("capacity = ?");
            values.push(parseInt(capacity));
        }
        if (is_available !== undefined) {
            updates.push("is_available = ?");
            values.push(is_available ? 1 : 0);
        }
        if (image !== undefined) {
            updates.push("image = ?");
            values.push(image);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: "No fields to update" });
        }

        values.push(roomId);
        const sql = `UPDATE rooms SET ${updates.join(', ')} WHERE room_id = ?`;

        con.query(sql, values, function (err, result) {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: "Database server error", details: err.message });
            }

            if (result.affectedRows === 0) {
                return res.status(404).json({ error: "Room not found" });
            }

            res.json({
                message: "Room updated successfully",
                roomId: roomId
            });
        });
    }
});

// --- ⬇️ NEW/MODIFIED ENDPOINTS BASED ON REQUIREMENTS ⬇️ ---

/**
 * GET /dashboard/stats
 * Lecturer/Staff. Return aggregated counts for dashboard (pending/reserved/disabled/free slots).
 * Now includes time-based disabled slots (past time slots are counted as disabled).
 * Response: { pending_slots, reserved_slots, disabled_rooms, free_slots }
 */
app.get('/dashboard/stats', async (req, res) => {
    const TIME_SLOTS = [
        { start: '08:00', end: '10:00' },
        { start: '10:00', end: '12:00' },
        { start: '13:00', end: '15:00' },
        { start: '15:00', end: '17:00' }
    ];

    try {
        // Get current date and time
        const now = new Date();
        const currentDate = now.toISOString().split('T')[0]; // YYYY-MM-DD
        const currentHour = now.getHours();
        const currentMinute = now.getMinutes();

        // Helper function to check if time has passed
        const hasTimePassed = (endTime) => {
            const [endHour, endMinute] = endTime.split(':').map(Number);
            if (currentHour > endHour) return true;
            if (currentHour === endHour && currentMinute >= endMinute) return true;
            return false;
        };

        // 1. Get all data in parallel
        const [
            [disabledRoomsResult],
            [availableRoomsResult],
            [pendingSlotsResult],
            [reservedSlotsResult]
        ] = await Promise.all([
            // 1. Count physically disabled rooms
            con.promise().query("SELECT COUNT(*) as count FROM rooms WHERE is_available = 0"),

            // 2. Count available rooms
            con.promise().query("SELECT COUNT(*) as count FROM rooms WHERE is_available = 1"),

            // 3. Count pending slots for today
            con.promise().query("SELECT COUNT(*) as count FROM bookings WHERE status = 'pending' AND DATE(booking_date) = CURDATE()"),

            // 4. Count reserved slots for today
            con.promise().query("SELECT COUNT(*) as count FROM bookings WHERE status = 'approved' AND DATE(booking_date) = CURDATE()")
        ]);

        const disabledRoomCount = disabledRoomsResult[0].count;
        const availableRoomCount = availableRoomsResult[0].count;
        const pendingSlotCount = pendingSlotsResult[0].count;
        const reservedSlotCount = reservedSlotsResult[0].count;

        // 2. Calculate time-based disabled slots
        let timeBasedDisabledSlots = 0;
        for (const slot of TIME_SLOTS) {
            if (hasTimePassed(slot.end)) {
                // Each passed time slot affects all available rooms
                timeBasedDisabledSlots += availableRoomCount;
            }
        }

        // 3. Calculate stats
        const totalSlots = availableRoomCount * TIME_SLOTS.length;
        const totalDisabledSlots = (disabledRoomCount * TIME_SLOTS.length) + timeBasedDisabledSlots;
        const totalFreeSlots = totalSlots - pendingSlotCount - reservedSlotCount - timeBasedDisabledSlots;

        // 4. Send response
        res.json({
            message: "Dashboard stats retrieved",
            pending_slots: pendingSlotCount,
            reserved_slots: reservedSlotCount,
            disabled_rooms: Math.floor(totalDisabledSlots / TIME_SLOTS.length), // Convert slots to room count for display
            free_slots: Math.max(0, totalFreeSlots) // Ensure non-negative
        });

    } catch (err) {
        console.error('Database error in /dashboard/stats:', err);
        res.status(500).json({ error: "DB error", details: err.message });
    }
});

/**
 * GET /rooms/slots
 * Public/Lecturer. Return each room with time slots and slot status for a specific date (free/pending/reserved/disabled).
 * Query params: ?date=YYYY-MM-DD (optional, defaults to today)
 * Response: { message, date, rooms: [{ room_id, name, time_slots: [{time, status}] }] }
 */
app.get('/rooms/slots', (req, res) => {
    // Get date from query parameter or use current date
    const requestedDate = req.query.date || new Date().toISOString().split('T')[0];
    
    const roomsSql = "SELECT room_id, name, capacity, is_available FROM rooms";
    // Query bookings for the specific date using DATE() to ignore timezone issues
    // Only include pending and approved bookings (exclude rejected and cancelled)
    const bookingsSql = "SELECT room_id, time_slot, status FROM bookings WHERE DATE(booking_date) = ? AND status IN ('pending', 'approved')";

    con.query(roomsSql, (err, rooms) => {
        if (err) return res.status(500).json({ error: "DB error (rooms)" });
        con.query(bookingsSql, [requestedDate], (err, bookings) => {
            if (err) return res.status(500).json({ error: "DB error (bookings)" });

            // Get current date and time for comparison
            const now = new Date();
            const todayStr = now.toISOString().split('T')[0];
            const isToday = requestedDate === todayStr;
            const currentHour = now.getHours();
            const currentMinute = now.getMinutes();
            
            // Function to check if time slot has passed
            const hasTimePassed = (timeSlot) => {
                if (!isToday) return false; // Future dates are always available
                
                // Extract end time from slot (e.g., "08:00-10:00" -> "10:00")
                const endTime = timeSlot.split('-')[1];
                const [endHour, endMinute] = endTime.split(':').map(Number);
                
                // Check if current time is past the slot end time
                if (currentHour > endHour) return true;
                if (currentHour === endHour && currentMinute > endMinute) return true;
                return false;
            };

            // สร้าง time slots ตามข้อกำหนด
            const timeSlotsTemplate = ["08:00-10:00", "10:00-12:00", "13:00-15:00", "15:00-17:00"];

            const results = rooms.map(room => {
                const slots = timeSlotsTemplate.map(slot => {
                    let status = "free";

                    if (room.is_available === 0) {
                        status = "disabled";
                    } else if (hasTimePassed(slot)) {
                        // Time slot has passed - disable it
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

            // Add cache control headers to prevent caching of room status
            res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
            res.setHeader('Pragma', 'no-cache');
            res.setHeader('Expires', '0');
            
            res.json({ 
                message: "Rooms with time slots retrieved", 
                date: requestedDate,
                rooms: results 
            });
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
 * Query params: ?approverId=X (optional) - filter by specific approver (lecturer)
 * Response: { message, bookings: [...] }
 */
app.get('/bookings/history', (req, res) => {
    const approverId = req.query.approverId; // Get lecturer ID from query parameter
    
    let sql = `
        SELECT
            b.booking_id, b.user_id, b.room_id, b.status,
            b.booking_date, b.time_slot, b.reason,
            b.rejection_reason, b.approver_id,
            r.name as room_name, r.description, r.capacity,
            u_student.name as reserved_by,
            u_approver.name as approved_by
        FROM bookings b
        JOIN rooms r ON b.room_id = r.room_id
        JOIN users u_student ON b.user_id = u_student.user_id
        LEFT JOIN users u_approver ON b.approver_id = u_approver.user_id
        WHERE b.status IN ('approved', 'rejected')
    `;
    
    const params = [];
    
    // If approverId is provided, filter by that lecturer's actions only
    if (approverId) {
        sql += ` AND b.approver_id = ?`;
        params.push(approverId);
    }
    
    sql += ` ORDER BY b.booking_date DESC, b.time_slot DESC`;

    con.query(sql, params, (err, results) => {
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

    // Check if time slot has already passed (only for today)
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];
    
    if (booking_date === todayStr) {
        const endTime = time_slot.split('-')[1]; // e.g., "10:00" from "08:00-10:00"
        const [endHour, endMinute] = endTime.split(':').map(Number);
        const currentHour = now.getHours();
        const currentMinute = now.getMinutes();
        
        // Check if current time is past the slot end time
        if (currentHour > endHour || (currentHour === endHour && currentMinute > endMinute)) {
            return res.status(400).json({ error: 'Cannot book past time slots. This time slot has already passed.' });
        }
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
        
        // Notify all connected clients about cancellation
        broadcastEvent('booking_cancelled', { bookingId });
    });
});

// --- ⬆️ END OF NEW/MODIFIED ENDPOINTS ⬆️ ---
/* --- API ROUTES END --- */

// Auto-update config.dart when IP changes
let currentServerIP = getLocalIPAddress();

function checkAndUpdateIP() {
    const newIP = getLocalIPAddress();
    if (newIP !== currentServerIP && newIP !== '0.0.0.0') {
        console.log(`\n⚠️  Network change detected!`);
        console.log(`   Old IP: ${currentServerIP}`);
        console.log(`   New IP: ${newIP}`);
        
        currentServerIP = newIP;
        
        // Auto-update config.dart
        const { exec } = require('child_process');
        exec('node update-ip.js', (error, stdout, stderr) => {
            if (error) {
                console.error(`❌ Error updating config: ${error.message}`);
                return;
            }
            console.log(`✅ Config.dart updated automatically!`);
            console.log(`📱 New URL: http://${newIP}:${PORT}`);
        });
    }
}

// Check for IP changes every 15 seconds
setInterval(checkAndUpdateIP, 15000);

// Start server on port 3000
const PORT = 3000;
const HOST = '0.0.0.0'; // Listen on ALL network interfaces (allows any device to connect)

app.listen(PORT, HOST, () => {
    const localIP = getLocalIPAddress();
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║          📱 Mobile App Server - Ready for Connections      ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log(`\n🚀 Server running on: ${HOST}:${PORT}`);
    console.log(`📁 Database: mobi_app (Connected)\n`);
    
    console.log('🌐 Connect from ANY device using these URLs:\n');
    console.log(`   📱 Same Network:     http://${localIP}:${PORT}`);
    console.log(`   💻 This Computer:    http://localhost:${PORT}`);
    console.log(`   📲 Android Emulator: http://10.0.2.2:${PORT}`);
    console.log(`   🔍 Get Server IP:    http://${localIP}:${PORT}/server-ip\n`);
    
    console.log('📋 Connection Instructions:');
    console.log('   1. Make sure devices are on the SAME Wi-Fi network');
    console.log('   2. Check Windows Firewall allows port 3000');
    console.log(`   3. Use IP: ${localIP} in your Flutter app\n`);
    
    console.log('🔍 Auto-monitoring network changes (every 15s)...');
    console.log('═══════════════════════════════════════════════════════════\n');
});
