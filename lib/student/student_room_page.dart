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
      } else if (event == 'booking_created' || event == 'booking_updated') {
        if (mounted) {
          _loadBookingsFromServer();
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
      await Future.wait([
        _loadRoomsFromServer(),
        _loadBookingsFromServer(),
      ]);
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
        if(mounted) _logout(context);
      } else {
        print('Failed to load rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  // ============================
  //   LOAD BOOKINGS (TODAY)
  // ============================
  Future<void> _loadBookingsFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) throw Exception('userId not found');

      final headers = await _getAuthHeaders();
      final response = await http.get(
          Uri.parse('$baseUrl/user/$userId/bookings'),
          headers: headers,
      ).timeout(const Duration(seconds: 10));

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
          final String dateStr = (booking['date'] ?? '').toString(); // API เดิมส่ง date เป็น string
          final String roomId = booking['room_id']?.toString() ?? '';
          final String timeSlot = (booking['time'] ?? '').toString();

          // Parse Date
          DateTime? bookingDate;
          try {
             // ลอง parse จาก format ที่ API ส่งมา (เช่น 'MMM d, yyyy')
             bookingDate = DateFormat('MMM d, yyyy', 'en_US').parse(dateStr);
             // หรือถ้า API ส่งเป็น YYYY-MM-DD ให้ใช้: DateTime.parse(dateStr);
          } catch (_) {
            try {
               bookingDate = DateTime.parse(dateStr);
            } catch(__) {
               bookingDate = null;
            }
          }

          // Check if booking is today
          if (bookingDate != null &&
              bookingDate.year == today.year &&
              bookingDate.month == today.month &&
              bookingDate.day == today.day) {
            
            // ❇️ แก้ไขจุดสำคัญ: เช็คก่อนว่าเป็น Pending หรือ Approved
            // ถ้าเป็น Cancelled หรือ Rejected จะไม่เข้าเงื่อนไขนี้ ทำให้สถานะห้องยังคงเป็น Free
            if (status == 'Pending' || status == 'Approved') {
              activeFound = true;

              // Update Slot Status
              for (var room in rooms) {
                if (room['room_id']?.toString() == roomId) {
                   // Only mark reserved/pending if room is actually enabled
                   if (room['is_available'] == true) {
                      int timeIndex = timeSlots.indexOf(timeSlot);
                      if (timeIndex != -1) {
                        room['status'][timeIndex] = (status == 'Pending') ? 'Pending' : 'Reserved';
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
        if(mounted) _logout(context);
      }
    } catch (e) {
      print('Error loading bookings: $e');
    }
  }

  Color _getColor(String status) {
    switch (status) {
      case "Free": return Colors.green;
      case "Pending": return Colors.amber;
      case "Reserved": return Colors.red;
      case "Disabled":
      case "Disable": return Colors.grey;
      default: return Colors.grey;
    }
  }

  void _showBookingDialog(String roomName, String timeSlot) {
    if (_hasActiveBooking) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width:10), Text("Limit Reached")]),
          content: const Text("You can book only once per day."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
            onPressed: () async {
              Navigator.pop(context);
              final reason = reasonController.text.trim();
              
              if (roomId != null) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getInt('userId');
                  final headers = await _getAuthHeaders();
                  final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

                  final response = await http.post(
                    Uri.parse('$baseUrl/book-room'),
                    headers: headers,
                    body: json.encode({
                      'userId': userId,
                      'roomId': int.parse(roomId!), // Parse เป็น int ตาม backend
                      'booking_date': dateStr,
                      'time_slot': timeSlot,
                      'reason': reason.isEmpty ? null : reason
                    })
                  );

                  if (response.statusCode == 201) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Booking sent!"), backgroundColor: Colors.green));
                     _loadBookingsFromServer(); // Refresh UI
                  } else {
                     final err = json.decode(response.body);
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err['error'] ?? "Failed"), backgroundColor: Colors.red));
                  }

                } catch(e) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error"), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Book Now", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String todayText = DateFormat('MMM d, yyyy').format(DateTime.now());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Room", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: () => _logout(context))
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
                   decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                   child: const Row(children: [
                      Icon(Icons.info, color: Colors.orange), 
                      SizedBox(width: 8), 
                      Expanded(child: Text("You already have a booking today.", style: TextStyle(color: Colors.deepOrange)))
                   ]),
                 ),
              
              // Date Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Text("Today: $todayText", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),

              // Header Row: Room and Time Slots (WITH BOX DESIGN)
              Row(
                children: [
                  // "Room" header box
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(4), // ขอบ
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text("Room", style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                  ),
                  // Time slots header boxes
                  ...timeSlots.map((t) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(4), // ขอบ
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: FittedBox(
                        fit: BoxFit.scaleDown, 
                        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
                      )),
                    ),
                  )),
                ],
              ),
              const Divider(),

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
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text(room['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  ...List.generate(room['status'].length, (i) {
                                     String status = room['status'][i];
                                     bool isFree = status == "Free";
                                     bool canBook = isFree && !_hasActiveBooking;
                                     
                                     return Expanded(
                                       child: GestureDetector(
                                         onTap: canBook ? () => _showBookingDialog(room['name'], timeSlots[i]) : null,
                                         child: Container(
                                           margin: const EdgeInsets.symmetric(horizontal: 2),
                                           height: 40,
                                           decoration: BoxDecoration(
                                             color: _getColor(status),
                                             borderRadius: BorderRadius.circular(4)
                                           ),
                                           alignment: Alignment.center,
                                           child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                         ),
                                       ),
                                     );
                                  })
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Colors.black54,
        onTap: (i) {
          if (i == index) return;
          if (i == 0) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentHomePage()));
          else if (i == 1) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentRoomPage()));
          else if (i == 2) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentCheckPage()));
          else if (i == 3) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentHistoryPage()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.meeting_room_outlined), label: "Room"),
          BottomNavigationBarItem(icon: Icon(Icons.checklist_rtl), label: "Check Request"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}
