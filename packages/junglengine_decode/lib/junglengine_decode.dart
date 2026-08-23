/// Decodes audio files to raw PCM using the platform's own decoder.
///
/// The app decodes WAV itself, in Dart, because it has to: the mixer wants
/// interleaved float and a WAV is already that once you have read the header.
/// MP3, M4A, AAC and FLAC are a different problem, and shipping a decoder for
/// each of them in Dart would be a worse app than asking the phone, which has
/// hardware decoders for all of them, to do it.
///
/// AVFoundation on iOS and macOS, MediaCodec on Android. Nothing else is
/// supported and callers are expected to fall back to the Dart WAV path when
/// [decodeAudioFile] throws [AudioDecodeUnavailable].
library;

import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Interleaved 32 bit float PCM, exactly as the platform decoder produced it.
///
/// No resampling and no channel folding happen here: the caller knows what the
/// mixer wants and already has the code to conform a clip to it.
class DecodedAudio {
  const DecodedAudio({
    required this.samples,
    required this.channels,
    required this.sampleRate,
    required this.truncated,
  });

  final Float32List samples;
  final int channels;
  final int sampleRate;

  /// Whether the file was longer than the frame cap the caller asked for.
  final bool truncated;

  int get frames => channels == 0 ? 0 : samples.length ~/ channels;

  Duration get duration => Duration(
    microseconds: sampleRate == 0 ? 0 : (frames * 1000000 / sampleRate).round(),
  );
}

/// The file could not be decoded: wrong format, corrupt, or no audio track.
class AudioDecodeException implements Exception {
  AudioDecodeException(this.message);

  final String message;

  @override
  String toString() => 'AudioDecodeException: $message';
}

/// There is no platform decoder here. Fall back to whatever the caller can do
/// itself rather than telling the user their file is broken.
class AudioDecodeUnavailable implements Exception {
  @override
  String toString() => 'AudioDecodeUnavailable: no platform decoder';
}

const MethodChannel _channel = MethodChannel('junglengine_decode');

/// Decodes [path] to interleaved float PCM at the file's own rate.
///
/// [maxFrames] caps the decode so that picking a two hour podcast by mistake
/// costs a second and a few megabytes rather than the process. Zero means no
/// cap. A file that hits the cap comes back with [DecodedAudio.truncated] set,
/// which is a thing to tell the user, not an error.
Future<DecodedAudio> decodeAudioFile(String path, {int maxFrames = 0}) async {
  final Map<Object?, Object?>? reply;
  try {
    reply = await _channel.invokeMethod<Map<Object?, Object?>>('decodeFile', {
      'path': path,
      'maxFrames': maxFrames,
    });
  } on MissingPluginException {
    throw AudioDecodeUnavailable();
  } on PlatformException catch (error) {
    throw AudioDecodeException(error.message ?? error.code);
  }

  if (reply == null) throw AudioDecodeException('decoder returned nothing');

  final pcm = reply['pcm'];
  final channels = reply['channels'];
  final sampleRate = reply['sampleRate'];
  if (pcm is! Uint8List || channels is! int || sampleRate is! int) {
    throw AudioDecodeException('decoder returned a malformed reply');
  }
  if (channels <= 0 || sampleRate <= 0) {
    throw AudioDecodeException('decoder returned no usable format');
  }

  return DecodedAudio(
    samples: _asFloat32(pcm),
    channels: channels,
    sampleRate: sampleRate,
    truncated: reply['truncated'] == true,
  );
}

/// Views the reply's bytes as floats, copying only when the platform channel
/// handed back a buffer that is not four byte aligned. Native writes little
/// endian, which is every platform this ships on.
Float32List _asFloat32(Uint8List bytes) {
  final count = bytes.lengthInBytes ~/ 4;
  if (bytes.offsetInBytes % 4 == 0) {
    return Float32List.view(bytes.buffer, bytes.offsetInBytes, count);
  }
  final aligned = Uint8List.fromList(bytes);
  return Float32List.view(aligned.buffer, 0, count);
}
