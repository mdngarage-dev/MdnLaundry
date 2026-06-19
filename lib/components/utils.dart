// utils.dart
import 'package:intl/intl.dart';

String formatRupiah(dynamic val) {
  try {
    final n = val is num ? val.toInt() : int.parse(val.toString());
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(n);
  } catch (_) {
    return 'Rp $val';
  }
}
