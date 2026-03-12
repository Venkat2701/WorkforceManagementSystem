import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../services/employee_service.dart';

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
              const _WorkforceOverviewSection(),
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
    final displayName =
        user?.displayName ?? user?.email?.split('@')[0] ?? 'Admin';
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : (now.hour < 17 ? 'Good Afternoon' : 'Good Evening');

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
    return LayoutBuilder(
      builder: (context, constraints) {
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
              subtitle: stats.employeesJoinedThisWeek > 0
                  ? '+${stats.employeesJoinedThisWeek} new this week'
                  : 'Stable workforce',
              icon: Icons.groups_rounded,
              color: Colors.blue,
              onTap: () => _showForceDetails(context, stats),
            ),
            _StatCard(
              title: 'Attendance',
              value: '${(stats.attendanceToday * 100).toInt()}%',
              subtitle: '${stats.presentCount}/${stats.totalCount} present',
              icon: Icons.fact_check_rounded,
              color: Colors.green,
              progress: stats.attendanceToday,
              onTap: () => _showAttendanceDetails(context, stats),
            ),
            _StatCard(
              title: 'Proj. Payout',
              value: '₹${NumberFormat('#,##,###').format(stats.weeklyPayout)}',
              subtitle: 'Current week total',
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              onTap: () => _showPayoutDetails(context, stats),
            ),
            _StatCard(
              title: 'Active Shifts',
              value: '${stats.activeShifts}',
              subtitle: stats.shiftNames.isNotEmpty
                  ? stats.shiftNames.join(', ')
                  : 'No shifts defined',
              icon: Icons.pending_actions_rounded,
              color: Colors.purple,
              onTap: () => _showShiftDetails(context, stats),
            ),
          ],
        );
      },
    );
  }
}

class _ChartsSection extends ConsumerWidget {
  const _ChartsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider).value;
    if (stats == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
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
                    child: RepaintBoundary(
                      child: _PayoutTrendChart(stats: stats),
                    ),
                  ),
              ],
            ),
            if (!isWide) ...[
              const SizedBox(height: AppSpacing.m),
              RepaintBoundary(child: _PayoutTrendChart(stats: stats)),
            ],
          ],
        );
      },
    );
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
              Text(
                'Weekly Attendance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Last 7 Days',
                style: TextStyle(color: AppColors.textMedium, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(height: 220, child: _AttendanceBarChart(stats: stats)),
        ],
      ),
    );
  }
}

class _AttendanceBarChart extends StatefulWidget {
  final DashboardStats stats;
  const _AttendanceBarChart({required this.stats});

  @override
  State<_AttendanceBarChart> createState() => _AttendanceBarChartState();
}

class _AttendanceBarChartState extends State<_AttendanceBarChart> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final double maxVal =
        [...widget.stats.attendanceTrend, ...widget.stats.overtimeTrend].isEmpty
        ? 1.0
        : [
            ...widget.stats.attendanceTrend,
            ...widget.stats.overtimeTrend,
          ].reduce((a, b) => a > b ? a : b);
    final double dynamicMaxY = maxVal > 1.0 ? (maxVal * 1.1) : 1.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterChip('All'),
              const SizedBox(width: 8),
              _buildFilterChip('Regular'),
              const SizedBox(width: 8),
              _buildFilterChip('Overtime'),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rodWidth = (constraints.maxWidth / 20).clamp(6.0, 12.0);

              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: dynamicMaxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) =>
                          const Color(0xFF2C3E50).withOpacity(0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final isOvertime = rod.color != AppColors.primary;
                        final label = isOvertime ? 'Overtime' : 'Regular';
                        return BarTooltipItem(
                          '$label: ${(rod.toY * 100).toInt()}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          const days = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          final index = value.toInt();
                          if (index < 0 || index >= days.length)
                            return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              days[index],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMedium,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (i) {
                    final regVal = widget.stats.attendanceTrend.length > i
                        ? widget.stats.attendanceTrend[i]
                        : 0.0;
                    final otVal = widget.stats.overtimeTrend.length > i
                        ? widget.stats.overtimeTrend[i]
                        : 0.0;

                    final showReg = _filter == 'All' || _filter == 'Regular';
                    final showOt = _filter == 'All' || _filter == 'Overtime';

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        if (showReg)
                          BarChartRodData(
                            toY: regVal,
                            color: AppColors.primary,
                            width: rodWidth,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        if (showOt)
                          BarChartRodData(
                            toY: otVal,
                            color: const Color(0xFF34495E), // Midnight Blue
                            width: rodWidth,
                            borderRadius: BorderRadius.circular(2),
                          ),
                      ],
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return InkWell(
      onTap: () => setState(() => _filter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textMedium,
          ),
        ),
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
          const Text(
            'Cost Analysis',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Daily payout for the last 7 days',
            style: TextStyle(color: AppColors.textMedium, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(height: 200, child: _PayoutTrendLineChart(stats: stats)),
        ],
      ),
    );
  }
}

class _PayoutTrendLineChart extends StatelessWidget {
  final DashboardStats stats;
  const _PayoutTrendLineChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final now = DateTime.now();
                final index = value.toInt();
                if (index < 0 || index >= stats.payoutTrend.length)
                  return const SizedBox.shrink();

                // Show last 7 days initials
                final dayDate = now.subtract(
                  Duration(days: stats.payoutTrend.length - 1 - index),
                );
                final dayLabel = DateFormat('E').format(dayDate)[0]; // Mon -> M

                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    dayLabel,
                    style: const TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF2C3E50).withOpacity(0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '₹${spot.y.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: stats.payoutTrend
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : (constraints.maxWidth > 650 ? 2 : 1);
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditEmployeeScreen(),
                ),
              ),
            ),
            _ActionCard(
              icon: Icons.how_to_reg_rounded,
              label: 'Attendance',
              color: Colors.green,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyAttendanceScreen(),
                ),
              ),
            ),
            _ActionCard(
              icon: Icons.payments_rounded,
              label: 'Payroll',
              color: AppColors.primary,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WeeklyPayrollScreen()),
              ),
            ),
            _ActionCard(
              icon: Icons.settings_suggest_rounded,
              label: 'Work Shifts',
              color: Colors.purple,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const ShiftManagementScreen(),
                ),
              ),
            ),
          ],
        );
      },
    );
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
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
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
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
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
              style: TextStyle(
                fontSize: 11,
                color: progress != null ? color : AppColors.textMedium,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// Popup Dialog Helpers
void _showForceDetails(BuildContext context, DashboardStats stats) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Workforce Insights'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Joinees (Last 30 Days)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (stats.recentEmployees.isEmpty)
                const Text('No recent joinees found.')
              else
                ...stats.recentEmployees
                    .take(5)
                    .map(
                      (emp) => ListTile(
                        leading: CircleAvatar(child: Text(emp['name'][0])),
                        title: Text(emp['name']),
                        subtitle: Text(
                          'Joined: ${DateFormat('dd MMM yyyy').format((emp['joinedDate'] as Timestamp).toDate())}',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showAllEmployeesPopup(context);
          },
          child: const Text('View All Employees'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showAttendanceDetails(BuildContext context, DashboardStats stats) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Attendance Summary'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(label: 'Total Strength', value: '${stats.totalCount}'),
              _InfoRow(label: 'Present Today', value: '${stats.presentCount}'),
              _InfoRow(
                label: 'Absent Today',
                value: '${stats.totalCount - stats.presentCount}',
              ),
              _InfoRow(
                label: 'Overtime Today',
                value: '${stats.overtimeCountToday}',
                color: const Color(0xFF34495E),
              ),
              const Divider(height: 32),
              const Text(
                'Daily Attendance Trend',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Use the raw chart widget instead of the full card to avoid layout issues
              SizedBox(height: 200, child: _AttendanceBarChart(stats: stats)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showPayoutDetails(BuildContext context, DashboardStats stats) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Projected Payout Details'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            _InfoRow(
              label: 'Total Weekly Estimate',
              value: '₹${NumberFormat('#,##,###').format(stats.weeklyPayout)}',
            ),
            const Divider(height: 32),
            Expanded(
              child: stats.payoutByEmployee.isEmpty
                  ? const Center(child: Text('No payouts recorded this week.'))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: stats.payoutByEmployee.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final payout = stats.payoutByEmployee[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            payout['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: Text(
                            '₹${NumberFormat('#,##,###').format(payout['amount'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Replicate ResponsiveShell navigation logic
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const WeeklyPayrollScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 200),
              ),
            );
          },
          child: const Text('View All Payouts'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showShiftDetails(BuildContext context, DashboardStats stats) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Shift Assignments'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: stats.activeShiftsList.isEmpty
            ? const Center(child: Text('No shifts defined yet.'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: stats.activeShiftsList.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final shift = stats.activeShiftsList[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.schedule,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      shift['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Timing: ${shift['startTime']} - ${shift['endTime']}',
                      style: const TextStyle(color: AppColors.textMedium),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showAllEmployeesPopup(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('All Employees'),
      content: SizedBox(
        width: 400,
        height: 600,
        child: Consumer(
          builder: (context, ref, child) {
            final employeesAsync = ref.watch(employeesStreamProvider);
            return employeesAsync.when(
              data: (employees) => ListView.separated(
                itemCount: employees.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(employee.name[0])),
                    title: Text(employee.name),
                    subtitle: Text('Status: ${employee.status}'),
                    trailing: Text('₹${employee.hourlyRate.toInt()}/hr'),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMedium)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkforceOverviewSection extends ConsumerWidget {
  const _WorkforceOverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider).value;
    if (stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workforce Analytics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: AppSpacing.m),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return isWide
                ? Row(
                    children: [
                      Expanded(child: _StatusDistributionCard(stats: stats)),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(child: _ShiftOccupancyCard(stats: stats)),
                    ],
                  )
                : Column(
                    children: [
                      _StatusDistributionCard(stats: stats),
                      const SizedBox(height: AppSpacing.m),
                      _ShiftOccupancyCard(stats: stats),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _StatusDistributionCard extends StatelessWidget {
  final DashboardStats stats;
  const _StatusDistributionCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workforce Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: stats.employeesByStatus.entries.map((e) {
                      return PieChartSectionData(
                        color: _getStatusColor(e.key),
                        value: e.value.toDouble(),
                        title: '${e.value}',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${stats.totalEmployees}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: stats.employeesByStatus.keys.map((status) {
              return _LegendItem(color: _getStatusColor(status), label: status);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'on leave':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

class _ShiftOccupancyCard extends StatelessWidget {
  final DashboardStats stats;
  const _ShiftOccupancyCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shift Occupancy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Today',
                style: TextStyle(color: AppColors.textMedium, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Employees: Planned vs Actual',
            style: TextStyle(color: AppColors.textMedium, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (stats.totalCount > 0
                        ? stats.totalCount.toDouble()
                        : 10.0) *
                    1.2,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 ||
                            index >= stats.shiftDistribution.length)
                          return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 4,
                          child: Text(
                            stats.shiftDistribution.keys.elementAt(index),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: stats.shiftDistribution.entries
                    .toList()
                    .asMap()
                    .entries
                    .map((e) {
                      final shiftName = e.value.key;
                      final assigned = e.value.value.toDouble();
                      final present = (stats.shiftPresence[shiftName] ?? 0)
                          .toDouble();

                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: assigned,
                            color: const Color(
                              0xFF34495E,
                            ), // Midnight Blue (Planned)
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                          BarChartRodData(
                            toY: present,
                            color: AppColors.primary, // Saffron (Actual)
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ],
                        barsSpace: 4,
                      );
                    })
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: const Color(0xFF34495E), label: 'Planned'),
              const SizedBox(width: 16),
              _LegendItem(color: AppColors.primary, label: 'Actual'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
        ),
      ],
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
