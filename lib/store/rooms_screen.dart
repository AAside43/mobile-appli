import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_appli_1/store/room_store.dart';
import 'package:mobile_appli_1/models/room.dart';
import 'edit_room_screen.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RoomStore>();
    final rooms = store.rooms;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView.separated(
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final r = rooms[i];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10), color: Colors.white),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: r.imagePath != null ? Image.file(File(r.imagePath!), width: 80, height: 56, fit: BoxFit.cover) : Container(width: 80, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.photo, color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(r.status.label, style: TextStyle(color: Colors.grey.shade600)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditRoomScreen(room: r)))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: RoomStatus.ready.color),
                    onPressed: () {
                      store.changeStatus(r.id, r.status == RoomStatus.ready ? RoomStatus.notReady : RoomStatus.ready);
                    },
                    child: const Text('Toggle Ready'),
                  ),
                ])
              ],
            ),
          );
        },
      ),
    );
  }
}