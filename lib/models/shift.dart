import 'package:cloud_firestore/cloud_firestore.dart';

class Shift {
  final String id;
  final String name;
  final String startTime;
  final String endTime;

  Shift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  factory Shift.fromMap(Map<String, dynamic> map, String id) {
    return Shift(
      id: id,
      name: map['name'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}
