import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ignore: unused_import
import 'room_page.dart';
import 'history_page.dart';
import '../login_page.dart';
import 'user_session.dart';
import 'home_page.dart';

class CheckRequestPage extends StatefulWidget {
  const CheckRequestPage({Key? key}) : super(key: key);

  @override
  State<CheckRequestPage> createState() => _CheckRequestPageState();
}

class _CheckRequestPageState extends State<CheckRequestPage> {
  static const String serverUrl = 'http://192.168.57.1:3000';

  int get userId => UserSession.userId ?? 1;
  String get userRole => UserSession.role ?? "student";

  List<Map<String, dynamic>> requestList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingRequests();
  }

  // ==============================
  // LOAD BOOKING REQUESTS (SERVER)
  // ==============================
  Future<void> _loadBookingRequests() async {
    setState(() => _isLoading = true);

    try {
      final response =
          await http.get(Uri.parse('$serverUrl/user/$userId/bookings'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> list = data["bookings"];

        setState(() {
          requestList = list.map((b) {
            return {
              "booking_id": b["booking_id"].toString(),
              "room": b["room_name"] ?? "Unknown room",
              "room_id": b["room_id"]?.toString() ?? "",
              "description": b["description"] ?? "",
              "capacity": b["capacity"]?.toString() ?? "",
              "time": b["time_slot"] ?? "",
              "date": b["booking_date"] ?? "",
              "reason": b["reason"] ?? "",
              "status": b["status"] ?? "Pending",
              "reservedBy": UserSession.username ?? "You",
            };
          }).toList();

          _isLoading = false;
        });
      } else {
        print("❌ Server responded with ${response.statusCode}");
        _useLocalRequests();
      }
    } catch (e) {
      print("❌ Error: $e");
      _useLocalRequests();
    }
  }

  // ==============================
  // LOCAL FALLBACK
  // ==============================
  void _useLocalRequests() {
    final local = RoomPage.getBookingHistory();

    setState(() {
      requestList = local;
      _isLoading = false;
    });
  }

  // ==============================
  // CANCEL BOOKING
  // ==============================
  Future<void> _cancelBooking(String bookingId) async {
    try {
      final response =
          await http.delete(Uri.parse('$serverUrl/booking/$bookingId'));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Booking cancelled successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookingRequests();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed : ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Cancel error: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==============================
  // CONFIRM CANCEL DIALOG
  // ==============================
  void _showCancelDialog(String bookingId, String roomName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text("Cancel Booking"),
          ],
        ),
        content: Text("Do you want to cancel the booking for $roomName?"),
        actions: [
          TextButton(
            child: const Text("No"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(bookingId);
            },
          ),
        ],
      ),
    );
  }

  // Color of status badge
  Color _statusColor(String status) {
    status = status.toLowerCase();
    if (status == "pending") return Colors.amber;
    if (status == "approved" || status == "confirmed") return Colors.green;
    if (status == "rejected" || status == "cancelled") return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ==============================
      // APP BAR
      // ==============================
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

      // ==============================
      // BODY
      // ==============================
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFA726)),
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
                          Text("No requests found",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: requestList.length,
                      itemBuilder: (_, index) {
                        final item = requestList[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            children: [
                              // =====================
                              // LEFT SIDE DETAILS
                              // =====================
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF3E7BFA)),
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
                                    Text(
                                      "Booking ID: ${item["booking_id"]}",
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                    ),
                                    if (userRole != "student")
                                      Text(
                                          "Reserved by: ${item["reservedBy"]}"),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // =====================
                              // STATUS BADGE
                              // =====================
                              Column(
                                children: [
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

                                  const SizedBox(height: 8),

                                  // Cancel button only when pending
                                  if (item["status"].toLowerCase() == "pending")
                                    TextButton(
                                      child: const Text(
                                        "Cancel",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () => _showCancelDialog(
                                          item["booking_id"], item["room"]),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

      // ==============================
      // BOTTOM NAV
      // ==============================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 2,
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
            } // current page
            else if (index == 3) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()));
            }
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_filled), label: "Home"),
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
}
