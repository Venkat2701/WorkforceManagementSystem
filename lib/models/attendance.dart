import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TimeSegment {
  final String startTime; // Format: HH:mm
  final String endTime; // Format: HH:mm

  TimeSegment({required this.startTime, required this.endTime});

  double get durationHours {
    if (startTime.isEmpty || endTime.isEmpty) return 0;
    try {
      DateTime parseTime(String timeStr) {
        if (timeStr.toUpperCase().contains('AM') ||
            timeStr.toUpperCase().contains('PM')) {
          return DateFormat('hh:mm a').parse(timeStr);
        }
        return DateFormat('HH:mm').parse(timeStr);
      }

      final start = parseTime(startTime);
      final end = parseTime(endTime);
      var diff = end.difference(start).inMinutes;
      if (diff < 0) diff += 24 * 60; // Handle overnight shifts
      return diff / 60.0;
    } catch (e) {
      return 0;
    }
  }

  Map<String, dynamic> toMap() => {'startTime': startTime, 'endTime': endTime};

  factory TimeSegment.fromMap(Map<String, dynamic> map) => TimeSegment(
    startTime: map['startTime'] ?? '',
    endTime: map['endTime'] ?? '',
  );
}

class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final double hoursWorked;
  final double overtimeHours;
  final bool isPresent;
  final bool isPaid;
  final List<TimeSegment> segments;
  final double? hourlyRate;
  final double? overtimeRate;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.hoursWorked,
    required this.overtimeHours,
    required this.isPresent,
    this.isPaid = false,
    this.segments = const [],
    this.hourlyRate,
    this.overtimeRate,
  });

  factory Attendance.fromMap(Map<String, dynamic> map, String id) {
    var segmentList =
        (map['segments'] as List?)
            ?.map((s) => TimeSegment.fromMap(s as Map<String, dynamic>))
            .toList() ??
        [];
    return Attendance(
      id: id,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      hoursWorked: (map['hoursWorked'] ?? 0).toDouble(),
      overtimeHours: (map['overtimeHours'] ?? 0).toDouble(),
      isPresent: map['isPresent'] ?? false,
      isPaid: map['isPaid'] ?? false,
      segments: segmentList,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble(),
      overtimeRate: (map['overtimeRate'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': Timestamp.fromDate(date),
      'hoursWorked': hoursWorked,
      'overtimeHours': overtimeHours,
      'isPresent': isPresent,
      'isPaid': isPaid,
      'segments': segments.map((s) => s.toMap()).toList(),
      'hourlyRate': hourlyRate,
      'overtimeRate': overtimeRate,
    };
  }

  Attendance copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    DateTime? date,
    double? hoursWorked,
    double? overtimeHours,
    bool? isPresent,
    bool? isPaid,
    List<TimeSegment>? segments,
    double? hourlyRate,
    double? overtimeRate,
  }) {
    return Attendance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      date: date ?? this.date,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      isPresent: isPresent ?? this.isPresent,
      isPaid: isPaid ?? this.isPaid,
      segments: segments ?? this.segments,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      overtimeRate: overtimeRate ?? this.overtimeRate,
    );
  }
}
