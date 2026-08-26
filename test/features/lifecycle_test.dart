// What the app does when the phone takes the output away.
//
// Backgrounding, in particular: the app has to hand the device back rather
// than merely go quiet, because an output nobody is listening to is battery,
// and because neither engine can keep a stream fed from the background. See
// docs/M4.md, stage 5.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junglengine/app.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/state/studio.dart';

import '../support/fake_engine.dart';
import '../support/fake_pro_store.dart';

Future<FakeAudioEngine> _pumpApp(WidgetTester tester) async {
  final tempDir = Directory.systemTemp.createTempSync('junglengine-lifecycle');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path,
      );
  addTearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final engine = FakeAudioEngine();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        proStoreProvider.overrideWithValue(FakeProStore()),
      ],
      child: const JungleApp(),
    ),
  );
  await tester.pump();
  return engine;
}

void main() {
  testWidgets('backgrounding gives the output back and foregrounding asks for '
      'it again', (tester) async {
    final engine = await _pumpApp(tester);
    await engine.start();
    expect(engine.transport.value.playing, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(engine.suspended, isTrue);
    expect(
      engine.transport.value.playing,
      isFalse,
      reason: 'a transport left running against a closed device would be a '
          'playhead drawn over silence',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(engine.suspended, isFalse);
    expect(engine.resumeCount, 1);
    expect(
      engine.transport.value.playing,
      isFalse,
      reason: 'coming back to the app is not a request to play',
    );
  });

  testWidgets('the app killed from the switcher still hands the output back', (
    tester,
  ) async {
    final engine = await _pumpApp(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();

    expect(engine.suspended, isTrue);
    expect(engine.suspendCount, 2, reason: 'idempotent, and asked twice');
  });
}
