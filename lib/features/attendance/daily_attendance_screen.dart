import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/responsive_shell.dart';
import '../../services/employee_service.dart';
import '../../services/attendance_service.dart';
import '../../services/shift_service.dart';
import '../../models/attendance.dart';
import '../../models/employee.dart';
import '../../models/shift.dart';

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

  final List<({String start, String end, String label})> _segmentsConfig = [
    (label: "Time segment 1", start: "08:30", end: "13:00"),
    (label: "Time segment 2", start: "13:30", end: "17:00"),
    (label: "Time segment 3", start: "17:30", end: "20:30"),
  ];

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
          .saveBulkAttendance(_selectedDate, _attendanceMap.values.toList());
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

  void _updateAttendance(
    Employee employee,
    int segmentIndex,
    bool isStart,
    String time,
  ) {
    setState(() {
      final current =
          _attendanceMap[employee.id] ??
          Attendance(
            id: '',
            employeeId: employee.id,
            employeeName: employee.name,
            date: _selectedDate,
            hoursWorked: 0,
            overtimeHours: 0,
            isPresent: true,
            segments: List.generate(
              3,
              (i) => TimeSegment(startTime: '', endTime: ''),
            ),
          );

      List<TimeSegment> newSegments = List.from(current.segments);
      if (newSegments.length < 3) {
        newSegments = List.generate(
          3,
          (i) => i < current.segments.length
              ? current.segments[i]
              : TimeSegment(startTime: '', endTime: ''),
        );
      }

      final seg = newSegments[segmentIndex];
      newSegments[segmentIndex] = TimeSegment(
        startTime: isStart ? time : seg.startTime,
        endTime: isStart ? seg.endTime : time,
      );

      // Recalculate hours
      double totalHours = 0;
      for (var s in newSegments) {
        totalHours += s.durationHours;
      }

      final regHours = totalHours > 8 ? 8.0 : totalHours;
      final otHours = totalHours > 8 ? totalHours - 8 : 0.0;

      _attendanceMap[employee.id] = current.copyWith(
        segments: newSegments,
        hoursWorked: regHours,
        overtimeHours: otHours,
        isPresent: totalHours > 0,
        hourlyRate: employee.getHourlyRateForDate(_selectedDate),
        overtimeRate: employee.getOvertimeRateForDate(_selectedDate),
        shiftName: null, // Clear shift template if manual edit occurs
      );
    });
  }

  void _applyShiftToEmployee(Employee employee, Shift shift) {
    setState(() {
      final current =
          _attendanceMap[employee.id] ??
          Attendance(
            id: '',
            employeeId: employee.id,
            employeeName: employee.name,
            date: _selectedDate,
            hoursWorked: 0,
            overtimeHours: 0,
            isPresent: true,
            segments: List.generate(
              3,
              (i) => TimeSegment(startTime: '', endTime: ''),
            ),
          );

      List<TimeSegment> newSegments = List.generate(
        3,
        (i) => TimeSegment(startTime: '', endTime: ''),
      );
      newSegments[0] = TimeSegment(
        startTime: shift.startTime,
        endTime: shift.endTime,
      );

      double totalHours = newSegments[0].durationHours;
      // Subtract 1 hour for lunch/break when using a template
      if (totalHours > 0) {
        totalHours = (totalHours - 1.0).clamp(0, double.infinity);
      }

      final regHours = totalHours > 8 ? 8.0 : totalHours;
      final otHours = totalHours > 8 ? totalHours - 8 : 0.0;

      _attendanceMap[employee.id] = current.copyWith(
        segments: newSegments,
        hoursWorked: regHours,
        overtimeHours: otHours,
        isPresent: true,
        hourlyRate: employee.getHourlyRateForDate(_selectedDate),
        overtimeRate: employee.getOvertimeRateForDate(_selectedDate),
        shiftName: shift.name,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final shiftsAsync = ref.watch(shiftsStreamProvider);

    return ResponsiveShell(
      title: 'Daily Attendance',
      selectedIndex: 2,
      onDestinationSelected: (index) {},
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
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
                return _buildAttendanceTable(filtered, shiftsAsync.value ?? []);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          _buildFooter(),
        ],
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
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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

  Widget _buildAttendanceTable(List<Employee> employees, List<Shift> shifts) {
    if (employees.isEmpty) {
      return const Center(child: Text('No employees found.'));
    }

    return Card(
      margin: const EdgeInsets.all(AppSpacing.l),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: isWide ? 40 : 20,
                  horizontalMargin: 16,
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: isWide ? 200 : 140,
                        child: const Text(
                          'Employee Name',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Shift',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...List.generate(
                      3,
                      (i) => DataColumn(
                        label: Text(
                          _segmentsConfig[i].label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'OT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: employees.map((employee) {
                    final attendance = _attendanceMap[employee.id];
                    final segments = attendance?.segments ?? [];

                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: isWide ? 200 : 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  employee.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(_buildShiftSelector(employee, shifts)),
                        ...List.generate(3, (i) {
                          final isShiftActive = attendance?.shiftName != null;
                          final segmentEnabled = i == 0 || !isShiftActive;

                          final start = i < segments.length
                              ? segments[i].startTime
                              : "";
                          final end = i < segments.length
                              ? segments[i].endTime
                              : "";
                          return DataCell(
                            _buildSegmentEntry(
                              employee,
                              i,
                              start,
                              end,
                              enabled: segmentEnabled,
                            ),
                          );
                        }),
                        DataCell(
                          Text(
                            attendance?.hoursWorked.toStringAsFixed(1) ?? "0.0",
                          ),
                        ),
                        DataCell(
                          Text(
                            attendance?.overtimeHours.toStringAsFixed(1) ??
                                "0.0",
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShiftSelector(Employee employee, List<Shift> shifts) {
    final activeShift = _attendanceMap[employee.id]?.shiftName;

    return InkWell(
      onTap: () => _showShiftPicker(employee, shifts),
      child: Container(
        constraints: const BoxConstraints(minWidth: 70),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: activeShift != null
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.05),
          border: Border.all(
            color: activeShift != null
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activeShift != null ? Icons.check_circle : Icons.access_time,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              activeShift ?? "Shift",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftPicker(Employee employee, List<Shift> shifts) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Shift Template - ${employee.name}"),
          content: SizedBox(
            width: 300,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: shifts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final shift = shifts[index];
                return ListTile(
                  title: Text(shift.name),
                  subtitle: Text("${shift.startTime} - ${shift.endTime}"),
                  onTap: () {
                    _applyShiftToEmployee(employee, shift);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            if (_attendanceMap[employee.id]?.shiftName != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    final current = _attendanceMap[employee.id];
                    if (current != null) {
                      _attendanceMap[employee.id] = current.copyWith(
                        shiftName: null,
                      );
                    }
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  "Clear Shift",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSegmentEntry(
    Employee employee,
    int segmentIndex,
    String start,
    String end, {
    bool enabled = true,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TimeSelector(
          value: start,
          onChanged: (val) =>
              _updateAttendance(employee, segmentIndex, true, val),
          hint: "IN",
          enabled: enabled,
        ),
        const Text(" - ", style: TextStyle(color: Colors.grey)),
        _TimeSelector(
          value: end,
          onChanged: (val) =>
              _updateAttendance(employee, segmentIndex, false, val),
          hint: "OUT",
          enabled: enabled,
        ),
      ],
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
                'Marked: ${_attendanceMap.values.where((a) => a.isPresent).length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Total Employees: ${_attendanceMap.length}',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
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

class _TimeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool enabled;

  const _TimeSelector({
    required this.value,
    required this.onChanged,
    required this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _showIntervalPicker(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled
                ? Colors.grey.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
          ),
          borderRadius: BorderRadius.circular(4),
          color: enabled ? null : Colors.grey.withOpacity(0.05),
        ),
        child: Text(
          value.isEmpty ? hint : value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: value.isEmpty ? FontWeight.normal : FontWeight.bold,
            color: enabled
                ? (value.isEmpty ? Colors.grey : AppColors.primary)
                : Colors.grey.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  void _showIntervalPicker(BuildContext context) {
    final List<String> hours = List.generate(
      24,
      (i) => i.toString().padLeft(2, '0'),
    );
    final List<String> minutes = ["00", "15", "30", "45"];

    String selectedHour = value.contains(':') ? value.split(':')[0] : "08";
    String selectedMinute = value.contains(':') ? value.split(':')[1] : "30";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Select Time ($hint)"),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.m,
                      horizontal: AppSpacing.l,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      "$selectedHour : $selectedMinute",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Hours",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  SizedBox(
                    height: 140,
                    width: 300,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: 24,
                      itemBuilder: (context, index) {
                        final h = hours[index];
                        final isSelected = h == selectedHour;
                        return InkWell(
                          onTap: () => setState(() => selectedHour = h),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              h,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Minutes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: minutes.map((m) {
                      final isSelected = m == selectedMinute;
                      return InkWell(
                        onTap: () => setState(() => selectedMinute = m),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            m,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    onChanged("");
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Clear",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    onChanged("$selectedHour:$selectedMinute");
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
