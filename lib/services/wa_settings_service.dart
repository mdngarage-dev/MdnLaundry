import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  WA SETTINGS HELPER — pakai mode: 'off' | 'manual' | 'auto'
// ══════════════════════════════════════════════════════════════════════════════
class WaSettings {
  static const _keyMode = 'wa_mode';
  static const _keyToken = 'wa_fonnte_token';
  static const _keyFooter = 'wa_footer';
  static const _keyFooterEnabled = 'wa_footer_enabled'; //

  static const String defaultFooter =
      'Powered By : Madeena Laundry x Rdh Project';

  static Future<String> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMode) ?? 'manual';
  }

  static Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode);
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken) ?? '';
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  // ── Footer enabled/disabled
  static Future<bool> isFooterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFooterEnabled) ?? true; // default: aktif
  }

  static Future<void> setFooterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFooterEnabled, enabled);
  }

  // ── getFooter() sekarang cek toggle dulu
  static Future<String> getFooter() async {
    final enabled = await isFooterEnabled();
    if (!enabled) return ''; // OFF = total tidak ada footer

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyFooter);
    return (saved == null || saved.trim().isEmpty) ? defaultFooter : saved;
  }

  static Future<void> setFooter(String footer) async {
    final prefs = await SharedPreferences.getInstance();
    if (footer.trim().isEmpty) {
      await prefs.remove(_keyFooter);
    } else {
      await prefs.setString(_keyFooter, footer.trim());
    }
  }

  static Future<bool> isOff() async => (await getMode()) == 'off';
  static Future<bool> isManual() async => (await getMode()) == 'manual';
  static Future<bool> isAuto() async => (await getMode()) == 'auto';
}
