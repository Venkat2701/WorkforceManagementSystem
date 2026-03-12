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
    final startOfWeek = startOfToday.subtract(
      Duration(days: startOfToday.weekday - 1),
    );

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
          final joinedDate =
              (doc.data() as Map<String, dynamic>?)?['joinedDate']
                  as Timestamp?;
          return joinedDate != null && joinedDate.toDate().isAfter(startOfWeek);
        }).length;

        // Today's attendance (Unique IDs)
        final attendanceSnapshot = await _firestore
            .collection('attendance')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
            )
            .get();

        final presentEmployeeIdsToday = attendanceSnapshot.docs
            .where((d) => (d.data()['isPresent'] ?? false) == true)
            .map((d) => d['employeeId'] as String)
            .toSet();

        final presentCount = presentEmployeeIdsToday.length;

        final overtimeCountToday = attendanceSnapshot.docs
            .where((d) {
              final data = d.data();
              return (data['isPresent'] ?? false) == true &&
                  (data['overtimeHours'] ?? 0.0) > 0.0;
            })
            .map((d) => d['employeeId'] as String)
            .toSet()
            .length;

        // Active shifts
        final shifts = latestShifts!.docs;
        final shiftNames = shifts
            .map((s) => (s.data() as Map<String, dynamic>)['name'] as String)
            .toList();

        // Analytical Trends (Last 7 days)
        List<double> attendanceTrend = [];
        List<double> overtimeTrend = [];
        List<double> payoutTrend = [];

        for (int i = 6; i >= 0; i--) {
          final d = startOfToday.subtract(Duration(days: i));
          final nextD = d.add(const Duration(days: 1));

          // Fetch attendance for this day
          final snap = await _firestore
              .collection('attendance')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(d))
              .where('date', isLessThan: Timestamp.fromDate(nextD))
              .get();

          // 1. Attendance & Overtime trends
          final presentEmployeeIds = snap.docs
              .where((doc) => (doc['isPresent'] ?? false) == true)
              .map((doc) => doc['employeeId'] as String)
              .toSet();

          final overtimeEmployeeIds = snap.docs
              .where((doc) {
                final data = doc.data();
                return (data['isPresent'] ?? false) == true &&
                    (data['overtimeHours'] ?? 0.0) > 0.0;
              })
              .map((doc) => doc['employeeId'] as String)
              .toSet();

          attendanceTrend.add(
            totalEmployees > 0
                ? presentEmployeeIds.length / totalEmployees
                : 0.0,
          );
          overtimeTrend.add(
            totalEmployees > 0
                ? overtimeEmployeeIds.length / totalEmployees
                : 0.0,
          );

          // 2. Payout trend for this specific day
          double dayPayout = 0;
          for (var doc in snap.docs) {
            final data = doc.data();
            if ((data['isPresent'] ?? false) == true) {
              final eId = data['employeeId'] as String;
              final emp = employees.any((e) => e.id == eId)
                  ? employees.firstWhere((e) => e.id == eId)
                  : null;
              if (emp != null) {
                final empData = emp.data() as Map<String, dynamic>;
                final hRate =
                    (empData['hourlyRate'] as num?)?.toDouble() ?? 50.0;
                final oRate =
                    (empData['overtimeRate'] as num?)?.toDouble() ??
                    (hRate * 1.5);
                final hours = (data['hoursWorked'] as num?)?.toDouble() ?? 0.0;
                final ovt = (data['overtimeHours'] as num?)?.toDouble() ?? 0.0;
                dayPayout += (hours * hRate) + (ovt * oRate);
              }
            }
          }
          payoutTrend.add(dayPayout);
        }

        // Simplified Weekly Payout (Estimated from active attendance this week)
        final weekAttendanceSnap = await _firestore
            .collection('attendance')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
            )
            .get();
        double estimatedPayout = 0;
        final Map<String, double> employeePayouts = {};

        // Track per-employee payouts this week
        for (var doc in weekAttendanceSnap.docs) {
          final data = doc.data();
          if (data['isPresent'] == true) {
            final empId = data['employeeId'];
            final empDoc = employees.firstWhere((e) => e.id == empId);
            final empData = empDoc.data() as Map<String, dynamic>;
            final hRate = (empData['hourlyRate'] as num?)?.toDouble() ?? 0.0;
            final oRate = (empData['overtimeRate'] as num?)?.toDouble() ?? 0.0;

            final hours = (data['hoursWorked'] as num).toDouble();
            final ovt = (data['overtimeHours'] as num).toDouble();
            final payout = (hours * hRate) + (ovt * oRate);

            estimatedPayout += payout;
            employeePayouts[empId] = (employeePayouts[empId] ?? 0.0) + payout;
          }
        }

        final payoutByEmployeeDetails = employeePayouts.entries.map((e) {
          final empDoc = employees.firstWhere((emp) => emp.id == e.key);
          return {
            'id': e.key,
            'name':
                (empDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown',
            'amount': e.value,
          };
        }).toList();

        // Employees by Status
        Map<String, int> employeesByStatus = {};
        for (var doc in employees) {
          final status =
              (doc.data() as Map<String, dynamic>?)?['status'] as String? ??
              'Active';
          employeesByStatus[status] = (employeesByStatus[status] ?? 0) + 1;
        }

        // Shift Data (Assigned vs Present)
        Map<String, int> shiftDistribution = {};
        Map<String, int> shiftPresenceToday = {};

        for (var doc in employees) {
          final data = doc.data() as Map<String, dynamic>;
          final sId = data['shiftId'] as String? ?? 'Default';
          final sName = shifts.any((s) => s.id == sId)
              ? (shifts.firstWhere((s) => s.id == sId).data()
                        as Map<String, dynamic>)['name']
                    as String
              : sId;

          // Assigned count
          shiftDistribution[sName] = (shiftDistribution[sName] ?? 0) + 1;

          // Present today count
          if (presentEmployeeIdsToday.contains(doc.id)) {
            shiftPresenceToday[sName] = (shiftPresenceToday[sName] ?? 0) + 1;
          }
        }

        // Initialize missing shifts with 0 in presence map
        for (var name in shiftDistribution.keys) {
          shiftPresenceToday[name] ??= 0;
        }

        // Recent Employees (Joined in last 30 days)
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        final recentEmployees = employees
            .where((doc) {
              final joinedDate =
                  (doc.data() as Map<String, dynamic>?)?['joinedDate']
                      as Timestamp?;
              return joinedDate != null &&
                  joinedDate.toDate().isAfter(thirtyDaysAgo);
            })
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unknown',
                'joinedDate': data['joinedDate'],
              };
            })
            .toList();

        controller.add(
          DashboardStats(
            totalEmployees: totalEmployees,
            employeesJoinedThisWeek: joinedThisWeek,
            attendanceToday: totalEmployees > 0
                ? presentCount / totalEmployees
                : 0.0,
            presentCount: presentCount,
            totalCount: totalEmployees,
            overtimeCountToday: overtimeCountToday,
            weeklyPayout: estimatedPayout,
            activeShifts: shifts.length,
            shiftNames: shiftNames,
            attendanceTrend: attendanceTrend,
            payoutTrend: payoutTrend,
            overtimeTrend: overtimeTrend,
            employeesByStatus: employeesByStatus,
            shiftDistribution: shiftDistribution,
            shiftPresence: shiftPresenceToday,
            recentEmployees: recentEmployees,
            payoutByEmployee: payoutByEmployeeDetails,
            activeShiftsList: shifts.map((s) {
              final data = s.data() as Map<String, dynamic>;
              return {
                'id': s.id,
                'name': data['name'] ?? '',
                'startTime': data['startTime'] ?? '',
                'endTime': data['endTime'] ?? '',
              };
            }).toList(),
          ),
        );
      }

      final empSub = employeesStream.listen((event) {
        latestEmployees = event;
        emit();
      });
      final shiftSub = shiftsStream.listen((event) {
        latestShifts = event;
        emit();
      });

      controller.onCancel = () {
        empSub.cancel();
        shiftSub.cancel();
      };
    });
  }
}
