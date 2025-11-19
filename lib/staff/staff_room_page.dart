import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';

import 'staff_add_room_page.dart';
import 'staff_dashboard_page.dart';
import 'staff_edit_room_page.dart';
import 'staff_history_page.dart';

class StaffRoomPage extends StatefulWidget {
  const StaffRoomPage({super.key});

  @override
  State<StaffRoomPage> createState() => _StaffRoomPageState();
}

class _StaffRoomPageState extends State<StaffRoomPage> {
  final String baseUrl = apiBaseUrl;
  List<dynamic> roomList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
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
      'Authorization': 'Bearer $token'
    };
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _getAuthHeaders();
      final response =
          await http.get(Uri.parse('$baseUrl/rooms'), headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          roomList = data['rooms'];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error loading rooms: $e");
    }
  }

  Future<void> _toggleRoomStatus(int index, bool currentValue) async {
    final room = roomList[index];
    final roomId = room['room_id'];

    // Optimistically update UI
    setState(() {
      roomList[index]['is_available'] = currentValue ? 1 : 0;
    });

    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/rooms/$roomId'),
        headers: headers,
        body: json.encode({
          "is_available": currentValue,
        }),
      );

      if (response.statusCode == 200) {
        // Success - show confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(currentValue 
                ? "Room enabled successfully" 
                : "Room disabled successfully"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Revert on failure
        setState(() {
          roomList[index]['is_available'] = !currentValue ? 1 : 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to update room status"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        roomList[index]['is_available'] = !currentValue ? 1 : 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRoomImage(dynamic imageData) {
    if (imageData != null && imageData is String && imageData.isNotEmpty) {
      try {
        // Decode base64 image
        Uint8List bytes = base64Decode(imageData);
        return Image.memory(
          bytes,
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _defaultRoomImage();
          },
        );
      } catch (e) {
        return _defaultRoomImage();
      }
    }
    return _defaultRoomImage();
  }

  Widget _defaultRoomImage() {
    return Image.asset(
      "assets/images/Room1.jpg",
      height: 100,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 100,
          width: double.infinity,
          color: Colors.grey[300],
          child: const Icon(Icons.meeting_room, size: 40, color: Colors.grey),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        title: const Text("Room Management",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded,
                color: Colors.black, size: 26),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StaffAddRoomPage()));
            },
          ),
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
          : roomList.isEmpty
              ? const Center(child: Text("No room yet"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: roomList.length,
                  itemBuilder: (context, index) {
                    final item = roomList[index];
                    final bool isAvailable = (item['is_available'] == 1 ||
                        item['is_available'] == true);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildRoomImage(item["image"]),
                                ),
                                const SizedBox(height: 8),
                                Text(item["name"] ?? "Room",
                                    style: const TextStyle(
                                        color: Color(0xFF3E7BFA),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Text("Capacity: ${item["capacity"]} People"),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: isAvailable,
                                onChanged: (val) =>
                                    _toggleRoomStatus(index, val),
                                activeThumbColor: Colors.green,
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => StaffEditRoomPage(
                                              roomData: item)));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: const Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: 1,
          selectedItemColor: Colors.orange[700],
          onTap: (index) {
            if (index == 0)
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StaffDashboardPage()));
            else if (index == 2)
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const StaffHistoryPage()));
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: "Dashboard"),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Color(0xFFFFA726), shape: BoxShape.circle),
                child: const Icon(Icons.meeting_room_outlined,
                    color: Colors.white),
              ),
              label: "Room",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.history), label: "History"),
          ],
        ),
      ),
    );
  }
}
