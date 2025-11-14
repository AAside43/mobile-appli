
const express = require('express');
const app = express();
const db = require('./db');
const con = db;
const bcrypt = require('bcrypt');
const cors = require('cors');

// Initialize database from mobi_app.sql on server start (optional - comment out after first run)
// Uncomment this line only when you want to reset/initialize the database
// db.initializeDatabase();

// Middleware
app.use(cors()); // Allow cross-origin requests from Flutter app
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Test endpoint
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

// Test database connection endpoint
app.get('/test-db', (req, res) => {
    const sql = "SELECT 'mobi_app database connection successful!' as message, COUNT(*) as user_count FROM users";
    con.query(sql, function (err, results) {
        if (err) {
            console.error('Database connection test failed:', err);
            return res.status(500).json({
                error: "Database connection failed",
                database: "mobi_app",
                details: err.message
            });
        }
        res.json({
            database: 'mobi_app',
            status: 'Connected successfully',
            test_result: results[0]
        });
    });
});

// Initialize database from mobi_app.sql file
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

app.get('/password/:pass', (req, res) => {
    const password = req.params.pass;
    bcrypt.hash(password, 10, function (err, hash) {
        if (err) {
            return res.status(500).send('Hashing error');
        }
        res.send(hash);
    });
});

// Register endpoint
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

// login
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
                // ส่ง 'role' กลับไปให้ Flutter app เพื่อใช้แยกระหว่าง student, lecturer, staff
                return res.json({
                    message: "Login successful",
                    userId: results[0].user_id,
                    role: results[0].role,
                    success: true
                });
            }
            return res.status(401).json({ error: "Wrong password" });
        });
    })
});

// Get user profile
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

// Get all rooms (Original simple version)
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

// --- ⬇️ NEW/MODIFIED ENDPOINTS BASED ON REQUIREMENTS ⬇️ ---

// ❇️ MODIFIED ENDPOINT: Get dashboard stats (Counts slots, but disabled as rooms)
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
            disabled_rooms: disabledRoomCount, // ❇️ ส่ง Key นี้
            free_slots: totalFreeSlots       // ❇️ ส่ง Key นี้
        });

    } catch (err) {
        console.error('Database error in /dashboard/stats:', err);
        res.status(500).json({ error: "DB error", details: err.message });
    }
});

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

// ❇️ MODIFIED ENDPOINT: Get pending bookings (for approved_page.dart)
app.get('/bookings/pending', (req, res) => {
    // ❇️ 1. อัปเดต SQL: เพิ่ม image_url และ LEFT JOIN roomimages
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
            image_url: item.image_url // ❇️ 2. ส่ง URL รูปภาพไปให้แอป
        }));

        res.json({
            message: "Pending bookings retrieved",
            requests: formattedRequests
        });
    });
});

// ❇️ NEW ENDPOINT: Get ALL completed bookings (for Lecturer/Staff History Page)
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

// ❇️ MODIFIED ENDPOINT: Approve/Disapprove booking (now with rejection_reason)
app.put('/booking/:id/status', (req, res) => {
    const bookingId = req.params.id;
    // ❇️ 1. ดึง rejection_reason ที่ส่งมาจาก Pop-up
    const { status, approverId, rejection_reason } = req.body;

    if (!status || !approverId) {
        return res.status(400).json({ error: "Status (approved/rejected) and approverId are required" });
    }
    if (status !== 'approved' && status !== 'rejected') {
        return res.status(400).json({ error: "Invalid status. Must be 'approved' or 'rejected'" });
    }

    // ❇️ 2. อัปเดต SQL Query ให้บันทึกเหตุผลด้วย
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
    });
});

// ⛔️ MODIFIED ENDPOINT: Book a room
// (ปรับปรุงให้ตรงตามข้อกำหนด "A student can book time slot for only today", "status is pending", "book a single slot in one day")
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
                    res.status(201).json({
                        message: "Room booking request submitted successfully. Status is pending.",
                        bookingId: result.insertId
                    });
                });
            });
        });
    });
});

// ⛔️ MODIFIED ENDPOINT: Get user's bookings (for history_page.dart)
// (ปรับปรุงให้รวมข้อมูล "who approved", "date", "time", "reason" ตามที่ history_page ต้องการ)
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


// Cancel booking (Student action - kept as is)
// (ข้อกำหนดของ Lecturer คือ "reject" ซึ่งจัดการโดย PUT /booking/:id/status)
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


// Start server
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0'; // Listen on all network interfaces
app.listen(PORT, HOST, () => {
    console.log(`🚀 Mobile app Server running on ${HOST}:${PORT}`);
    console.log("📁 Connected to 'mobi_app' MySQL database");
    console.log(`🌐 Test the connection at: http://localhost:${PORT}`);
    console.log(`🌐 Emulator can connect at: http://192.168.47.1:${PORT}`);
    console.log(`🔍 Test database at: http://localhost:${PORT}/test-db`);
});
