import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';

import 'lecturer_history_page.dart';
import 'lecturer_room_page.dart';
import 'lecturer_approved_page.dart';

class LecturerDashboardPage extends StatefulWidget {
  const LecturerDashboardPage({super.key});

  @override
  State<LecturerDashboardPage> createState() => _LecturerDashboardPageState();
}

class _LecturerDashboardPageState extends State<LecturerDashboardPage> {
  int selectedIndex = 0;
  final String baseUrl = apiBaseUrl;

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  // --- ฟังก์ชันระบบคงเดิม (JWT, Logout, API) ---

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

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    if (token == null) {
      throw Exception('No token found');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _stats = json.decode(response.body);
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) _logout(context);
      } else {
        setState(() {
          _errorMessage = "Failed to load stats: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('No token found')) {
        if (mounted) _logout(context);
      } else {
        setState(() {
          _errorMessage = "Error connecting to server";
          _isLoading = false;
        });
      }
    }
  }

  void onTabTapped(int index) {
    if (index == selectedIndex) return;

    setState(() => selectedIndex = index);

    if (index == 0) return;
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LecturerRoomPage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LecturerApprovedPage()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LecturerHistoryPage()),
      );
    }
  }

  // --- 🎨 ปรับดีไซน์ Widget การ์ดให้เหมือนรูป ---
  Widget _buildStatCard(String label, int count, Color bgColor) {
    return GestureDetector(
      onTap: () {
        // Logic การ Filter เหมือนเดิม
        String? statusFilter;
        final lower = label.toLowerCase();
        if (lower.contains('pending')) statusFilter = 'pending';
        if (lower.contains('free')) statusFilter = 'free';
        if (lower.contains('disable')) statusFilter = 'disabled';
        if (lower.contains('reserved')) statusFilter = 'reserved';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LecturerRoomPage(filterStatus: statusFilter),
          ),
        );
      },
      child: Container(
        width: double.infinity, // ให้กว้างเต็มจอ
        margin: const EdgeInsets.only(bottom: 16), // ระยะห่างระหว่างการ์ด
        padding: const EdgeInsets.symmetric(vertical: 24), // ความสูงของการ์ด
        decoration: BoxDecoration(
          color: bgColor, // สีพื้นหลังตามที่ส่งมา
          borderRadius: BorderRadius.circular(12), // มุมโค้ง
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF5F6FA), // สีพื้นหลัง AppBar อ่อนๆ ตามรูป
        elevation: 0,
        title: const Text(
          "Dashboard",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            // ไอคอน Logout เป็นลูกศรสีแดง
            icon: const Icon(Icons.exit_to_app, color: Colors.red, size: 28),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("Cancel")),
                    TextButton(
                      onPressed: () => _logout(context),
                      child: const Text("Logout",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // 1. Pending Room (สีเหลือง)
                      _buildStatCard(
                        "Pending room",
                        _stats['pending_slots'] ?? 0,
                        const Color(0xFFFFF159), // เหลือง
                      ),
                      // 2. Free Room (สีเขียว)
                      _buildStatCard(
                        "Free room",
                        _stats['free_slots'] ?? 0,
                        const Color(0xFF4CAF50), // เขียว
                      ),
                      // 3. Disable Room (สีเทา)
                      _buildStatCard(
                        "Disable room",
                        _stats['disabled_rooms'] ?? 0,
                        const Color(0xFF9E9E9E), // เทา
                      ),
                      // 4. Reserved Room (สีแดง)
                      _buildStatCard(
                        "Reserved room",
                        _stats['reserved_slots'] ?? 0,
                        const Color(0xFFF44336), // แดง
                      ),
                    ],
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
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: onTabTapped,
          items: [
            BottomNavigationBarItem(
              icon: selectedIndex == 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFA726),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home_filled, color: Colors.white),
                    )
                  : const Icon(Icons.home_filled),
              label: "Dashboard",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.meeting_room_outlined), label: "Room"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rtl), label: "Check Request"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.history), label: "History"),
          ],
        ),
      ),
    );
  }
}
