import 'package:mobile_appli_1/models/room.dart';

class RoomHistory {
  final String id;
  final String roomId;
  final String roomNumber;
  final RoomStatus? from;
  final RoomStatus to;
  final DateTime timestamp;

  RoomHistory({
    required this.id,
    required this.roomId,
    required this.roomNumber,
    required this.from,
    required this.to,
    required this.timestamp,
  });
}