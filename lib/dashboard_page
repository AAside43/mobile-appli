import 'package:flutter/material.dart';
import 'login_page.dart';
import 'room_page.dart';
import 'history_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0; // ✅ Dashboard tab

  final List<Map<String, dynamic>> roomStatus = [
    {"label": "Pending room", "count": 2, "color": Colors.yellow},
    {"label": "Free room", "count": 4, "color": Colors.green},
    {"label": "Disable room", "count": 1, "color": Colors.grey},
    {"label": "Reserved room", "count": 2, "color": Colors.red},
  ];

  // ✅ ฟังก์ชันเปลี่ยนหน้า bottom nav
  void onTabTapped(int index) {
    setState(() => selectedIndex = index);

    if (index == 0) return; // Dashboard อยู่แล้ว
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoomPage()),
      );
    } else if (index == 2) {
      // ไปหน้า Check Request (ยังไม่ได้สร้าง)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Check Request page not added yet")),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HistoryPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        title: const Text(
          "Dashboard",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
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
                        child: const Text("Cancel")),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: roomStatus.map((room) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: room["color"],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    room["label"],
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room["count"].toString(),
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
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
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          onTap: onTabTapped,
          items: [
            BottomNavigationBarItem(
              icon: selectedIndex == 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFA726),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home_filled, color: Colors.white),
                    )
                  : const Icon(Icons.home_filled),
              label: "Dashboard",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.meeting_room_outlined), label: "Room"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rtl), label: "Check Request"),
            BottomNavigationBarItem(
              icon: selectedIndex == 3
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFA726),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history, color: Colors.white),
                    )
                  : const Icon(Icons.history),
              label: "History",
            ),
          ],
        ),
      ),
    );
  }
}
