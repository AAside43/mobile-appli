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

class StudentCheckPage extends StatefulWidget {
  const StudentCheckPage({super.key});

  @override
  State<StudentCheckPage> createState() => _StudentCheckPageState();
}

class _StudentCheckPageState extends State<StudentCheckPage> {
  final String baseUrl = apiBaseUrl;

  List<Map<String, dynamic>> requestList = [];
  bool _isLoading = true;
  StreamSubscription? _sseSub;

  @override
  void initState() {
    super.initState();
    _loadBookingRequests();

    // Listen for updates (Real-time)
    _sseSub = sseService.events.listen((msg) {
      final event = msg['event'];
      // ถ้ามีการจองใหม่ หรือสถานะเปลี่ยน ให้โหลดข้อมูลใหม่
      if (event == 'booking_created' ||
          event == 'booking_updated' ||
          event == 'room_changed') {
        if (mounted) _loadBookingRequests();
      }
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    if (token == null) throw Exception('No token found');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // ตัวช่วยแกะข้อมูล (กัน Crash)
  String _getString(Map<dynamic, dynamic> data, List<String> keys,
      {String fallback = "-"}) {
    for (var key in keys) {
      if (data[key] != null &&
          data[key].toString().isNotEmpty &&
          data[key].toString() != "null") {
        return data[key].toString();
      }
    }
    return fallback;
  }

  Future<void> _loadBookingRequests() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) throw Exception('userId not found');

      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/bookings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> list = data['bookings'] ?? [];

        setState(() {
          requestList = list
              .map((b) {
                // Clean Capacity
                String rawCap = _getString(b, ['capacity', 'room_capacity']);
                String cap = rawCap
                    .replaceAll(RegExp(r'people', caseSensitive: false), '')
                    .trim();

                return {
                  "booking_id": _getString(b, ['booking_id', 'id']),
                  "room": _getString(b, ['room_name', 'name', 'room']),
                  "capacity": cap.isEmpty ? "0" : cap,
                  "date": _getString(b, ['booking_date', 'date']),
                  "time": _getString(b, ['time_slot', 'time']),
                  "reason": _getString(b, ['reason', 'description']),
                  "status": _getString(b, ['status'], fallback: 'Pending'),
                  "reserved": _getString(b, ['reserved', 'reserved_by'],
                      fallback: 'You'),
                };
              })
              .where((item) {
                // 🟢 กรองเฉพาะ Pending
                return item["status"].toString().toLowerCase() == 'pending';
              })
              .toList()
              .cast<Map<String, dynamic>>();

          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) _logout(context);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse(
            '$baseUrl/booking/$bookingId'), // ตรวจสอบ Endpoint ใน app.js ว่า booking หรือ bookings
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("✅ Request cancelled"),
              backgroundColor: Colors.green),
        );
        _loadBookingRequests();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ Failed: ${response.statusCode}"),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // handle error
    }
  }

  void _showCancelDialog(String bookingId, String roomName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Request"),
        content: Text("Cancel booking for $roomName?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(bookingId);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text("Check Request",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFA726)))
          : requestList.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No pending requests",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requestList.length,
                  itemBuilder: (context, index) {
                    final item = requestList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Room Name & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['room'],
                                style: const TextStyle(
                                  color: Color(0xFF3E7BFA), // สีฟ้าตามต้องการ
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange, // Pending สีส้ม
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item['status'],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          Text("${item['capacity']} People",
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 12),

                          // Details
                          _buildInfoText("Date", item['date']),
                          _buildInfoText("Time", item['time']),
                          _buildInfoText("Reason", item['reason']),
                          _buildInfoText("Reserved by", item['reserved']),
                          _buildInfoText("Approved by", "N/A"), // Pending

                          const SizedBox(height: 16),

                          // Cancel Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _showCancelDialog(
                                  item['booking_id'], item['room']),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("Cancel Request",
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
                text: "$label : ",
                style: const TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(
                text: value, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: 2,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Colors.black54,
        onTap: (index) {
          if (index == 2) return;
          if (index == 0)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentHomePage()));
          else if (index == 1)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentRoomPage()));
          else if (index == 3)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentHistoryPage()));
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
                  color: Color(0xFFFFA726), shape: BoxShape.circle),
              child: const Icon(Icons.checklist_rtl, color: Colors.white),
            ),
            label: "Check Request",
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}
