import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'room_page.dart';
import 'history_page.dart';

class ApprovedPage extends StatefulWidget {
  const ApprovedPage({Key? key}) : super(key: key);

  @override
  State<ApprovedPage> createState() => _ApprovedPageState();
}

class _ApprovedPageState extends State<ApprovedPage> {
  int selectedIndex = 2; // this page = Check Request Tab

  final List<Map<String, String>> requests = [
    {
      'room': 'Room 1',
      'capacity': '4',
      'date': 'Oct 1, 2025',
      'time': '08:00 - 10:00',
      'image': 'assets/images/room1.jpg'
    },
    {
      'room': 'Room 2',
      'capacity': '8',
      'date': 'Oct 1, 2025',
      'time': '08:00 - 10:00',
      'image': 'assets/images/room2.jpg'
    },
    {
      'room': 'Room 3',
      'capacity': '16',
      'date': 'Oct 1, 2025',
      'time': '08:30 - 10:00',
      'image': 'assets/images/room3.jpg'
    },
    {
      'room': 'Room 4',
      'capacity': '4',
      'date': 'Oct 1, 2025',
      'time': '08:00 - 10:00',
      'image': 'assets/images/room1.jpg'
    },
  ];

  void onTabTapped(int index) {
    setState(() {
      selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => DashboardPage()));
    } else if (index == 1) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => RoomPage()));
    } else if (index == 2) {
      // CURRENT PAGE: Approved / Check Request page
    } else if (index == 3) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HistoryPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Checking Request",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(requests[index]);
        },
      ),

      /// ✅ Bottom Navigation Bar added
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
                icon: Icon(Icons.home_filled), label: "Home"),
            BottomNavigationBarItem(
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
            BottomNavigationBarItem(
              icon: Icon(Icons.history), label: "History"),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, String> data) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.asset(
              data['image']!,
              width: 120,
              height: 110,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['room']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Capacity : ${data['capacity']} people"),
                  Text("Date : ${data['date']}"),
                  Text("Time : ${data['time']}"),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _actionButton("Accept", Colors.green),
                      const SizedBox(width: 6),
                      _actionButton("Reject", Colors.red),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
