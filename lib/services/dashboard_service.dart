import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_stats.dart';

final dashboardServiceProvider = Provider((ref) => DashboardService());

final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) {
  return ref.watch(dashboardServiceProvider).getStats();
});

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DashboardStats> getStats() {
    // We combine snapshots from multiple collections to create a real-time reactive dashboard
    final employeesStream = _firestore.collection('employees').snapshots();
    final shiftsStream = _firestore.collection('shifts').snapshots();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: startOfToday.weekday - 1));

    return Stream.multi((controller) {
      // Internal state to track latest data
      QuerySnapshot? latestEmployees;
      QuerySnapshot? latestShifts;
      
      void emit() async {
        if (latestEmployees == null || latestShifts == null) return;

        final employees = latestEmployees!.docs;
        final totalEmployees = employees.length;

        // Joined this week
        final joinedThisWeek = employees.where((doc) {
          final joinedDate = (doc.data() as Map<String, dynamic>?)?['joinedDate'] as Timestamp?;
          return joinedDate != null && joinedDate.toDate().isAfter(startOfWeek);
        }).length;

        // Today's attendance
        final attendanceSnapshot = await _firestore
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
            .get();
        final presentCount = attendanceSnapshot.docs.where((d) => (d.data()['isPresent'] ?? false) == true).length;
        
        // Active shifts
        final shifts = latestShifts!.docs;
        final shiftNames = shifts.map((s) => (s.data() as Map<String, dynamic>)['name'] as String).toList();

        // Attendance Trend (Last 7 days)
        List<double> attendanceTrend = [];
        for (int i = 6; i >= 0; i--) {
          final d = startOfToday.subtract(Duration(days: i));
          final nextD = d.add(const Duration(days: 1));
          final snap = await _firestore.collection('attendance')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(d))
              .where('date', isLessThan: Timestamp.fromDate(nextD))
              .get();
          final count = snap.docs.where((doc) => (doc.data()['isPresent'] ?? false) == true).length;
          attendanceTrend.add(totalEmployees > 0 ? count / totalEmployees : 0.0);
        }

        // Simplified Weekly Payout (Estimated from active attendance this week)
        final weekAttendanceSnap = await _firestore.collection('attendance')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
            .get();
        double estimatedPayout = 0;
        // Optimization: In a real app we'd cache employee rates to avoid O(N*M)
        for (var doc in weekAttendanceSnap.docs) {
          final data = doc.data();
          if (data['isPresent'] == true) {
            final empId = data['employeeId'];
            final empDoc = employees.firstWhere((e) => e.id == empId);
            final empData = empDoc.data() as Map<String, dynamic>;
            final hRate = (empData['hourlyRate'] as num?)?.toDouble() ?? 0.0;
            final oRate = (empData['overtimeRate'] as num?)?.toDouble() ?? 0.0;
            estimatedPayout += (data['hoursWorked'] as num).toDouble() * hRate;
            estimatedPayout += (data['overtimeHours'] as num).toDouble() * oRate;
          }
        }

        controller.add(DashboardStats(
          totalEmployees: totalEmployees,
          employeesJoinedThisWeek: joinedThisWeek,
          attendanceToday: totalEmployees > 0 ? presentCount / totalEmployees : 0.0,
          presentCount: presentCount,
          totalCount: totalEmployees,
          weeklyPayout: estimatedPayout,
          activeShifts: shifts.length,
          shiftNames: shiftNames,
          attendanceTrend: attendanceTrend,
          payoutTrend: [0.8, 1.2, 0.9, 1.5, 2.0, 1.8], // Keep some mock for trend visual until we have weeks of data
        ));
      }

      final empSub = employeesStream.listen((event) { latestEmployees = event; emit(); });
      final shiftSub = shiftsStream.listen((event) { latestShifts = event; emit(); });

      controller.onCancel = () {
        empSub.cancel();
        shiftSub.cancel();
      };
    });
  }
}
