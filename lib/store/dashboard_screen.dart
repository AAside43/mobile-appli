import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_appli_1/store/room_store.dart';
import 'package:mobile_appli_1/widgets/room_card.dart';
import 'edit_room_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<RoomStore>().rooms;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final r = rooms[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditRoomScreen(room: r))),
                  child: RoomCard(room: r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}