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
