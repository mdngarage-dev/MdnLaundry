import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarHelper {
  static Future<DateTimeRange?> showFullDatePicker(BuildContext context) async {
    final result = await showModalBottomSheet<DateTimeRange?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomDateRangePicker(
        initialViewMonth: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          1,
        ),
        onConfirm: (range) => Navigator.pop(ctx, range),
        onCancel: () => Navigator.pop(ctx, null),
      ),
    );

    return result;
  }
}

enum _PickerMode { tanggal, bulan }

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
  _PickerMode _mode = _PickerMode.tanggal;

  // ── Mode "Per Tanggal" ──
  late DateTime _viewMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  // ── Mode "Per Bulan" ──
  late int _viewYear;
  DateTime? _startMonth; // disimpan sebagai tanggal 1 pada bulan terpilih
  DateTime? _endMonth;

  static const _dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  @override
  void initState() {
    super.initState();
    _viewMonth = widget.initialViewMonth;
    _viewYear = widget.initialViewMonth.year;
  }

  // ════════════════════════════════════════════════════════
  // HELPERS — Mode Tanggal
  // ════════════════════════════════════════════════════════
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

  // ════════════════════════════════════════════════════════
  // HELPERS — Mode Bulan
  // ════════════════════════════════════════════════════════
  int _monthIndex(DateTime d) => d.year * 12 + d.month;

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  bool _isMonthInRange(DateTime date) {
    if (_startMonth == null || _endMonth == null) return false;
    final di = _monthIndex(date);
    return di > _monthIndex(_startMonth!) && di < _monthIndex(_endMonth!);
  }

  bool _isMonthStart(DateTime date) =>
      _startMonth != null && _isSameMonth(date, _startMonth!);

  bool _isMonthEnd(DateTime date) =>
      _endMonth != null && _isSameMonth(date, _endMonth!);

  void _onMonthTap(int monthNumber) {
    final date = DateTime(_viewYear, monthNumber, 1);
    setState(() {
      if (_startMonth == null || (_startMonth != null && _endMonth != null)) {
        _startMonth = date;
        _endMonth = null;
      } else {
        if (date.isBefore(_startMonth!)) {
          _endMonth = _startMonth;
          _startMonth = date;
        } else if (_isSameMonth(date, _startMonth!)) {
          _startMonth = null;
        } else {
          _endMonth = date;
        }
      }
    });
  }

  // ════════════════════════════════════════════════════════
  // SHARED
  // ════════════════════════════════════════════════════════
  bool get _hasStarted =>
      _mode == _PickerMode.tanggal ? _startDate != null : _startMonth != null;

  bool get _canConfirm => _mode == _PickerMode.tanggal
      ? (_startDate != null && _endDate != null)
      : (_startMonth != null && _endMonth != null);

  String _rangePreviewText() {
    if (_mode == _PickerMode.tanggal) {
      if (_startDate == null) return 'Pilih tanggal mulai';
      if (_endDate == null) {
        return '${DateFormat('dd MMM yyyy', 'id_ID').format(_startDate!)}  →  Pilih tanggal akhir';
      }
      return '${DateFormat('dd MMM yyyy', 'id_ID').format(_startDate!)}  –  '
          '${DateFormat('dd MMM yyyy', 'id_ID').format(_endDate!)}';
    } else {
      if (_startMonth == null) return 'Pilih bulan mulai';
      if (_endMonth == null) {
        return '${_monthLabels[_startMonth!.month - 1]} ${_startMonth!.year}  →  Pilih bulan akhir';
      }
      return '${_monthLabels[_startMonth!.month - 1]} ${_startMonth!.year}  –  '
          '${_monthLabels[_endMonth!.month - 1]} ${_endMonth!.year}';
    }
  }

  void _confirm() {
    if (_mode == _PickerMode.tanggal) {
      if (_startDate != null && _endDate != null) {
        widget.onConfirm(DateTimeRange(start: _startDate!, end: _endDate!));
      }
    } else {
      if (_startMonth != null && _endMonth != null) {
        final start = DateTime(_startMonth!.year, _startMonth!.month, 1);
        final end = DateTime(_endMonth!.year, _endMonth!.month + 1, 0);
        widget.onConfirm(DateTimeRange(start: start, end: end));
      }
    }
  }

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

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

          Row(
            children: [
              Icon(Icons.date_range_outlined, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pilih Periode Laporan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _mode == _PickerMode.tanggal
                ? 'Ketuk tanggal mulai, lalu tanggal akhir'
                : 'Ketuk bulan mulai, lalu bulan akhir',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          const SizedBox(height: 16),

          _buildModeToggle(theme, primary),
          const SizedBox(height: 16),

          if (_mode == _PickerMode.tanggal)
            _buildDateCalendar(theme, primary, isDark)
          else
            _buildMonthGrid(theme, primary, isDark),

          const SizedBox(height: 14),

          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _hasStarted ? primary.withOpacity(0.07) : theme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hasStarted
                    ? primary.withOpacity(0.25)
                    : theme.dividerColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: _hasStarted ? primary : theme.hintColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rangePreviewText(),
                    style: TextStyle(
                      color: _hasStarted ? primary : theme.hintColor,
                      fontWeight: _hasStarted
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
                  onPressed: _canConfirm ? _confirm : null,
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
                    _canConfirm
                        ? 'Gunakan Rentang Ini'
                        : (_mode == _PickerMode.tanggal
                              ? 'Pilih Tanggal'
                              : 'Pilih Bulan'),
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

  // ════════════════════════════════════════════════════════
  // WIDGET: Toggle Mode
  // ════════════════════════════════════════════════════════
  Widget _buildModeToggle(ThemeData theme, Color primary) {
    Widget seg(String label, _PickerMode value, IconData icon) {
      final bool selected = _mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : theme.hintColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          seg(
            'Per Tanggal',
            _PickerMode.tanggal,
            Icons.calendar_view_day_rounded,
          ),
          seg(
            'Per Bulan',
            _PickerMode.bulan,
            Icons.calendar_view_month_rounded,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // WIDGET: Kalender harian (mode "Per Tanggal")
  // ════════════════════════════════════════════════════════
  Widget _buildDateCalendar(ThemeData theme, Color primary, bool isDark) {
    final now = DateTime.now();
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final totalDays = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final startWeekday = (firstDay.weekday - 1) % 7;

    return Column(
      children: [
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
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

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
            if (isSelected) {
              bgColor = primary;
            } else if (inRange) {
              bgColor = primary.withOpacity(0.12);
            }

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
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // WIDGET: Grid bulan (mode "Per Bulan")
  // ════════════════════════════════════════════════════════
  Widget _buildMonthGrid(ThemeData theme, Color primary, bool isDark) {
    final now = DateTime.now();

    return Column(
      children: [
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
                onPressed: () => setState(() => _viewYear--),
                icon: Icon(Icons.chevron_left_rounded, color: primary),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_viewYear',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _viewYear++),
                icon: Icon(Icons.chevron_right_rounded, color: primary),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 12,
          itemBuilder: (_, index) {
            final monthNumber = index + 1;
            final date = DateTime(_viewYear, monthNumber, 1);
            final isStart = _isMonthStart(date);
            final isEnd = _isMonthEnd(date);
            final inRange = _isMonthInRange(date);
            final isSelected = isStart || isEnd;
            final isCurrentMonth =
                date.year == now.year && date.month == now.month;

            Color? bgColor;
            if (isSelected) {
              bgColor = primary;
            } else if (inRange) {
              bgColor = primary.withOpacity(0.12);
            }

            Color textColor;
            if (isSelected) {
              textColor = Colors.white;
            } else if (isDark) {
              textColor = Colors.white70;
            } else {
              textColor = Colors.black87;
            }

            return GestureDetector(
              onTap: () => _onMonthTap(monthNumber),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: isCurrentMonth && !isSelected
                      ? Border.all(color: primary.withOpacity(0.5), width: 1)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _monthLabels[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected || isCurrentMonth
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
