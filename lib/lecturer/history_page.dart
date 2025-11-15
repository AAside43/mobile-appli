import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:mobile_appli_1/lecturer/dashboard_page.dart';
import 'package:mobile_appli_1/lecturer/room_page.dart'; // ❇️ (สำหรับ Student)
import 'package:mobile_appli_1/lecturer/approved_page.dart'; // ❇️ (สำหรับ Lecturer)
import 'package:mobile_appli_1/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
// ❇️ (ลบ config.dart ที่ซ้ำออก)

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // ❇️ (Lecturer: 3, Student: 2)
  // เราจะตั้งค่า selectedIndex หลังจากรู้ Role แล้ว
  int selectedIndex = 0;
  final String baseUrl = apiBaseUrl;

  List<dynamic> _historyList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  String? _userRole;
  int? _userId;
  bool _isLecturerOrStaff = false; // ตัวแปรคุม UI

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchHistory();
  }

  Future<void> _loadUserDataAndFetchHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // ดึงข้อมูล User และตั้งค่า State
    _userId = prefs.getInt('userId');
    _userRole = prefs.getString('role');
    _isLecturerOrStaff = (_userRole == 'lecturer' || _userRole == 'staff');

    setState(() {
      // ❇️ ตั้งค่า selectedIndex ตาม Role
      selectedIndex = _isLecturerOrStaff ? 3 : 2;
    });

    _fetchHistory(); // เรียกฟังก์ชันดึงข้อมูล
  }

  Future<void> _fetchHistory() async {
    // ❇️ ป้องกัน Error ถ้าหา Role ไม่เจอ
    if (_userId == null || _userRole == null) {
      setState(() {
        _errorMessage = "User data not found. Please re-login.";
        _isLoading = false;
      });
      return;
    }

    // --- ❇️ ตรรกะสำคัญ: เปลี่ยน API URL ตาม Role ---
    String apiUrl;
    if (_isLecturerOrStaff) {
      // ถ้าเป็น Lecturer/Staff, ดึงประวัติทั้งหมด (จาก API ใหม่)
      apiUrl = '$baseUrl/bookings/history';
    } else {
      // ถ้าเป็น Student, ดึงเฉพาะของตัวเอง (API เดิม)
      apiUrl = '$baseUrl/user/$_userId/bookings';
    }
    // --- สิ้นสุดตรรกะ ---

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          _historyList = json.decode(response.body)['bookings'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load history: ${response.statusCode}";
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

  Color _getStatusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Rejected") return Colors.red;
    if (status == "Pending") return Colors.orange;
    if (status == "Cancelled") return Colors.blueGrey;
    return Colors.grey;
  }

  void onTabTapped(int index) {
    // ❇️ (Lecturer: 3, Student: 2)
    final int currentIndex = _isLecturerOrStaff ? 3 : 2;
    if (index == currentIndex) return;

    // สำหรับ Lecturer/Staff (มี 4 ปุ่ม)
    if (_isLecturerOrStaff) {
      if (index == 0) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const DashboardPage()));
      } else if (index == 1) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const RoomPage()));
      } else if (index == 2) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ApprovedPage()));
      }
    }
    // สำหรับ Student (มี 3 ปุ่ม)
    else {
      if (index == 0) {
        // (สมมติว่าหน้าหลัก Student คือ HomePage)
        // Navigator.pushReplacement(
        //     context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else if (index == 1) {
        // (สมมติว่าหน้าจองของ Student คือ RoomPage)
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const RoomPage()));
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ล้างข้อมูลล็อกอิน

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "History",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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
                builder: (context) => AlertDialog(
                  title: const Text(
                    "Logout",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout(); // ❇️ เรียกใช้ฟังก์ชัน Logout
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(_errorMessage,
                        style: TextStyle(color: Colors.red)))
                : _historyList.isEmpty
                    ? Center(
                        child: Text(
                          _isLecturerOrStaff
                              ? "No approved/rejected history yet"
                              : "No booking history yet",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historyList.length,
                        itemBuilder: (context, index) {
                          final item = _historyList[index];

                          // ❇️ ดึงเหตุผลการปฏิเสธออกมา
                          final String? rejectionReason =
                              item["rejection_reason"];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item["room"],
                                        style: const TextStyle(
                                          color: Color(0xFF3E7BFA),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(item["capacity"]),
                                      const SizedBox(height: 4),
                                      Text("Date : ${item["date"]}"),
                                      Text("Time : ${item["time"]}"),
                                      Text(
                                          "Reason : ${item["reason"] ?? 'N/A'}"),
                                      Text("Reserved by : ${item["reserved"]}"),
                                      Text("Approved by : ${item["approved"]}"),

                                      // ❇️ นี่คือ Widget ที่เพิ่มเข้ามา ❇️
                                      // (แสดงผลเฉพาะถ้า Status = Rejected และมีเหตุผล)
                                      if (item["status"] == "Rejected" &&
                                          rejectionReason != null &&
                                          rejectionReason.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            "Reject Reason: $rejectionReason",
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(item["status"]),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item["status"],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),

      // ❇️ BottomNavigationBar แบบไดนามิก ❇️
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
          // ❇️ สร้างรายการปุ่ม (items) แบบไดนามิก
          items: _isLecturerOrStaff
              // --- ถ้าเป็น Lecturer (4 ปุ่ม) ---
              ? [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
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
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        // ❇️ แก้ไขโค้ดสีที่ผิด (0xFFFFA726)
                        color: Color(0xFFFFA726),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history, color: Colors.white),
                    ),
                    label: "History",
                  ),
                ]
              // --- ถ้าเป็น Student (3 ปุ่ม) ---
              : [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
                    label: "Home",
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.meeting_room_outlined),
                    label: "Room",
                  ),
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
