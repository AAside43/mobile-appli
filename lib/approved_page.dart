import 'package:flutter/material.dart';
// Make sure these paths are correct for your project structure
import 'dashboard_page.dart';
import 'room_page.dart';
import 'history_page.dart';

class ApprovedPage extends StatefulWidget {
  const ApprovedPage({Key? key}) : super(key: key);

  @override
  State<ApprovedPage> createState() => _ApprovedPageState();
}

// Dummy data moved outside the class to be used in initState
final List<Map<String, String>> _dummyRequests = [
  {
    'room': 'Room 1',
    'capacity': '4',
    'date': 'Oct 1, 2025',
    'time': '08:00 - 10:00',
    // FIX 1: Reverted to Image.asset and using case-sensitive filenames
    // from your screenshot (e.g., Room1.jpg, not room1.jpg)
    'image': 'assets/images/Room1.jpg'
  },
  {
    'room': 'Room 2',
    'capacity': '8',
    'date': 'Oct 1, 2025',
    'time': '08:00 - 10:00',
    'image': 'assets/images/Room2.jpg'
  },
  {
    'room': 'Room 3',
    'capacity': '16',
    'date': 'Oct 1, 2025',
    'time': '08:30 - 10:00',
    'image': 'assets/images/Room3.jpg'
  },
  {
    'room': 'Room 4',
    'capacity': '4',
    'date': 'Oct 1, 2025',
    'time': '08:00 - 10:00',
    'image': 'assets/images/Room1.jpg' // Re-using Room1.jpg as in your original code
  },
];

class _ApprovedPageState extends State<ApprovedPage> {
  int selectedIndex = 2; // this page = Check Request Tab
  late List<Map<String, String>> _requests; // Mutable list for state

  @override
  void initState() {
    super.initState();
    // Initialize the mutable list from the dummy data
    _requests = List.from(_dummyRequests);
  }

  void onTabTapped(int index) {
    if (index == selectedIndex) return; // Don't navigate to the same page

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
      // No navigation needed
    } else if (index == 3) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HistoryPage()));
    }
  }

  // Function to handle processing the request (accept or reject)
  void _processRequest(int index, String status) {
    final roomName = _requests[index]['room'];

    setState(() {
      _requests.removeAt(index);
    });

    // Show a snackbar to confirm the action
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$roomName request has been $status.'),
        backgroundColor: status == 'Accepted' ? Colors.green : Colors.red,
      ),
    );
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
            onPressed: () {
              // Example of how to refresh the list
              setState(() {
                _requests = List.from(_dummyRequests);
              });
            },
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: _requests.isEmpty
          ? const Center(
              child: Text(
                'No pending requests.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(
                  _requests[index],
                  () => _processRequest(index, 'Accepted'),
                  () => _processRequest(index, 'Rejected'),
                );
              },
            ),

      /// ✅ Bottom Navigation Bar
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
                  color: Color(0xFFFFA726), // Orange color for active tab
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

  Widget _buildRequestCard(
    Map<String, String> data,
    VoidCallback onAccept,
    VoidCallback onReject,
  ) {
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
            // FIX 1: Changed back to Image.asset
            child: Image.asset(
              data['image']!,
              width: 120,
              height: 110,
              fit: BoxFit.cover,
              // Add an error builder for robustness
              errorBuilder: (context, error, stackTrace) => Container(
                width: 120,
                height: 110,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
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
                  // FIX 2: Wrapped buttons in Expanded to prevent overflow
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          "Accept",
                          Colors.green,
                          onAccept,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _actionButton(
                          "Reject",
                          Colors.red,
                          onReject,
                        ),
                      ),
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

  // Changed this to an ElevatedButton for better layout control and click handling
  Widget _actionButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        // Ensures text doesn't wrap and fits
        child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }
}

