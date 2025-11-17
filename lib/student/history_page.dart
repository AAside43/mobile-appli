import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

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
  static const String serverUrl = 'http://192.168.57.1:3000';

  int get userId => UserSession.userId ?? 1;
  String get userRole => UserSession.role ?? "student";

  List<Map<String, dynamic>> historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingHistory();
  }

  // =============================
  // LOAD HISTORY FROM SERVER
  // =============================
  Future<void> _loadBookingHistory() async {
    try {
      final response =
          await http.get(Uri.parse('$serverUrl/user/$userId/bookings'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> list = data["bookings"];

        setState(() {
          historyList = list.map((b) {
            return {
              "booking_id": b["booking_id"].toString(),
              "room": b["room_name"] ?? "Unknown room",
              "room_id": b["room_id"]?.toString() ?? "",
              "description": b["description"] ?? "",
              "capacity": b["capacity"]?.toString() ?? "",
              "time": b["time_slot"],
              "date": b["booking_date"],
              "reason": b["reason"] ?? "",
              "status": b["status"] ?? "Pending",
              "reservedBy": b["reserved"] ?? "-",
              "approvedBy": b["approved"] ?? "-",
              "rejection_reason": b["rejection_reason"] ?? "",
            };
          }).toList();

          // sort: latest → oldest
          historyList.sort((a, b) {
            try {
              final da = DateFormat("MMM d, yyyy").parse(a["date"]);
              final db = DateFormat("MMM d, yyyy").parse(b["date"]);
              return db.compareTo(da);
            } catch (_) {
              return 0;
            }
          });

          _isLoading = false;
        });
      } else {
        print("❌ Server returned ${response.statusCode}");
        _useLocalHistory();
      }
    } catch (e) {
      print("❌ Error loading history: $e");
      _useLocalHistory();
    }
  }

  // Local fallback if server unreachable
  void _useLocalHistory() {
    final local = RoomPage.getBookingHistory();
    setState(() {
      historyList = local;
      _isLoading = false;
    });
  }

  // =============================
  // STATUS COLOR
  // =============================
  Color _statusColor(String s) {
    s = s.toLowerCase();
    if (s == "approved") return Colors.green;
    if (s == "pending") return Colors.amber;
    if (s == "rejected") return Colors.red;
    if (s == "cancelled") return Colors.grey;
    return Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // =============================
      // APP BAR
      // =============================
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
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Logout and reset all data?"),
                  actions: [
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: const Text("Logout",
                          style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        RoomPage.resetAll();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      // =============================
      // BODY
      // =============================
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFA726)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: historyList.isEmpty
                  ? const Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No history yet",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: historyList.length,
                      itemBuilder: (_, index) {
                        final item = historyList[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 6),
                            ],
                          ),

                          // =============================
                          // CARD BODY
                          // =============================
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT DETAILS
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.meeting_room,
                                            color: Color(0xFF3E7BFA)),
                                        const SizedBox(width: 8),
                                        Text(
                                          item["room"],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF3E7BFA),
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if ((item["date"] ?? "").isNotEmpty)
                                      Text("Date: ${item["date"]}"),
                                    if ((item["time"] ?? "").isNotEmpty)
                                      Text("Time: ${item["time"]}"),
                                    if ((item["description"] ?? "").isNotEmpty)
                                      Text(
                                          "Description: ${item["description"]}"),
                                    if ((item["reason"] ?? "").isNotEmpty)
                                      Text("Reason: ${item["reason"]}"),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Booking ID: ${item["booking_id"]}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                    ),
                                    if (userRole != "student") ...[
                                      const SizedBox(height: 4),
                                      Text(
                                          "Reserved by: ${item["reservedBy"]}"),
                                      if ((item["approvedBy"] ?? "") != "")
                                        Text(
                                            "Approved by: ${item["approvedBy"]}"),
                                      if ((item["rejection_reason"] ?? "")
                                          .isNotEmpty)
                                        Text(
                                            "Rejection Reason: ${item["rejection_reason"]}"),
                                    ]
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // STATUS BADGE
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(item["status"]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item["status"],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

      // =============================
      // BOTTOM NAV
      // =============================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: const Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 3,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
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
            } else if (index == 3) {}
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_filled), label: "Home"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.meeting_room_outlined), label: "Room"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rtl), label: "Check Request"),
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
