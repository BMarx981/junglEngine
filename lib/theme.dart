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

  /// The big numbers: tempo, swing, volume, pitch, bar and slice counts.
  ///
  /// These are the only places monospace earns itself, and they are ASCII in
  /// every locale by policy, so the mono face is never asked for a script it
  /// cannot draw. Tabular figures stop the digits jittering as they count.
  static TextStyle readout({
    required double fontSize,
    required Color color,
    double height = 1.05,
  }) => TextStyle(
    color: color,
    fontSize: fontSize,
    height: height,
    fontFamily: 'monospace',
    fontWeight: FontWeight.w700,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Tracking is part of the look, but it is not safe everywhere.
  ///
  /// Arabic is cursive: prising the letters apart stops them joining and the
  /// word stops being a word. CJK glyphs are already on a square body and
  /// tracking only steals width from a phone that has none. Both get dialled
  /// back rather than switched off, so the type still feels like this app.
  static double _tracking(Locale locale, double wide) =>
      switch (locale.languageCode) {
        'ar' => 0,
        'ja' || 'ko' || 'zh' => wide / 2,
        _ => wide,
      };

  static ThemeData build(Locale locale) {
    final wide = _tracking(locale, 1.4);
    final medium = _tracking(locale, 1.2);
    final tight = _tracking(locale, 0.5);

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
      // No app wide monospace. It used to be set here, which meant every
      // translated label was asking a mono face for Arabic and CJK coverage it
      // does not have. Monospace is what the numeric readouts want, and only
      // them: see [readout].
      textTheme: TextTheme(
        labelSmall: TextStyle(
          color: textDim,
          fontSize: 10,
          letterSpacing: wide,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          color: text,
          fontSize: 12,
          letterSpacing: medium,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: tight,
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
