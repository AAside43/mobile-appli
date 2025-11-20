import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';

import 'lecturer_dashboard_page.dart';
import 'lecturer_room_page.dart';
import 'lecturer_history_page.dart';

class LecturerApprovedPage extends StatefulWidget {
  const LecturerApprovedPage({Key? key}) : super(key: key);

  @override
  State<LecturerApprovedPage> createState() => _LecturerApprovedPageState();
}

class _LecturerApprovedPageState extends State<LecturerApprovedPage> {
  int selectedIndex = 2;
  final String baseUrl = apiBaseUrl;

  List<dynamic> _requests = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
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

  // (ฟังก์ชัน _logout, _fetchPendingRequests, onTabTapped ... ไม่เปลี่ยนแปลง)
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Future<void> _fetchPendingRequests() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final headers = await _getAuthHeaders();

      final response = await http
          .get(
        Uri.parse('$baseUrl/bookings/pending'),
        headers: headers,
      )
          .timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _requests = json.decode(response.body)['requests'];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) _logout();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Failed to load requests: ${response.statusCode}";
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
              "Error connecting to server: ${e.toString().replaceAll('Exception: ', '')}";
          _isLoading = false;
        });
      }
    }
  }

  void onTabTapped(int index) {
    if (index == selectedIndex) return;
    setState(() {
      selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LecturerDashboardPage()));
    } else if (index == 1) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LecturerRoomPage()));
    } else if (index == 2) {
      // CURRENT PAGE
    } else if (index == 3) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LecturerHistoryPage()));
    }
  }

  // แยกฟังก์ชันการยิง API ออกมา
  Future<void> _callProcessApi(
      int index, String apiStatus, String? rejectionReason) async {
    final request = _requests[index];
    final bookingId = request['booking_id'];
    final roomName = request['room_name'];

    final prefs = await SharedPreferences.getInstance();
    final int approverId = prefs.getInt('userId') ?? 1;

    try {
      final headers = await _getAuthHeaders();

      final response = await http
          .put(
        Uri.parse('$baseUrl/booking/$bookingId/status'),
        headers: headers,
        body: json.encode({
          'status': apiStatus,
          'approverId': approverId,
          'rejection_reason': rejectionReason
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _requests.removeAt(index);
        });
        String action = apiStatus == 'approved' ? 'Accepted' : 'Rejected';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$roomName request has been $action.'),
            backgroundColor: action == 'Accepted' ? Colors.green : Colors.red,
          ),
        );
      } else if (response.statusCode == 401) {
        if (mounted) _logout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process request: ${response.body}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (e.toString().contains('No token found')) {
        if (mounted) _logout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  // สร้างฟังก์ชันสำหรับ Pop-up
  Future<void> _showRejectionDialog(int index) async {
    final TextEditingController reasonController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reason for Rejection'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(hintText: "Enter reason here..."),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  // (Optional) แสดง Error ถ้าไม่ใส่เหตุผล
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a reason.'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.of(context).pop(); // ปิด Pop-up
                // เรียก API
                _callProcessApi(index, 'rejected', reason);
              },
              child: const Text('Submit Reject'),
            ),
          ],
        );
      },
    );
  }

  // แก้ไขฟังก์ชัน _processRequest เดิม
  void _processRequest(int index, String action) {
    if (action == 'Accepted') {
      // ถ้า Accept, ยิง API เลย (ส่ง reason เป็น null)
      _callProcessApi(index, 'approved', null);
    } else {
      // ถ้า Reject, ให้เปิด Pop-up ก่อน
      _showRejectionDialog(index);
    }
  }

  // (ฟังก์ชัน _getRoomImage, build, _buildRequestCard, _actionButton ... ไม่เปลี่ยนแปลง)
  String _getRoomImage(String roomName) {
    String lowerRoomName = roomName.toLowerCase();
    if (lowerRoomName.contains('room 1')) return 'assets/images/Room1.jpg';
    if (lowerRoomName.contains('room 2')) return 'assets/images/Room2.jpg';
    if (lowerRoomName.contains('room 3')) return 'assets/images/Room3.jpg';
    if (lowerRoomName.contains('room 4')) return 'assets/images/Room4.jpg';
    if (lowerRoomName.contains('study room')) return 'assets/images/Room1.jpg';
    if (lowerRoomName.contains('meeting room')) {
      return 'assets/images/Room2.jpg';
    }
    if (lowerRoomName.contains('entertaining space')) {
      return 'assets/images/Room3.jpg';
    }
    return 'assets/images/Room1.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Checking Request",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 20,
          ),
        ),
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
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child:
                      Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _requests.isEmpty
                  ? const Center(
                      child: Text(
                        'No pending requests.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(
                          _requests[index],
                          // ❇️ 4. แก้ไขการส่งฟังก์ชัน
                          () => _processRequest(index, 'Accepted'),
                          () => _processRequest(index, 'Rejected'),
                        );
                      },
                    ),

      /// Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
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
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_filled), label: "Dashboard"),
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

  Widget _buildRequestCard(
    Map<String, dynamic> data,
    VoidCallback onAccept,
    VoidCallback onReject,
  ) {
    final String roomName = data['room_name'] ?? 'Room';
    final String capacity = data['capacity']?.toString() ?? 'N/A';
    final String date = data['date'] ?? 'N/A';
    final String time = data['time_slot'] ?? 'N/A';
    final String studentName = data['student_name'] ?? 'Student';
    final String reason = data['reason'] ?? 'N/A';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.asset(
              _getRoomImage(roomName),
              width: 120,
              height: 130,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 120,
                height: 130,
                color: Colors.grey[200],
                child: Icon(Icons.image_not_supported_rounded,
                    color: Colors.grey[400], size: 40),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roomName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Capacity : $capacity people"),
                  Text("Date : $date"),
                  Text("Time : $time"),
                  Text("Request by: $studentName"),
                  Text("Reason : $reason"),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          "Accept",
                          Colors.green,
                          onAccept,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _actionButton(
                          "Reject",
                          Colors.red,
                          onReject, // ❇️ ฟังก์ชันนี้จะไปเปิด Pop-up
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }
}
