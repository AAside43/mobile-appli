import 'package:flutter/material.dart';
import 'login_page.dart';  // Adjust the import path based on your file structure

class AddRoom extends StatefulWidget {
  const AddRoom({super.key});

  @override
  State<AddRoom> createState() => _AddRoomState();
}

class _AddRoomState extends State<AddRoom> {
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        title: const Text(
          "Add Room",
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

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Image upload placeholder
            GestureDetector(
              onTap: () {
                // TODO: Add image picker logic
              },
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: Center(
                  child: Icon(Icons.add, size: 40, color: Colors.grey),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Room name input
            TextField(
              controller: _roomNameController,
              decoration: InputDecoration(
                labelText: 'Add Room Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Description input
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Add description here',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 24),

            // Save and Cancel buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: Save logic
                    print('Room Saved');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text('Save'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),

    );
  }
}