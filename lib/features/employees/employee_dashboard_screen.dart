import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/custom_card.dart';
import '../../models/employee.dart';
import '../../models/attendance.dart';
import '../../models/salary_record.dart';
import '../../services/attendance_service.dart';
import '../../services/salary_service.dart';
import 'add_edit_employee_screen.dart';

final employeeAttendanceProvider = FutureProvider.autoDispose
    .family<List<Attendance>, String>((ref, employeeId) {
      return ref
          .read(attendanceServiceProvider)
          .getEmployeeAttendanceHistory(employeeId);
    });

final employeePaymentProvider = FutureProvider.autoDispose
    .family<List<WeeklySalary>, String>((ref, employeeId) {
      return ref
          .read(salaryServiceProvider)
          .getEmployeePaymentHistory(employeeId);
    });

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  final Employee employee;

  const EmployeeDashboardScreen({super.key, required this.employee});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textHigh,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Employee',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AddEditEmployeeScreen(employee: widget.employee),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeeAttendanceProvider(widget.employee.id));
          ref.invalidate(employeePaymentProvider(widget.employee.id));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailsCard(),
              const SizedBox(height: AppSpacing.xl),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildAttendanceCalendarSection()),
                    const SizedBox(width: AppSpacing.l),
                    Expanded(flex: 2, child: _buildPaymentHistorySection()),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttendanceCalendarSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildPaymentHistorySection(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return CustomCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              widget.employee.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.employee.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    _buildStatusBadge(widget.employee.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          widget.employee.phone,
                          style: const TextStyle(color: AppColors.textMedium),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 16,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Aadhar: ${widget.employee.aadharNumber}',
                          style: const TextStyle(color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                const Divider(),
                const SizedBox(height: AppSpacing.m),
                Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.m,
                  children: [
                    _buildInfoColumn('Salary Type', widget.employee.salaryType),
                    _buildInfoColumn(
                      'Base Rate',
                      '₹${widget.employee.hourlyRate.toStringAsFixed(2)}/hr',
                      isPrimary: true,
                    ),
                    _buildInfoColumn(
                      'OT Rate',
                      '₹${widget.employee.overtimeRate.toStringAsFixed(2)}/hr',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    String value, {
    bool isPrimary = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isPrimary ? AppColors.primary : AppColors.textHigh,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color;
    switch (status) {
      case 'Active':
        color = Colors.green;
        break;
      case 'On Leave':
        color = Colors.orange;
        break;
      case 'Archived':
        color = Colors.red;
        break;
      default:
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAttendanceCalendarSection() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Calendar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          ref
              .watch(employeeAttendanceProvider(widget.employee.id))
              .when(
                data: (attendanceList) {
                  // Create a map for quick lookup
                  final attendanceMap = {
                    for (var a in attendanceList)
                      DateTime(a.date.year, a.date.month, a.date.day): a,
                  };

                  return TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        final cleanDate = DateTime(
                          date.year,
                          date.month,
                          date.day,
                        );
                        final record = attendanceMap[cleanDate];

                        if (record != null) {
                          return Positioned(
                            bottom: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: record.isPresent
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              width: 8.0,
                              height: 8.0,
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
          if (_selectedDay != null) ...[
            const SizedBox(height: AppSpacing.m),
            const Divider(),
            const SizedBox(height: AppSpacing.m),
            _buildSelectedDayDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDayDetails() {
    final attendanceHistoryOpt = ref
        .watch(employeeAttendanceProvider(widget.employee.id))
        .value;

    if (attendanceHistoryOpt == null) return const SizedBox.shrink();

    final cleanSelectedDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );

    Attendance? selectedRecord;
    for (var a in attendanceHistoryOpt) {
      if (a.date.year == cleanSelectedDate.year &&
          a.date.month == cleanSelectedDate.month &&
          a.date.day == cleanSelectedDate.day) {
        selectedRecord = a;
        break;
      }
    }

    if (selectedRecord == null) {
      return Text(
        'No attendance record for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
        style: const TextStyle(color: AppColors.textMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMM dd, yyyy').format(_selectedDay!),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: AppSpacing.s),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selectedRecord.isPresent
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedRecord.isPresent ? 'Present' : 'Absent',
                style: TextStyle(
                  color: selectedRecord.isPresent ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            if (selectedRecord.isPresent) ...[
              const SizedBox(width: AppSpacing.m),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selectedRecord.isPaid
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedRecord.isPaid ? 'Paid' : 'Pending Payment',
                  style: TextStyle(
                    color: selectedRecord.isPaid ? Colors.blue : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (selectedRecord.isPresent)
          Text(
            '${selectedRecord.hoursWorked.toStringAsFixed(1)} Regular Hours | ${selectedRecord.overtimeHours.toStringAsFixed(1)} OT Hours',
            style: const TextStyle(color: AppColors.textHigh),
          ),
      ],
    );
  }

  Widget _buildPaymentHistorySection() {
    return CustomCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.l),
            child: Text(
              'Payment History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
          ),
          const Divider(height: 1),
          ref
              .watch(employeePaymentProvider(widget.employee.id))
              .when(
                data: (payments) {
                  if (payments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No payment history found',
                          style: TextStyle(color: AppColors.textMedium),
                        ),
                      ),
                    );
                  }

                  // Group by Pending and Paid
                  final pending = payments.where((p) => !p.paid).toList();
                  final paid = payments.where((p) => p.paid).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pending.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                            vertical: AppSpacing.m,
                          ),
                          child: Text(
                            'Pending Payments',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ...pending.map(_buildPaymentItem),
                      ],
                      if (paid.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                            vertical: AppSpacing.m,
                          ),
                          child: Text(
                            'Paid History',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ...paid.map(_buildPaymentItem),
                      ],
                      const SizedBox(height: AppSpacing.m),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Center(child: Text('Error: $err')),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(WeeklySalary salary) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        backgroundColor: salary.paid
            ? Colors.blue.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        child: Icon(
          salary.paid ? Icons.check_circle_outline : Icons.pending_actions,
          color: salary.paid ? Colors.blue : Colors.orange,
          size: 20,
        ),
      ),
      title: Text(
        'Week: ${DateFormat('MMM dd').format(salary.startDate)} - ${DateFormat('MMM dd').format(salary.endDate)}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      subtitle: Text(
        '${salary.totalHours.toStringAsFixed(1)} hrs | ₹${salary.totalSalary.toStringAsFixed(2)}',
        style: const TextStyle(color: AppColors.textMedium, fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: salary.paid
              ? Colors.blue.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          salary.paid ? 'Paid' : 'Pending',
          style: TextStyle(
            color: salary.paid ? Colors.blue : Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
