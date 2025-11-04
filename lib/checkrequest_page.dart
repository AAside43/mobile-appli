import 'package:flutter/material.dart';
// ignore: unused_import
import 'home_page.dart';
import 'room_page.dart';
import 'history_page.dart';
import '้home_page.dart';
import 'login_page.dart';

class CheckRequestPage extends StatefulWidget {
  const CheckRequestPage({Key? key}) : super(key: key);

  @override
  State<CheckRequestPage> createState() => _CheckRequestPageState();
}

class _CheckRequestPageState extends State<CheckRequestPage> {
  // ✅ จำลองบทบาท (จะมาจาก Login จริงในอนาคต)
  final String userRole = "student"; // เปลี่ยนเป็น "staff" หรือ "lecturer" ได้

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    int selectedIndex = 2;

    // ✅ ดึงข้อมูลจาก RoomPage โดยตรง
    final List<Map<String, String>> allRequests = RoomPage.getBookingHistory();

    // ✅ แสดงเฉพาะคำขอของตัวเอง (สำหรับ student)
    final requestList = userRole == "student"
        ? allRequests.where((req) => req["reservedBy"] == "Student A").toList()
        : allRequests;

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

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: requestList.isEmpty
            ? const Center(child: Text("No requests found."))
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
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1), blurRadius: 8)
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
                          child: Text(item["status"]!,
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
