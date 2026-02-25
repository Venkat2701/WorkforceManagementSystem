import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../models/attendance.dart';
import '../../models/shift.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/hour_picker.dart';

class AttendanceDialog extends StatefulWidget {
  final Employee employee;
  final Attendance initialAttendance;
  final List<Shift> shifts;
  final DateTime date;

  const AttendanceDialog({
    super.key,
    required this.employee,
    required this.initialAttendance,
    required this.shifts,
    required this.date,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  late bool _isPresent;
  late List<TimeSegment> _segments;
  late TextEditingController _overtimeController;
  String? _selectedShiftId;

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _isPresent = widget.initialAttendance.isPresent;
    _segments = List.from(widget.initialAttendance.segments);

    // Try to auto-detect if the current segment matches a shift template
    if (_segments.length == 1 && _isPresent) {
      final seg = _segments[0];
      for (var shift in widget.shifts) {
        if (shift.startTime == seg.startTime && shift.endTime == seg.endTime) {
          _selectedShiftId = shift.id;
          break;
        }
      }
    }

    if (_segments.isEmpty && _isPresent) {
      _segments.add(TimeSegment(startTime: '09:00', endTime: '18:00'));
    }
    _overtimeController = TextEditingController(
      text: widget.initialAttendance.overtimeHours.toString(),
    );
    _overtimeController.addListener(_onOvertimeChanged);
  }

  @override
  void dispose() {
    _overtimeController.dispose();
    super.dispose();
  }

  double get _totalPresenceHours =>
      _segments.fold(0.0, (sum, s) => sum + s.durationHours);

  double get _effectiveTotalHours {
    double total = _totalPresenceHours;
    if (_selectedShiftId != null) {
      total = (total - 1.0).clamp(0.0, 24.0);
    }
    return total;
  }

  String _adjustTime(String time, double hoursToAdd) {
    if (time.isEmpty) return '09:00';
    try {
      final parts = time.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      int totalMinutes = (h * 60 + m + (hoursToAdd * 60)).round();
      while (totalMinutes < 0) totalMinutes += 24 * 60;
      int newH = (totalMinutes ~/ 60) % 24;
      int newM = totalMinutes % 60;
      return '${newH.toString().padLeft(2, '0')}:${newM.toString().padLeft(2, '0')}';
    } catch (_) {
      return time;
    }
  }

  void _onOvertimeChanged() {
    if (_isSyncing) return;
    final val = double.tryParse(_overtimeController.text);
    if (val != null) {
      if (_selectedShiftId != null) {
        setState(() {
          _selectedShiftId = null;
        });
      }
      _updateSegmentsFromOvertime(val);
    }
  }

  void _updateOvertimeFromSegments() {
    if (_isSyncing) return;
    _isSyncing = true;
    final ot = _effectiveTotalHours > 8 ? _effectiveTotalHours - 8 : 0.0;
    final otText = ot.toStringAsFixed(2);
    if (_overtimeController.text != otText) {
      _overtimeController.text = otText;
    }
    _isSyncing = false;
  }

  void _updateSegmentsFromOvertime(double newOT) {
    if (_isSyncing) return;
    if (_segments.isEmpty) return;

    _isSyncing = true;
    double targetPresence =
        (8.0 + newOT + (_selectedShiftId != null ? 1.0 : 0.0)).clamp(0.0, 48.0);
    double currentPresence = _totalPresenceHours;
    double adjustment = targetPresence - currentPresence;

    if (adjustment.abs() > 0.01) {
      setState(() {
        int lastIndex = _segments.length - 1;
        final segment = _segments[lastIndex];
        _segments[lastIndex] = TimeSegment(
          startTime: segment.startTime,
          endTime: _adjustTime(segment.endTime, adjustment),
        );
      });
    }
    _isSyncing = false;
  }

  void _addSegment() {
    if (_selectedShiftId != null) return; // Disabled if template selected
    setState(() {
      _segments.add(TimeSegment(startTime: '09:00', endTime: '18:00'));
    });
    _updateOvertimeFromSegments();
  }

  void _removeSegment(int index) {
    if (_selectedShiftId != null) return; // Disabled if template selected
    setState(() {
      _segments.removeAt(index);
    });
    _updateOvertimeFromSegments();
  }

  void _toggleShiftTemplate(Shift shift) {
    setState(() {
      if (_selectedShiftId == shift.id) {
        // Unselect
        _selectedShiftId = null;
      } else {
        // Select
        _selectedShiftId = shift.id;
        _segments = [
          TimeSegment(startTime: shift.startTime, endTime: shift.endTime),
        ];
        _isPresent = true;
      }
    });
    _updateOvertimeFromSegments();
  }

  Future<void> _selectTime(
    BuildContext context,
    int index,
    bool isStart,
  ) async {
    if (_selectedShiftId != null) return; // Disabled if template selected

    final segment = _segments[index];
    final initialTime = isStart ? segment.startTime : segment.endTime;

    TimeOfDay initialTimeOfDay = const TimeOfDay(hour: 9, minute: 0);
    try {
      if (initialTime.contains(' ')) {
        // Handle "09:00 AM" format
        final timePart = initialTime.split(' ')[0];
        final parts = timePart.split(':');
        var hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        if (initialTime.toUpperCase().contains('PM') && hour < 12) hour += 12;
        if (initialTime.toUpperCase().contains('AM') && hour == 12) hour = 0;
        initialTimeOfDay = TimeOfDay(hour: hour, minute: minute);
      } else if (initialTime.contains(':')) {
        final parts = initialTime.split(':');
        initialTimeOfDay = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (_) {}

    final int? pickedHour = await showHourPicker(
      context: context,
      initialHour: initialTimeOfDay.hour,
      title: isStart ? 'Select Start Hour' : 'Select End Hour',
    );

    if (pickedHour != null) {
      setState(() {
        final timeStr = '${pickedHour.toString().padLeft(2, '0')}:00';
        _segments[index] = TimeSegment(
          startTime: isStart ? timeStr : segment.startTime,
          endTime: isStart ? segment.endTime : timeStr,
        );
      });
      _updateOvertimeFromSegments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTemplateSelected = _selectedShiftId != null;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(widget.employee.name[0]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ID: ${widget.employee.id.substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text(
                  'Present Today',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _isPresent ? 'Marking as present' : 'Marking as absent',
                ),
                value: _isPresent,
                onChanged: (val) {
                  setState(() {
                    _isPresent = val;
                    if (!val) {
                      _selectedShiftId = null;
                    }
                  });
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_isPresent) ...[
                const Divider(),
                const Text(
                  'Quick Shift Templates',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: widget.shifts.map((shift) {
                    final isSelected = _selectedShiftId == shift.id;
                    return ChoiceChip(
                      label: Text(shift.name),
                      selected: isSelected,
                      onSelected: (selected) => _toggleShiftTemplate(shift),
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      backgroundColor: AppColors.primary.withOpacity(0.05),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMedium,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Time Segments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  _segments.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTimeField(
                            'In',
                            _segments[index].startTime,
                            isTemplateSelected
                                ? null
                                : () => _selectTime(context, index, true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimeField(
                            'Out',
                            _segments[index].endTime,
                            isTemplateSelected
                                ? null
                                : () => _selectTime(context, index, false),
                          ),
                        ),
                        if (!isTemplateSelected)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => _removeSegment(index),
                          ),
                        if (isTemplateSelected)
                          const SizedBox(
                            width: 48,
                          ), // Spacer to maintain alignment
                      ],
                    ),
                  ),
                ),
                if (!isTemplateSelected)
                  TextButton.icon(
                    onPressed: _addSegment,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Segment (Breaks/Flex)'),
                  ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Worked Hours',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (_effectiveTotalHours > 8
                                      ? 8.0
                                      : _effectiveTotalHours)
                                  .toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overtime (Hrs)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _overtimeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isPresent && _effectiveTotalHours <= 0)
              ? null
              : () {
                  final otValue =
                      double.tryParse(_overtimeController.text) ?? 0.0;
                  final regHours = _effectiveTotalHours > 8
                      ? 8.0
                      : _effectiveTotalHours;
                  final attendance = widget.initialAttendance.copyWith(
                    isPresent: _isPresent,
                    hoursWorked: _isPresent ? regHours : 0.0,
                    overtimeHours: _isPresent ? otValue : 0.0,
                    segments: _isPresent ? _segments : [],
                  );
                  Navigator.pop(context, attendance);
                },
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, String value, VoidCallback? onTap) {
    final bool isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMedium),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDisabled
                  ? AppColors.backgroundAlt.withOpacity(0.5)
                  : Colors.transparent,
              border: Border.all(color: Colors.black.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value.isEmpty ? '--:--' : value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? AppColors.textMedium
                        : AppColors.textHigh,
                  ),
                ),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isDisabled ? AppColors.textLow : AppColors.textMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
