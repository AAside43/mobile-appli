import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
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
  File? _selectedImage;
  String? _selectedAssetImage;
  final ImagePicker _picker = ImagePicker();
  
  final List<String> _assetImages = [
    'assets/images/Room1.jpg',
    'assets/images/Room2.jpg',
    'assets/images/Room3.jpg',
  ];

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

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.orange),
              title: const Text('Assets'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromAssets();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedAssetImage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  Future<void> _pickImageFromAssets() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose from Assets'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _assetImages.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAssetImage = _assetImages[index];
                    _selectedImage = null;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      _assetImages[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRoom() async {
    setState(() => _isLoading = true);
    final roomId = widget.roomData['room_id'];

    try {
      final headers = await _getAuthHeaders();
      
      // Convert image to base64 if a new one was selected
      String? imageBase64 = widget.roomData['image']; // Keep existing image by default
      
      if (_selectedImage != null) {
        // From gallery
        final bytes = await _selectedImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      } else if (_selectedAssetImage != null) {
        // From assets
        final ByteData data = await rootBundle.load(_selectedAssetImage!);
        final Uint8List bytes = data.buffer.asUint8List();
        imageBase64 = base64Encode(bytes);
      }
      
      final response = await http.put(
        Uri.parse('$baseUrl/rooms/$roomId'),
        headers: headers,
        body: json.encode({
          "name": _roomNameController.text,
          "description": _descriptionController.text,
          "capacity": int.tryParse(_capacityController.text) ?? 1,
          "image": imageBase64
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

  Widget _buildRoomImage() {
    // Show newly selected gallery image
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    
    // Show newly selected asset image
    if (_selectedAssetImage != null) {
      return Image.asset(
        _selectedAssetImage!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    
    // Show existing image from database (base64)
    if (widget.roomData['image'] != null && widget.roomData['image'] is String && widget.roomData['image'].isNotEmpty) {
      try {
        Uint8List bytes = base64Decode(widget.roomData['image']);
        return Image.memory(
          bytes,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _defaultRoomImage();
          },
        );
      } catch (e) {
        return _defaultRoomImage();
      }
    }
    
    // Fallback to default image
    return _defaultRoomImage();
  }

  Widget _defaultRoomImage() {
    return Image.asset(
      "assets/images/Room1.jpg",
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 180,
          width: double.infinity,
          color: Colors.grey[300],
          child: const Icon(Icons.meeting_room, size: 40, color: Colors.grey),
        );
      },
    );
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
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
<<<<<<< HEAD
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: Icon(Icons.edit, color: Colors.white, size: 40)),
=======
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey)),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildRoomImage(),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 40),
                            SizedBox(height: 8),
                            Text('Tap to change image',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
>>>>>>> 799f64965b5f4f11c1671a1c22f4a0cfae077645
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white))
                      : const Text("Save Changes"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
