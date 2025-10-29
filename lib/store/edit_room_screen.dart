import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mobile_appli_1/models/room.dart';
import 'package:mobile_appli_1/store/room_store.dart';

class EditRoomScreen extends StatefulWidget {
  final Room room;
  const EditRoomScreen({required this.room, super.key});

  @override
  State<EditRoomScreen> createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends State<EditRoomScreen> {
  late Room editable;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    editable = widget.room;
  }

  Future<void> _pickImage() async {
    final XFile? f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (f != null) setState(() => editable = editable.copyWith(imagePath: f.path));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<RoomStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Room')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Room', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(editable.number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Preview Image', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100),
            child: editable.imagePath != null ? Image.file(File(editable.imagePath!), fit: BoxFit.cover) : const Center(child: Icon(Icons.photo, size: 48, color: Colors.grey)),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _pickImage, child: const Text('Upload Image')),
          const SizedBox(height: 12),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: RoomStatus.values.map((s) {
            final selected = editable.status == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s.label),
                selected: selected,
                selectedColor: s.color,
                backgroundColor: Colors.grey.shade200,
                onSelected: (_) => setState(() => editable = editable.copyWith(status: s)),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
              ),
            );
          }).toList()),
          const Spacer(),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  store.updateRoom(editable);
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