import 'package:flutter/material.dart';
import 'package:mobile_appli_1/student/home_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ignore: unused_import
import 'home_page.dart';
import 'checkrequest_page.dart';
import 'history_page.dart';
import '../login_page.dart';
import 'user_session.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({Key? key}) : super(key: key);

  // ✅ ใช้ Static Getter ให้หน้าอื่นเรียกข้อมูลได้โดยตรง
  static List<Map<String, String>> getBookingHistory() =>
      _RoomPageState._bookingHistory;

  @override
  State<RoomPage> createState() => _RoomPageState();

  // ✅ เพิ่มฟังก์ชันนี้ เพื่อให้หน้าอื่นสามารถรีเซ็ตค่าทุกอย่างได้
  static void resetAll() {
    _RoomPageState._resetStatic();
  }
}

class _RoomPageState extends State<RoomPage> {
  bool _isLoading = true;
  bool _hasActiveBooking = false; // Track if user has active bookings

  // Server URL - use 10.0.2.2 for Android emulator
  static const String serverUrl = 'http://192.168.57.1:3000';

  // 🧠 ตัวแปรเก็บประวัติการจอง (แชร์ข้ามหน้า)
  static List<Map<String, String>> _bookingHistory = [];

  final List<String> timeSlots = [
    '08:00-10:00',
    '10:00-12:00',
    '13:00-15:00',
    '15:00-17:00',
  ];

  // ✅ ตารางห้องแบบ Static เพื่อจำสถานะข้ามหน้า
  static List<Map<String, dynamic>> rooms = [
    {
      "name": "Room 1",
      "status": ["Free", "Reserved", "Reserved", "Reserved"]
    },
    {
      "name": "Room 2",
      "status": ["Free", "Free", "Pending", "Reserved"]
    },
    {
      "name": "Room 3",
      "status": ["Disabled", "Disabled", "Disabled", "Disabled"]
    },
    {
      "name": "Room 4",
      "status": ["Free", "Pending", "Free", "Free"]
    },
    {
      "name": "Room 5",
      "status": ["Pending", "Free", "Reserved", "Free"]
    },
    {
      "name": "Room 6",
      "status": ["Free", "Free", "Free", "Pending"]
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRoomsFromServer();
    _loadBookingsFromServer();
  }

  // Load rooms from server
  Future<void> _loadRoomsFromServer() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/rooms'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> roomsData = data['rooms'];
        
        setState(() {
          // Update static rooms with database data
          rooms = roomsData.map((room) {
            return {
              "room_id": room['room_id'].toString(),
              "name": room['name'],
              "is_available": room['is_available'] == 1,
              "status": ["Free", "Free", "Free", "Free"] // Default to Free for all slots
            };
          }).toList();
        });
      } else {
        // Server returned error
        print('Failed to load rooms: ${response.statusCode}');
      }
    } catch (e) {
      // If server is not available, use static data
      print('Error loading rooms: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load bookings from server and update room statuses
  Future<void> _loadBookingsFromServer() async {
    try {
      // Get all bookings for current user
      final userId = UserSession.userId ?? 1;
      final response = await http.get(
        Uri.parse('$serverUrl/user/$userId/bookings'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> bookingsData = data['bookings'];
        
        setState(() {
          // Reset all room statuses to Free first
          for (var room in rooms) {
            room['status'] = ["Free", "Free", "Free", "Free"];
          }
          
          // Check if user has any active bookings (pending or confirmed, NOT cancelled)
          _hasActiveBooking = bookingsData.any((booking) => 
            booking['status'] == 'pending' || booking['status'] == 'confirmed'
          );
          
          // Update room statuses based on ACTIVE bookings only
          for (var booking in bookingsData) {
            String status = booking['status']?.toString() ?? '';
            
            // Skip cancelled bookings
            if (status == 'cancelled') continue;
            
            String roomId = booking['room_id']?.toString() ?? '';
            
            // Find matching room and update first available slot
            for (var room in rooms) {
              if (room['room_id'] == roomId) {
                // Update first Free slot with booking status
                List<String> statusList = List<String>.from(room['status']);
                for (int i = 0; i < statusList.length; i++) {
                  if (statusList[i] == "Free") {
                    statusList[i] = status == 'pending' ? 'Pending' : 'Reserved';
                    room['status'] = statusList;
                    break;
                  }
                }
                break;
              }
            }
          }
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
      // Continue without bookings if server unavailable
      setState(() {
        _hasActiveBooking = false;
      });
    }
  }

  Color _getColor(String status) {
    switch (status) {
      case "Free":
        return Colors.green;
      case "Reserved":
        return Colors.red;
      case "Pending":
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // ✅ Popup จองห้อง
  void _showBookingDialog(String roomName, String timeSlot) {
    // Check if user already has an active booking
    if (_hasActiveBooking) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text("Cannot Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              "You already have an active booking. Please cancel your existing booking before making a new one.",
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Colors.orange)),
              ),
            ],
          );
        },
      );
      return;
    }
    
    final TextEditingController reasonController = TextEditingController();
    
    // Find room_id from roomName
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
              Text("Booking $roomName",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 6),
              Text("Time : $timeSlot",
                  style: const TextStyle(color: Colors.black54, fontSize: 14)),
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

                // Determine booking status based on user role
                // Students get 'pending' status, staff/lecturer get 'confirmed'
                String bookingStatus = UserSession.isStudent ? 'pending' : 'confirmed';
                String statusDisplay = UserSession.isStudent ? 'Pending' : 'Confirmed';

                // Book room via server if roomId exists
                if (roomId != null) {
                  try {
                    final response = await http.post(
                      Uri.parse('$serverUrl/book-room'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'userId': UserSession.userId ?? 1,
                        'roomId': int.parse(roomId),
                        'status': bookingStatus,
                      }),
                    );

                    if (response.statusCode == 201) {
                      final data = json.decode(response.body);
                      
                      // Reload bookings to update UI
                      await _loadBookingsFromServer();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            UserSession.isStudent
                                ? "✅ Booking sent for approval!"
                                : "✅ ${data['message']}",
                            textAlign: TextAlign.center,
                          ),
                          backgroundColor: UserSession.isStudent ? Colors.amber : Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    // Handle offline mode
                  }
                }

                setState(() {
                  _bookingHistory.add({
                    "room": roomName,
                    "time": timeSlot,
                    "reason": reason.isEmpty ? "—" : reason,
                    "status": statusDisplay,
                    "reservedBy": UserSession.username ?? "Student A",
                    "approvedBy": "Lecturer CE",
                  });

                  for (var room in rooms) {
                    if (room["name"] == roomName) {
                      int timeIndex = timeSlots.indexOf(timeSlot);
                      if (timeIndex != -1 &&
                          room["status"][timeIndex] == "Free") {
                        // Set visual status based on user role
                        room["status"][timeIndex] = UserSession.isStudent ? "Pending" : "Reserved";
                      }
                      break;
                    }
                  }
                });

                // Don't show duplicate snackbar - already shown from API response
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text("Book Now", style: TextStyle(color: Colors.white)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  // ✅ รีเซ็ตข้อมูลตอน Logout
  void _resetAll() {
    setState(() {
      _resetStatic();
    });
  }

  // ✅ ฟังก์ชัน static สำหรับใช้รีเซ็ตข้อมูลจากหน้าอื่น (ไม่ต้อง setState)
  static void _resetStatic() {
    _bookingHistory.clear();
    rooms = [
      {
        "name": "Room 1",
        "status": ["Free", "Reserved", "Reserved", "Reserved"]
      },
      {
        "name": "Room 2",
        "status": ["Free", "Free", "Pending", "Reserved"]
      },
      {
        "name": "Room 3",
        "status": ["Disabled", "Disabled", "Disabled", "Disabled"]
      },
      {
        "name": "Room 4",
        "status": ["Free", "Pending", "Free", "Free"]
      },
      {
        "name": "Room 5",
        "status": ["Pending", "Free", "Reserved", "Free"]
      },
      {
        "name": "Room 6",
        "status": ["Free", "Free", "Free", "Pending"]
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Room",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue, size: 26),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadRoomsFromServer();
              await _loadBookingsFromServer();
              setState(() {
                _isLoading = false;
              });
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
                builder: (context) => AlertDialog(
                  title: const Text("Logout",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text(
                      "Are you sure you want to log out and reset all data?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetAll();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text("Logout",
                          style: TextStyle(color: Colors.red)),
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
              // Active booking warning banner
              if (_hasActiveBooking)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You have an active booking. Cancel it to book another room.",
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: Colors.black54, size: 18),
                  SizedBox(width: 8),
                  Text("Today: Oct 5, 2025",
                      style: TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                      width: 70,
                      child: Text("Room/Time",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  ...timeSlots.map((slot) => Expanded(
                        child: Center(
                            child: Text(slot,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13))),
                      )),
                ],
              ),
            ),
            const Divider(thickness: 1, height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (context, roomIndex) {
                  final room = rooms[roomIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 60,
                            child: Text(room["name"],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              room["status"].length,
                              (statusIndex) {
                                String status = room["status"][statusIndex];
                                bool canBook = status == "Free" && !_hasActiveBooking;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: canBook
                                        ? () => _showBookingDialog(
                                              room["name"],
                                              timeSlots[statusIndex],
                                            )
                                        : status == "Free" && _hasActiveBooking
                                            ? () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      '⚠️ You already have an active booking',
                                                      textAlign: TextAlign.center,
                                                    ),
                                                    backgroundColor: Colors.orange,
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            : null,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _getColor(status),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(status,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12)),
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
                  context, MaterialPageRoute(builder: (_) => const HomePage()));
            } else if (index == 1) {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const RoomPage()));
            } else if (index == 2) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const CheckRequestPage())); // ✅ หน้าเช็คคำขอ
            } else if (index == 3) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const HistoryPage())); // ✅ หน้าประวัติการจอง
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
                child:
                    const Icon(Icons.meeting_room_outlined, color: Colors.white),
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