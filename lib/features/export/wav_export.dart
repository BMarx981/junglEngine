import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:junglengine/audio/engine.dart';
import 'package:junglengine/audio/pattern_renderer.dart';
import 'package:junglengine/audio/wav.dart';

/// How many repeats of the pattern a loop export may be.
const List<int> exportBarChoices = [1, 2, 4, 8];

class ExportResult {
  const ExportResult({
    required this.file,
    required this.bars,
    required this.duration,
  });

  final File file;
  final int bars;
  final Duration duration;

  String get fileName => file.uri.pathSegments.last;
}

/// Renders to a 16 bit WAV.
///
/// Renders through the [AudioEngine] rather than around it, so the file is
/// what you heard and swapping in a different engine takes export with it.
/// A loop and a song are the same call: an arrangement is a spec whose one
/// pass happens to be the whole song, so there is no second render path.
class WavExporter {
  const WavExporter._();

  static Future<ExportResult> export({
    required AudioEngine engine,
    required RenderSpec spec,
    required int repeats,
    String name = 'beat',
  }) async {
    final frames = engine.loopFramesFor(spec) * repeats;
    final samples = await engine.renderOffline(spec, frames);
    final bytes = encodeWav(samples, sampleRate: spec.sampleRate, channels: 2);

    final bars = repeats * spec.bars;
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/${fileNameFor(name, spec.bpm, bars)}',
    );
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(
      file: file,
      bars: bars,
      duration: Duration(
        microseconds: (frames * 1000000 / spec.sampleRate).round(),
      ),
    );
  }

  static String fileNameFor(String name, double bpm, int bars) {
    final safe = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'junglengine-${safe.isEmpty ? 'beat' : safe}-'
        '${bpm.round()}bpm-${bars}bar.wav';
  }
}
