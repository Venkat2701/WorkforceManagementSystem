import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';

final attendanceServiceProvider = Provider((ref) => AttendanceService());

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Attendance>> getAttendanceForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((doc) => Attendance.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> saveBulkAttendance(
    DateTime date,
    List<Attendance> attendanceList,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final batch = _firestore.batch();
    final newDocIds = <String>{};

    for (var attendance in attendanceList) {
      // Create a deterministic ID to allow easy updates
      final dateStr = DateFormat('yyyy-MM-dd').format(attendance.date);
      final docId = '${attendance.employeeId}_$dateStr';
      newDocIds.add(docId);

      final docRef = _firestore.collection('attendance').doc(docId);
      batch.set(docRef, attendance.toMap(), SetOptions(merge: true));
    }

    for (var doc in snapshot.docs) {
      if (!newDocIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  Future<List<Attendance>> getEmployeeAttendanceHistory(
    String employeeId,
  ) async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final records = snapshot.docs
        .map((doc) => Attendance.fromMap(doc.data(), doc.id))
        .toList();

    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }
}
