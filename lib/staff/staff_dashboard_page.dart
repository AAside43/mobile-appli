import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';

import 'staff_room_page.dart';
import 'staff_history_page.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final String baseUrl = apiBaseUrl;

  List<Map<String, dynamic>> roomStatus = [
    {"label": "Pending room", "count": 0, "color": Colors.yellow},
    {"label": "Free room", "count": 0, "color": Colors.green},
    {"label": "Disable room", "count": 0, "color": Colors.grey},
    {"label": "Reserved room", "count": 0, "color": Colors.red},
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _logout() async {
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
      _logout();
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
        final data = json.decode(response.body);
        setState(() {
          roomStatus[0]["count"] = data['pending_slots'] ?? 0;
          roomStatus[1]["count"] = data['free_slots'] ?? 0;
          roomStatus[2]["count"] = data['disabled_rooms'] ?? 0;
          roomStatus[3]["count"] = data['reserved_slots'] ?? 0;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        title: const Text("Dashboard",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _logout();
                        },
                        child: const Text("Logout",
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: roomStatus.map((room) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: room["color"],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(room["label"],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(room["count"].toString(),
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          selectedItemColor: Colors.orange[700],
          onTap: (index) {
            if (index == 1) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StaffRoomPage()));
            } else if (index == 2)
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StaffHistoryPage()));
          },
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Color(0xFFFFA726), shape: BoxShape.circle),
                child: const Icon(Icons.dashboard, color: Colors.white),
              ),
              label: "Dashboard",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.meeting_room_outlined), label: "Room"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.history), label: "History"),
          ],
        ),
      ),
    );
  }
}
