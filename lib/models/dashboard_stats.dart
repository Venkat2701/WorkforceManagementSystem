class DashboardStats {
  final int totalEmployees;
  final int employeesJoinedThisWeek;
  final double attendanceToday;
  final int presentCount;
  final int totalCount;
  final double weeklyPayout;
  final int activeShifts;
  final List<String> shiftNames;
  final List<double> attendanceTrend; // Percentage for last 7 days
  final List<double> payoutTrend;     // Amount for last 6 weeks (or similar)

  DashboardStats({
    required this.totalEmployees,
    required this.employeesJoinedThisWeek,
    required this.attendanceToday,
    required this.presentCount,
    required this.totalCount,
    required this.weeklyPayout,
    required this.activeShifts,
    required this.shiftNames,
    required this.attendanceTrend,
    required this.payoutTrend,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalEmployees: 0,
      employeesJoinedThisWeek: 0,
      attendanceToday: 0.0,
      presentCount: 0,
      totalCount: 0,
      weeklyPayout: 0.0,
      activeShifts: 0,
      shiftNames: [],
      attendanceTrend: [],
      payoutTrend: [],
    );
  }
}
