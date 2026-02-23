import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/responsive_shell.dart';
import '../../core/widgets/custom_card.dart';
import '../../services/salary_service.dart';
import '../../models/salary_record.dart';
import 'salary_slip_view.dart'; // To be implemented

class WeeklyPayrollScreen extends ConsumerStatefulWidget {
  const WeeklyPayrollScreen({super.key});

  @override
  ConsumerState<WeeklyPayrollScreen> createState() => _WeeklyPayrollScreenState();
}

class _WeeklyPayrollScreenState extends ConsumerState<WeeklyPayrollScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  List<WeeklySalary>? _salaries;
  bool _isLoading = false;

  List<WeeklySalary> get _filteredSalaries {
    return (_salaries ?? []).where((s) => s.totalSalary > 0).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchPayroll();
  }

  Future<void> _fetchPayroll() async {
    setState(() => _isLoading = true);
    try {
      final results = await ref.read(salaryServiceProvider).calculateWeeklySalary(
            _dateRange.start,
            _dateRange.end,
          );
      setState(() => _salaries = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      title: 'Weekly Payroll',
      selectedIndex: 3,
      onDestinationSelected: (index) {},
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildHeader(),
              if (_salaries != null) _buildSummaryCards(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchPayroll,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _salaries == null || _filteredSalaries.isEmpty
                          ? const Center(child: Text('No employees with payout in this range'))
                          : _buildPayrollList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return Row(
            crossAxisAlignment: isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payroll Period', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _dateRange,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() => _dateRange = picked);
                          _fetchPayroll();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${DateFormat('MMM dd').format(_dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange.end)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isWide) ...[
                const SizedBox(width: AppSpacing.m),
                ElevatedButton.icon(
                  onPressed: _fetchPayroll,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh Data'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards() {
    final filtered = _filteredSalaries;
    double totalPayout = filtered.fold(0, (sum, s) => sum + s.totalSalary);
    double totalHours = filtered.fold(0, (sum, s) => sum + s.totalHours);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
      child: Row(
        children: [
          Expanded(child: _buildMiniStat('Total Payout', '₹${totalPayout.toStringAsFixed(0)}', AppColors.primary)),
          const SizedBox(width: AppSpacing.m),
          Expanded(child: _buildMiniStat('Total Hours', '${totalHours.toStringAsFixed(0)}h', AppColors.textMedium)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return CustomCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPayrollList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        final childAspectRatio = constraints.maxWidth > 900 ? 2.5 : (constraints.maxWidth > 600 ? 2.8 : 3.5);

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
          ),
          itemCount: _filteredSalaries.length,
          itemBuilder: (context, index) {
            final salary = _filteredSalaries[index];
            return CustomCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SalarySlipView(salary: salary)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(salary.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${salary.totalHours}h Reg | ${salary.totalOvertime}h Ovt', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '₹${salary.totalSalary.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textLow),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
