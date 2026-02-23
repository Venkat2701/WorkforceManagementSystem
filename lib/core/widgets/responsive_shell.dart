import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../responsive/responsive_layout.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/employees/employee_list_screen.dart';
import '../../features/attendance/daily_attendance_screen.dart';
import '../../features/salary/weekly_payroll_screen.dart';
import '../../features/shifts/shift_management_screen.dart';
import '../../features/auth/login_screen.dart';

import '../../services/auth_service.dart';

class ResponsiveShell extends ConsumerStatefulWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final String title;
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const ResponsiveShell({
    super.key,
    required this.body,
    this.floatingActionButton,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onNavigation(int index) {
    if (index == widget.selectedIndex) return;
    
    if (index == 5) {
      _handleLogout();
      return;
    }

    // Use a post-frame callback to avoid navigating during the widget tree's build/layout phase
    // This prevents the "history.isNotEmpty" assertion error on web during rapid navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final nextScreen = _getScreenForIndex(index);
      if (nextScreen == null) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        ),
      );
    });

    widget.onDestinationSelected(index);
  }

  Widget? _getScreenForIndex(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const EmployeeListScreen();
      case 2: return const DailyAttendanceScreen();
      case 3: return const WeeklyPayrollScreen();
      case 4: return const ShiftManagementScreen();
      default: return null;
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Sign out from Firebase
              await ref.read(authServiceProvider).signOut();
              
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              key: const ValueKey('mobile_appbar'),
              title: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.m),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                  ),
                ),
              ],
            )
          : null,
      drawer: isMobile ? _buildNavigationDrawer(context) : null,
      body: Row(
        children: [
          if (!isMobile)
            _buildNavigationRail(context),
          Expanded(
            child: Container(
              color: AppColors.backgroundAlt,
              child: Column(
                children: [
                   if (!isMobile) 
                    _buildDesktopHeader(context),
                  Expanded(
                    child: widget.body,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: null,
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: AppSpacing.m),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person, color: AppColors.primary, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: const Icon(Icons.precision_manufacturing, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Foundry EMS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textHigh,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
          _buildDrawerItem(1, Icons.badge_outlined, Icons.badge, 'Employees'),
          _buildDrawerItem(2, Icons.fact_check_outlined, Icons.fact_check, 'Attendance'),
          _buildDrawerItem(3, Icons.payments_outlined, Icons.payments, 'Payroll'),
          _buildDrawerItem(4, Icons.schedule_outlined, Icons.schedule, 'Shifts'),
          const Spacer(),
          _buildDrawerItem(5, Icons.logout, Icons.logout, 'Logout'),
          const SizedBox(height: AppSpacing.m),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(bool isExpanded) {
    if (!isExpanded) {
      return IconButton(
        icon: const Icon(Icons.logout, color: AppColors.textMedium),
        onPressed: _handleLogout,
        tooltip: 'Logout',
      );
    }

    return InkWell(
      onTap: _handleLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.textMedium),
            SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(color: AppColors.textHigh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = widget.selectedIndex == index;
    return ListTile(
      leading: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected ? AppColors.primary : AppColors.textMedium,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textHigh,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        if (index == 5) {
          _handleLogout();
        } else {
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
             Navigator.of(context).pop();
          }
          _onNavigation(index);
        }
      },
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return NavigationRail(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: _onNavigation,
      extended: isDesktop,
      minExtendedWidth: 200,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primary.withOpacity(0.1),
      unselectedIconTheme: const IconThemeData(color: AppColors.textMedium),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedLabelTextStyle: const TextStyle(color: AppColors.textMedium),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
      ),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.precision_manufacturing, color: Colors.white, size: 24),
            ),
            if (isDesktop) ...[
              const SizedBox(height: AppSpacing.s),
              const Text(
                'Foundry EMS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.badge_outlined),
          selectedIcon: Icon(Icons.badge),
          label: Text('Employees'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: Text('Attendance'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments),
          label: Text('Payroll'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.schedule_outlined),
          selectedIcon: Icon(Icons.schedule),
          label: Text('Shifts'),
        ),
      ],
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.l),
        child: _buildLogoutButton(isDesktop),
      ),
    );
  }

}
