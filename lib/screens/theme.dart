import 'package:flutter/material.dart';

// ─── Warna Utama ──────────────────────────────────────────────────────────────
const Color kPrimary = Color(
  0xFF5B9BD5,
); // Blue utama (lebih dalam agar readable)
const Color kPrimaryLight = Color(0xFFF0F6FC); // Background sangat terang
const Color kPrimaryMid = Color(0xFFDCEEF9); // Divider / highlight ringan
const Color kAccentBlue = Color(0xFF8BC3E6); // Accent / Light blue dari foto
const Color kPastelBlue = Color(0xFFA7C6ED); // Pastel blue primer dari foto
const Color kTextDark = Color(0xFF1E293B);
const Color kTextLight = Color(0xFF64748B);
const Color kWhite = Colors.white;
const Color kCardWhite = Color(0xFFFFFFFF);
const Color kAccentSuccess = Color(0xFF10B981);
const Color kAccentWarning = Color(0xFFF59E0B);

// ─── InputDecoration Global ───────────────────────────────────────────────────
InputDecoration customInputDecoration({
  required BuildContext context,
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
    prefixIcon: Icon(
      icon,
      color: isDark ? Colors.white70 : kTextLight,
      size: 20,
    ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: isDark ? Colors.white.withOpacity(0.08) : kCardWhite,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? Colors.white24 : const Color(0xFFD4E6F5),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
  );
}

// ─── Button Styles ────────────────────────────────────────────────────────────
ButtonStyle primaryButtonStyle({bool isEnabled = true}) {
  return ElevatedButton.styleFrom(
    backgroundColor: kPrimary,
    foregroundColor: kWhite,
    disabledBackgroundColor: kPrimary.withOpacity(0.45),
    disabledForegroundColor: kWhite.withOpacity(0.6),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    minimumSize: const Size(double.infinity, 55),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 15,
      letterSpacing: 0.3,
    ),
  );
}

ButtonStyle secondaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: kPrimary,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
      side: const BorderSide(color: kPrimary),
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}

ButtonStyle textLinkButtonStyle() {
  return TextButton.styleFrom(
    foregroundColor: kPrimary,
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
  );
}

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: kCardWhite,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: kPastelBlue.withOpacity(0.18),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ─── LIGHT THEME ──────────────────────────────────────────────────────────────
ThemeData lightTheme({Color seed = kPrimary}) {
  return ThemeData(
    brightness: Brightness.light,
    primaryColor: seed,
    scaffoldBackgroundColor: kPrimaryLight,
    cardColor: kCardWhite,
    canvasColor: kCardWhite,
    hintColor: kTextLight,

    colorScheme: ColorScheme.light(
      primary: seed,
      secondary: kAccentBlue,
      surface: kCardWhite,
      onPrimary: Colors.white,
      onSurface: kTextDark,
      outline: const Color(0xFFD4E6F5),
      surfaceContainerHighest: const Color(0xFFE8F4FC),
      onSurfaceVariant: kTextLight,
      tertiary: const Color(0xFF2E86C1),
      onTertiary: Colors.white,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: seed,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),

    iconTheme: const IconThemeData(color: kTextLight),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: kCardWhite,
      selectedItemColor: seed,
      unselectedItemColor: kTextLight,
      elevation: 8,
    ),

    dividerColor: const Color(0xFFD4E6F5),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: kTextDark),
      displayMedium: TextStyle(color: kTextDark),
      displaySmall: TextStyle(color: kTextDark),
      headlineLarge: TextStyle(color: kTextDark),
      headlineMedium: TextStyle(color: kTextDark),
      headlineSmall: TextStyle(color: kTextDark),
      titleLarge: TextStyle(color: kTextDark),
      titleMedium: TextStyle(color: kTextDark),
      titleSmall: TextStyle(color: kTextLight),
      bodyLarge: TextStyle(color: kTextDark, fontSize: 14),
      bodyMedium: TextStyle(color: kTextLight),
      bodySmall: TextStyle(color: kTextLight, fontSize: 12),
      labelLarge: TextStyle(color: kTextDark),
      labelMedium: TextStyle(color: kTextLight),
      labelSmall: TextStyle(color: kTextLight),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardWhite,
      hintStyle: const TextStyle(color: kTextLight, fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD4E6F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: seed, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? seed : Colors.grey[400],
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? seed.withOpacity(0.4)
            : Colors.grey[300],
      ),
    ),

    cardTheme: CardThemeData(
      color: kCardWhite,
      elevation: 2,
      shadowColor: const Color(0x1A5B9BD5),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: seed.withOpacity(0.15)),
      ),
    ),

    dialogTheme: const DialogThemeData(backgroundColor: kCardWhite),
  );
}

// ─── Helper Blend Warna untuk Dark Theme ──────────────────────────────────────
// Mencampur warna seed dengan base navy gelap supaya appbar/background
// dark mode ikut "tint" sesuai warna pilihan, tapi tetap gelap & readable.
Color _blendDark(Color base, Color seed, double amount) {
  return Color.lerp(base, seed, amount)!;
}

// ─── DARK THEME ───────────────────────────────────────────────────────────────
ThemeData darkTheme({Color seed = kPastelBlue}) {
  const Color darkBase = Color(0xFF0D1B2A);
  const Color darkSurfaceBase = Color(0xFF152232);
  const Color darkCardBase = Color(0xFF1C2E40);

  // Tint ringan dari seed dicampur ke base navy.
  // amount kecil agar tetap gelap & nyaman dibaca, tapi terasa nuansanya.
  final Color darkBaseTinted = _blendDark(darkBase, seed, 0.12);
  final Color darkSurface = _blendDark(darkSurfaceBase, seed, 0.16);
  final Color darkCard = _blendDark(darkCardBase, seed, 0.14);

  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: seed,
    scaffoldBackgroundColor: darkBaseTinted,
    cardColor: darkCard,
    canvasColor: darkSurface,
    hintColor: Colors.white38,

    colorScheme: ColorScheme.dark(
      primary: seed,
      secondary: kAccentBlue,
      surface: darkSurface,
      onPrimary: const Color(0xFF1E293B),
      onSurface: Colors.white,
      outline: const Color(0xFF2A4A65),
      surfaceContainerHighest: const Color(0xFF1F3A52),
      onSurfaceVariant: Colors.white70,
      tertiary: const Color(0xFF8BC3E6),
      onTertiary: const Color(0xFF0D1B2A),
    ),

    // Appbar ikut tint seed
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),

    iconTheme: const IconThemeData(color: Colors.white70),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: seed,
      unselectedItemColor: Colors.white54,
    ),

    dividerColor: Colors.white12,

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white),
      displayMedium: TextStyle(color: Colors.white),
      displaySmall: TextStyle(color: Colors.white),
      headlineLarge: TextStyle(color: Colors.white),
      headlineMedium: TextStyle(color: Colors.white),
      headlineSmall: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Colors.white70),
      bodyLarge: TextStyle(color: Colors.white, fontSize: 14),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white54, fontSize: 12),
      labelLarge: TextStyle(color: Colors.white),
      labelMedium: TextStyle(color: Colors.white70),
      labelSmall: TextStyle(color: Colors.white54),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      hintStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: seed, width: 2),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: seed,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? seed : Colors.white54,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? seed.withOpacity(0.4)
            : Colors.white24,
      ),
    ),

    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 4,
      shadowColor: const Color(0x805B9BD5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),

    dialogTheme: DialogThemeData(backgroundColor: darkSurface),
  );
}
