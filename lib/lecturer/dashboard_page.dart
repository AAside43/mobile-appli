import 'package:flutter/material.dart';
import 'package:mobile_appli_1/lecturer/history_page.dart';
import 'package:mobile_appli_1/login_page.dart';
import 'package:mobile_appli_1/lecturer/room_page.dart';
// ❇️ 1. เพิ่ม imports สำหรับ http และ convert
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'approved_page.dart'; // ❇️ เพิ่ม import สำหรับ approved_page
import '../config.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0; // ✅ Dashboard tab

  // ❇️ 2. กำหนด Base URL ของ API
  final String baseUrl = apiBaseUrl; // centralized in lib/config.dart

  // ❇️ 3. สร้างตัวแปร State สำหรับเก็บข้อมูลสถิติและสถานะการโหลด
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _errorMessage = '';

  // ❇️ 4. ลบ List<Map<String, dynamic>> roomStatus ของเดิมออก

  @override
  void initState() {
    super.initState();
    // ❇️ 5. เรียกฟังก์ชันดึงข้อมูลเมื่อหน้าจอเริ่มทำงาน
    _fetchDashboardStats();
  }

  // ❇️ 6. สร้างฟังก์ชันสำหรับเรียก API
  Future<void> _fetchDashboardStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/dashboard/stats'));

      if (response.statusCode == 200) {
        setState(() {
          _stats = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load stats: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error connecting to server: $e";
        _isLoading = false;
      });
    }
  }

  // ✅ ฟังก์ชันเปลี่ยนหน้า bottom nav
  void onTabTapped(int index) {
    if (index == selectedIndex) return;

    setState(() => selectedIndex = index);

    if (index == 0) return; // Dashboard อยู่แล้ว
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoomPage()),
      );
    } else if (index == 2) {
      // ❇️ แก้ไขให้ไปหน้า ApprovedPage ได้
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ApprovedPage()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HistoryPage()),
      );
    }
  }

  // ❇️ 7. (Optional) สร้าง Widget helper เพื่อความสะอาด
  Widget _buildStatCardGrid(String label, int count) {
  return GestureDetector(
    onTap: () {
      String? statusFilter;
      final lower = label.toLowerCase();
      if (lower.contains('pending')) statusFilter = 'pending';
      if (lower.contains('free')) statusFilter = 'free';
      if (lower.contains('disabled')) statusFilter = 'disabled';
      if (lower.contains('reserved')) statusFilter = 'reserved';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoomPage(filterStatus: statusFilter),
        ),
      );
    },
    child: Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],      // สีเทาอ่อน
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
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
        // (AppBar code... ไม่เปลี่ยนแปลง)
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        title: const Text(
          "Dashboard",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
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
      // ❇️ 8. ปรับดีไซน์ใหม่เป็น 2x2 Grid สีเทา
body: Padding(
  padding: const EdgeInsets.all(16.0),
  child: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : GridView.count(
              crossAxisCount: 2,               // 2 คอลัมน์
              crossAxisSpacing: 12,            // ระยะห่างระหว่างช่องแนวตั้ง
              mainAxisSpacing: 12,             // ระยะห่างระหว่างช่องแนวนอน
              childAspectRatio: 1.2,           // อัตราส่วนกล่อง
              children: [
                _buildStatCardGrid(
                  "Pending Slots",
                  _stats['pending_slots'] ?? 0,
                ),
                _buildStatCardGrid(
                  "Free Slots",
                  _stats['free_slots'] ?? 0,
                ),
                _buildStatCardGrid(
                  "Disabled Rooms",
                  _stats['disabled_rooms'] ?? 0,
                ),
                _buildStatCardGrid(
                  "Reserved Slots",
                  _stats['reserved_slots'] ?? 0,
                ),
              ],
            ),
),

      // ❇️ 9. แก้ไข BottomNavigationBar ให้ตรงกับหน้าอื่น
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
              label: "Dashboard", // ← เปลี่ยนจาก Home เป็น Dashboard
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.meeting_room_outlined), label: "Room"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rtl), label: "Check Request"),
            const BottomNavigationBarItem(
                // ❇️ แก้ไข icon
                icon: Icon(Icons.history),
                label: "History"),
          ],
        ),
      ),
    );
  }
}
