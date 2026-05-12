import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

final appDarkTheme = buildDarkTheme();
final appLightTheme = buildLightTheme();

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kColorOrange,
      brightness: Brightness.dark,
      primary: kColorOrange,
    ),
  );

  final scheme = base.colorScheme.copyWith(
    primary: kColorOrange,
    secondary: kColorCream,
    surface: kColorBg,
    surfaceContainerHighest: const Color(0xFF1A1A1A),
    onPrimary: Colors.white,
    onSecondary: kColorBg,
    onSurface: kColorCream,
    outline: kColorBorder,
  );

  return base.copyWith(
    scaffoldBackgroundColor: kColorBg,
    colorScheme: scheme,
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: kColorCream,
      displayColor: kColorCream,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kColorBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.outfit(
        color: kColorCream,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: kColorCream),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF111111),
      indicatorColor: kColorOrange.withOpacity(0.18),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? kColorOrange : kColorCream.withOpacity(0.6),
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.outfit(
          color: selected ? kColorOrange : kColorCream.withOpacity(0.6),
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kColorOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kColorOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? kColorOrange.withOpacity(0.18)
              : Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? kColorOrange
              : kColorCream.withOpacity(0.7);
        }),
        side: const WidgetStatePropertyAll(BorderSide(color: kColorBorder)),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorOrange, width: 1.5),
      ),
      labelStyle: const TextStyle(color: kColorCream),
      hintStyle: TextStyle(color: kColorCream.withOpacity(0.35)),
    ),
    dividerColor: kColorBorder,
    cardColor: kColorPanel,
    cardTheme: const CardTheme(
      color: kColorPanel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: kColorBorder),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      titleTextStyle: GoogleFonts.outfit(
        color: kColorCream,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: GoogleFonts.outfit(
        color: kColorCream.withOpacity(0.7),
        fontSize: 13,
        height: 1.5,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      contentTextStyle: GoogleFonts.outfit(color: kColorCream, fontSize: 13),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: kColorOrange.withOpacity(0.2),
      disabledColor: Colors.transparent,
      side: const BorderSide(color: kColorBorder),
      labelStyle: GoogleFonts.outfit(fontSize: 11),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
  );
}

ThemeData buildLightTheme() {
  const orangeColor = Color(0xFFE8541A);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: orangeColor,
      brightness: Brightness.light,
      primary: orangeColor,
    ),
  );

  final scheme = base.colorScheme.copyWith(
    primary: orangeColor,
    secondary: const Color(0xFF5D4037),
    surface: const Color(0xFFF7F5F2),
    surfaceContainerHighest: const Color(0xFFECE9E4),
    onPrimary: Colors.white,
    onSurface: const Color(0xFF1A1207),
    outline: const Color(0xFFD4CCBC),
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF7F5F2),
    colorScheme: scheme,
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF7F5F2),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.outfit(
        color: const Color(0xFF1A1207),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1A1207)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFF7F5F2),
      indicatorColor: orangeColor.withOpacity(0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? orangeColor : const Color(0xFF5D4037),
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.outfit(
          color: selected ? orangeColor : const Color(0xFF5D4037),
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: orangeColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: orangeColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? orangeColor.withOpacity(0.14)
              : Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? orangeColor
              : const Color(0xFF5D4037);
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: Color(0xFFD4CCBC)),
        ),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    cardTheme: CardTheme(
      color: const Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4CCBC)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.outfit(
        color: const Color(0xFF1A1207),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: GoogleFonts.outfit(
        color: const Color(0xFF5D4037),
        fontSize: 13,
        height: 1.5,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      contentTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
