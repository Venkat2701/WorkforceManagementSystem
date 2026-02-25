import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/salary_record.dart';
import '../models/attendance.dart';
import '../models/employee.dart';

final salaryServiceProvider = Provider((ref) => SalaryService());

class SalaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, List<WeeklySalary>>> calculateWeeklySalary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final weekId = "${startDate.year}_W${(startDate.day / 7).ceil()}";

    // 1. Get all employees
    final employeesSnapshot = await _firestore.collection('employees').get();
    final employees = employeesSnapshot.docs
        .map((doc) => Employee.fromMap(doc.data(), doc.id))
        .toList();

    // 2. Get attendance for the period (inclusive of the entire end day)
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));

    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    final attendanceRecords = attendanceSnapshot.docs
        .map((doc) => Attendance.fromMap(doc.data(), doc.id))
        .toList();

    // 3. Aggregate each employee's data
    List<WeeklySalary> allSalaries = [];
    List<WeeklySalary> paidSalaries = [];
    List<WeeklySalary> unpaidSalaries = [];

    for (var employee in employees) {
      final empAttendance = attendanceRecords.where(
        (a) => a.employeeId == employee.id,
      );

      double totalHours = 0, totalOvertime = 0;
      double paidHours = 0, paidOvertime = 0;
      double unpaidHours = 0, unpaidOvertime = 0;
      double totalBasePay = 0;
      double totalOvertimePay = 0;
      double paidBasePay = 0;
      double paidOvertimePay = 0;
      double unpaidBasePay = 0;
      double unpaidOvertimePay = 0;

      for (var record in empAttendance) {
        if (record.isPresent) {
          totalHours += record.hoursWorked;
          totalOvertime += record.overtimeHours;

          final recordHourlyRate =
              record.hourlyRate ?? employee.getHourlyRateForDate(record.date);
          final recordOvertimeRate =
              record.overtimeRate ??
              employee.getOvertimeRateForDate(record.date);

          final basePay = record.hoursWorked * recordHourlyRate;
          final otPay = record.overtimeHours * recordOvertimeRate;

          totalBasePay += basePay;
          totalOvertimePay += otPay;

          if (record.isPaid) {
            paidHours += record.hoursWorked;
            paidOvertime += record.overtimeHours;
            paidBasePay += basePay;
            paidOvertimePay += otPay;
          } else {
            unpaidHours += record.hoursWorked;
            unpaidOvertime += record.overtimeHours;
            unpaidBasePay += basePay;
            unpaidOvertimePay += otPay;
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
        allSalaries.add(
          WeeklySalary(
            totalHours: totalHours,
            totalOvertime: totalOvertime,
            baseSalary: totalBasePay,
            overtimePay: totalOvertimePay,
            totalSalary: totalBasePay + totalOvertimePay,
            paid: unpaidHours == 0,
            employeeId: common['employeeId'] as String,
            employeeName: common['employeeName'] as String,
            weekId: common['weekId'] as String,
            startDate: common['startDate'] as DateTime,
            endDate: common['endDate'] as DateTime,
            hourlyRate: common['hourlyRate'] as double,
            overtimeRate: common['overtimeRate'] as double,
          ),
        );
      }

      if (paidHours > 0) {
        paidSalaries.add(
          WeeklySalary(
            totalHours: paidHours,
            totalOvertime: paidOvertime,
            baseSalary: paidBasePay,
            overtimePay: paidOvertimePay,
            totalSalary: paidBasePay + paidOvertimePay,
            paid: true,
            employeeId: common['employeeId'] as String,
            employeeName: common['employeeName'] as String,
            weekId: common['weekId'] as String,
            startDate: common['startDate'] as DateTime,
            endDate: common['endDate'] as DateTime,
            hourlyRate: common['hourlyRate'] as double,
            overtimeRate: common['overtimeRate'] as double,
          ),
        );
      }

      if (unpaidHours > 0) {
        unpaidSalaries.add(
          WeeklySalary(
            totalHours: unpaidHours,
            totalOvertime: unpaidOvertime,
            baseSalary: unpaidBasePay,
            overtimePay: unpaidOvertimePay,
            totalSalary: unpaidBasePay + unpaidOvertimePay,
            paid: false,
            employeeId: common['employeeId'] as String,
            employeeName: common['employeeName'] as String,
            weekId: common['weekId'] as String,
            startDate: common['startDate'] as DateTime,
            endDate: common['endDate'] as DateTime,
            hourlyRate: common['hourlyRate'] as double,
            overtimeRate: common['overtimeRate'] as double,
          ),
        );
      }
    }

    return {'all': allSalaries, 'paid': paidSalaries, 'unpaid': unpaidSalaries};
  }

  Future<void> markPeriodAsPaid(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));

    // We only query by date range here because we know it's a supported index.
    // Filtering for specific employee and unpaid status in memory to avoid
    // requiring a complex composite index in Firestore.
    final snapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final batch = _firestore.batch();
    int count = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['employeeId'] == employeeId &&
          (data['isPaid'] == false || data['isPaid'] == null)) {
        batch.update(doc.reference, {'isPaid': true});
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  Future<void> revertPaymentStatus(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('attendance')
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

  Future<List<WeeklySalary>> getEmployeePaymentHistory(
    String employeeId,
  ) async {
    // 1. Get employee data
    final employeeDoc = await _firestore
        .collection('employees')
        .doc(employeeId)
        .get();
    if (!employeeDoc.exists) return [];
    final employee = Employee.fromMap(employeeDoc.data()!, employeeDoc.id);

    // 2. Get all attendance records for this employee
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final attendanceRecords = attendanceSnapshot.docs
        .map((doc) => Attendance.fromMap(doc.data(), doc.id))
        .toList();

    // 3. Group by calendar week (Monday as start)
    Map<DateTime, List<Attendance>> weeklyGroups = {};
    for (var record in attendanceRecords) {
      if (!record.isPresent) continue; // Only aggregate present days

      final date = record.date;
      final startOfWeek = DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: date.weekday - 1));
      weeklyGroups.putIfAbsent(startOfWeek, () => []).add(record);
    }

    List<WeeklySalary> result = [];

    weeklyGroups.forEach((startOfWeek, records) {
      double paidHours = 0,
          paidOvertime = 0,
          paidBasePay = 0,
          paidOvertimePay = 0;
      double unpaidHours = 0,
          unpaidOvertime = 0,
          unpaidBasePay = 0,
          unpaidOvertimePay = 0;

      for (var record in records) {
        final recordHourlyRate =
            record.hourlyRate ?? employee.getHourlyRateForDate(record.date);
        final recordOvertimeRate =
            record.overtimeRate ?? employee.getOvertimeRateForDate(record.date);
        final basePay = record.hoursWorked * recordHourlyRate;
        final otPay = record.overtimeHours * recordOvertimeRate;

        if (record.isPaid) {
          paidHours += record.hoursWorked;
          paidOvertime += record.overtimeHours;
          paidBasePay += basePay;
          paidOvertimePay += otPay;
        } else {
          unpaidHours += record.hoursWorked;
          unpaidOvertime += record.overtimeHours;
          unpaidBasePay += basePay;
          unpaidOvertimePay += otPay;
        }
      }

      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final weekId = "${startOfWeek.year}_W${(startOfWeek.day / 7).ceil()}";

      if (paidHours > 0) {
        result.add(
          WeeklySalary(
            employeeId: employee.id,
            employeeName: employee.name,
            weekId: weekId,
            startDate: startOfWeek,
            endDate: endOfWeek,
            totalHours: paidHours,
            totalOvertime: paidOvertime,
            hourlyRate: employee.hourlyRate,
            overtimeRate: employee.overtimeRate,
            baseSalary: paidBasePay,
            overtimePay: paidOvertimePay,
            totalSalary: paidBasePay + paidOvertimePay,
            paid: true,
          ),
        );
      }

      if (unpaidHours > 0) {
        result.add(
          WeeklySalary(
            employeeId: employee.id,
            employeeName: employee.name,
            weekId: weekId,
            startDate: startOfWeek,
            endDate: endOfWeek,
            totalHours: unpaidHours,
            totalOvertime: unpaidOvertime,
            hourlyRate: employee.hourlyRate,
            overtimeRate: employee.overtimeRate,
            baseSalary: unpaidBasePay,
            overtimePay: unpaidOvertimePay,
            totalSalary: unpaidBasePay + unpaidOvertimePay,
            paid: false,
          ),
        );
      }
    });

    result.sort((a, b) => b.startDate.compareTo(a.startDate));
    return result;
  }
}
