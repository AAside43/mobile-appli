import 'package:flutter/material.dart';
import 'package:mobile_appli_1/home_page.dart';

// ignore: unused_import
import 'home_page.dart';
import 'checkrequest_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import '้home_page.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({Key? key}) : super(key: key);

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  // ignore: unused_field
  int _selectedIndex = 1;

  // 🧠 ตัวแปรเก็บประวัติการจอง
  static List<Map<String, String>> _bookingHistory = [];

  final List<String> timeSlots = [
    '08:00-10:00',
    '10:00-12:00',
    '13:00-15:00',
    '15:00-17:00',
  ];

  final List<Map<String, dynamic>> rooms = [
    {
      "name": "Room 1",
      "status": ["Free", "Reserved", "Reserved", "Reserved"]
    },
    {
      "name": "Room 2",
      "status": ["Free", "Free", "Pending", "Reserved"]
    },
    {
      "name": "Room 3",
      "status": ["Disabled", "Disabled", "Disabled", "Disabled"]
    },
    {
      "name": "Room 4",
      "status": ["Free", "Pending", "Free", "Free"]
    },
    {
      "name": "Room 5",
      "status": ["Pending", "Free", "Reserved", "Free"]
    },
    {
      "name": "Room 6",
      "status": ["Free", "Free", "Free", "Pending"]
    },
  ];

  Color _getColor(String status) {
    switch (status) {
      case "Free":
        return Colors.green;
      case "Reserved":
        return Colors.red;
      case "Pending":
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // ✅ ฟังก์ชัน popup พร้อมบันทึกข้อมูลจริง
  void _showBookingDialog(String roomName, String timeSlot) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Column(
            children: [
              Text("Booking $roomName",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 6),
              Text("Time : $timeSlot",
                  style: const TextStyle(color: Colors.black54, fontSize: 14)),
            ],
          ),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: "Enter reason for booking...",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                Navigator.pop(context);

                // ✅ บันทึกประวัติ
                setState(() {
                  _bookingHistory.add({
                    "room": roomName,
                    "time": timeSlot,
                    "reason": reason.isEmpty ? "—" : reason,
                    "status": "Pending",
                  });
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("✅ $roomName booked for $timeSlot",
                        textAlign: TextAlign.center),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text("Book Now", style: TextStyle(color: Colors.white)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  // ✅ ฟังก์ชันส่งข้อมูลประวัติให้หน้า HistoryPage
  List<Map<String, String>> getBookingHistory() => _bookingHistory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Room",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false,
                        );
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // วันที่
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.calendar_today_outlined,
                      color: Colors.black54, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Today: Oct 5, 2025",
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),

// ✅ เพิ่มระยะห่างระหว่างช่องวันที่กับช่องเวลา
            const SizedBox(height: 12),


            // ตารางเวลา (คงเดิม)
            SizedBox(
              height: 45,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: timeSlots.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text("Room/Time",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ),
                    );
                  } else {
                    final slot = timeSlots[index - 1];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(slot,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.black87)),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            const Divider(thickness: 1, height: 20),

            // ✅ ตารางห้อง (อัปเดต)
            Expanded(
              child: ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (context, roomIndex) {
                  final room = rooms[roomIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(room["name"],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              room["status"].length,
                              (statusIndex) {
                                String status = room["status"][statusIndex];
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: status == "Free"
                                        ? () => _showBookingDialog(
                                              room["name"],
                                              timeSlots[statusIndex],
                                            )
                                        : null,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _getColor(status),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(status,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12)),
                                    ),
                                  ),
                                );
                              },
                            ),
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

      // ✅ ส่งข้อมูลไป HistoryPage
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
          currentIndex: 1,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => const HomePage()));

            } else if (index == 2) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CheckRequestPage()));
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryPage(history: _bookingHistory),
                ),
              );
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA726),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.meeting_room_outlined,
                    color: Colors.white),
              ),
              label: "Room",
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.checklist_rtl),
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
