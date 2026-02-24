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
  Map<String, List<WeeklySalary>>? _salaryData;
  String _statusFilter = 'All'; // 'All', 'Paid', 'UnPaid'
  bool _isLoading = false;

  List<WeeklySalary> get _filteredSalaries {
    if (_salaryData == null) return [];
    
    switch (_statusFilter) {
      case 'Paid':
        return _salaryData!['paid'] ?? [];
      case 'UnPaid':
        return _salaryData!['unpaid'] ?? [];
      default:
        return _salaryData!['all'] ?? [];
    }
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
      setState(() => _salaryData = results);
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
      title: 'Payroll',
      selectedIndex: 3,
      onDestinationSelected: (index) {},
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchPayroll,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _salaryData == null || _filteredSalaries.isEmpty
                          ? const Center(child: Text('No employees with payout in this range'))
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  if (_salaryData != null) _buildSummaryCards(),
                                  _buildPayrollList(),
                                  const SizedBox(height: AppSpacing.xl),
                                ],
                              ),
                            ),
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
                    const SizedBox(height: AppSpacing.m),
                    _buildFilterRow(),
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

  Widget _buildFilterRow() {
    return Row(
      children: [
        _buildFilterChip('All', Colors.grey[600]!, Colors.grey[100]!),
        const SizedBox(width: AppSpacing.s),
        _buildFilterChip('UnPaid', const Color(0xFFEF5350), const Color(0xFFFFEBEE)),
        const SizedBox(width: AppSpacing.s),
        _buildFilterChip('Paid', const Color(0xFF66BB6A), const Color(0xFFE8F5E9)),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color activeColor, Color activeBg) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.circular),
          border: Border.all(
            color: isSelected ? activeColor : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : AppColors.textMedium,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
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
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1));
        final childAspectRatio = constraints.maxWidth > 1200 ? 2.2 : (constraints.maxWidth > 900 ? 2.5 : (constraints.maxWidth > 600 ? 2.8 : 3.5));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SalarySlipView(
                    salary: salary,
                    isReadOnly: _statusFilter == 'All',
                  )),
                );
                if (result == true) {
                  _fetchPayroll();
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _statusFilter == 'All' 
                          ? Colors.grey.withOpacity(0.2) 
                          : (salary.paid ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(salary.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${salary.totalHours.toStringAsFixed(1)}h Reg | ${salary.totalOvertime.toStringAsFixed(1)}h Ovt', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '₹${salary.totalSalary.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: _statusFilter == 'All' 
                              ? const Color(0xFFF57C00) 
                              : (salary.paid ? const Color(0xFF43A047) : const Color(0xFFE53935)), 
                          fontSize: 18
                        ),
                      ),
                      Text(
                        _statusFilter == 'All' ? 'TOTAL' : (salary.paid ? 'PAID' : 'DUE'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _statusFilter == 'All' 
                              ? const Color(0xFFF57C00).withOpacity(0.8) 
                              : (salary.paid ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.textLow),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
