import 'package:flutter/material.dart';
// ignore: unused_import
import 'home_page.dart';
import 'room_page.dart';
import 'checkrequest_page.dart';
import '้home_page.dart';
import 'login_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({Key? key}) : super(key: key);

  // ✅ จำลองบทบาท (student / staff / lecturer)
  final String userRole = "student";

  Color _getStatusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Rejected") return Colors.red;
    if (status == "Pending") return Colors.amber;
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: historyList.isEmpty
            ? const Center(child: Text("No booking history yet"))
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
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1), blurRadius: 6)
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item["room"] ?? "-",
                                    style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text("Date : ${item["date"] ?? "Oct 5, 2025"}"),
                                Text("Time: ${item["time"]}"),
                                Text("Reason: ${item["reason"]}"),
                                if (userRole != "student") ...[
                                  const SizedBox(height: 4),
                                  Text("Reserved by: ${item["reservedBy"]}"),
                                  Text("Approved by: ${item["approvedBy"]}"),
                                ]
                              ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: _getStatusColor(item["status"] ?? ""),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(item["status"] ?? "",
                              style: const TextStyle(
                                  color: Colors.white,
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
