import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHelper {
  static Future<DateTimeRange?> showFullDatePicker(BuildContext context) async {
    DateTime viewMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime? startDate;
    DateTime? endDate;

    final result = await showModalBottomSheet<DateTimeRange?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomDateRangePicker(
        initialViewMonth: viewMonth,
        onConfirm: (range) => Navigator.pop(ctx, range),
        onCancel: () => Navigator.pop(ctx, null),
      ),
    );

    return result;
  }
}

class _CustomDateRangePicker extends StatefulWidget {
  final DateTime initialViewMonth;
  final void Function(DateTimeRange) onConfirm;
  final VoidCallback onCancel;

  const _CustomDateRangePicker({
    required this.initialViewMonth,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<_CustomDateRangePicker> {
  late DateTime _viewMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  static const _dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  void initState() {
    super.initState();
    _viewMonth = widget.initialViewMonth;
  }

  bool _isInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return date.isAfter(_startDate!) && date.isBefore(_endDate!);
  }

  bool _isStart(DateTime date) =>
      _startDate != null && _isSameDay(date, _startDate!);

  bool _isEnd(DateTime date) => _endDate != null && _isSameDay(date, _endDate!);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _onDayTap(DateTime date) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
      } else {
        if (date.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = date;
        } else if (_isSameDay(date, _startDate!)) {
          _startDate = null;
        } else {
          _endDate = date;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final now = DateTime.now();

    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final totalDays = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final startWeekday = (firstDay.weekday - 1) % 7;

    String _rangePreviewText() {
      if (_startDate == null) return 'Pilih tanggal mulai';
      if (_endDate == null) {
        return '${DateFormat('dd MMM yyyy', 'id_ID').format(_startDate!)}  →  Pilih tanggal akhir';
      }
      return '${DateFormat('dd MMM yyyy', 'id_ID').format(_startDate!)}  –  ${DateFormat('dd MMM yyyy', 'id_ID').format(_endDate!)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Icon(Icons.date_range_outlined, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pilih Rentang Tanggal',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ketuk tanggal mulai, lalu tanggal akhir',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          const SizedBox(height: 16),

          // Month navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _viewMonth = DateTime(
                      _viewMonth.year,
                      _viewMonth.month - 1,
                      1,
                    );
                  }),
                  icon: Icon(Icons.chevron_left_rounded, color: primary),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(_viewMonth),
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _viewMonth = DateTime(
                      _viewMonth.year,
                      _viewMonth.month + 1,
                      1,
                    );
                  }),
                  icon: Icon(Icons.chevron_right_rounded, color: primary),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Day headers
          Row(
            children: _dayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: d == 'Min'
                              ? Colors.red.shade400
                              : theme.hintColor,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 2,
              crossAxisSpacing: 0,
            ),
            itemCount: startWeekday + totalDays,
            itemBuilder: (_, index) {
              if (index < startWeekday) return const SizedBox();
              final day = index - startWeekday + 1;
              final date = DateTime(_viewMonth.year, _viewMonth.month, day);
              final isToday = _isSameDay(date, now);
              final isStart = _isStart(date);
              final isEnd = _isEnd(date);
              final inRange = _isInRange(date);
              final isSunday = date.weekday == DateTime.sunday;
              final isSelected = isStart || isEnd;

              Color? bgColor;
              if (isSelected)
                bgColor = primary;
              else if (inRange)
                bgColor = primary.withOpacity(0.12);

              Color textColor;
              if (isSelected) {
                textColor = Colors.white;
              } else if (isSunday) {
                textColor = Colors.red.shade400;
              } else if (isDark) {
                textColor = Colors.white70;
              } else {
                textColor = Colors.black87;
              }

              return GestureDetector(
                onTap: () => _onDayTap(date),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: (isStart || isEnd)
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: (isStart || isEnd)
                        ? null
                        : inRange
                        ? BorderRadius.circular(4)
                        : null,
                    border: isToday && !isSelected
                        ? Border.all(color: primary.withOpacity(0.5), width: 1)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Range preview
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _startDate != null
                  ? primary.withOpacity(0.07)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _startDate != null
                    ? primary.withOpacity(0.25)
                    : theme.dividerColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: _startDate != null ? primary : theme.hintColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rangePreviewText(),
                    style: TextStyle(
                      color: _startDate != null ? primary : theme.hintColor,
                      fontWeight: _startDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.hintColor,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_startDate != null && _endDate != null)
                      ? () => widget.onConfirm(
                          DateTimeRange(start: _startDate!, end: _endDate!),
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    (_startDate != null && _endDate != null)
                        ? 'Gunakan Rentang Ini'
                        : 'Pilih Tanggal',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
