import 'package:flutter/material.dart';

enum RoomStatus { ready, inProgress, notReady }

extension RoomStatusExt on RoomStatus {
  String get label {
    switch (this) {
      case RoomStatus.ready:
        return 'Ready';
      case RoomStatus.inProgress:
        return 'In Progress';
      case RoomStatus.notReady:
        return 'Not Ready';
    }
  }

  Color get color {
    switch (this) {
      case RoomStatus.ready:
        return Colors.green;
      case RoomStatus.inProgress:
        return Colors.grey;
      case RoomStatus.notReady:
        return Colors.red;
    }
  }
}

class Room {
  final String id;
  final String number;
  final RoomStatus status;
  final String? imagePath;

  Room({
    required this.id,
    required this.number,
    required this.status,
    this.imagePath,
  });

  Room copyWith({String? number, RoomStatus? status, String? imagePath}) {
    return Room(
      id: id,
      number: number ?? this.number,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}