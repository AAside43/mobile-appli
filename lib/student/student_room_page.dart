import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';
import '../services/sse_service.dart';
import 'package:intl/intl.dart';

import 'student_home_page.dart';
import 'student_check_page.dart';
import 'student_history_page.dart';

class StudentRoomPage extends StatefulWidget {
  const StudentRoomPage({Key? key}) : super(key: key);

  static List<Map<String, String>> getBookingHistory() =>
      _StudentRoomPageState._bookingHistory;

  @override
  State<StudentRoomPage> createState() => _StudentRoomPageState();

  static void resetAll() {
    _StudentRoomPageState._resetStatic();
  }
}

class _StudentRoomPageState extends State<StudentRoomPage> {
  bool _isLoading = true;
  bool _hasActiveBooking = false;
  final String baseUrl = apiBaseUrl;

  // ตัวแปรเก็บประวัติการจอง (แชร์ข้ามหน้า)
  static final List<Map<String, String>> _bookingHistory = [];

  final List<String> timeSlots = [
    '08:00-10:00',
    '10:00-12:00',
    '13:00-15:00',
    '15:00-17:00',
  ];

  // ตารางห้องแบบ Static เพื่อจำสถานะข้ามหน้า
  static List<Map<String, dynamic>> rooms = [];

  StreamSubscription? _sseSub;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    // listen for server-sent events
    _sseSub = sseService.events.listen((msg) {
      final event = msg['event'];
      if (event == 'room_changed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room updated'),
              duration: Duration(seconds: 2),
            ),
          );
          _loadAllData();
        }
      } else if (event == 'booking_created' || 
                 event == 'booking_updated' || 
                 event == 'booking_cancelled') {
        if (mounted) {
          print('🔔 [Student] Real-time update: $event');
          _loadAllData();
        }
      }
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  static void _resetStatic() {
    _bookingHistory.clear();
    rooms = [];
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

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // Load rooms first, then check user's active booking, then load all slots (this overwrites with all bookings)
      await _loadRoomsFromServer();
      await _checkUserActiveBooking(); // Only check if user has active booking today
      await _loadRoomSlotsFromServer(); // Load actual slot status from ALL users
    } catch (e) {
      print("Error loading data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ล้างข้อมูลทั้งหมด
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // ============================
  //   LOAD ROOMS FROM SERVER
  // ============================
  Future<void> _loadRoomsFromServer() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/rooms'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> roomsData = data['rooms'];

        setState(() {
          rooms = roomsData.map((room) {
            return {
              "room_id": room['room_id'].toString(),
              "name": room['name'],
              "capacity": room['capacity']?.toString() ?? 'N/A',
              "description": room['description'] ?? '',
              "is_available": room['is_available'] == 1,
              "image": room['image'],
              // Default slots status (เริ่มต้นเป็น Free ทั้งหมด)
              "status": ["Free", "Free", "Free", "Free"]
            };
          }).toList();
        });
      } else if (response.statusCode == 401) {
        if (mounted) _logout(context);
      } else {
        print('Failed to load rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  // ============================
  //   LOAD ROOM SLOTS STATUS (ALL BOOKINGS)
  // ============================
  Future<void> _loadRoomSlotsFromServer() async {
    try {
      final headers = await _getAuthHeaders();
      final DateTime today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Add timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final requestHeaders = {
        ...headers,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      };
      
      print('🔵 [Student] Fetching room slots for date: $dateStr (timestamp: $timestamp)');
      final response = await http.get(
        Uri.parse('$baseUrl/rooms/slots?date=$dateStr&_t=$timestamp'),
        headers: requestHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> roomsData = data['rooms'] ?? [];
        print('🟢 [Student] Received ${roomsData.length} rooms with slot data');
        
        // Update room status based on actual bookings from server
        for (var serverRoom in roomsData) {
          final String serverRoomId = serverRoom['room_id'].toString();
          
          // Find matching room in our local rooms list
          for (var localRoom in rooms) {
            if (localRoom['room_id'].toString() == serverRoomId) {
              // Update slot status from server data
              final List<dynamic> slots = serverRoom['slots'] ?? [];
              List<String> newStatus = ["Free", "Free", "Free", "Free"];
              
              for (int i = 0; i < slots.length && i < timeSlots.length; i++) {
                final slotData = slots[i];
                final String slotStatus = slotData['status']?.toString() ?? 'free';
                
                // Map server status to display status
                if (slotStatus == 'pending') {
                  newStatus[i] = 'Pending';
                } else if (slotStatus == 'reserved') {
                  newStatus[i] = 'Reserved';
                } else if (slotStatus == 'disabled') {
                  newStatus[i] = 'Disabled';
                } else {
                  newStatus[i] = 'Free';
                }
              }
              
              localRoom['status'] = newStatus;
              print('🟡 [Student] Room ${localRoom['name']}: ${newStatus.join(", ")}');
              break;
            }
          }
        }
        
        if (mounted) setState(() {});
      } else if (response.statusCode == 401) {
        if (mounted) _logout(context);
      }
    } catch (e) {
      print('Error loading room slots: $e');
    }
  }

  // ============================
  //   CHECK USER'S ACTIVE BOOKING (FOR BOOKING LIMIT)
  // ============================
  Future<void> _checkUserActiveBooking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) throw Exception('userId not found');

      final headers = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/user/$userId/bookings'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> bookingsData = data['bookings'] ?? [];

        final DateTime today = DateTime.now();
        bool activeFound = false;

        // Reset room status first based on availability
        for (var room in rooms) {
          bool isAvailable = room['is_available'] == true;
          room['status'] = isAvailable
              ? ["Free", "Free", "Free", "Free"]
              : ["Disabled", "Disabled", "Disabled", "Disabled"];
        }

        for (var booking in bookingsData) {
          final String status = (booking['status'] ?? '').toString();
          final String dateStr = (booking['date'] ?? '').toString();
          final String roomId = booking['room_id']?.toString() ?? '';
          final String timeSlot = (booking['time'] ?? '').toString();

          DateTime? bookingDate;
          try {
            bookingDate = DateFormat('MMM d, yyyy', 'en_US').parse(dateStr);
          } catch (_) {
            try {
              bookingDate = DateTime.parse(dateStr);
            } catch (__) {
              bookingDate = null;
            }
          }

          // Check if booking is today and active
          if (bookingDate != null &&
              bookingDate.year == today.year &&
              bookingDate.month == today.month &&
              bookingDate.day == today.day) {
            // Only mark if Pending or Approved
            if (status == 'Pending' || status == 'Approved') {
              activeFound = true;

              // Update Slot Status
              for (var room in rooms) {
                if (room['room_id']?.toString() == roomId) {
                  if (room['is_available'] == true) {
                    int timeIndex = timeSlots.indexOf(timeSlot);
                    if (timeIndex != -1) {
                      room['status'][timeIndex] =
                          (status == 'Pending') ? 'Pending' : 'Reserved';
                    }
                  }
                  break;
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _hasActiveBooking = activeFound;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) _logout(context);
      }
    } catch (e) {
      print('Error checking user booking: $e');
    }
  }

  Color _getColor(String status) {
    switch (status) {
      case "Free":
        return const Color(0xFF4CAF50); // Green
      case "Pending":
        return Colors.amber;
      case "Reserved":
      case "Busy":
        return const Color(0xFFF44336); // Red
      case "Disabled":
      case "Disable":
        return const Color(0xFF9E9E9E); // Grey
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon(String status) {
    switch (status) {
      case "Free":
        return Icons.check_circle_outline;
      case "Pending":
        return Icons.schedule;
      case "Reserved":
      case "Busy":
        return Icons.cancel_outlined; // or Icons.highlight_off
      case "Disabled":
      case "Disable":
        return Icons.block_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getDisplayText(String status) {
    if (status == "Reserved") return "Busy";
    return status;
  }

  String _getDisplayText(String status) {
    if (status == "Reserved") return "Busy";
    return status;
  }

  void _showBookingDialog(String roomName, String timeSlot) {
    if (_hasActiveBooking) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 10),
            Text("Limit Reached")
          ]),
          content: const Text("You can book only once per day."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
          ],
        ),
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();
    String? roomId;
    for (var room in rooms) {
      if (room["name"] == roomName) {
        roomId = room["room_id"];
        break;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Book $roomName\n$timeSlot", textAlign: TextAlign.center),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Enter reason..."),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726)),
            onPressed: () async {
              Navigator.pop(context);
              final reason = reasonController.text.trim();

              if (roomId != null) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getInt('userId');
                  final headers = await _getAuthHeaders();
                  final dateStr =
                      DateFormat('yyyy-MM-dd').format(DateTime.now());

                  final response =
                      await http.post(Uri.parse('$baseUrl/book-room'),
                          headers: headers,
                          body: json.encode({
                            'userId': userId,
                            'roomId': int.parse(roomId!),
                            'booking_date': dateStr,
                            'time_slot': timeSlot,
                            'reason': reason.isEmpty ? null : reason
                          }));

                  if (response.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("✅ Booking sent!"),
                        backgroundColor: Colors.green));
                    _loadBookingsFromServer(); // Refresh UI
                  } else {
                    final err = json.decode(response.body);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err['error'] ?? "Failed"),
                        backgroundColor: Colors.red));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Connection Error"),
                      backgroundColor: Colors.red));
                }
              }
            },
            child:
                const Text("Book Now", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // Flat style like image
        title: const Text("Room",
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
        actions: [
          // Refresh Icon
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadAllData,
          ),
          // Logout Icon (Exit style)
          IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              onPressed: () => _logout(context))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_hasActiveBooking)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange)),
                  child: const Row(children: [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text("You already have a booking today.",
                            style: TextStyle(color: Colors.deepOrange)))
                  ]),
                ),

              // Date Header (Blue Outline Button Style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border.all(color: const Color(0xFF3E7BFA), width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF3E7BFA), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Today: ${_formatDate(now)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E7BFA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Header Row: Room and Time Slots
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    // "Room" header box
                    Container(
                      width: 70, // Fixed Width for Name
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text("Room",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ),
                    ),
                    // Time slots header boxes
                    Expanded(
                      child: Row(
                        children: timeSlots
                            .map((t) => Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                        child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(t,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87)),
                                    )),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Rooms List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : rooms.isEmpty
                        ? const Center(child: Text("No rooms available"))
                        : ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final room = rooms[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors
                                          .blue.shade100), // Light Blue Border
                                ),
                                child: Row(
                                  children: [
                                    // Room Name & Disabled Text
                                    SizedBox(
                                      width: 70, // Fixed Width to match header
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(room['name'],
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                          if (room['is_available'] == false)
                                            const Text("Disabled",
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Status Slots
                                    Expanded(
                                      child: Row(
                                        children: List.generate(
                                            room['status'].length, (i) {
                                          String status = room['status'][i];
                                          bool isFree = status == "Free";
                                          bool canBook =
                                              isFree && !_hasActiveBooking;
                                          Color cellColor = _getColor(status);
                                          IconData cellIcon = _getIcon(status);
                                          String displayText =
                                              _getDisplayText(status);

                                          return Expanded(
                                            child: GestureDetector(
                                              onTap: canBook
                                                  ? () => _showBookingDialog(
                                                      room['name'],
                                                      timeSlots[i])
                                                  : null,
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 3),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: cellColor,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(cellIcon,
                                                        color: Colors.white,
                                                        size: 18),
                                                    const SizedBox(height: 2),
                                                    FittedBox(
                                                      child: Text(displayText,
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context, 1),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Colors.black54,
        onTap: (i) {
          if (i == index) return;
          if (i == 0)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentHomePage()));
          else if (i == 1)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentRoomPage()));
          else if (i == 2)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentCheckPage()));
          else if (i == 3)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StudentHistoryPage()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined), label: "Room"),
          BottomNavigationBarItem(
              icon: Icon(Icons.checklist_rtl), label: "Check Request"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}
