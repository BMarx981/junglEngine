import 'package:flutter/material.dart';

/// junglEngine's look: near black, one acid accent, nothing decorative.
///
/// Phone first and high contrast, because this gets used in the dark with one
/// thumb. There is no theming feature and there is not going to be one.
class JungleTheme {
  const JungleTheme._();

  static const Color background = Color(0xFF0A0C0A);
  static const Color surface = Color(0xFF141814);
  static const Color surfaceHigh = Color(0xFF1F251F);
  static const Color line = Color(0xFF2C332C);

  /// Slices on the grid.
  static const Color accent = Color(0xFFC8FF3C);

  /// The sub lane.
  static const Color sub = Color(0xFF3CE0FF);

  /// Scramble, and anything else that changes a lot of music at once.
  static const Color hot = Color(0xFFFF5C3C);

  static const Color text = Color(0xFFE4EDE2);
  static const Color textDim = Color(0xFF7E8A7C);

  /// Row tints from slice analysis, so the grid reads at a glance.
  static const Color kickTint = Color(0xFFFF9E3C);
  static const Color snareTint = Color(0xFFC8FF3C);
  static const Color ghostTint = Color(0xFF5F6B5E);

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF0A0C0A),
      secondary: sub,
      surface: surface,
      onSurface: text,
      error: hot,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: NoSplash.splashFactory,
      fontFamily: 'monospace',
      textTheme: const TextTheme(
        labelSmall: TextStyle(
          color: textDim,
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          color: text,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: line,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: text, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
