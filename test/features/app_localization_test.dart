import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/app.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

import '../support/fake_engine.dart';
import '../support/fake_pro_store.dart';

/// The real [JungleApp], rather than a MaterialApp assembled by a test.
///
/// Everything localization depends on is wired inside that widget: the delegate
/// list, the locale aware theme and the title. The rest of the suite builds its
/// own MaterialApp around StudioScreen, which means none of that wiring was
/// covered by anything until this file.
Future<void> _pumpApp(WidgetTester tester) async {
  final tempDir = Directory.systemTemp.createTempSync('junglengine-app');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path,
      );
  addTearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(FakeAudioEngine()),
        proStoreProvider.overrideWithValue(FakeProStore()),
      ],
      child: const JungleApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the app declares all twelve locales', (tester) async {
    await _pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales.map((l) => l.languageCode).toSet(), {
      'en',
      'ar',
      'es',
      'fil',
      'fr',
      'ht',
      'ja',
      'ko',
      'pt',
      'ru',
      'vi',
      'zh',
    });
    // No picker, and no forced locale in a normal run: the system decides.
    expect(app.locale, isNull);
  });

  testWidgets('every declared locale resolves, Haitian Creole included', (
    tester,
  ) async {
    await _pumpApp(tester);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    for (final locale in app.supportedLocales) {
      // Flutter ships no Haitian Creole, so without the fallback delegates the
      // framework's own strings would go unresolved here and the app would
      // warn on every launch in that locale.
      for (final type in [
        MaterialLocalizations,
        CupertinoLocalizations,
        WidgetsLocalizations,
      ]) {
        expect(
          app.localizationsDelegates!.any(
            (d) => d.type == type && d.isSupported(locale),
          ),
          isTrue,
          reason: 'no $type for ${locale.languageCode}',
        );
      }
    }
  });

  test('Arabic drops the letter spacing that breaks its joins', () {
    double tracking(String code) =>
        JungleTheme.build(Locale(code)).textTheme.labelSmall!.letterSpacing!;

    // Spacing out a cursive script stops the letters joining, so Arabic gets
    // none of it. CJK is on a square body and only loses width to tracking.
    expect(tracking('ar'), 0);
    expect(tracking('ja'), lessThan(tracking('en')));
    expect(tracking('ko'), lessThan(tracking('en')));
    expect(tracking('zh'), lessThan(tracking('en')));
    // Everything else keeps the look the app was designed with.
    expect(tracking('fr'), tracking('en'));
    expect(tracking('en'), greaterThan(0));
  });

  test('monospace is only on the numeric readouts', () {
    // A mono face has no Arabic or CJK coverage, so it must never be the
    // default. It stays where the text is ASCII by policy.
    expect(
      JungleTheme.build(const Locale('en')).textTheme.labelSmall!.fontFamily,
      isNot('monospace'),
    );
    expect(
      JungleTheme.readout(fontSize: 26, color: JungleTheme.text).fontFamily,
      'monospace',
    );
  });
}
