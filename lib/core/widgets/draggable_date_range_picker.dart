import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class DraggableDateRangePicker extends StatefulWidget {
  final DateTimeRange initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const DraggableDateRangePicker({
    super.key,
    required this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<DraggableDateRangePicker> createState() =>
      _DraggableDateRangePickerState();
}

enum PickerMode { calendar, manual, yearPicker }

class _DraggableDateRangePickerState extends State<DraggableDateRangePicker> {
  late DateTime _displayedMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _isDragging = false;
  PickerMode _mode = PickerMode.calendar;

  // Controllers for manual input
  late TextEditingController _startController;
  late TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(
      widget.initialDateRange.start.year,
      widget.initialDateRange.start.month,
      1,
    );
    _rangeStart = widget.initialDateRange.start;
    _rangeEnd = widget.initialDateRange.end;

    _startController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_rangeStart!),
    );
    _endController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_rangeEnd!),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
        _rangeStart = day;
        _rangeEnd = null;
      } else if (day.isBefore(_rangeStart!)) {
        _rangeEnd = _rangeStart;
        _rangeStart = day;
      } else {
        _rangeEnd = day;
      }
      _updateControllers();
    });
  }

  void _updateControllers() {
    if (_rangeStart != null) {
      _startController.text = DateFormat('dd/MM/yyyy').format(_rangeStart!);
    }
    if (_rangeEnd != null) {
      _endController.text = DateFormat('dd/MM/yyyy').format(_rangeEnd!);
    }
  }

  void _handleManualInput() {
    try {
      final start = DateFormat('dd/MM/yyyy').parseStrict(_startController.text);
      final end = DateFormat('dd/MM/yyyy').parseStrict(_endController.text);

      if (start.isAfter(widget.lastDate) || start.isBefore(widget.firstDate))
        return;
      if (end.isAfter(widget.lastDate) || end.isBefore(widget.firstDate))
        return;

      setState(() {
        _rangeStart = start;
        _rangeEnd = end;
        _displayedMonth = DateTime(start.year, start.month, 1);
      });
    } catch (e) {
      // Invalid date format
    }
  }

  void _handleGesture(Offset localPosition, BoxConstraints constraints) {
    final cellWidth = constraints.maxWidth / 7.0;
    final cellHeight = cellWidth;

    final col = (localPosition.dx / cellWidth).floor();
    final row = (localPosition.dy / cellHeight).floor();

    if (col >= 0 && col < 7 && row >= 0) {
      final firstDayOfMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month,
        1,
      );
      final firstDayOffset = (firstDayOfMonth.weekday % 7);

      final index = row * 7 + col;
      final dayNumber = index - firstDayOffset + 1;
      final daysInMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        0,
      ).day;

      if (dayNumber >= 1 && dayNumber <= daysInMonth) {
        final day = DateTime(
          _displayedMonth.year,
          _displayedMonth.month,
          dayNumber,
        );
        if (day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate))
          return;

        setState(() {
          if (!_isDragging) {
            _rangeStart = day;
            _rangeEnd = null;
            _isDragging = true;
          } else {
            _rangeEnd = day;
          }
          _updateControllers();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: _buildTitle(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: SizedBox(
        width: 350,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBody(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: (_rangeStart != null && _rangeEnd != null)
                ? AppColors.primary
                : Colors.grey[300],
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: (_rangeStart != null && _rangeEnd != null)
              ? () {
                  DateTime start = _rangeStart!;
                  DateTime end = _rangeEnd!;
                  if (start.isAfter(end)) {
                    final temp = start;
                    start = end;
                    end = temp;
                  }
                  Navigator.pop(context, DateTimeRange(start: start, end: end));
                }
              : null,
          child: const Text('Select Range'),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Date Range',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: Icon(
              _mode == PickerMode.manual
                  ? Icons.calendar_month
                  : Icons.edit_calendar,
              color: AppColors.primary,
            ),
            onPressed: () {
              setState(() {
                if (_mode == PickerMode.manual) {
                  _mode = PickerMode.calendar;
                } else {
                  _mode = PickerMode.manual;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case PickerMode.manual:
        return _buildManualInput();
      case PickerMode.yearPicker:
        return _buildYearPicker();
      case PickerMode.calendar:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCalendarHeader(),
            const SizedBox(height: 16),
            _buildWeekdaysRow(),
            _buildCalendarGrid(),
          ],
        );
    }
  }

  Widget _buildManualInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (value) => _handleManualInput(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endController,
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.event, size: 18),
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (value) => _handleManualInput(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearPicker() {
    final int startYear = widget.firstDate.year;
    final int endYear = widget.lastDate.year;
    final years = List.generate(
      endYear - startYear + 1,
      (i) => startYear + i,
    ).reversed.toList();

    return SizedBox(
      height: 300,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2,
        ),
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index];
          final isSelected = year == _displayedMonth.year;
          return InkWell(
            onTap: () {
              setState(() {
                _displayedMonth = DateTime(year, _displayedMonth.month, 1);
                _mode = PickerMode.calendar;
              });
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$year',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.grey),
          onPressed: () => _changeMonth(-1),
        ),
        InkWell(
          onTap: () => setState(() => _mode = PickerMode.yearPicker),
          child: Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_displayedMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.primary),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.grey),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildWeekdaysRow() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: days
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final firstDayOffset = (firstDayOfMonth.weekday % 7);
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) {
            _isDragging = false;
            _handleGesture(details.localPosition, constraints);
          },
          onPanUpdate: (details) =>
              _handleGesture(details.localPosition, constraints),
          onPanEnd: (details) => setState(() => _isDragging = false),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - firstDayOffset + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth)
                return const SizedBox.shrink();

              final day = DateTime(
                _displayedMonth.year,
                _displayedMonth.month,
                dayNumber,
              );

              final bool startSelected =
                  _rangeStart != null && isSameDay(day, _rangeStart!);
              final bool endSelected =
                  _rangeEnd != null && isSameDay(day, _rangeEnd!);
              final bool inRange = _isDateInRange(day);

              bool isRangeStart = startSelected;
              bool isRangeEnd = endSelected;

              if (_rangeStart != null &&
                  _rangeEnd != null &&
                  _rangeStart!.isAfter(_rangeEnd!)) {
                isRangeStart = endSelected;
                isRangeEnd = startSelected;
              }

              return _CalendarDayCell(
                day: dayNumber,
                isRangeStart: isRangeStart,
                isRangeEnd: isRangeEnd,
                isInRange: inRange,
                isToday: isSameDay(day, DateTime.now()),
                isOutside:
                    day.isBefore(widget.firstDate) ||
                    day.isAfter(widget.lastDate),
                onTap: () => _onDaySelected(day),
              );
            },
          ),
        );
      },
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + offset,
        1,
      );
    });
  }

  bool _isDateInRange(DateTime date) {
    if (_rangeStart == null || _rangeEnd == null) return false;
    DateTime start = _rangeStart!;
    DateTime end = _rangeEnd!;
    if (start.isAfter(end)) {
      final temp = start;
      start = end;
      end = temp;
    }
    return (date.isAfter(start) || isSameDay(date, start)) &&
        (date.isBefore(end) || isSameDay(date, end));
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isRangeStart;
  final bool isRangeEnd;
  final bool isInRange;
  final bool isToday;
  final bool isOutside;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.day,
    required this.isRangeStart,
    required this.isRangeEnd,
    required this.isInRange,
    required this.isToday,
    required this.isOutside,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOutside ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (isInRange)
            Align(
              alignment: Alignment.center,
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.horizontal(
                    left: isRangeStart
                        ? const Radius.circular(16)
                        : Radius.zero,
                    right: isRangeEnd ? const Radius.circular(16) : Radius.zero,
                  ),
                ),
              ),
            ),
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isRangeStart || isRangeEnd)
                    ? AppColors.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !(isRangeStart || isRangeEnd)
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  color: (isRangeStart || isRangeEnd)
                      ? Colors.white
                      : (isOutside ? Colors.grey[350] : Colors.black87),
                  fontWeight: (isRangeStart || isRangeEnd || isToday)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
