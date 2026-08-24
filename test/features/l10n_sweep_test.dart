import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/features/bass/sub_editor.dart';
import 'package:junglengine/features/bass/sub_lane_view.dart';
import 'package:junglengine/features/bass/sub_panel.dart';
import 'package:junglengine/features/export/export_sheet.dart';
import 'package:junglengine/features/grid/chop_grid.dart';
import 'package:junglengine/features/song/beat_bar.dart';
import 'package:junglengine/features/song/new_beat_sheet.dart';
import 'package:junglengine/features/studio_screen.dart';
import 'package:junglengine/features/transport/action_bar.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

import '../support/fake_engine.dart';
import '../support/fake_pro_store.dart';

/// Every locale, on the phones that will hurt most.
///
/// The point is not to check the translations, which no test can do. It is to
/// catch the thing that actually breaks when an app written in terse English
/// gets translated: a label that was six characters becomes eighteen and blows
/// its row apart. A `RenderFlex overflowed` is a real bug and this finds it.
///
/// What it cannot find: the test font has uniform glyph metrics and does no
/// Arabic shaping or CJK advance widths, so this measures *length* and not
/// *typography*. Wide CJK glyphs and Arabic ligatures still need eyes on a
/// device. See the JE_LOCALE override in `lib/app.dart` for that pass.

/// Each device carries its own pixel ratio, because the logical width is what
/// the layout actually sees and it does not follow from the pixel count. A
/// 1080 pixel Android panel is about 2.75, not 3, and guessing 3 invents a
/// 360dp phone that nobody sells.
const List<({String name, Size size, double ratio})> _phones = [
  (name: 'iPhone 13', size: Size(1170, 2532), ratio: 3), // 390dp
  (name: 'Pixel 7', size: Size(1080, 2400), ratio: 2.75), // 393dp
  (name: 'iPhone SE', size: Size(750, 1334), ratio: 2), // 375dp, the narrowest
];

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  ({String name, Size size, double ratio}) phone,
) async {
  final tempDir = Directory.systemTemp.createTempSync('junglengine-sweep');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path,
      );
  addTearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  tester.view.physicalSize = phone.size;
  tester.view.devicePixelRatio = phone.ratio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(FakeAudioEngine()),
        proStoreProvider.overrideWithValue(FakeProStore()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: junglengineLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: JungleTheme.build(locale),
        home: const StudioScreen(),
      ),
    ),
  );
  for (var i = 0; i < 40 && find.byType(ChopGrid).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Text that is wider than the box drawn for it.
///
/// `RenderFlex` reports its own overflows loudly, but a `Text` inside a fixed
/// `SizedBox` or `Container` just gets clipped in silence, and those are
/// exactly the tight chips this app is built out of.
Iterable<String> _clipped(WidgetTester tester, Finder scope) sync* {
  final paragraphs = find.descendant(
    of: scope,
    matching: find.byType(RichText),
  );
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    // A wrapping paragraph is doing what it was asked to. Only single line
    // text that does not fit is a layout failure.
    if (paragraph.size.height > paragraph.preferredLineHeight * 1.5) continue;
    final needed = paragraph.getMaxIntrinsicWidth(double.infinity);
    if (needed > paragraph.size.width + 0.5) {
      yield '"${paragraph.text.toPlainText()}" needs '
          '${needed.toStringAsFixed(1)}px in ${paragraph.size.width}px';
    }
  }
}

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    for (final phone in _phones) {
      final where = '${locale.languageCode} on ${phone.name}';

      testWidgets('the studio lays out in $where', (tester) async {
        await _pump(tester, locale, phone);

        // Any RenderFlex overflow anywhere on the main screen.
        expect(tester.takeException(), isNull, reason: 'overflow in $where');

        for (final bar in [find.byType(ActionBar), find.byType(BeatBar)]) {
          final clipped = _clipped(tester, bar).toList();
          expect(clipped, isEmpty, reason: 'clipped in $where: $clipped');
        }
      });

      testWidgets('the sheets lay out in $where', (tester) async {
        await _pump(tester, locale, phone);
        final l10n = await AppLocalizations.delegate.load(locale);

        // The new beat sheet: four length chips and two machine choices, all
        // in fixed height boxes.
        await tester.tap(
          find.descendant(
            of: find.byType(BeatBar),
            matching: find.text(l10n.beatBarNew),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'new beat in $where');
        final beatSheet = _clipped(tester, find.byType(NewBeatSheet)).toList();
        expect(beatSheet, isEmpty, reason: 'new beat in $where: $beatSheet');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // The export sheet: three mode chips sharing one row, each with a
        // label and a detail line under it.
        await tester.tap(
          find.descendant(
            of: find.byType(ActionBar),
            matching: find.text(l10n.actionExport),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'export in $where');
        final exportSheet = _clipped(tester, find.byType(ExportSheet)).toList();
        expect(exportSheet, isEmpty, reason: 'export in $where: $exportSheet');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // The sub note editor: a heading, a hint line and a footer of three
        // buttons sharing one phone width.
        await tester.tap(
          find.descendant(
            of: find.byType(SubLaneView),
            matching: find.text('SUB'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'sub editor in $where');
        final subEditor = _clipped(tester, find.byType(SubEditor)).toList();
        expect(subEditor, isEmpty, reason: 'sub editor in $where: $subEditor');
        // By its own button rather than by the scrim: this sheet is most of
        // the screen, and a scrim tap that quietly missed would leave every
        // assertion after it passing against a sheet that never opened.
        await tester.tap(
          find.descendant(
            of: find.byType(SubEditor),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SubEditor), findsNothing, reason: where);

        // The sub panel: five parameter rows, each a label, a slider and a
        // value in a 34 pixel box.
        await tester.tap(
          find.descendant(
            of: find.byType(ActionBar),
            matching: find.text('SUB'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'sub panel in $where');
        final subPanel = _clipped(tester, find.byType(SubPanel)).toList();
        expect(subPanel, isEmpty, reason: 'sub panel in $where: $subPanel');
      });
    }
  }
}
