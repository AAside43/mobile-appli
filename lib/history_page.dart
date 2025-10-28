import 'package:flutter/material.dart';
// ignore: unused_import
import 'home_page.dart';
import 'room_page.dart';
import 'checkrequest_page.dart';
import '้home_page.dart';
import 'login_page.dart';

class HistoryPage extends StatelessWidget {
  // ✅ เพิ่มพารามิเตอร์รับข้อมูลจาก RoomPage
  final List<Map<String, String>>? history;
  const HistoryPage({Key? key, this.history}) : super(key: key);

  Color _getStatusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Rejected") return Colors.red;
    if (status == "Pending") return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex = 3;

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

    // ✅ ถ้ามี history จาก RoomPage ให้ใช้ข้อมูลจริง
    final List<Map<String, dynamic>> historyList = history != null && history!.isNotEmpty
        ? history!
            .map((item) => {
                  "room": item["room"],
                  "capacity": "-",
                  "date": "Oct 5, 2025",
                  "time": item["time"],
                  "reserved": "Student A",
                  "approved": "Lecturer CE",
                  "reason": item["reason"],
                  "status": item["status"] ?? "Pending",
                })
            .toList()
        : [
            // ✅ ข้อมูลตัวอย่างเดิมของคุณ (fallback)
            {
              "room": "ROOM 1",
              "capacity": "4 People",
              "date": "Oct 5, 2025",
              "time": "08:00 - 10:00",
              "reserved": "Student A",
              "approved": "Lecturer A",
              "status": "Approved"
            },
            {
              "room": "ROOM 2",
              "capacity": "8 People",
              "date": "Oct 5, 2025",
              "time": "10:00 - 12:00",
              "reserved": "Student A",
              "approved": "Lecturer B",
              "status": "Approved"
            },
            {
              "room": "ROOM 3",
              "capacity": "16 People",
              "date": "Oct 5, 2025",
              "time": "13:00 - 15:00",
              "reserved": "Student A",
              "approved": "Lecturer C",
              "status": "Rejected"
            },
            {
              "room": "ROOM 4",
              "capacity": "16 People",
              "date": "Oct 5, 2025",
              "time": "15:00 - 17:00",
              "reserved": "Student A",
              "approved": "Lecturer D",
              "status": "Rejected"
            },
          ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "History",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.red,
              size: 26,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text(
                    "Logout",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: historyList.isEmpty
            ? const Center(
                child: Text(
                  "No booking history yet",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: historyList.length,
                itemBuilder: (context, index) {
                  final item = historyList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item["room"],
                                style: const TextStyle(
                                  color: Color(0xFF3E7BFA),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(item["capacity"]),
                              const SizedBox(height: 4),
                              Text("Date : ${item["date"]}"),
                              Text("Time : ${item["time"]}"),
                              if (item["reason"] != null)
                                Text("Reason : ${item["reason"]}"),
                              Text("Reserved by : ${item["reserved"]}"),
                              Text("Approved by : ${item["approved"]}"),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(item["status"]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item["status"],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),

      // ✅ bottom nav (คงเดิม)
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
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: onTabTapped,
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
