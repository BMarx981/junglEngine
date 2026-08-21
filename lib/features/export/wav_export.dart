import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../audio/engine.dart';
import '../../audio/pattern_renderer.dart';
import '../../audio/wav.dart';

/// How many repeats of the pattern an export may be.
const List<int> exportBarChoices = [1, 2, 4, 8];

class ExportResult {
  const ExportResult({required this.file, required this.bars, required this.duration});

  final File file;
  final int bars;
  final Duration duration;

  String get fileName => file.uri.pathSegments.last;
}

/// Renders the loop to a 16 bit WAV.
///
/// Renders through the [AudioEngine] rather than around it, so the file is
/// what you heard and swapping in a different engine takes export with it.
class WavExporter {
  const WavExporter._();

  static Future<ExportResult> exportLoop({
    required AudioEngine engine,
    required RenderSpec spec,
    required int repeats,
    String beatName = 'beat',
  }) async {
    final frames = engine.loopFramesFor(spec) * repeats;
    final samples = await engine.renderOffline(spec, frames);
    final bytes = encodeWav(
      samples,
      sampleRate: spec.sampleRate,
      channels: 2,
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${_fileName(beatName, spec, repeats)}');
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(
      file: file,
      bars: repeats * spec.beat.bars,
      duration: Duration(
        microseconds: (frames * 1000000 / spec.sampleRate).round(),
      ),
    );
  }

  static String _fileName(String beatName, RenderSpec spec, int repeats) {
    final safe = beatName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final bars = repeats * spec.beat.bars;
    final bpm = spec.bpm.round();
    return 'junglengine-${safe.isEmpty ? 'beat' : safe}-${bpm}bpm-${bars}bar.wav';
  }
}
