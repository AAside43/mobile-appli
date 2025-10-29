import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_appli_1/store/room_store.dart';
import 'package:mobile_appli_1/models/room.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<RoomStore>().history;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Expanded(
          child: history.isEmpty
              ? const Center(child: Text('No logs yet'))
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final h = history[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8), color: Colors.white),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${h.roomNumber} changed from ${h.from?.label ?? '—'} to ${h.to.label}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(h.timestamp.toLocal().toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ]),
                    );
                  },
                ),
        )
      ]),
    );
  }
}