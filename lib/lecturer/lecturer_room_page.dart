import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';

import 'lecturer_dashboard_page.dart';
import 'lecturer_approved_page.dart';
import 'lecturer_history_page.dart';

class LecturerRoomPage extends StatefulWidget {
  final String? filterStatus;

  const LecturerRoomPage({Key? key, this.filterStatus}) : super(key: key);

  @override
  State<LecturerRoomPage> createState() => _LecturerRoomPageState();
}

class _LecturerRoomPageState extends State<LecturerRoomPage> {
  // กำหนด Base URL และตัวแปร State
  final String baseUrl = apiBaseUrl; // centralized in lib/config.dart
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _activeFilter;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // set active filter from widget
    _activeFilter = widget.filterStatus;
    // เรียกฟังก์ชันใหม่เพื่อดึงข้อมูลสถานะห้องทั้งหมด
    _fetchRoomSlots();
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

  // สร้างฟังก์ชันใหม่สำหรับเรียก GET /rooms/slots
  Future<void> _fetchRoomSlots() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final headers = await _getAuthHeaders();
      // Format date as YYYY-MM-DD for API
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final response = await http
          .get(
        Uri.parse('$baseUrl/rooms/slots?date=$dateStr'),
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _rooms = data['rooms'];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) _logout();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Failed to load rooms: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('No token found')) {
        if (mounted) _logout();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              "Error loading rooms: ${e.toString().replaceAll('Exception: ', '')}";
          _isLoading = false;
        });
      }
    }
  }

  Color _getColor(String status) {
    switch (status) {
      case "free":
        return Colors.green;
      case "reserved": // API ส่ง 'reserved'
        return Colors.red;
      case "pending":
        return Colors.amber;
      case "disabled": // API ส่ง 'disabled'
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  //สร้างฟังก์ชัน Logout ใหม่ที่เคลียร์ SharedPreferences
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ล้างข้อมูลล็อกอินทั้งหมด

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ), // <-- This closing parenthesis was missing
      (route) => false,
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 26),
            tooltip: "Refresh",
            onPressed: _fetchRoomSlots,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
            tooltip: "Logout",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text(
                      "Are you sure you want to log out?"), // ❇️ 10. แก้ไขข้อความ
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout(); // เรียกใช้ฟังก์ชัน Logout ใหม่
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
        onRefresh: _fetchRoomSlots,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Date display (fixed to today, non-interactive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF3E7BFA), width: 2),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF3E7BFA), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Today: ${_formatDate(_selectedDate)}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E7BFA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                  : _errorMessage.isNotEmpty
                      ? Expanded(
                          child: Center(
                              child: Text(_errorMessage,
                                  style: const TextStyle(color: Colors.red))))
                      : _rooms.isEmpty
                          ? const Expanded(
                              child: Center(child: Text("No rooms found.")))
                          : Expanded(
                              child: Column(
                                children: [
                                  // สร้าง Header Row (Time Slots) จาก API
                                  SizedBox(
                                    height: 45,
                                    child: Row(
                                      children: [
                                        // "Room/Time" Header
                                        Container(
                                          width: 60, // ความกว้างเท่ากับชื่อห้อง
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.black26),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Text("Room",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87)),
                                          ),
                                        ),
                                        // Time Slots Headers
                                        Expanded(
                                          child: Row(
                                            children: (_rooms[0]['time_slots']
                                                    as List)
                                                .map<Widget>((slot) {
                                              return Expanded(
                                                child: Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 2),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors.black26),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Center(
                                                    child: Text(slot['time'],
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize:
                                                                11, // ❇️ ลดขนาด Fone
                                                            color: Colors
                                                                .black87)),
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

                                  // สร้าง List ของ Rooms และ Status
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _rooms.length,
                                      itemBuilder: (context, roomIndex) {
                                        final room = _rooms[roomIndex];
                                        final List<dynamic> slots =
                                            room['time_slots'];

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: room['status'] == 'disabled'
                                                ? Colors.grey.withOpacity(0.3)
                                                : Colors.blue.withOpacity(0.2),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              // Room Name
                                              SizedBox(
                                                width: 60,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      room["name"],
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    if (room['status'] == 'disabled')
                                                      const Text(
                                                        'Disabled',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Status Slots
                                              Expanded(
                                                child: Row(
                                                  children:
                                                      slots.map<Widget>((slot) {
                                                    String status =
                                                        slot['status'];

                                                    // If an active filter is set, only highlight matching slots.
                                                    final bool matchesFilter =
                                                        _activeFilter == null ||
                                                            status ==
                                                                _activeFilter;

                                                    Color cellColor;
                                                    String displayText;

                                                    if (room['status'] ==
                                                        'disabled') {
                                                      cellColor = Colors.grey;
                                                      displayText = 'Disabled';
                                                    } else if (!matchesFilter &&
                                                        _activeFilter != null) {
                                                      // subdued for non-matching when filter active
                                                      cellColor =
                                                          Colors.black12;
                                                      displayText = '-';
                                                    } else {
                                                      cellColor =
                                                          _getColor(status);
                                                      displayText = status == 'free' 
                                                          ? 'Free' 
                                                          : status == 'reserved' 
                                                              ? 'Busy' 
                                                              : status == 'pending'
                                                                  ? 'Pending'
                                                                  : status;
                                                    }

                                                    return Expanded(
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          // Show slot details on tap
                                                          if (status != '-') {
                                                            showDialog(
                                                              context: context,
                                                              builder: (context) => AlertDialog(
                                                                title: Text(
                                                                  '${room["name"]} - ${slot["time"]}',
                                                                  style: const TextStyle(
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                                content: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          status == 'free' 
                                                                            ? Icons.check_circle 
                                                                            : status == 'reserved'
                                                                                ? Icons.event_busy
                                                                                : Icons.pending,
                                                                          color: cellColor,
                                                                        ),
                                                                        const SizedBox(width: 8),
                                                                        Text(
                                                                          'Status: $displayText',
                                                                          style: TextStyle(
                                                                            fontWeight: FontWeight.bold,
                                                                            color: cellColor,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(context),
                                                                    child: const Text('Close'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        child: Container(
                                                          margin: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 2),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 10,
                                                                  horizontal: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: cellColor,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(6),
                                                            border: Border.all(
                                                              color: Colors.white,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(
                                                                status == 'free' 
                                                                  ? Icons.check_circle_outline 
                                                                  : status == 'reserved'
                                                                      ? Icons.cancel
                                                                      : status == 'pending'
                                                                          ? Icons.schedule
                                                                          : Icons.block,
                                                                color: Colors.white,
                                                                size: 16,
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                displayText,
                                                                textAlign:
                                                                    TextAlign.center,
                                                                style:
                                                                    const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600,
                                                                        fontSize: 10),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
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
            ],
          ),
        ),
      ),

      // แก้ไข BottomNavigationBar
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
          currentIndex: 1,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LecturerDashboardPage()));
            } else if (index == 1) {
              // อยู่หน้านี้แล้ว
            } else if (index == 2) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LecturerApprovedPage()));
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  // ไม่ต้องส่ง history ไปแล้ว เพราะ HistoryPage ดึงข้อมูลเอง
                  builder: (context) => const LecturerHistoryPage(),
                ),
              );
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Dashboard", // เปลี่ยนชื่อให้ตรงกับหน้าอื่น
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA726),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.meeting_room_outlined,
                    color: Colors.white),
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
