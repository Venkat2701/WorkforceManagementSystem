class DashboardStats {
  final int totalEmployees;
  final int employeesJoinedThisWeek;
  final double attendanceToday;
  final int presentCount;
  final int totalCount;
  final int overtimeCountToday;
  final double weeklyPayout;
  final int activeShifts;
  final List<String> shiftNames;
  final List<double> attendanceTrend; // Percentage for last 7 days
  final List<double> overtimeTrend; // Overtime percentage for last 7 days
  final List<double> payoutTrend; // Amount for last 6 weeks (or similar)

  // New Analytical Data
  final Map<String, int> employeesByStatus;
  final Map<String, int> shiftDistribution; // Assigned
  final Map<String, int> shiftPresence; // Present Today
  final List<Map<String, dynamic>> recentEmployees;
  final List<Map<String, dynamic>> payoutByEmployee;
  final List<Map<String, dynamic>> activeShiftsList;

  DashboardStats({
    required this.totalEmployees,
    required this.employeesJoinedThisWeek,
    required this.attendanceToday,
    required this.presentCount,
    required this.totalCount,
    required this.overtimeCountToday,
    required this.weeklyPayout,
    required this.activeShifts,
    required this.shiftNames,
    required this.attendanceTrend,
    required this.overtimeTrend,
    required this.payoutTrend,
    required this.employeesByStatus,
    required this.shiftDistribution,
    required this.shiftPresence,
    required this.recentEmployees,
    required this.payoutByEmployee,
    required this.activeShiftsList,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalEmployees: 0,
      employeesJoinedThisWeek: 0,
      attendanceToday: 0.0,
      presentCount: 0,
      totalCount: 0,
      overtimeCountToday: 0,
      weeklyPayout: 0.0,
      activeShifts: 0,
      shiftNames: [],
      attendanceTrend: [],
      overtimeTrend: [],
      payoutTrend: [],
      employeesByStatus: {},
      shiftDistribution: {},
      shiftPresence: {},
      recentEmployees: [],
      payoutByEmployee: [],
      activeShiftsList: [],
    );
  }
}
