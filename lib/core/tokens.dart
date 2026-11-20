import 'package:flutter/material.dart';

/// Colour tokens. Names match the Figma variables "Colors Day" / "Colors Night".
@immutable
class DndColors extends ThemeExtension<DndColors> {
  const DndColors({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.onAccent,
    required this.accent,
    required this.accentTint,
    required this.armed,
    required this.warning,
    required this.warningTint,
    required this.critical,
  });

  final Color canvas; // bg/canvas
  final Color surface; // bg/surface
  final Color surfaceAlt; // bg/surface-alt
  final Color border; // border/default
  final Color textPrimary; // text/primary
  final Color textSecondary; // text/secondary
  final Color onAccent; // text/on-accent
  final Color accent; // accent/primary
  final Color accentTint; // accent/primary-tint
  final Color armed; // status/armed
  final Color warning; // status/warning
  final Color warningTint; // status/warning-tint
  final Color critical; // status/critical

  static const day = DndColors(
    canvas: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF0F8),
    border: Color(0xFFE1E4F0),
    textPrimary: Color(0xFF14172F),
    textSecondary: Color(0xFF5B6085),
    onAccent: Color(0xFFFFFFFF),
    accent: Color(0xFF3F51B5),
    accentTint: Color(0xFFE8EBFA),
    armed: Color(0xFF00897B),
    warning: Color(0xFFB26A00),
    warningTint: Color(0xFFFFF4D6),
    critical: Color(0xFFD32F2F),
  );

  static const night = DndColors(
    canvas: Color(0xFF0F1226),
    surface: Color(0xFF1B1F3B),
    surfaceAlt: Color(0xFF252A4D),
    border: Color(0xFF343A66),
    textPrimary: Color(0xFFF3F4FF),
    textSecondary: Color(0xFFA8ADD6),
    onAccent: Color(0xFF0F1226),
    accent: Color(0xFF8C9EFF),
    accentTint: Color(0xFF2B3366),
    armed: Color(0xFF4DB6AC),
    warning: Color(0xFFFFCA28),
    warningTint: Color(0xFF3A3010),
    critical: Color(0xFFEF5350),
  );

  @override
  DndColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? onAccent,
    Color? accent,
    Color? accentTint,
    Color? armed,
    Color? warning,
    Color? warningTint,
    Color? critical,
  }) {
    return DndColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onAccent: onAccent ?? this.onAccent,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      armed: armed ?? this.armed,
      warning: warning ?? this.warning,
      warningTint: warningTint ?? this.warningTint,
      critical: critical ?? this.critical,
    );
  }

  @override
  DndColors lerp(ThemeExtension<DndColors>? other, double t) {
    if (other is! DndColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return DndColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      onAccent: l(onAccent, other.onAccent),
      accent: l(accent, other.accent),
      accentTint: l(accentTint, other.accentTint),
      armed: l(armed, other.armed),
      warning: l(warning, other.warning),
      warningTint: l(warningTint, other.warningTint),
      critical: l(critical, other.critical),
    );
  }
}

/// Shape tokens: radius/input, radius/card, radius/pill.
abstract final class Radii {
  static const double input = 12;
  static const double card = 16;
  static const double pill = 999;
}

/// Spacing tokens: space/4 ... space/32.
abstract final class Space {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
}

extension DndContext on BuildContext {
  DndColors get dnd => Theme.of(this).extension<DndColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
