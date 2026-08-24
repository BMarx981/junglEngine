import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/decode.dart';
import 'package:junglengine/audio/wav.dart';
import 'package:junglengine/features/library/import_store.dart';
import 'package:junglengine/models/import_ref.dart';

/// Bring your own audio.
///
/// Pick a file, decode it, say where the loop is and how fast it is, and it
/// becomes the project break. Everything here is deliberately manual: no BPM
/// detection and no transient analysis, both of which are parked, and both of
/// which are worse than a person who can hear the loop tapping four times.

/// Audio the user picked, decoded and conformed to what the mixer wants.
class ImportCandidate {
  ImportCandidate({
    required String name,
    required this.clip,
    required this.truncated,
  }) : name = ImportStore.displayName(name);

  /// The file's own name, tidied: no extension, no path, short enough for a
  /// chip. Normalised here rather than at each call site so that every name
  /// written into a project has been through the same door.
  final String name;

  /// Stereo, at the engine's sample rate, unnormalised.
  final AudioClip clip;

  /// Whether the file ran past the import cap and was cut short.
  final bool truncated;

  int get frames => clip.frames;

  Duration get duration =>
      Duration(microseconds: (frames * 1000000 / clip.sampleRate).round());
}

/// Why an import could not go ahead.
///
/// A code rather than a sentence, because these are raised deep in the import
/// path where there is no [BuildContext] to translate against. The wording
/// lives in `importFailureMessage`, beside the widgets that show it.
enum ImportFailure {
  /// The system file browser would not open.
  picker,

  /// The file is not audio this app can read.
  decode,

  /// The audio is too brief to cut into slices.
  tooShort,
}

/// Thrown when the user picked something that is not usable audio.
class ImportException implements Exception {
  ImportException(this.failure, {this.detail});

  final ImportFailure failure;

  /// The underlying platform error, for logs. Never shown to the user: it is
  /// untranslated, and usually a stack fragment.
  final String? detail;

  @override
  String toString() => detail == null ? '$failure' : '$failure ($detail)';
}

/// Opens the system picker.
///
/// Returns null when the user backed out, which is not a failure and should not
/// put anything on screen. The picker covers iCloud, Drive and Dropbox for
/// free, because on both platforms those mount as document providers.
///
/// Deliberately separate from [decodePicked]: the picker is its own wait, and
/// the spinner belongs over the decode that follows it rather than over a
/// system sheet that is already on screen.
Future<PlatformFile?> chooseAudioFile() async {
  try {
    return await FilePicker.pickFile(type: FileType.audio);
  } on Object catch (error) {
    throw ImportException(ImportFailure.picker, detail: '$error');
  }
}

/// Decodes a picked file, copying it out of the picker first when the platform
/// handed back something that is not on disk.
///
/// Android's document picker can return a `content://` URI with no path, and
/// the platform decoders want a path. Materialising it costs one copy and
/// removes the whole class of problem.
Future<ImportCandidate> decodePicked(
  PlatformFile picked, {
  required int sampleRate,
}) async {
  var path = picked.path;
  File? scratch;
  if (path == null) {
    final temporary = await getTemporaryDirectory();
    scratch = File('${temporary.path}/junglengine-import-${picked.name}');
    await scratch.writeAsBytes(await picked.readAsBytes(), flush: true);
    path = scratch.path;
  }

  try {
    return await decodeImportedPath(
      path,
      name: picked.name,
      sampleRate: sampleRate,
    );
  } finally {
    try {
      scratch?.deleteSync();
    } on Object {
      // A leftover in the temp directory is the OS's problem, not the user's.
    }
  }
}

/// Decodes a file already on disk. Also the entry point for audio arriving
/// through the share sheet, which hands over a path rather than a picker.
Future<ImportCandidate> decodeImportedPath(
  String path, {
  required String name,
  required int sampleRate,
}) async {
  final DecodedImport decoded;
  try {
    decoded = await decodeImport(path);
  } on ImportDecodeException catch (error) {
    throw ImportException(ImportFailure.decode, detail: error.message);
  }

  final clip = decoded.clip.toStereo().resampledTo(sampleRate);
  if (clip.frames < _minimumFrames) {
    throw ImportException(ImportFailure.tooShort);
  }
  return ImportCandidate(name: name, clip: clip, truncated: decoded.truncated);
}

/// Under a tenth of a second there is no loop to find.
const int _minimumFrames = 4410;

/// Where the loop is inside the imported file, and what it is.
///
/// The trim is stored in frames rather than seconds because that is what gets
/// sliced, and a rounding error at the loop point is the one place in this app
/// where a single frame is audible.
class TrimSelection {
  const TrimSelection({
    required this.startFrame,
    required this.lengthFrames,
    required this.bars,
  });

  final int startFrame;
  final int lengthFrames;

  /// How many bars the trimmed region is. Not guessed: the import screen makes
  /// the user say, because slice divisions are per bar and getting this wrong
  /// makes every slice the wrong note value.
  final int bars;

  int get endFrame => startFrame + lengthFrames;

  /// The tempo the trim implies. Bars times four beats over the length.
  double bpmAt(int sampleRate) {
    if (lengthFrames <= 0) return 0;
    return bars * 4 * 60 * sampleRate / lengthFrames;
  }

  /// How long [bars] bars are at [bpm]. The inverse of [bpmAt], and what moves
  /// the end handle when the user types a tempo or taps one in.
  static int framesFor({
    required double bpm,
    required int bars,
    required int sampleRate,
  }) {
    if (bpm <= 0) return 0;
    return (bars * 4 * 60 * sampleRate / bpm).round();
  }

  TrimSelection copyWith({int? startFrame, int? lengthFrames, int? bars}) =>
      TrimSelection(
        startFrame: startFrame ?? this.startFrame,
        lengthFrames: lengthFrames ?? this.lengthFrames,
        bars: bars ?? this.bars,
      );
}

/// The trimmed region as its own clip: what gets previewed, and what gets
/// written.
AudioClip sliceOf(AudioClip clip, TrimSelection trim) {
  final start = trim.startFrame.clamp(0, clip.frames);
  final end = trim.endFrame.clamp(start, clip.frames);
  if (end <= start) {
    return AudioClip.silent(frames: 1, sampleRate: clip.sampleRate);
  }
  return AudioClip(
    samples: clip.samples.sublist(start * clip.channels, end * clip.channels),
    channels: clip.channels,
    sampleRate: clip.sampleRate,
  );
}

/// Writes the trimmed loop into the imports directory and describes it.
///
/// The trim is baked in rather than stored, so the file on disk is always
/// exactly the loop the grid is chopping and there is no second source of truth
/// about where the loop starts.
Future<ImportedBreak> writeImportedBreak({
  required ImportStore store,
  required ImportCandidate candidate,
  required TrimSelection trim,
  required double bpm,
  required int stamp,
}) async {
  final loop = sliceOf(candidate.clip, trim);
  final fileName = await store.write(
    candidate.name,
    encodeWav(
      loop.samples,
      sampleRate: loop.sampleRate,
      channels: loop.channels,
    ),
    stamp: stamp,
  );
  return ImportedBreak(
    id: 'import-$stamp',
    name: candidate.name,
    fileName: fileName,
    bpm: bpm,
    bars: trim.bars,
  );
}

/// The longest a one shot can be. Kit slots are one shots, not loops: past a
/// couple of seconds you have imported a break into a pad by mistake.
const double maxOneShotSeconds = 4;

/// Writes a one shot into the imports directory for a Kit slot.
///
/// Trimmed at both ends and peak normalised, because a slot is played against
/// seven others and a sample that starts a hundred milliseconds late or sits
/// 12 dB below the kit is not a usable drum. This is the one place imported
/// audio is levelled: a bundled kit's balance is baked into its files, and an
/// imported hit has to arrive somewhere near the same place.
Future<ImportedSlot> writeImportedSlot({
  required ImportStore store,
  required ImportCandidate candidate,
  required int slot,
  required int stamp,
}) async {
  final trimmed = trimSilence(
    candidate.clip,
  ).cappedTo(maxOneShotSeconds).normalized();
  final fileName = await store.write(
    'slot$slot-${candidate.name}',
    encodeWav(
      trimmed.samples,
      sampleRate: trimmed.sampleRate,
      channels: trimmed.channels,
    ),
    stamp: stamp,
  );
  return ImportedSlot(
    slot: slot,
    label: ImportStore.slotLabel(candidate.name),
    fileName: fileName,
  );
}

/// Drops silence from the head and tail of a clip.
///
/// The threshold is deliberately low: this is here to remove the dead air a
/// sample editor leaves in front of a hit, not to gate the sample.
AudioClip trimSilence(AudioClip clip, {double threshold = 0.002}) {
  final frames = clip.frames;
  if (frames == 0) return clip;

  var first = 0;
  while (first < frames && _peakAt(clip, first) < threshold) {
    first++;
  }
  if (first >= frames) return clip;

  var last = frames - 1;
  while (last > first && _peakAt(clip, last) < threshold) {
    last--;
  }

  if (first == 0 && last == frames - 1) return clip;
  return AudioClip(
    samples: clip.samples.sublist(
      first * clip.channels,
      (last + 1) * clip.channels,
    ),
    channels: clip.channels,
    sampleRate: clip.sampleRate,
  );
}

double _peakAt(AudioClip clip, int frame) {
  var peak = 0.0;
  for (var c = 0; c < clip.channels; c++) {
    final v = clip.samples[frame * clip.channels + c].abs();
    if (v > peak) peak = v;
  }
  return peak;
}

extension on AudioClip {
  /// The head of a clip, when it runs longer than a one shot has any business
  /// being.
  AudioClip cappedTo(double seconds) {
    final limit = (sampleRate * seconds).round();
    if (frames <= limit) return this;
    return AudioClip(
      samples: samples.sublist(0, limit * channels),
      channels: channels,
      sampleRate: sampleRate,
    );
  }
}
