import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../login_page.dart';
import 'staff_room_page.dart';

class StaffEditRoomPage extends StatefulWidget {
  final Map<String, dynamic> roomData;
  const StaffEditRoomPage({super.key, required this.roomData});

  @override
  State<StaffEditRoomPage> createState() => _StaffEditRoomPageState();
}

class _StaffEditRoomPageState extends State<StaffEditRoomPage> {
  late TextEditingController _roomNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _capacityController;
  final String baseUrl = apiBaseUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController(text: widget.roomData['name']);
    _descriptionController =
        TextEditingController(text: widget.roomData['description'] ?? '');
    _capacityController =
        TextEditingController(text: widget.roomData['capacity'].toString());
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    if (token == null) {
      _logout();
      throw Exception('No token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };
  }

  Future<void> _updateRoom() async {
    setState(() => _isLoading = true);
    final roomId = widget.roomData['room_id'];

    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/rooms/$roomId'),
        headers: headers,
        body: json.encode({
          "name": _roomNameController.text,
          "description": _descriptionController.text,
          "capacity": int.tryParse(_capacityController.text) ?? 1,
          "image": widget.roomData['image']
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Room updated successfully!")));
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const StaffRoomPage()),
            (r) => false);
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3,
        title: const Text("Edit Room",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _logout();
                        },
                        child: const Text("Logout",
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                      image: AssetImage(widget.roomData['image'] ??
                          "assets/images/Room1.jpg"),
                      fit: BoxFit.cover)),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: Icon(Icons.edit, color: Colors.white, size: 40)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
                controller: _roomNameController,
                decoration: const InputDecoration(
                    labelText: 'Room Name', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(
                controller: _capacityController,
                decoration: const InputDecoration(
                    labelText: 'Capacity', border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateRoom,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white))
                      : const Text("Save Changes"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Cancel"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
