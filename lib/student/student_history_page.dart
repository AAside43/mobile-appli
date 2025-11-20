import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

import 'student_home_page.dart';
import 'student_room_page.dart';
import 'student_check_page.dart';
import '../login_page.dart';

class StudentHistoryPage extends StatefulWidget {
  const StudentHistoryPage({super.key});

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  final String baseUrl = apiBaseUrl;

  List<dynamic> historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingHistory();
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

  Future<void> _loadBookingHistory() async {
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
        List<dynamic> list = data["bookings"];

        setState(() {
          historyList = list.map((b) {
            String rawCap = _getString(b, ['capacity', 'room_capacity']);
            String cap = rawCap
                .replaceAll(RegExp(r'people', caseSensitive: false), '')
                .trim();
            String status = _getString(b, ['status'], fallback: 'Pending');

            return {
              "booking_id": b["booking_id"],
              "room": _getString(b, ['room_name', 'name', 'room']),
              "capacity": cap.isEmpty ? "0" : cap,
              "time": _getString(b, ['time_slot', 'time']),
              "date": _getString(b, ['booking_date', 'date']),
              "reason": _getString(b, ['reason', 'description']),
              "status": status,
              "reserved": _getString(b, ['reserved', 'reserved_by']),
              "approved":
                  _getString(b, ['approved', 'approved_by', 'approver']),
              "rejection_reason":
                  _getString(b, ['rejection_reason'], fallback: ""),
            };
          }).where((item) {
            // 🟢 กรองเอาเฉพาะสถานะที่ไม่ใช่ Pending
            return item["status"].toString().toLowerCase() != 'pending';
          }).toList();

          // Sort Date descending
          historyList.sort((a, b) {
            try {
              // ปรับ format ตามที่ API ส่งมา (ถ้าส่งเป็น YYYY-MM-DD ก็ใช้ได้เลย)
              // แต่ถ้าส่งเป็น MMM d, yyyy ต้อง parse ให้ถูก
              // Code นี้พยายาม parse แบบมาตรฐานก่อน
              DateTime da, db;
              try {
                da = DateFormat("MMM d, yyyy").parse(a["date"]);
                db = DateFormat("MMM d, yyyy").parse(b["date"]);
              } catch (e) {
                // fallback for ISO format
                da = DateTime.parse(a["date"]);
                db = DateTime.parse(b["date"]);
              }
              return db.compareTo(da);
            } catch (_) {
              return 0;
            }
          });

          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) _logout(context);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Rejected") return Colors.red;
    if (status == "Cancelled") return Colors.grey;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text("History",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : historyList.isEmpty
              ? const Center(
                  child: Text("No history yet",
                      style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: historyList.length,
                  itemBuilder: (_, index) {
                    final item = historyList[index];
                    final String rejectionReason = item["rejection_reason"];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
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
                          // Top Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item["room"],
                                style: const TextStyle(
                                  color: Color(0xFF3E7BFA), // สีฟ้า
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(item["status"]),
                                  borderRadius: BorderRadius.circular(20),
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
                          Text("${item['capacity']} People",
                              style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 12),

                          // Details
                          _buildInfoText("Date", item["date"]),
                          _buildInfoText("Time", item["time"]),
                          _buildInfoText("Reason", item["reason"]),
                          _buildInfoText("Reserved by", item["reserved"]),
                          _buildInfoText("Approved by", item["approved"]),

                          // 🛑 SHOW REJECT REASON (IF EXISTS)
                          if (item["status"] == "Rejected" &&
                              rejectionReason.isNotEmpty &&
                              rejectionReason != "-")
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                "Reject Reason : $rejectionReason",
                                style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic),
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
        currentIndex: 3,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Colors.black54,
        onTap: (i) {
          if (i == 3) return;
          if (i == 0)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentHomePage()));
          else if (i == 1)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentRoomPage()));
          else if (i == 2)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentCheckPage()));
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
                  color: Color(0xFFFFA726), shape: BoxShape.circle),
              child: const Icon(Icons.history, color: Colors.white),
            ),
            label: "History",
          ),
        ],
      ),
    );
  }
}
