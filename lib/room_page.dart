import 'package:flutter/material.dart';
import 'package:mobile_appli_1/add_room.dart';
import 'package:mobile_appli_1/dashboard_page.dart';
import 'package:mobile_appli_1/edit_room.dart';
import 'package:mobile_appli_1/history_page.dart';
import 'package:mobile_appli_1/login_page.dart';

class RoomPage extends StatefulWidget {
  final List<Map<String, String>>? room;
  const RoomPage({super.key, this.room});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> roomList =
        widget.room != null && widget.room!.isNotEmpty
            ? widget.room!
                .map((item) => {
                      "image": item["image"] ?? "",
                      "room": item["room"],
                      "capacity": "-",
                      "switch": item["status"] == "available" ? true : false,
                    })
                .toList()
            : [
                // ✅ ข้อมูลตัวอย่างเดิมของคุณ (fallback)
                {
                  "image": "assets/images/Room1.jpg",
                  "room": "ROOM 1",
                  "capacity": "4 People",
                  "switch": true,
                },
                {
                  "image": "assets/images/Room2.jpg",
                  "room": "ROOM 2",
                  "capacity": "8 People",
                  "switch": true,
                },
                {
                  "image": "assets/images/Room3.jpg",
                  "room": "ROOM 3",
                  "capacity": "16 People",
                  "switch": true,
                },
                {
                  "image": "assets/images/Room1.jpg",
                  "room": "ROOM 4",
                  "capacity": "16 People",
                  "switch": true,
                },
                {
                  "image": "assets/images/Room2.jpg",
                  "room": "ROOM 5",
                  "capacity": "8 People",
                  "switch": true,
                },
                {
                  "image": "assets/images/Room3.jpg",
                  "room": "ROOM 6",
                  "capacity": "16 People",
                  "switch": true,
                },
              ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        title: const Text(
          "Room",
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
              Icons.add_box_rounded,
              color: Colors.black,
              size: 26,
            ),
            onPressed: () {
              // Action when pressed
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AddRoom()),
              );
            },
          ),
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

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: roomList.isEmpty
            ? const Center(
                child: Text(
                  "No room yet",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: roomList.length,
                itemBuilder: (context, index) {
                  final item = roomList[index];
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
                              item["image"] != null && item["image"]!.isNotEmpty
                                  ? Image.network(
                                      item["image"],
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 120,
                                      width: double.infinity,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.photo,
                                        color: Colors.grey,
                                        size: 50,
                                      ),
                                    ),
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
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: item["switch"] ?? false,
                                onChanged: (bool value) {
                                  setState(() {
                                    item["switch"] = value;
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.black,
                                  size: 26,
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const EditRoom()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
          currentIndex: 1, // หน้า Home คือ index 0
          selectedItemColor: Colors.orange[700],
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          backgroundColor: Colors.white,

          // ✅ ฟังก์ชันเมื่อกดแท็บ
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardPage()),
              );
            } else if (index == 1) {
              // อยู่หน้า Room แล้ว ไม่ต้องทำอะไร
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            }
          },

          // ✅ รายการไอคอน (พร้อมวงกลมสีส้มเฉพาะ Home)
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: "Dashboard",
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
              icon: Icon(Icons.history),
              label: "History",
            ),
          ],
        ),
      ),
    );
  }
}
