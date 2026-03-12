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

class _DraggableDateRangePickerState extends State<DraggableDateRangePicker> {
  late DateTime _displayedMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _isDragging = false;

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
    });
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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCalendarHeader(),
            const SizedBox(height: 16),
            _buildWeekdaysRow(),
            _buildCalendarGrid(),
          ],
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

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.grey),
          onPressed: () => _changeMonth(-1),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_displayedMonth),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
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

              // Determine visual state
              final bool startSelected =
                  _rangeStart != null && isSameDay(day, _rangeStart!);
              final bool endSelected =
                  _rangeEnd != null && isSameDay(day, _rangeEnd!);
              final bool inRange = _isDateInRange(day);

              // Premium range highlight logic
              bool isRangeStart = startSelected;
              bool isRangeEnd = endSelected;

              // Normalize if dragging backwards
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
          // Range background highlight
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

          // Selection circle or Today indicator
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
