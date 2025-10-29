import 'package:flutter/material.dart';
import 'package:mobile_appli_1/models/room.dart';
import 'package:mobile_appli_1/models/room_history.dart';

class RoomStore extends ChangeNotifier {
  final List<Room> _rooms = [];
  final List<RoomHistory> _history = [];

  List<Room> get rooms => List.unmodifiable(_rooms);
  List<RoomHistory> get history => List.unmodifiable(_history);

  void loadSample() {
    _rooms.clear();
    _rooms.addAll([
      Room(id: '1', number: 'Room 1', status: RoomStatus.notReady),
      Room(id: '2', number: 'Room 2', status: RoomStatus.ready),
      Room(id: '4', number: 'Room 4', status: RoomStatus.inProgress),
      Room(id: '3', number: 'Room 3', status: RoomStatus.ready),
    ]);
    notifyListeners();
  }

  void addRoom(Room r) {
    _rooms.insert(0, r);
    _history.insert(
      0,
      RoomHistory(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        roomId: r.id,
        roomNumber: r.number,
        from: null,
        to: r.status,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void updateRoom(Room updated) {
    final idx = _rooms.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    final prev = _rooms[idx];
    if (prev.status != updated.status) {
      _history.insert(
        0,
        RoomHistory(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          roomId: updated.id,
          roomNumber: updated.number,
          from: prev.status,
          to: updated.status,
          timestamp: DateTime.now(),
        ),
      );
    }
    _rooms[idx] = updated;
    notifyListeners();
  }

  void changeStatus(String roomId, RoomStatus newStatus) {
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx == -1) return;
    final prev = _rooms[idx];
    _rooms[idx] = prev.copyWith(status: newStatus);
    _history.insert(
      0,
      RoomHistory(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        roomId: prev.id,
        roomNumber: prev.number,
        from: prev.status,
        to: newStatus,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
