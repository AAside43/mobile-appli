import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ignore: unused_import
import 'home_page.dart';
import 'room_page.dart';
import 'checkrequest_page.dart';
import '../login_page.dart';
import 'user_session.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Server URL - use 10.0.2.2 for Android emulator
  static const String serverUrl = 'http://192.168.57.1:3000';
  
  // ✅ Use actual user from session
  String get userRole => UserSession.role ?? 'student';
  int get userId => UserSession.userId ?? 1;
  
  List<Map<String, dynamic>> historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingHistory();
  }

  // Load booking history from server
  Future<void> _loadBookingHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/user/$userId/bookings'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> bookingsData = data['bookings'];
        
        setState(() {
          historyList = bookingsData.map((booking) {
            return {
              "booking_id": booking['booking_id'].toString(),
              "room": booking['room_name'],
              "room_id": booking['room_id'].toString(),
              "description": booking['description'] ?? '',
              "capacity": booking['capacity'].toString(),
              "status": booking['status'],
              "reservedBy": "You", // Current user
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        // Fallback to local data if server fails
        _useLocalHistory();
      }
    } catch (e) {
      // If server is not available, use local data
      _useLocalHistory();
    }
  }

  void _useLocalHistory() {
    final allHistory = RoomPage.getBookingHistory();
    setState(() {
      historyList = userRole == "student"
          ? allHistory.where((h) => h["reservedBy"] == "Student A").toList()
          : allHistory;
      _isLoading = false;
    });
  }

  Color _getStatusColor(String status) {
    if (status == "Approved" || status == "confirmed") return Colors.green;
    if (status == "Rejected" || status == "cancelled") return Colors.red;
    if (status == "Pending" || status == "pending") return Colors.amber;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    int selectedIndex = 3;

    final allHistory = RoomPage.getBookingHistory();

    // ✅ แยกบทบาท
    final historyList = userRole == "student"
        ? allHistory.where((h) => h["reservedBy"] == "Student A").toList()
        : allHistory;

    // ignore: unused_element
    void onTabTapped(int index) {
      if (index == 0) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else if (index == 1) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const RoomPage()));
      } else if (index == 2) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const CheckRequestPage()));
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "History",
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

                        // ✅ รีเซ็ตค่าทั้งหมดจาก RoomPage
                        RoomPage.resetAll();

                        // ✅ กลับไปหน้า LoginPage
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFA726),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: historyList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No booking history yet",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: historyList.length,
                      itemBuilder: (context, index) {
                        final item = historyList[index];
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
                                  blurRadius: 6)
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.meeting_room,
                                              size: 20,
                                              color: Color(0xFF3E7BFA)),
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
                                      if (userRole != "student") ...[
                                        const SizedBox(height: 4),
                                        Text(
                                            "Reserved by: ${item["reservedBy"] ?? "-"}",
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87)),
                                      ]
                                    ]),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: _getStatusColor(
                                        item["status"] ?? ""),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(item["status"] ?? "",
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
          currentIndex: 3, // ✅ หน้านี้คือ History
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.checklist_rtl),
              label: "Check Request",
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
