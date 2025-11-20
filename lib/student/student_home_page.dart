import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../config.dart';
import '../login_page.dart';

import 'student_room_page.dart';
import 'student_check_page.dart';
import 'student_history_page.dart';
import '../services/sse_service.dart';

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
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  String? _role;
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRoomsFromServer();
    _startClock();
    _loadRole();
    _startSse();
  }

  final SseService _sse = sseService;

  void _startSse() async {
    await _sse.connect();
    _sse.events.listen((msg) {
      final event = msg['event'];
      if (event == 'room_changed') {
        // refresh rooms on any room change
        _loadRoomsFromServer();
      } else if (event == 'booking_created' || event == 'booking_updated') {
        // optionally refresh bookings page or show notification
      }
    });
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? r = prefs.getString('role');
      setState(() {
        _role = r;
      });
    } catch (e) {
      // ignore and leave role null
    }
  }

  String _rolePurpose() {
    switch (_role) {
      case 'student':
        return 'Student — can book slots and view history.';
      case 'lecturer':
        return 'Lecturer — review and approve booking requests.';
      case 'staff':
        return 'Staff — manage rooms (add/edit/delete) and view dashboard.';
      default:
        return _role == null ? 'Role: not set' : 'Role: $_role';
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
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
        shadowColor: Colors.black.withAlpha((0.15 * 255).round()),
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
              color: Colors.red,
              size: 26,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text(
                    "Logout",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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

      // BODY: single-app PageView for smooth navigation between main sections
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        children: [
          // HOME (improved UI)
          Container(
            color: const Color(0xFFF8F9FB),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated Date Box
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(
                          DateFormat('EEE, MMM d, yyyy HH:mm').format(_now)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.06 * 255).round()),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: Colors.black54),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    DateFormat('EEE, MMM d, yyyy').format(_now),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(DateFormat('HH:mm:ss').format(_now),
                                        style: const TextStyle(
                                            color: Colors.black54)),
                                    Text(_rolePurpose(),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rooms grid with pull-to-refresh and smooth cards
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadRoomsFromServer,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: rooms.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return GestureDetector(
                            onTap: () {
                              // subtle tap animation then navigate to room page
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const StudentRoomPage()));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black
                                          .withAlpha((0.08 * 255).round()),
                                      blurRadius: 12,
                                      offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(14),
                                        topRight: Radius.circular(14)),
                                    child: Image.asset(room['image'],
                                        fit: BoxFit.cover,
                                        height: 110,
                                        width: double.infinity),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(room['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text(room['capacity'],
                                            style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ROOM PAGE
          const StudentRoomPage(),
          // CHECK REQUEST PAGE
          const StudentCheckPage(),
          // HISTORY PAGE
          const StudentHistoryPage(),
        ],
      ),

      // BOTTOM NAV BAR
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: (index) {
<<<<<<< HEAD
            setState(() => _currentIndex = index);
            _pageController.animateToPage(index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
=======
            if (index == 0) {
              // Already on Home, do nothing
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
>>>>>>> 799f64965b5f4f11c1671a1c22f4a0cfae077645
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
