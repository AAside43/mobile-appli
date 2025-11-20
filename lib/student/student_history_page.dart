import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

import 'student_home_page.dart';
import 'student_room_page.dart';
import 'student_check_page.dart';
import '../login_page.dart';
import '../services/sse_service.dart';
import '../widgets/skeleton.dart';

class StudentHistoryPage extends StatefulWidget {
  const StudentHistoryPage({Key? key}) : super(key: key);

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  // ใช้ baseUrl จาก config.dart
  final String baseUrl = apiBaseUrl;

  List<Map<String, dynamic>> historyList = [];
  bool _isLoading = true;
  String _userRole = "student"; // เพิ่มตัวแปรเก็บ Role

  @override
  void initState() {
    super.initState();
    _loadBookingHistory();
    _sseSub = sseService.events.listen((msg) {
      final event = msg['event'];
      if (event == 'booking_created' || event == 'booking_updated') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(event == 'booking_created'
                  ? 'New booking created'
                  : 'Booking updated'),
              duration: const Duration(seconds: 2),
            ),
          );
          _loadBookingHistory();
        }
      } else if (event == 'room_changed') {
        if (mounted) _loadBookingHistory();
      }
    });
  }

  StreamSubscription? _sseSub;

  @override
  void dispose() {
    _sseSub?.cancel();
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

  // =============================
  // LOAD HISTORY FROM SERVER
  // =============================
  Future<void> _loadBookingHistory() async {
    try {
      // ดึง userId และ role จาก SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      final role = prefs.getString('role') ?? "student";
      if (userId == null) throw Exception('userId not found');

      // เพิ่ม Headers และใช้ baseUrl
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/bookings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> list = data["bookings"];

        setState(() {
          _userRole = role; // เก็บ role ไว้ใช้ใน UI
          historyList = list.map((b) {
            return {
              "booking_id": b["booking_id"].toString(),
              "room": b["room_name"] ?? "Unknown room",
              "room_id": b["room_id"]?.toString() ?? "",
              "description": b["description"] ?? "",
              "capacity": b["capacity"]?.toString() ?? "",
              "time": b["time_slot"],
              "date": b["booking_date"],
              "reason": b["reason"] ?? "",
              "status": b["status"] ?? "Pending",
              "reservedBy": b["reserved"] ?? "-",
              "approvedBy": b["approved"] ?? "-",
              "rejection_reason": b["rejection_reason"] ?? "",
            };
          }).toList();

          // sort: latest → oldest
          historyList.sort((a, b) {
            try {
              final da = DateFormat("MMM d, yyyy").parse(a["date"]);
              final db = DateFormat("MMM d, yyyy").parse(b["date"]);
              return db.compareTo(da);
            } catch (_) {
              return 0;
            }
          });

          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _logout(context);
      } else {
        print("❌ Server returned ${response.statusCode}");
        _useLocalHistory();
      }
    } catch (e) {
      print("❌ Error loading history: $e");
      _useLocalHistory();
    }
  }

  // Local fallback if server unreachable
  void _useLocalHistory() {
    final local = StudentRoomPage.getBookingHistory();
    setState(() {
      historyList = local;
      _isLoading = false;
    });
  }

  // =============================
  // STATUS COLOR
  // =============================
  Color _statusColor(String s) {
    s = s.toLowerCase();
    if (s == "approved") return Colors.green;
    if (s == "pending") return Colors.amber;
    if (s == "rejected") return Colors.red;
    if (s == "cancelled") return Colors.grey;
    return Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // =============================
      // APP BAR
      // =============================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "History",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                    TextButton(
                      child: const Text("Logout",
                          style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        _logout(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      // =============================
      // BODY
      // =============================
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(4, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SkeletonBox(height: 14, width: 24),
                                  SizedBox(width: 8),
                                  SkeletonBox(height: 14, width: 120),
                                ],
                              ),
                              SizedBox(height: 8),
                              SkeletonBox(height: 12, width: 80),
                              SizedBox(height: 6),
                              SkeletonBox(height: 12),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        SkeletonBox(height: 28, width: 60),
                      ],
                    ),
                  );
                }),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: historyList.isEmpty
                  ? const Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No history yet",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: historyList.length,
                      itemBuilder: (_, index) {
                        final item = historyList[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 6),
                            ],
                          ),

                          // =============================
                          // CARD BODY
                          // =============================
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT DETAILS
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.meeting_room,
                                            color: Color(0xFF3E7BFA)),
                                        const SizedBox(width: 8),
                                        Text(
                                          item["room"],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF3E7BFA),
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if ((item["date"] ?? "").isNotEmpty)
                                      Text("Date: ${item["date"]}"),
                                    if ((item["time"] ?? "").isNotEmpty)
                                      Text("Time: ${item["time"]}"),
                                    if ((item["description"] ?? "").isNotEmpty)
                                      Text(
                                          "Description: ${item["description"]}"),
                                    if ((item["reason"] ?? "").isNotEmpty)
                                      Text("Reason: ${item["reason"]}"),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Booking ID: ${item["booking_id"]}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                    ),
                                    if (_userRole != "student") ...[
                                      const SizedBox(height: 4),
                                      Text(
                                          "Reserved by: ${item["reservedBy"]}"),
                                      if ((item["approvedBy"] ?? "") != "")
                                        Text(
                                            "Approved by: ${item["approvedBy"]}"),
                                      if ((item["rejection_reason"] ?? "")
                                          .isNotEmpty)
                                        Text(
                                            "Rejection Reason: ${item["rejection_reason"]}"),
                                    ]
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // STATUS BADGE
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(item["status"]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item["status"],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

      // =============================
      // BOTTOM NAV
      // =============================
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
<<<<<<< HEAD
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, -2)),
=======
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
>>>>>>> 799f64965b5f4f11c1671a1c22f4a0cfae077645
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 3,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StudentHomePage()));
            } else if (index == 1) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StudentRoomPage()));
            } else if (index == 2) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StudentCheckPage()));
            } else if (index == 3) {
              // Already on History, do nothing
            }
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_filled), label: "Home"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.meeting_room_outlined), label: "Room"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rtl), label: "Check Request"),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA726),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, color: Colors.white),
              ),
              label: "History",
            ),
          ],
        ),
      ),
    );
  }
}
