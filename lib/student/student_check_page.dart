import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';

import 'student_room_page.dart';
import 'student_history_page.dart';
import 'student_home_page.dart';
import '../services/sse_service.dart';
import '../widgets/skeleton.dart';

class StudentCheckPage extends StatefulWidget {
  const StudentCheckPage({Key? key}) : super(key: key);

  @override
  State<StudentCheckPage> createState() => _StudentCheckPageState();
}

class _StudentCheckPageState extends State<StudentCheckPage> {
  // ใช้ baseUrl จาก config.dart
  final String baseUrl = apiBaseUrl;

  List<Map<String, dynamic>> requestList = [];
  bool _isLoading = true;
  String userRole = 'student';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadBookingRequests();
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
          _loadBookingRequests();
        }
      } else if (event == 'room_changed') {
        // rooms changed may affect requests listing in some setups
        if (mounted) _loadBookingRequests();
      }
    });
  }

  StreamSubscription? _sseSub;

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString('role') ?? 'student';
    });
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

  // เพิ่มฟังก์ชัน _getAuthHeaders (เหมือนใน home_page)
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      _logout(context);
      throw Exception('No token found. Logging out.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ==============================
  // LOAD BOOKING REQUESTS (SERVER)
  // ==============================
  Future<void> _loadBookingRequests() async {
    setState(() => _isLoading = true);

    try {
      // ดึง userId จาก SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) throw Exception('userId not found');

      // เพิ่ม Headers และใช้ baseUrl
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/bookings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);

        setState(() {
          requestList = list.map((b) {
            return {
              "booking_id": b["booking_id"].toString(),
              "room": b["room_name"] ?? "Unknown room",
              "room_id": b["room_id"]?.toString() ?? "",
              "description": b["description"] ?? "",
              "capacity": b["capacity"]?.toString() ?? "",
              "time": b["time_slot"] ?? "",
              "date": b["booking_date"] ?? "",
              "reason": b["reason"] ?? "",
              "status": b["status"] ?? "Pending",
              "reservedBy": "You",
            };
          }).toList();

          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _logout(context);
      } else {
        print("❌ Server responded with ${response.statusCode}");
        _useLocalRequests();
      }
    } catch (e) {
      print("❌ Error: $e");
      _useLocalRequests();
    }
  }

  // ==============================
  // LOCAL FALLBACK
  // ==============================
  void _useLocalRequests() {
    final local = StudentRoomPage.getBookingHistory();

    setState(() {
      requestList = local;
      _isLoading = false;
    });
  }

  // ==============================
  // CANCEL BOOKING
  // ==============================
  Future<void> _cancelBooking(String bookingId) async {
    try {
      // เพิ่ม Headers และใช้ baseUrl
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/booking/$bookingId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Booking cancelled successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookingRequests(); // โหลดใหม่
      } else if (response.statusCode == 401) {
        _logout(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed : ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Cancel error: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==============================
  // CONFIRM CANCEL DIALOG
  // ==============================
  void _showCancelDialog(String bookingId, String roomName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text("Cancel Booking"),
          ],
        ),
        content: Text("Do you want to cancel the booking for $roomName?"),
        actions: [
          TextButton(
            child: const Text("No"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(bookingId);
            },
          ),
        ],
      ),
    );
  }

  // Color of status badge
  Color _statusColor(String status) {
    status = status.toLowerCase();
    if (status == "pending") return Colors.amber;
    if (status == "approved" || status == "confirmed") return Colors.green;
    if (status == "rejected" || status == "cancelled") return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ==============================
      // APP BAR
      // ==============================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "Check Request",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
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

      // ==============================
      // BODY
      // ==============================
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(4, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha((0.03 * 255).round()),
                            blurRadius: 6),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(height: 14, width: 120),
                              SizedBox(height: 8),
                              SkeletonBox(height: 12, width: 80),
                              SizedBox(height: 6),
                              SkeletonBox(height: 12),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        SkeletonBox(height: 28, width: 80),
                      ],
                    ),
                  );
                }),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: requestList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pending_actions,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("No requests found",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: requestList.length,
                      itemBuilder: (_, index) {
                        final item = requestList[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withAlpha((0.08 * 255).round()),
                                  blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            children: [
                              // =====================
                              // LEFT SIDE DETAILS
                              // =====================
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF3E7BFA)),
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
                                    Text(
                                      "Booking ID: ${item["booking_id"]}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                    ),
                                    if (userRole != "student")
                                      Text(
                                          "Reserved by: ${item["reservedBy"]}"),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // =====================
                              // STATUS BADGE
                              // =====================
                              Column(
                                children: [
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

                                  const SizedBox(height: 8),

                                  // Cancel button only when pending
                                  if (item["status"].toLowerCase() == "pending")
                                    TextButton(
                                      child: const Text(
                                        "Cancel",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () => _showCancelDialog(
                                          item["booking_id"], item["room"]),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

      // ==============================
      // BOTTOM NAV
      // ==============================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.1 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 2,
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
            } // current page
            else if (index == 3) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StudentHistoryPage()));
            }
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_filled), label: "Home"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.meeting_room_outlined), label: "Room"),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA726),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.checklist_rtl, color: Colors.white),
              ),
              label: "Check Request",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.history), label: "History"),
          ],
        ),
      ),
    );
  }
}
