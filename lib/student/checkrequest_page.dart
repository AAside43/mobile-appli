import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ignore: unused_import
import 'home_page.dart';
import 'room_page.dart';
import 'history_page.dart';
import '้home_page.dart';
import '../login_page.dart';
import 'user_session.dart';

class CheckRequestPage extends StatefulWidget {
  const CheckRequestPage({Key? key}) : super(key: key);

  @override
  State<CheckRequestPage> createState() => _CheckRequestPageState();
}

class _CheckRequestPageState extends State<CheckRequestPage> {
  // Server URL - use 10.0.2.2 for Android emulator
  static const String serverUrl = 'http://192.168.57.1:3000';
  
  // ✅ Use actual user from session
  String get userRole => UserSession.role ?? 'student';
  int get userId => UserSession.userId ?? 1;
  
  List<Map<String, dynamic>> requestList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingRequests();
  }

  // Load booking requests from server
  Future<void> _loadBookingRequests() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/user/$userId/bookings'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> bookingsData = data['bookings'];
        
        setState(() {
          requestList = bookingsData.map((booking) {
            return {
              "booking_id": booking['booking_id']?.toString() ?? "",
              "room": booking['room_name']?.toString() ?? "Unknown Room",
              "room_id": booking['room_id']?.toString() ?? "",
              "description": booking['description']?.toString() ?? '',
              "capacity": booking['capacity']?.toString() ?? '0',
              "status": booking['status']?.toString() ?? 'unknown',
              "reservedBy": "You", // Current user
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        print('Server returned status: ${response.statusCode}');
        // Fallback to local data if server fails
        _useLocalRequests();
      }
    } catch (e) {
      print('Error loading booking requests: $e');
      // If server is not available, use local data
      _useLocalRequests();
    }
  }

  void _useLocalRequests() {
    final allRequests = RoomPage.getBookingHistory();
    setState(() {
      requestList = userRole == "student"
          ? allRequests.where((req) => req["reservedBy"] == "Student A").toList()
          : allRequests;
      _isLoading = false;
    });
  }

  // Cancel booking
  Future<void> _cancelBooking(String bookingId) async {
    // Validate booking ID
    if (bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Invalid booking ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      print('Attempting to cancel booking: $bookingId');
      print('Server URL: $serverUrl/booking/$bookingId');
      
      final response = await http.delete(
        Uri.parse('$serverUrl/booking/$bookingId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout - Server not responding');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Booking cancelled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload booking requests
        await _loadBookingRequests();
      } else {
        if (!mounted) return;
        // Show more detailed error message
        final errorMsg = response.statusCode == 404 
            ? 'Booking not found' 
            : 'Failed to cancel (Status: ${response.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error canceling booking: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Show cancel confirmation dialog
  void _showCancelDialog(String bookingId, String roomName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text("Cancel Booking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            "Are you sure you want to cancel your booking for $roomName?",
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelBooking(bookingId);
              },
              child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    int selectedIndex = 2;

    // ignore: unused_element
    void onTabTapped(int index) {
      if (index == 0) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else if (index == 1) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const RoomPage()));
      } else if (index == 3) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HistoryPage()));
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
  backgroundColor: Colors.white,
  elevation: 1,
  centerTitle: true,
  title: const Text(
    "Check Request",
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              "Logout",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
                "Are you sure you want to log out and reset all data?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // ✅ รีเซ็ตค่าทั้งหมด โดยเรียกฟังก์ชัน reset จาก RoomPage
                  RoomPage.resetAll();

                  // ✅ กลับไปหน้า LoginPage
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                child:
                    const Text("Logout", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    ),
  ],
),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFA726),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: requestList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pending_actions,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No booking requests found",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: requestList.length,
                      itemBuilder: (context, index) {
                        final item = requestList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8)
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.meeting_room,
                                            size: 20, color: Color(0xFF3E7BFA)),
                                        const SizedBox(width: 8),
                                        Text(item["room"] ?? "-",
                                            style: const TextStyle(
                                                color: Color(0xFF3E7BFA),
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (item["description"] != null &&
                                        item["description"]!.isNotEmpty)
                                      Text(
                                          "Description: ${item["description"]}",
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87)),
                                    if (item["capacity"] != null)
                                      Text(
                                          "Capacity: ${item["capacity"]} people",
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text(
                                        "Booking ID: ${item["booking_id"] ?? "-"}",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54)),
                                    if (item["time"] != null)
                                      Text("Time: ${item["time"]}",
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87)),
                                    if (item["reason"] != null)
                                      Text("Reason: ${item["reason"]}",
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: item["status"] == "pending"
                                      ? Colors.amber
                                      : item["status"] == "confirmed"
                                          ? Colors.green
                                          : item["status"] == "cancelled"
                                              ? Colors.red
                                              : Colors.grey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(item["status"] ?? "Unknown",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                },
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
          currentIndex: 2, // ✅ หน้านี้คือ Check Request
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const HomePage()));
            } else if (index == 1) {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const RoomPage()));
            } else if (index == 2) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const CheckRequestPage()));
            } else if (index == 3) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()));
            }
          },
          items: [
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
                child: const Icon(Icons.checklist_rtl, color: Colors.white),
              ),
              label: "Check Request",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
          ],
        ),
      ),
    );
  }
}
