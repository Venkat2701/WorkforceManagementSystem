import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String name;
  final String phone;
  final double hourlyRate;
  final double overtimeRate;
  final String shiftId;
  final String status; // 'Active', 'On Leave', 'On Shift'
  final DateTime joinedDate;
  final DateTime dateOfBirth;
  final String aadharNumber;
  final String salaryType; // 'Daily', 'Monthly'
  final Map<String, double> hourlyRateHistory;
  final Map<String, double> overtimeRateHistory;

  Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.hourlyRate,
    required this.overtimeRate,
    required this.shiftId,
    required this.status,
    required this.joinedDate,
    required this.dateOfBirth,
    required this.aadharNumber,
    required this.salaryType,
    Map<String, double>? hourlyRateHistory,
    Map<String, double>? overtimeRateHistory,
  }) : hourlyRateHistory = hourlyRateHistory ?? {},
       overtimeRateHistory = overtimeRateHistory ?? {};

  double getHourlyRateForDate(DateTime date) {
    if (hourlyRateHistory.isEmpty) return hourlyRate;
    final dateStr = _formatDateKey(date);
    final sortedKeys = hourlyRateHistory.keys.toList()..sort();
    double lastRate = hourlyRate;
    for (var key in sortedKeys) {
      if (key.compareTo(dateStr) <= 0) {
        lastRate = hourlyRateHistory[key]!;
      } else {
        break;
      }
    }
    return lastRate;
  }

  double getOvertimeRateForDate(DateTime date) {
    if (overtimeRateHistory.isEmpty) return overtimeRate;
    final dateStr = _formatDateKey(date);
    final sortedKeys = overtimeRateHistory.keys.toList()..sort();
    double lastRate = overtimeRate;
    for (var key in sortedKeys) {
      if (key.compareTo(dateStr) <= 0) {
        lastRate = overtimeRateHistory[key]!;
      } else {
        break;
      }
    }
    return lastRate;
  }

  static String _formatDateKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  factory Employee.fromMap(Map<String, dynamic> map, String id) {
    return Employee(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      hourlyRate: (map['hourlyRate'] ?? 100.0).toDouble(),
      overtimeRate: (map['overtimeRate'] ?? 150.0).toDouble(),
      shiftId: map['shiftId'] ?? 'Default',
      status: map['status'] ?? 'Active',
      joinedDate: (map['joinedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateOfBirth:
          (map['dateOfBirth'] as Timestamp?)?.toDate() ?? DateTime(1990, 1, 1),
      aadharNumber: map['aadharNumber'] ?? '',
      salaryType: map['salaryType'] ?? 'Daily',
      hourlyRateHistory: (map['hourlyRateHistory'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
      overtimeRateHistory: (map['overtimeRateHistory'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'hourlyRate': hourlyRate,
      'overtimeRate': overtimeRate,
      'shiftId': shiftId,
      'status': status,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'aadharNumber': aadharNumber,
      'salaryType': salaryType,
      'hourlyRateHistory': hourlyRateHistory,
      'overtimeRateHistory': overtimeRateHistory,
    };
  }
}
