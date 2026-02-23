import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/employees/employee_list_screen.dart';
import '../features/attendance/daily_attendance_screen.dart';
import '../features/salary/weekly_payroll_screen.dart';
import '../features/shifts/shift_management_screen.dart';

class NavigationController extends StatefulWidget {
  const NavigationController({super.key});

  @override
  State<NavigationController> createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const EmployeeListScreen(),
    const DailyAttendanceScreen(),
    const WeeklyPayrollScreen(),
    const ShiftManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Note: The ResponsiveShell is already inside each screen to handle local navigation/title.
    // This controller manages which screen is active.
    return _screens[_currentIndex];
  }
}
