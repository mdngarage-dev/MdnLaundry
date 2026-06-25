export 'package:mdnlaundry_project/getstarted.dart';
export 'package:mdnlaundry_project/signin.dart';
export 'package:mdnlaundry_project/signup.dart';

export 'package:mdnlaundry_project/components/navbar.dart';
export 'package:mdnlaundry_project/components/button_bawah.dart';
export 'package:mdnlaundry_project/components/theme.dart';
export 'package:mdnlaundry_project/components/global_refresh.dart';
export 'package:mdnlaundry_project/components/date_range_picker_widget.dart';
export 'package:mdnlaundry_project/components/thermal_printer_service.dart';

export 'package:mdnlaundry_project/screens/profile_screen.dart';
export 'package:mdnlaundry_project/screens/add.dart';
export 'package:mdnlaundry_project/screens/order/order.dart';
export 'package:mdnlaundry_project/screens/home_wrapper.dart';
export 'package:mdnlaundry_project/screens/home_screen.dart';
export 'package:mdnlaundry_project/screens/notifikasi.dart';
export 'package:mdnlaundry_project/screens/print_screen.dart';

export 'package:mdnlaundry_project/screens/laporan/laporan_harian.dart';
export 'package:mdnlaundry_project/screens/laporan/list_pengeluaran.dart';
export 'package:mdnlaundry_project/screens/laporan/laporan_order.dart';
export 'package:mdnlaundry_project/screens/laporan/analisis_pelanggan.dart';
export 'package:mdnlaundry_project/screens/laporan/kinerja_pegawai.dart';
export 'package:mdnlaundry_project/screens/laporan/main_laporan.dart';
export 'package:mdnlaundry_project/screens/laporan/form_pengeluaran_page.dart';
export 'package:mdnlaundry_project/screens/laporan/ringkasan_outlet.dart';

export 'package:mdnlaundry_project/screens/settings/main_setting.dart';
export 'package:mdnlaundry_project/screens/settings/password.dart';
export 'package:mdnlaundry_project/screens/settings/akun_keamanan.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/kelola_outlet.dart';
export 'package:mdnlaundry_project/screens/settings/about.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/wa_settings.dart';
export 'package:mdnlaundry_project/screens/settings/theme_provider.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/rak_monitoring.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/layanan.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/daftar_pelanggan.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/printer_setting.dart';
export 'package:mdnlaundry_project/screens/settings/outlet_setting.dart';
export 'package:mdnlaundry_project/screens/settings/outlet/list_admin.dart';

export 'package:mdnlaundry_project/screens/order/order_detail.dart';

export 'package:google_fonts/google_fonts.dart';
export 'dart:convert';
export 'package:firebase_auth/firebase_auth.dart';
export 'package:intl/intl.dart';
export 'printer_dialog.dart';
export 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class OutletSettings {
  static String namaLaundry = "Laundry Ku";
  static String noHpLaundry = "0816829052";
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
