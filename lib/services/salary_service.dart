import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/salary_record.dart';
import '../models/attendance.dart';
import '../models/employee.dart';
import 'employee_service.dart';

final salaryServiceProvider = Provider((ref) => SalaryService());

class SalaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, List<WeeklySalary>>> calculateWeeklySalary(DateTime startDate, DateTime endDate) async {
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
    List<WeeklySalary> allSalaries = [];
    List<WeeklySalary> paidSalaries = [];
    List<WeeklySalary> unpaidSalaries = [];

    for (var employee in employees) {
      final empAttendance = attendanceRecords.where((a) => a.employeeId == employee.id);
      
      double totalHours = 0, totalOvertime = 0;
      double paidHours = 0, paidOvertime = 0;
      double unpaidHours = 0, unpaidOvertime = 0;

      for (var record in empAttendance) {
        if (record.isPresent) {
          totalHours += record.hoursWorked;
          totalOvertime += record.overtimeHours;
          
          if (record.isPaid) {
            paidHours += record.hoursWorked;
            paidOvertime += record.overtimeHours;
          } else {
            unpaidHours += record.hoursWorked;
            unpaidOvertime += record.overtimeHours;
          }
        }
      }

      final common = {
        'employeeId': employee.id,
        'employeeName': employee.name,
        'weekId': weekId,
        'startDate': startDate,
        'endDate': endDate,
        'hourlyRate': employee.hourlyRate,
        'overtimeRate': employee.overtimeRate,
      };

      if (totalHours > 0) {
        allSalaries.add(WeeklySalary(
          totalHours: totalHours, totalOvertime: totalOvertime,
          baseSalary: totalHours * employee.hourlyRate,
          overtimePay: totalOvertime * employee.overtimeRate,
          totalSalary: (totalHours * employee.hourlyRate) + (totalOvertime * employee.overtimeRate),
          paid: unpaidHours == 0,
          employeeId: common['employeeId'] as String,
          employeeName: common['employeeName'] as String,
          weekId: common['weekId'] as String,
          startDate: common['startDate'] as DateTime,
          endDate: common['endDate'] as DateTime,
          hourlyRate: common['hourlyRate'] as double,
          overtimeRate: common['overtimeRate'] as double,
        ));
      }

      if (paidHours > 0) {
        paidSalaries.add(WeeklySalary(
          totalHours: paidHours, totalOvertime: paidOvertime,
          baseSalary: paidHours * employee.hourlyRate,
          overtimePay: paidOvertime * employee.overtimeRate,
          totalSalary: (paidHours * employee.hourlyRate) + (paidOvertime * employee.overtimeRate),
          paid: true,
          employeeId: common['employeeId'] as String,
          employeeName: common['employeeName'] as String,
          weekId: common['weekId'] as String,
          startDate: common['startDate'] as DateTime,
          endDate: common['endDate'] as DateTime,
          hourlyRate: common['hourlyRate'] as double,
          overtimeRate: common['overtimeRate'] as double,
        ));
      }

      if (unpaidHours > 0) {
        unpaidSalaries.add(WeeklySalary(
          totalHours: unpaidHours, totalOvertime: unpaidOvertime,
          baseSalary: unpaidHours * employee.hourlyRate,
          overtimePay: unpaidOvertime * employee.overtimeRate,
          totalSalary: (unpaidHours * employee.hourlyRate) + (unpaidOvertime * employee.overtimeRate),
          paid: false,
          employeeId: common['employeeId'] as String,
          employeeName: common['employeeName'] as String,
          weekId: common['weekId'] as String,
          startDate: common['startDate'] as DateTime,
          endDate: common['endDate'] as DateTime,
          hourlyRate: common['hourlyRate'] as double,
          overtimeRate: common['overtimeRate'] as double,
        ));
      }
    }

    return {
      'all': allSalaries,
      'paid': paidSalaries,
      'unpaid': unpaidSalaries,
    };
  }

  Future<void> markPeriodAsPaid(String employeeId, DateTime startDate, DateTime endDate) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));

    // We only query by date range here because we know it's a supported index.
    // Filtering for specific employee and unpaid status in memory to avoid 
    // requiring a complex composite index in Firestore.
    final snapshot = await _firestore.collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final batch = _firestore.batch();
    int count = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['employeeId'] == employeeId && (data['isPaid'] == false || data['isPaid'] == null)) {
        batch.update(doc.reference, {'isPaid': true});
        count++;
      }
    }
    
    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> revertPaymentStatus(String employeeId, DateTime startDate, DateTime endDate) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));

    final snapshot = await _firestore.collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final batch = _firestore.batch();
    int count = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['employeeId'] == employeeId && data['isPaid'] == true) {
        batch.update(doc.reference, {'isPaid': false});
        count++;
      }
    }
    
    if (count > 0) {
      await batch.commit();
    }
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
