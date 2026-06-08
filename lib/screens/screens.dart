export 'getstarted.dart';
export 'signin.dart';
export 'signup.dart';
export 'navbar.dart';
export 'button_bawah.dart';
export 'theme.dart';
export 'package:mdnlaundry_project/profile_screen.dart';
export 'package:google_fonts/google_fonts.dart';
export 'add.dart';
export 'order.dart';
export 'home_wrapper.dart';
export 'home_screen.dart';
export 'package:firebase_auth/firebase_auth.dart';
export 'package:intl/intl.dart';
export 'printer_dialog.dart';
export '../thermal_printer_service.dart';
export 'package:blue_thermal_printer/blue_thermal_printer.dart';
export 'print_screen.dart';
export '../laporan/harian.dart';
export '../laporan/list_pengeluaran.dart';
export '../laporan/laporan_order.dart';
export '../laporan/analisis_pelanggan.dart';
export '../laporan/kinerja_pegawai.dart';
export 'notifikasi.dart';

export 'setting.dart';
export '../settings/password.dart';
export '../settings/profile.dart';
export '../settings/outlet.dart';
export '../settings/about.dart';
export '../settings/theme_provider.dart';
export '../laporan/main.dart';
export '../laporan/form_pengeluaran_page.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/layanan.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/daftar_pelanggan.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/printer_setting.dart';

export 'package:mdnlaundry_project/screens/settings/outlet/main.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/admin.dart';

export 'package:mdnlaundry_project/components/global_refresh.dart';
export 'package:mdnlaundry_project/laporan/ringkasan.dart';
export 'package:mdnlaundry_project/laporan/date_range_picker_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class OutletSettings {
  static String namaMadeenalaundry = "Rdh project";
  static String noHpMadeenalaundry = "0816829052";
  static String alamat = "Jl. Raya Puncak Km.78";
  static String logoPath = ""; // path file logo lokal, kosong = icon default
}

class AppConfig {
  static String appVersion = '';
  static String buildNumber = '';

  static Future<void> init() async {
    if (kIsWeb) {
      // ✅ Web: hardcode manual karena package_info_plus
      // tidak bisa baca pubspec.yaml di web
      appVersion = '1.0.4';
      buildNumber = '2';
    } else {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    }
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;

    // Hanya ambil angka
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    double value = double.parse(cleanText);
    final formatter = NumberFormat.decimalPattern(
      'id',
    ); // Format Indonesia (titik)
    String newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    double value = double.parse(newText) / 100;
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 2,
    );
    String formatted = formatter.format(value).trim();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global Role & Permission Helpers
// ─────────────────────────────────────────────────────────────────────────────

String getUserRole() {
  final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
  final parts = displayName.split('|');
  return parts.length >= 3 ? parts[2] : 'Admin';
}

Future<bool> canAccess(String key, {bool ownerOnly = false}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final role = getUserRole();

  // Khusus Admin saja (Owner tidak tampil)
  if (ownerOnly) return role == 'Admin';

  // Owner selalu bisa
  if (role == 'Owner') return true;

  // Admin — cek Firestore
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?[key] ?? false;
  } catch (e) {
    return false;
  }
}
