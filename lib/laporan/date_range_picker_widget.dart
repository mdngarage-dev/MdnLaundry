import 'package:flutter/material.dart';

class CalendarHelper {
  static Future<DateTimeRange?> showFullDatePicker(BuildContext context) async {
    // ✅ Cukup pakai theme yang sudah ada, tidak perlu override manual lagi
    // surfaceContainerHighest & onSurfaceVariant di theme sudah fix bug start date
    return await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select range',
      saveText: 'Save',
      builder: (context, child) {
        // ✅ Hanya perlu pass Theme.of(context) langsung — semua warna sudah defined
        return Theme(data: Theme.of(context), child: child!);
      },
    );
  }
}
