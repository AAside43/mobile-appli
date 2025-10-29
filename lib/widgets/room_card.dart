import 'package:flutter/material.dart';
import 'package:mobile_appli_1/models/room.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  const RoomCard({required this.room, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(room.number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: room.status.color, borderRadius: BorderRadius.circular(20)),
              child: Text(room.status.label, style: const TextStyle(color: Colors.white)),
            ),
            TextButton(onPressed: () {}, child: const Text('Edit')),
          ]),
        ]),
      ),
    );
  }
}