import 'package:flutter/material.dart';
// ignore: unused_import
import 'home_page.dart';
import 'room_page.dart';
import 'history_page.dart';
import '้home_page.dart';
import 'login_page.dart';

class CheckRequestPage extends StatefulWidget {
  final List<Map<String, String>>? history; // ✅ รับค่ามาจาก RoomPage
  const CheckRequestPage({Key? key, this.history}) : super(key: key);

  @override
  State<CheckRequestPage> createState() => _CheckRequestPageState();
}

class _CheckRequestPageState extends State<CheckRequestPage> {
  @override
  Widget build(BuildContext context) {
    int selectedIndex = 2;

    void onTabTapped(int index) {
      if (index == 0) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else if (index == 1) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const RoomPage()));
      } else if (index == 3) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => HistoryPage(history: widget.history ?? [])));
      }
    }

    // ✅ ดึงข้อมูลจริงจากหน้า RoomPage
    final List<Map<String, dynamic>> requestList =
        widget.history != null && widget.history!.isNotEmpty
            ? widget.history!
                .map((item) => {
                      "room": item["room"],
                      "time": item["time"],
                      "reason": item["reason"],
                      "status": item["status"] ?? "Pending",
                    })
                .toList()
            : [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Check Request",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
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

      // ✅ BODY (สำหรับ Student)
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: requestList.isEmpty
            ? const Center(
                child: Text(
                  "No requests found.",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              )
            : Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.calendar_today_outlined,
                            color: Colors.black54),
                        SizedBox(width: 10),
                        Text(
                          "Today: Oct 5, 2025",
                          style:
                              TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ✅ แสดงรายการจาก RoomPage (แค่ดู ไม่แก้ไข)
                  Expanded(
                    child: ListView.builder(
                      itemCount: requestList.length,
                      itemBuilder: (context, index) {
                        final item = requestList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item["room"] ?? "Unknown Room",
                                      style: const TextStyle(
                                          fontSize: 18,
                                          color: Color(0xFF3E7BFA),
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text("Capacity: -",
                                        style: TextStyle(fontSize: 14)),
                                    const SizedBox(height: 6),
                                    const Text("Date : Oct 5, 2025"),
                                    Text("Time : ${item["time"] ?? "-"}"),
                                    Text("Reason : ${item["reason"] ?? "-"}"),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item["status"] == "Pending"
                                      ? Colors.amber
                                      : item["status"] == "Approved"
                                          ? Colors.green
                                          : Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item["status"]!,
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
                ],
              ),
      ),

      // ✅ Bottom Navigation Bar (เหมือนเดิม)
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