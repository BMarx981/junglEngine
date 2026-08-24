import 'dart:io';
import 'dart:typed_data';

import 'package:junglengine_decode/junglengine_decode.dart';

import 'package:junglengine/audio/audio_clip.dart';
import 'package:junglengine/audio/wav.dart';

/// How much of a file an import will decode.
///
/// About three minutes at 48 kHz. The cap exists so that picking a two hour
/// podcast by mistake costs a second and a few megabytes rather than the
/// process; nobody chops a break out of the back half of an album.
const int maxImportFrames = 48000 * 180;

/// Thrown when a file cannot be turned into audio by any route.
class ImportDecodeException implements Exception {
  ImportDecodeException(this.message);

  final String message;

  @override
  String toString() => 'ImportDecodeException: $message';
}

/// What one import produced.
class DecodedImport {
  const DecodedImport({required this.clip, required this.truncated});

  final AudioClip clip;

  /// Whether the file ran past [maxImportFrames] and was cut short. Worth
  /// telling the user; not worth refusing the import over.
  final bool truncated;
}

/// Decodes any audio file the phone can read.
///
/// The platform decoder goes first, because it handles MP3, M4A, AAC, ALAC,
/// FLAC and Ogg and is the whole reason the native plugin exists. The Dart WAV
/// reader is the fallback, and it is not only a fallback for platforms without
/// a plugin: it reads 24 bit and 64 bit float WAVs that some platform decoders
/// hand back as an error.
Future<DecodedImport> decodeImport(String path) async {
  try {
    final decoded = await decodeAudioFile(path, maxFrames: maxImportFrames);
    if (decoded.frames == 0) {
      throw AudioDecodeException('file decoded to silence');
    }
    return DecodedImport(
      clip: AudioClip(
        samples: decoded.samples,
        channels: decoded.channels,
        sampleRate: decoded.sampleRate,
      ),
      truncated: decoded.truncated,
    );
  } on AudioDecodeUnavailable {
    return _decodeWavFile(path, 'no audio decoder on this platform');
  } on AudioDecodeException catch (error) {
    return _decodeWavFile(path, error.message);
  }
}

/// The Dart path. [reason] is what the platform decoder said, so that a file
/// neither route can read reports the more useful of the two failures.
Future<DecodedImport> _decodeWavFile(String path, String reason) async {
  final Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } on Object catch (error) {
    throw ImportDecodeException('could not read the file ($error)');
  }
  try {
    final clip = decodeWav(bytes);
    final frames = clip.frames;
    if (frames == 0) throw WavFormatException('file decoded to silence');
    return frames > maxImportFrames
        ? DecodedImport(
            clip: _firstFrames(clip, maxImportFrames),
            truncated: true,
          )
        : DecodedImport(clip: clip, truncated: false);
  } on WavFormatException {
    throw ImportDecodeException(reason);
  }
}

/// The head of a clip, for capping a long WAV the Dart reader loaded whole.
AudioClip _firstFrames(AudioClip clip, int frames) => AudioClip(
  samples: clip.samples.sublist(0, frames * clip.channels),
  channels: clip.channels,
  sampleRate: clip.sampleRate,
);
