import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/responsive_shell.dart';
import '../../core/widgets/custom_card.dart';
import '../../services/employee_service.dart';
import '../../services/attendance_service.dart';
import '../../services/shift_service.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import 'attendance_dialog.dart';

class DailyAttendanceScreen extends ConsumerStatefulWidget {
  const DailyAttendanceScreen({super.key});

  @override
  ConsumerState<DailyAttendanceScreen> createState() =>
      _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends ConsumerState<DailyAttendanceScreen> {
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, Attendance> _attendanceMap = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAttendance();
    });
  }

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);
    try {
      final records = await ref
          .read(attendanceServiceProvider)
          .getAttendanceForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _attendanceMap = {for (var r in records) r.employeeId: r};
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching attendance: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(attendanceServiceProvider)
          .saveBulkAttendance(_attendanceMap.values.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving attendance: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAttendanceDialog(Employee employee) async {
    final shifts = ref.read(shiftsStreamProvider).value ?? [];

    final existingAttendance =
        _attendanceMap[employee.id] ??
        Attendance(
          id: '',
          employeeId: employee.id,
          employeeName: employee.name,
          date: _selectedDate,
          hoursWorked: 0,
          overtimeHours: 0,
          isPresent: false,
          segments: [],
        );

    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => AttendanceDialog(
        employee: employee,
        initialAttendance: existingAttendance,
        shifts: shifts,
        date: _selectedDate,
        isAlreadyMarked: _attendanceMap.containsKey(employee.id),
      ),
    );

    if (result == 'unmark') {
      setState(() {
        _attendanceMap.remove(employee.id);
      });
    } else if (result is Attendance) {
      setState(() {
        _attendanceMap[employee.id] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final shiftsAsync = ref.watch(shiftsStreamProvider);

    return ResponsiveShell(
      title: 'Daily Attendance',
      selectedIndex: 2,
      onDestinationSelected: (index) {},
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchAttendance,
                  child: employeesAsync.when(
                    data: (employees) {
                      final filtered = employees.where((e) {
                        final matchesSearch =
                            e.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            e.aadharNumber.contains(_searchQuery);
                        final isActive = e.status != 'Archived';
                        return matchesSearch && isActive;
                      }).toList();
                      return _buildEmployeeList(filtered);
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ),
              _buildFooter(),
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
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _fetchAttendance();
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
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search Employee...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList(List<Employee> employees) {
    if (employees.isEmpty) {
      return const Center(child: Text('No employees found.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : (constraints.maxWidth > 900
                  ? 3
                  : (constraints.maxWidth > 600 ? 2 : 1));
        final childAspectRatio = constraints.maxWidth > 1200
            ? 2.2
            : (constraints.maxWidth > 900 ? 2.5 : 3.0);

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.l),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
          ),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            final attendance = _attendanceMap[employee.id];
            final isMarked = attendance != null;
            final isPresent = attendance?.isPresent ?? false;

            return RepaintBoundary(
              child: CustomCard(
                onTap: () => _openAttendanceDialog(employee),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              (isMarked
                                      ? (isPresent ? Colors.green : Colors.red)
                                      : AppColors.primary)
                                  .withOpacity(0.1),
                          child: Text(
                            employee.name[0],
                            style: TextStyle(
                              color: isMarked
                                  ? (isPresent ? Colors.green : Colors.red)
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                employee.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Aadhar: ${employee.aadharNumber}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMedium,
                                ),
                              ),
                              if (isMarked) ...[
                                const SizedBox(height: 4),
                                Text(
                                  isPresent
                                      ? '${attendance.hoursWorked}h + ${attendance.overtimeHours}h OT'
                                      : 'Absent/Leave',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isPresent
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_note, color: AppColors.textLow),
                      ],
                    ),
                    if (isMarked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Icon(
                          isPresent ? Icons.check_circle : Icons.cancel,
                          color: isPresent ? Colors.green : Colors.red,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marked: ${_attendanceMap.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Present: ${_attendanceMap.values.where((a) => a.isPresent).length}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveAttendance,
            icon: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Save Daily Attendance'),
          ),
        ],
      ),
    );
  }
}
