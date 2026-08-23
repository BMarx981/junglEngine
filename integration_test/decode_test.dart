// Runs the native audio decoder against real files on a real platform.
//
//   flutter test integration_test/decode_test.dart -d macos
//   flutter test integration_test/decode_test.dart -d <phone>
//
// The Dart WAV reader is unit tested and needs no device. This is here for the
// half of importing that only exists on the other side of a method channel:
// AVFoundation on Apple platforms, MediaCodec on Android. A unit test cannot
// tell you whether that channel is wired up, whether the decoder hands back
// what it claims, or whether the bytes survive the trip.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:junglengine/audio/decode.dart';
import 'package:junglengine/audio/wav.dart';
import 'package:junglengine/features/library/break_library.dart';
import 'package:junglengine_decode/junglengine_decode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory scratch;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('junglengine-decode');
  });

  tearDown(() async {
    if (scratch.existsSync()) await scratch.delete(recursive: true);
  });

  /// Puts a bundled asset on disk, because the decoders take paths.
  Future<String> assetOnDisk(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final file = File('${scratch.path}/${assetPath.split('/').last}');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  testWidgets('the platform decoder agrees with the Dart WAV reader', (
    tester,
  ) async {
    final ref = BreakLibrary.defaultBreak;
    final path = await assetOnDisk(ref.assetPath);
    final expected = decodeWav(await File(path).readAsBytes());

    final decoded = await decodeAudioFile(path);

    expect(decoded.sampleRate, expected.sampleRate);
    expect(decoded.channels, expected.channels);
    // A decoder is allowed to differ by a frame at the tail; being out by more
    // than that would move the loop point, which is audible.
    expect(decoded.frames, closeTo(expected.frames, 1));
    expect(decoded.truncated, isFalse);

    // Same audio, not just the same shape. Sixteen bit WAV in, float out, so
    // the tolerance is one LSB.
    for (var frame = 0; frame < decoded.frames; frame += 997) {
      for (var channel = 0; channel < decoded.channels; channel++) {
        final index = frame * decoded.channels + channel;
        expect(
          decoded.samples[index],
          closeTo(expected.samples[index], 1 / 32768),
          reason: 'frame $frame channel $channel',
        );
      }
    }
  });

  testWidgets('the frame cap stops a long file short and says so', (
    tester,
  ) async {
    final path = await assetOnDisk(BreakLibrary.defaultBreak.assetPath);
    final whole = await decodeAudioFile(path);

    final capped = await decodeAudioFile(path, maxFrames: 1000);

    expect(capped.frames, 1000);
    expect(capped.truncated, isTrue);
    expect(whole.frames, greaterThan(1000));
  });

  testWidgets('a file that is not audio fails as a decode error', (
    tester,
  ) async {
    final file = File('${scratch.path}/not-audio.wav');
    await file.writeAsString('this is not a wave file');

    await expectLater(
      decodeAudioFile(file.path),
      throwsA(isA<AudioDecodeException>()),
    );
  });

  testWidgets('the import path conforms whatever it decodes to the mixer', (
    tester,
  ) async {
    final path = await assetOnDisk(BreakLibrary.defaultBreak.assetPath);
    final imported = await decodeImport(path);

    expect(imported.clip.frames, greaterThan(0));
    expect(imported.truncated, isFalse);
  });

  // AIFF is the format macOS has lying around that the Dart reader cannot
  // touch, which makes it the cheapest proof that import is not secretly
  // WAV only. On a phone this is skipped; the formats that matter there --
  // MP3 and M4A -- go through the same decoder as this does.
  testWidgets('a format the Dart reader cannot read still imports', (
    tester,
  ) async {
    final system = File('/System/Library/Sounds/Glass.aiff');
    if (!system.existsSync()) {
      markTestSkipped('no AIFF on this platform');
      return;
    }

    expect(
      () => decodeWav(system.readAsBytesSync()),
      throwsA(isA<WavFormatException>()),
      reason: 'if Dart can read this, it proves nothing about the plugin',
    );

    final decoded = await decodeImport(system.path);
    expect(decoded.clip.frames, greaterThan(0));
    expect(decoded.clip.sampleRate, greaterThan(0));
  });
}
