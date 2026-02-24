import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/salary_record.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import 'employee_service.dart';

final salaryServiceProvider = Provider((ref) => SalaryService());

class SalaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<WeeklySalary>> calculateWeeklySalary(DateTime startDate, DateTime endDate) async {
    final weekId = "${startDate.year}_W${(startDate.day / 7).ceil()}";
    
    // 1. Get all employees
    final employeesSnapshot = await _firestore.collection('employees').get();
    final employees = employeesSnapshot.docs.map((doc) => Employee.fromMap(doc.data(), doc.id)).toList();

    // 2. Get attendance for the period (inclusive of the entire end day)
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));

    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    final attendanceRecords = attendanceSnapshot.docs.map((doc) => Attendance.fromMap(doc.data(), doc.id)).toList();

    // 3. Aggregate each employee's data
    List<WeeklySalary> salaries = [];
    for (var employee in employees) {
      final empAttendance = attendanceRecords.where((a) => a.employeeId == employee.id);
      
      double totalHours = 0;
      double totalOvertime = 0;
      for (var record in empAttendance) {
        if (record.isPresent) {
          totalHours += record.hoursWorked;
          totalOvertime += record.overtimeHours;
        }
      }

      salaries.add(WeeklySalary.calculate(
        employeeId: employee.id,
        employeeName: employee.name,
        weekId: weekId,
        startDate: startDate,
        endDate: endDate,
        hours: totalHours,
        overtime: totalOvertime,
        hRate: employee.hourlyRate,
        oRate: employee.overtimeRate,
      ));
    }

    return salaries;
  }

  Future<void> saveWeeklySalaries(List<WeeklySalary> salaries) async {
    final batch = _firestore.batch();
    for (var salary in salaries) {
      final docId = "${salary.weekId}_${salary.employeeId}";
      final docRef = _firestore.collection('weekly_salaries').doc(docId);
      batch.set(docRef, salary.toMap());
    }
    await batch.commit();
  }
}
