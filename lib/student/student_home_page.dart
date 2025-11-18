import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';

import 'student_room_page.dart';
import 'student_check_page.dart';
import 'student_history_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({Key? key}) : super(key: key);

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  // ใช้ baseUrl จาก config.dart
  final String baseUrl = apiBaseUrl;
  bool _isLoading = true;
  List<Map<String, dynamic>> rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRoomsFromServer();
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

  // 5. เพิ่มฟังก์ชัน _logout (จากข้อ 5)
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // ลบข้อมูลทั้งหมดที่เกี่ยวข้องกับการ Login
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('role');
    await prefs.setBool('isLoggedIn', false);

    if (!context.mounted) return;

    // กลับไปหน้า Login และลบหน้าเก่าๆ ทิ้งทั้งหมด
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // (route) => false คือการลบทุกหน้าใน Stack
    );
  }

// 7. แก้ไข _loadRoomsFromServer ให้ส่ง Token
  Future<void> _loadRoomsFromServer() async {
    try {
      final headers = await _getAuthHeaders(); // ดึง Header ที่มี Token

      final response = await http.get(
        Uri.parse('$baseUrl/rooms'), // ใช้ baseUrl
        headers: headers, // ใส่ Header
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> roomsData = data['rooms'];

        setState(() {
          rooms = roomsData.map((room) {
            return {
              "room_id": room['room_id'].toString(),
              "name": room['name'],
              "capacity": "${room['capacity']} people",
              "description": room['description'] ?? '',
              "is_available": room['is_available'] == 1,
              "image": _getDefaultImage(room['room_id'])
            };
          }).toList();
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // 401 = Unauthorized (Token หมดอายุหรือToken ไม่ถูกต้อง)
        // ให้เด้งกลับไปหน้า Login
        _logout(context);
      } else {
        _useDefaultRooms();
      }
    } catch (e) {
      // ถ้า server เชื่อมต่อไม่ได้ หรือเกิด Error อื่นๆ
      print('Error loading rooms: $e');
      _useDefaultRooms();
    }
  }

  String _getDefaultImage(int roomId) {
    // Map room IDs to local images
    switch (roomId % 3) {
      case 1:
        return "assets/images/Room1.jpg";
      case 2:
        return "assets/images/Room2.jpg";
      default:
        return "assets/images/Room3.jpg";
    }
  }

  void _useDefaultRooms() {
    setState(() {
      rooms = [
        {
          "name": "Room 1",
          "capacity": "4 people",
          "image": "assets/images/Room1.jpg"
        },
        {
          "name": "Room 2",
          "capacity": "8 people",
          "image": "assets/images/Room2.jpg"
        },
        {
          "name": "Room 3",
          "capacity": "16 people",
          "image": "assets/images/Room3.jpg"
        },
        {
          "name": "Room 4",
          "capacity": " 4 seats",
          "image": "assets/images/Room1.jpg"
        },
        {
          "name": "101 study room",
          "capacity": "Comfortable room with seat and television",
          "image": "assets/images/Room2.jpg"
        },
        {
          "name": "102 meeting room",
          "capacity": "10 seat",
          "image": "assets/images/Room3.jpg"
        },
        {
          "name": "103 enteraining space",
          "capacity": "16 people",
          "image": "assets/images/Room3.jpg"
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty && !_isLoading) {
      _useDefaultRooms();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        title: const Text(
          "Home",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.red, // สีแดง
              size: 26,
            ),
            onPressed: () {
              // popup ยืนยันก่อนออก
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  // ใช้ dialogContext
                  title: const Text(
                    "Logout",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext), // ❇️ ปิด dialog
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      // 8. แก้ไขปุ่ม Logout
                      onPressed: () {
                        // ไม่ต้อง pop(dialogContext) เพราะ _logout จะนำทางออกไปเลย
                        _logout(context); // เรียกใช้ฟังก์ชัน _logout
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

      // BODY
      body: Container(
        color: const Color(0xFFF8F9FB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Box
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.calendar_today_outlined, color: Colors.black54),
                    SizedBox(width: 10),
                    Text(
                      "Today: Nov 21, 2025",
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Grid of Rooms
              Expanded(
                child: GridView.builder(
                  itemCount: rooms.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ภาพห้องให้ลอยมีเงา
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    rooms[index]["image"],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rooms[index]["name"],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "Capacity : ${rooms[index]["capacity"]}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // BOTTOM NAV BAR
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
          currentIndex: 0, // ✅ หน้านี้คือ Home
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const StudentHomePage()));
            } else if (index == 1) {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const StudentRoomPage()));
            } else if (index == 2) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StudentCheckPage()));
            } else if (index == 3) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StudentHistoryPage()));
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA726),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_filled, color: Colors.white),
              ),
              label: "Home",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined),
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
