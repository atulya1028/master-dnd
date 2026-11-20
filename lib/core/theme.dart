import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Text styles map 1:1 to the Figma text styles:
/// Display -> displayLarge, Title -> titleLarge, Heading -> titleMedium,
/// Body/L -> bodyLarge, Body/M -> bodyMedium, Label -> labelLarge,
/// Caption -> bodySmall, Overline -> labelSmall (rendered uppercase by [OverlineText]).
TextTheme _textTheme(DndColors c) {
  TextStyle head(double size, double lh, FontWeight w) => GoogleFonts.plusJakartaSans(
      fontSize: size, height: lh / size, fontWeight: w, color: c.textPrimary);
  TextStyle body(double size, double lh, FontWeight w, [Color? color]) => GoogleFonts.inter(
      fontSize: size, height: lh / size, fontWeight: w, color: color ?? c.textPrimary);

  return TextTheme(
    displayLarge: head(32, 40, FontWeight.w700),
    titleLarge: head(22, 28, FontWeight.w700),
    titleMedium: head(18, 24, FontWeight.w600),
    bodyLarge: body(16, 24, FontWeight.w400),
    bodyMedium: body(14, 20, FontWeight.w400),
    labelLarge: body(14, 20, FontWeight.w600),
    bodySmall: body(12, 16, FontWeight.w400, c.textSecondary),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      height: 16 / 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.88, // 8%
      color: c.textSecondary,
    ),
  );
}

ThemeData buildTheme(DndColors c, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3F51B5),
    brightness: brightness,
  ).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    surface: c.surface,
    onSurface: c.textPrimary,
    error: c.critical,
    outline: c.border,
    secondaryContainer: c.accentTint,
    onSecondaryContainer: c.accent,
  );
  final text = _textTheme(c);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.canvas,
    textTheme: text,
    extensions: <ThemeExtension<dynamic>>[c],
    dividerColor: c.border,
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceAlt),
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textSecondary),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.border),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.accentTint,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? c.accent : c.textSecondary,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => text.bodySmall!.copyWith(
            color: s.contains(WidgetState.selected) ? c.accent : c.textSecondary,
          )),
    ),
  );
}

final ThemeData dayTheme = buildTheme(DndColors.day, Brightness.light);
final ThemeData nightTheme = buildTheme(DndColors.night, Brightness.dark);
