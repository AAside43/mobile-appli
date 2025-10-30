import 'package:flutter/material.dart';
import 'login_page.dart';  // Import the login page

class EditRoom extends StatefulWidget {
  const EditRoom({super.key});

  @override
  State<EditRoom> createState() => _EditRoomState();
}

class _EditRoomState extends State<EditRoom> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        title: const Text(
          "Edit Room",
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



    );
  }
}