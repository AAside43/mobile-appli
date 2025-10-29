import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mobile_appli_1/models/room.dart';
import 'package:mobile_appli_1/store/room_store.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _controller = TextEditingController();
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (f != null) setState(() => _imagePath = f.path);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<RoomStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Add Room')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(controller: _controller, decoration: const InputDecoration(labelText: 'Room #')),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: _imagePath == null ? const Center(child: Text('Tap to select image')) : Image.file(File(_imagePath!), fit: BoxFit.cover),
            ),
          ),
          const Spacer(),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final num = _controller.text.trim();
                  if (num.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter room number')));
                    return;
                  }
                  final r = Room(id: DateTime.now().microsecondsSinceEpoch.toString(), number: num, status: RoomStatus.notReady, imagePath: _imagePath);
                  store.addRoom(r);
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            )
          ])
        ]),
      ),
    );
  }
}