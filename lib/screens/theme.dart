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
ThemeData lightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    primaryColor: kPrimary,
    scaffoldBackgroundColor: kPrimaryLight,
    cardColor: kCardWhite,
    canvasColor: kCardWhite,
    hintColor: kTextLight,

    colorScheme: const ColorScheme.light(
      primary: kPrimary,
      secondary: kAccentBlue,
      surface: kCardWhite,
      onPrimary: Colors.white,
      onSurface: kTextDark,
      // Border & divider
      outline: Color(0xFFD4E6F5),
      // Highlight range selection (date picker)
      surfaceContainerHighest: Color(0xFFE8F4FC),
      onSurfaceVariant: kTextLight,
      // Badge/chip warna biru lebih dalam
      tertiary: Color(0xFF2E86C1),
      onTertiary: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),

    iconTheme: const IconThemeData(color: kTextLight),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kCardWhite,
      selectedItemColor: kPrimary,
      unselectedItemColor: kTextLight,
      elevation: 8,
    ),

    dividerColor: Color(0xFFD4E6F5),

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
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kPrimary : Colors.grey[400],
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? kPrimary.withOpacity(0.4)
            : Colors.grey[300],
      ),
    ),

    cardTheme: const CardThemeData(
      color: kCardWhite,
      elevation: 2,
      shadowColor: Color(0x1A5B9BD5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: Color(0x26A7C6ED)),
      ),
    ),

    dialogTheme: const DialogThemeData(backgroundColor: kCardWhite),
  );
}

// ─── DARK THEME ───────────────────────────────────────────────────────────────
ThemeData darkTheme() {
  const Color darkBase = Color(0xFF0D1B2A); // Deep navy base
  const Color darkSurface = Color(0xFF152232); // Navy surface
  const Color darkCard = Color(0xFF1C2E40); // Sedikit lebih terang dari surface

  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: kPastelBlue, // Pastel blue cocok di dark mode
    scaffoldBackgroundColor: darkBase,
    cardColor: darkCard,
    canvasColor: darkSurface,
    hintColor: Colors.white38,

    colorScheme: const ColorScheme.dark(
      primary: kPastelBlue,
      secondary: kAccentBlue,
      surface: darkSurface,
      onPrimary: Color(0xFF1E293B), // Teks gelap di atas warna pastel
      onSurface: Colors.white,
      // Border & divider
      outline: Color(0xFF2A4A65),
      // FIX: date picker range highlight
      surfaceContainerHighest: Color(0xFF1F3A52),
      onSurfaceVariant: Colors.white70,
      // Badge/chip
      tertiary: Color(0xFF8BC3E6),
      onTertiary: Color(0xFF0D1B2A),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),

    iconTheme: const IconThemeData(color: Colors.white70),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: kPastelBlue,
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
        borderSide: const BorderSide(color: kPastelBlue, width: 2),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPastelBlue,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kPastelBlue : Colors.white54,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? kPastelBlue.withOpacity(0.4)
            : Colors.white24,
      ),
    ),

    cardTheme: const CardThemeData(
      color: darkCard,
      elevation: 4,
      shadowColor: Color(0x805B9BD5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),

    dialogTheme: const DialogThemeData(backgroundColor: darkSurface),
  );
}
