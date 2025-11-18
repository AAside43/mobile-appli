import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';
import 'package:intl/intl.dart';

import 'student_home_page.dart';
import 'student_check_page.dart';
import 'student_history_page.dart';

class StudentRoomPage extends StatefulWidget {
  const StudentRoomPage({Key? key}) : super(key: key);

  // ใช้ Static Getter ให้หน้าอื่นเรียกข้อมูลได้โดยตรง
  static List<Map<String, String>> getBookingHistory() =>
      _StudentRoomPageState._bookingHistory;

  @override
  State<StudentRoomPage> createState() => _StudentRoomPageState();

  // ให้หน้าอื่นสามารถรีเซ็ตค่าทุกอย่างได้
  static void resetAll() {
    _StudentRoomPageState._resetStatic();
  }
}

class _StudentRoomPageState extends State<StudentRoomPage> {
  bool _isLoading = true;
  bool _hasActiveBooking = false;
  final String baseUrl = apiBaseUrl;

  // ตัวแปรเก็บประวัติการจอง (แชร์ข้ามหน้า)
  static List<Map<String, String>> _bookingHistory = [];

  final List<String> timeSlots = [
    '08:00-10:00',
    '10:00-12:00',
    '13:00-15:00',
    '15:00-17:00',
  ];

  // ตารางห้องแบบ Static เพื่อจำสถานะข้ามหน้า
  static List<Map<String, dynamic>> rooms = [
    {
      "name": "Room 1",
      "status": ["Free", "Free", "Free", "Free"]
    },
    {
      "name": "Room 2",
      "status": ["Free", "Free", "Free", "Free"]
    },
    {
      "name": "Room 3",
      "status": ["Disabled", "Disabled", "Disabled", "Disabled"]
    },
    {
      "name": "Room 4",
      "status": ["Free", "Free", "Free", "Free"]
    },
    {
      "name": "Study room",
      "status": ["Free", "Free", "Free", "Free"]
    },
    {
      "name": "meeting room",
      "status": ["Free", "Free", "Free", "Free"]
    },
    {
      "name": "entertaining space",
      "status": ["Disable", "Disable", "Disable", "Disable"]
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ฟังก์ชันสำหรับดึง Token มาสร้าง Headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      // ถ้าไม่มี Token (ไม่ควรเกิดขึ้น) ให้ส่งกลับไปหน้า Login
      // เราใช้ context.mounted เพื่อความปลอดภัย แม้ว่าอาจจะต้องส่ง context เข้ามา
      throw Exception('No token found');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // เรียก API ทั้งสองอย่างพร้อมกัน
      await Future.wait([
        _loadRoomsFromServer(),
        _loadBookingsFromServer(),
      ]);
    } catch (e) {
      print("Error loading data: $e");
      // ถ้า Error (เช่น 401) _logout จะถูกเรียกจากข้างในแล้ว
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // เพิ่มฟังก์ชัน _logout (เหมือนใน home_page)
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('role');
    await prefs.setBool('isLoggedIn', false);

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // ============================
  //   LOAD ROOMS FROM SERVER
  // ============================
  Future<void> _loadRoomsFromServer() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/rooms'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> roomsData = data['rooms'];
        // Update static rooms with database data
        rooms = roomsData.map((room) {
          return {
            "room_id": room['room_id'].toString(),
            "name": room['name'],
            "is_available": room['is_available'] == 1,
            "status": ["Free", "Free", "Free", "Free"]
          };
        }).toList();
      } else if (response.statusCode == 401) {
        _logout(context); // Token หมดอายุ
      } else {
        print('Failed to load rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  // ============================
  //   LOAD BOOKINGS (TODAY)
  // ============================
  Future<void> _loadBookingsFromServer() async {
    try {
      // ดึง userId จาก SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) throw Exception('userId not found');

      // เพิ่ม Headers และใช้ baseUrl
      final headers = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/user/$userId/bookings'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> bookingsData = data['bookings'] ?? [];

        final DateTime today = DateTime.now();
        _hasActiveBooking = false;

        // รีเซ็ตสถานะห้องทั้งหมดเป็น Free ก่อน
        for (var room in rooms) {
          room['status'] = ["Free", "Free", "Free", "Free"];
        }

        for (var booking in bookingsData) {
          final String status = (booking['status'] ?? '').toString();
          final String dateStr = (booking['date'] ?? '').toString();
          final String roomId = booking['room_id']?.toString() ?? '';
          final String timeSlot = (booking['time'] ?? '').toString();

          DateTime? bookingDate;
          try {
            bookingDate = DateFormat('MMM d, yyyy', 'en_US')
                .parse(dateStr, true)
                .toLocal();
          } catch (_) {
            bookingDate = null;
          }

          if (bookingDate == null ||
              bookingDate.year != today.year ||
              bookingDate.month != today.month ||
              bookingDate.day != today.day) {
            continue;
          }
          if (status == 'Pending' || status == 'Approved') {
            _hasActiveBooking = true;
          }
          for (var room in rooms) {
            if (room['room_id']?.toString() == roomId) {
              List<String> statusList =
                  List<String>.from(room['status'] as List);
              final int timeIndex = timeSlots.indexOf(timeSlot);
              if (timeIndex != -1) {
                statusList[timeIndex] =
                    status == 'Pending' ? 'Pending' : 'Reserved';
                room['status'] = statusList;
              }
              break;
            }
          }
        }
      } else if (response.statusCode == 401) {
        _logout(context); // Token หมดอายุ
      } else {
        print('Failed to load bookings: ${response.statusCode}');
        _hasActiveBooking = false;
      }
    } catch (e) {
      print('Error loading bookings: $e');
      _hasActiveBooking = false;
    }
  }

  // ============================
  //   STATUS COLOR
  // ============================
  Color _getColor(String status) {
    switch (status) {
      case "Free":
        return Colors.green;
      case "Pending":
        return Colors.amber;
      case "Reserved":
        return Colors.red;
      case "Disabled":
      case "Disable":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // ============================
  //   BOOKING DIALOG
  // ============================
  void _showBookingDialog(String roomName, String timeSlot) {
    // ถ้าวันนี้จองแล้ว 1 ครั้ง -> ไม่ให้จองเพิ่ม
    if (_hasActiveBooking) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.red, size: 28),
                SizedBox(width: 10),
                Text(
                  "Booking Limit Reached",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const Text(
              "You can book only once per day.\nPlease try again tomorrow.",
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "OK",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    // หา room_id จากชื่อห้อง
    String? roomId;
    for (var room in rooms) {
      if (room["name"] == roomName) {
        roomId = room["room_id"]?.toString();
        break;
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Column(
            children: [
              Text(
                "Booking $roomName",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                "Time : $timeSlot",
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: "Enter reason for booking...",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                Navigator.pop(context);

                final String bookingDateStr =
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
                if (roomId != null) {
                  try {
                    // ดึง userId จาก SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    final userId = prefs.getInt('userId');
                    if (userId == null) throw Exception('userId not found');

                    // เพิ่ม Headers และใช้ baseUrl
                    final headers = await _getAuthHeaders();
                    final response = await http.post(
                      Uri.parse('$baseUrl/book-room'),
                      headers: headers,
                      body: json.encode({
                        'userId': userId,
                        'roomId': int.parse(roomId),
                        'booking_date': bookingDateStr,
                        'time_slot': timeSlot,
                        'reason': reason.isEmpty ? null : reason,
                      }),
                    );

                    if (response.statusCode == 201) {
                      final data = json.decode(response.body);

                      // โหลด booking ใหม่จาก server เพื่ออัปเดตตาราง + _hasActiveBooking
                      await _loadBookingsFromServer();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "✅ ${data['message'] ?? 'Booking sent for approval!'}",
                            textAlign: TextAlign.center,
                          ),
                          backgroundColor: Colors.amber,
                        ),
                      );
                    } else if (response.statusCode == 409) {
                      // ซ้ำวันเดียวกันจากฝั่ง server
                      final data = json.decode(response.body);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            data['error'] ??
                                'You have already booked a slot for today.',
                            textAlign: TextAlign.center,
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      // บังคับ flag ว่ามี active booking
                      setState(() {
                        _hasActiveBooking = true;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Booking failed. Please try again.',
                            textAlign: TextAlign.center,
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cannot connect to server.',
                          textAlign: TextAlign.center,
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }

                // เก็บประวัติฝั่ง client ไว้ใช้ข้ามหน้า (ถ้าหน้าอื่นเรียกใช้)
                final prefs = await SharedPreferences.getInstance();
                final String username =
                    prefs.getString('username') ?? "Student";
                setState(() {
                  _bookingHistory.add({
                    "room": roomName,
                    "time": timeSlot,
                    "reason": reason.isEmpty ? "—" : reason,
                    "status": "Pending",
                    "reservedBy": username,
                    "approvedBy": "Lecturer CE",
                  });

                  // อัปเดตสีใน UI ทันทีช่องที่กด ให้เป็น Pending
                  for (var room in rooms) {
                    if (room["name"] == roomName) {
                      int timeIndex = timeSlots.indexOf(timeSlot);
                      if (timeIndex != -1 &&
                          room["status"][timeIndex] == "Free") {
                        room["status"][timeIndex] = "Pending";
                      }
                      break;
                    }
                  }

                  // ตั้ง flag ว่าวันนี้มีการจองแล้ว
                  _hasActiveBooking = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  "Book Now",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  // รีเซ็ตข้อมูลตอน Logout
  void _resetAll() {
    setState(() {
      _resetStatic();
    });
  }

  // ฟังก์ชัน static สำหรับใช้รีเซ็ตข้อมูลจากหน้าอื่น (ไม่ต้อง setState)
  static void _resetStatic() {
    _bookingHistory.clear();
    rooms = [
      {
        "name": "Room 1",
        "status": ["Free", "Free", "Free", "Free"]
      },
      {
        "name": "Room 2",
        "status": ["Free", "Free", "Free", "Free"]
      },
      {
        "name": "Room 3",
        "status": ["Free", "Free", "Free", "Free"]
      },
      {
        "name": "Room 4",
        "status": ["Free", "Free", "Free", "Free"]
      },
      {
        "name": "Study room",
        "status": ["Free", "Free", "Free", "Free"]
      },
      {
        "name": "meeting room",
        "status": ["Free", "Free", "Free", "Free"]
      },
      {
        "name": "entertaining space",
        "status": ["Disable", "Disable", "Disable", "Disable"]
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String todayText = DateFormat('MMM d, yyyy').format(DateTime.now());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Room",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue, size: 26),
            onPressed: () async {
              // แก้ไข refresh ให้เรียก _loadAllData
              await _loadAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Refreshed!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        _logout(context);
                      },
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadRoomsFromServer();
          await _loadBookingsFromServer();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // แถบเตือนว่ามีการจองวันนี้แล้ว
              if (_hasActiveBooking)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You already have a booking today. You can book only once per day.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // กล่อง Today: Oct 5, 2025
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.black54, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      "Today: $todayText",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // HEADER ROW
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // ====== ROOM BOX ======
                    SizedBox(
                      width: 80,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black26, width: 1),
                        ),
                        child: const Center(
                          child: Text(
                            "Room",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // ====== TIME SLOTS BOXES ======
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: timeSlots.map((slot) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.black26, width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  slot,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 1, height: 20),

              // LIST ROOMS
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (context, roomIndex) {
                          final room = rooms[roomIndex];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    room["name"],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      room["status"].length,
                                      (statusIndex) {
                                        String status =
                                            room["status"][statusIndex];
                                        bool isFree = status == "Free";
                                        bool canBook =
                                            isFree && !_hasActiveBooking;

                                        return Expanded(
                                          child: GestureDetector(
                                            onTap: canBook
                                                ? () => _showBookingDialog(
                                                      room["name"],
                                                      timeSlots[statusIndex],
                                                    )
                                                : isFree && _hasActiveBooking
                                                    ? () {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              '⚠️ You already have a booking today.',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                            backgroundColor:
                                                                Colors.orange,
                                                            duration: Duration(
                                                                seconds: 2),
                                                          ),
                                                        );
                                                      }
                                                    : null,
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: _getColor(status),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 1,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StudentHomePage()),
              );
            } else if (index == 1) {
              // อยู่หน้า Room อยู่แล้ว
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StudentCheckPage()),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StudentHistoryPage()),
              );
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA726),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: Colors.white,
                ),
              ),
              label: "Room",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.checklist_rtl),
              label: "Check Request",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
          ],
        ),
      ),
    );
  }
}
