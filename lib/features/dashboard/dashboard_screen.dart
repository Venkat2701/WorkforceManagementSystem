import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/responsive_shell.dart';
import '../../core/widgets/custom_card.dart';
import '../../services/dashboard_service.dart';
import '../../models/dashboard_stats.dart';
import '../employees/add_edit_employee_screen.dart';
import '../attendance/daily_attendance_screen.dart';
import '../salary/weekly_payroll_screen.dart';
import '../shifts/shift_management_screen.dart';
import '../../services/auth_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return ResponsiveShell(
      title: 'Foundry EMS',
      selectedIndex: 0,
      onDestinationSelected: (index) {},
      body: statsAsync.when(
        data: (stats) => _DashboardContent(stats: stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final DashboardStats stats;
  const _DashboardContent({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        await ref.read(dashboardStatsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardHeader(),
              const SizedBox(height: AppSpacing.xl),
              _StatsGrid(stats: stats),
              const SizedBox(height: AppSpacing.xl),
              const _ChartsSection(),
              const SizedBox(height: AppSpacing.xl),
              const _QuickActionsHeader(),
              const SizedBox(height: AppSpacing.m),
              const _QuickActionsGrid(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Admin';
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : (now.hour < 17 ? 'Good Afternoon' : 'Good Evening');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMM dd').format(now),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting, ${displayName.split(' ')[0]}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh,
                      fontSize: MediaQuery.of(context).size.width < 600 ? 24 : 32,
                    ),
              ),
            ],
          ),
        ),
        const _LiveBadge(),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;
      final isUltraWide = constraints.maxWidth > 1100;
      final crossAxisCount = isUltraWide ? 4 : 2;
      
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.m,
        crossAxisSpacing: AppSpacing.m,
        childAspectRatio: isUltraWide ? 1.5 : (isWide ? 1.8 : 1.1),
        children: [
           _StatCard(
            title: 'Total Force',
            value: '${stats.totalEmployees}',
            subtitle: stats.employeesJoinedThisWeek > 0 ? '+${stats.employeesJoinedThisWeek} new this week' : 'Stable workforce',
            icon: Icons.groups_rounded,
            color: Colors.blue,
          ),
          _StatCard(
            title: 'Attendance',
            value: '${(stats.attendanceToday * 100).toInt()}%',
            subtitle: '${stats.presentCount}/${stats.totalCount} present',
            icon: Icons.fact_check_rounded,
            color: Colors.green,
            progress: stats.attendanceToday,
          ),
          _StatCard(
            title: 'Proj. Payout',
            value: '₹${NumberFormat('#,##,###').format(stats.weeklyPayout)}',
            subtitle: 'Current week total',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.primary,
          ),
          _StatCard(
            title: 'Active Shifts',
            value: '${stats.activeShifts}',
            subtitle: stats.shiftNames.isNotEmpty ? stats.shiftNames.join(', ') : 'No shifts defined',
            icon: Icons.pending_actions_rounded,
            color: Colors.purple,
          ),
        ],
      );
    });
  }
}

class _ChartsSection extends ConsumerWidget {
  const _ChartsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider).value;
    if (stats == null) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 2 : 1,
                child: RepaintBoundary(child: _AttendanceChart(stats: stats)),
              ),
              if (isWide) const SizedBox(width: AppSpacing.m),
              if (isWide)
                Expanded(
                  flex: 1,
                  child: RepaintBoundary(child: _PayoutTrendChart(stats: stats)),
                ),
            ],
          ),
          if (!isWide) ...[
            const SizedBox(height: AppSpacing.m),
            RepaintBoundary(child: _PayoutTrendChart(stats: stats)),
          ],
        ],
      );
    });
  }
}

class _AttendanceChart extends StatelessWidget {
  final DashboardStats stats;
  const _AttendanceChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Last 7 Days', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final index = value.toInt() % 7;
                        return Text(days[index], style: const TextStyle(fontSize: 10, color: AppColors.textMedium));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: stats.attendanceTrend.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: AppColors.primary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 1.0,
                          color: AppColors.backgroundAlt,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutTrendChart extends StatelessWidget {
  final DashboardStats stats;
  const _PayoutTrendChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Payout trends per week', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: stats.payoutTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsHeader extends StatelessWidget {
  const _QuickActionsHeader();
  @override
  Widget build(BuildContext context) {
    return Text(
      'Quick Management',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        childAspectRatio: 2.8,
        mainAxisSpacing: AppSpacing.m,
        crossAxisSpacing: AppSpacing.m,
        children: [
          _ActionCard(
            icon: Icons.person_add_rounded, 
            label: 'Hire Staff', 
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen())),
          ),
          _ActionCard(
            icon: Icons.how_to_reg_rounded, 
            label: 'Attendance', 
            color: Colors.green,
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DailyAttendanceScreen())),
          ),
          _ActionCard(
            icon: Icons.payments_rounded, 
            label: 'Payroll', 
            color: AppColors.primary,
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WeeklyPayrollScreen())),
          ),
          _ActionCard(
            icon: Icons.settings_suggest_rounded, 
            label: 'Work Shifts', 
            color: Colors.purple,
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ShiftManagementScreen())),
          ),
        ],
      );
    });
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12, 
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'LIVE DATA',
            style: TextStyle(
              color: Colors.red, 
              fontWeight: FontWeight.bold, 
              fontSize: MediaQuery.of(context).size.width < 600 ? 8 : 10, 
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final double? progress;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: progress != null ? color : AppColors.textMedium),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon, 
    required this.label, 
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
