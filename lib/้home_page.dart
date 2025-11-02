import 'package:flutter/material.dart';
import 'room_page.dart';
import 'checkrequest_page.dart';
import 'history_page.dart';
import 'login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rooms = [
      {
        "name": "Room 1",
        "capacity": "4 people",
        "image": "assets/images/Room1.jpg"
      },
      {
        "name": "Room 2",
        "capacity": "8 people",
        "image": "assets/images/Room2.jpg"
      },
      {
        "name": "Room 3",
        "capacity": "16 people",
        "image": "assets/images/Room3.jpg"
      },
      {
        "name": "Room 4",
        "capacity": "16 people",
        "image": "assets/images/Room1.jpg"
      },
      {
        "name": "Room 5",
        "capacity": "8 people",
        "image": "assets/images/Room2.jpg"
      },
      {
        "name": "Room 6",
        "capacity": "16 people",
        "image": "assets/images/Room3.jpg"
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        title: const Text(
          "Home",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
  IconButton(
    icon: const Icon(
      Icons.logout_rounded,
      color: Colors.red, // 🔴 สีแดง
      size: 26,
    ),
    onPressed: () {
      // popup ยืนยันก่อนออก
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
                Navigator.pop(context); // ปิด popup
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                  (route) => false, // ล้าง stack ทั้งหมด
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

      // BODY
      body: Container(
        color: const Color(0xFFF8F9FB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Box
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.calendar_today_outlined, color: Colors.black54),
                    SizedBox(width: 10),
                    Text(
                      "Today: Oct 5, 2025",
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Grid of Rooms
              Expanded(
                child: GridView.builder(
                  itemCount: rooms.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ภาพห้องให้ลอยมีเงา
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    rooms[index]["image"],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rooms[index]["name"],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "Capacity : ${rooms[index]["capacity"]}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // BOTTOM NAV BAR
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: 0, // หน้า Home คือ index 0
          selectedItemColor: Colors.orange[700],
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          backgroundColor: Colors.white,

          // ✅ ฟังก์ชันเมื่อกดแท็บ
          onTap: (index) {
            if (index == 0) {
              // อยู่หน้า Home แล้ว ไม่ต้องทำอะไร
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const RoomPage()),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CheckRequestPage()),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            }
          },

          // ✅ รายการไอคอน (พร้อมวงกลมสีส้มเฉพาะ Home)
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA726),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_filled, color: Colors.white),
              ),
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

