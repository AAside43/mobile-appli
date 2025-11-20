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
  Map<int, Map<String, int>> roomBookingStats = {}; // room_id -> {pending: x, approved: y}

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
        });
        // Fetch booking statistics for today
        await _fetchBookingStats();
        setState(() => _isLoading = false);
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

  Future<void> _fetchBookingStats() async {
    try {
      final headers = await _getAuthHeaders();
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Add timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final requestHeaders = {
        ...headers,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      };
      
      print('🔵 [Staff] Fetching booking stats for date: $dateStr (timestamp: $timestamp)');
      final response = await http.get(
        Uri.parse('$baseUrl/rooms/slots?date=$dateStr&_t=$timestamp'),
        headers: requestHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rooms = data['rooms'] as List;
        print('🟢 [Staff] Received ${rooms.length} rooms');
        
        Map<int, Map<String, int>> stats = {};
        
        for (var room in rooms) {
          int roomId = room['room_id'];
          int pending = 0;
          int approved = 0;
          
          for (var slot in room['time_slots']) {
            if (slot['status'] == 'pending') pending++;
            if (slot['status'] == 'reserved') approved++;
          }
          
          stats[roomId] = {'pending': pending, 'approved': approved};
        }
        
        setState(() {
          roomBookingStats = stats;
        });
      }
    } catch (e) {
      print("Error loading booking stats: $e");
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
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.black, size: 26),
            tooltip: "Refresh",
            onPressed: _fetchRooms,
          ),
          IconButton(
            icon: const Icon(Icons.add_box_rounded,
                color: Color(0xFF3E7BFA), size: 28),
            tooltip: "Add New Room",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffAddRoomPage()),
              ).then((_) => _fetchRooms());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
            tooltip: "Logout",
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAvailable ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image with status overlay
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildRoomImage(item["image"]),
                              ),
                              // Status badge
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAvailable 
                                      ? Colors.green 
                                      : Colors.grey,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAvailable 
                                          ? Icons.check_circle 
                                          : Icons.block,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAvailable ? "Active" : "Disabled",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Room details
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["name"] ?? "Room",
                                      style: const TextStyle(
                                        color: Color(0xFF3E7BFA),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.people_outline,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Capacity: ${item["capacity"]} People",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Booking statistics for today
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.event_busy,
                                                size: 12,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Booked: ${roomBookingStats[item['room_id']]?['approved'] ?? 0}",
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.pending,
                                                size: 12,
                                                color: Colors.amber,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Pending: ${roomBookingStats[item['room_id']]?['pending'] ?? 0}",
                                                style: const TextStyle(
                                                  color: Colors.amber,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item["description"] != null && 
                                        item["description"].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item["description"],
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          // Action buttons
                          Row(
                            children: [
                              // Toggle switch with label
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.power_settings_new,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Enable Room:",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: isAvailable,
                                      onChanged: (val) => _toggleRoomStatus(index, val),
                                      activeColor: Colors.green,
                                      activeTrackColor: Colors.green.withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit button
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StaffEditRoomPage(roomData: item),
                                    ),
                                  ).then((_) => _fetchRooms());
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text("Edit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3E7BFA),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
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
          currentIndex: 1,
          selectedItemColor: Colors.orange[700],
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StaffDashboardPage()));
            } else if (index == 2)
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
