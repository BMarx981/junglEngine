import 'dart:typed_data';

import 'package:junglengine/audio/audio_clip.dart';

/// Thrown when a file does not look like a WAV this app can read.
class WavFormatException implements Exception {
  WavFormatException(this.message);

  final String message;

  @override
  String toString() => 'WavFormatException: $message';
}

const int _formatPcm = 1;
const int _formatFloat = 3;
const int _formatExtensible = 0xFFFE;

/// Minimal RIFF/WAVE reader.
///
/// Handles 8, 16, 24 and 32 bit integer PCM plus 32 and 64 bit IEEE float, mono
/// or multichannel, including WAVE_FORMAT_EXTENSIBLE. That covers every bundled
/// break and everything a phone file picker is likely to hand us in M3.
AudioClip decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 12) throw WavFormatException('file too short');
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
    throw WavFormatException('not a RIFF/WAVE file');
  }

  var format = _formatPcm;
  var channels = 0;
  var sampleRate = 0;
  var bitsPerSample = 0;
  Uint8List? pcm;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      if (body + 16 > bytes.length) throw WavFormatException('truncated fmt');
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bitsPerSample = data.getUint16(body + 14, Endian.little);
      if (format == _formatExtensible && size >= 40) {
        // The real format lives in the first two bytes of the GUID subformat.
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      final end = (body + size).clamp(body, bytes.length);
      pcm = Uint8List.sublistView(bytes, body, end);
    }
    // Chunks are word aligned.
    offset = body + size + (size.isOdd ? 1 : 0);
  }

  if (pcm == null) throw WavFormatException('no data chunk');
  if (channels <= 0 || sampleRate <= 0) {
    throw WavFormatException('no usable fmt chunk');
  }

  final samples = _toFloat(pcm, format, bitsPerSample);
  return AudioClip(
    samples: samples,
    channels: channels,
    sampleRate: sampleRate,
  );
}

Float32List _toFloat(Uint8List pcm, int format, int bits) {
  final view = ByteData.sublistView(pcm);
  if (format == _formatFloat) {
    if (bits == 32) {
      final n = pcm.lengthInBytes ~/ 4;
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        out[i] = view.getFloat32(i * 4, Endian.little);
      }
      return out;
    }
    if (bits == 64) {
      final n = pcm.lengthInBytes ~/ 8;
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        out[i] = view.getFloat64(i * 8, Endian.little);
      }
      return out;
    }
    throw WavFormatException('unsupported float width: $bits');
  }
  if (format != _formatPcm) {
    throw WavFormatException('unsupported wav format code: $format');
  }
  switch (bits) {
    case 8:
      // 8 bit WAV is unsigned.
      final out = Float32List(pcm.lengthInBytes);
      for (var i = 0; i < out.length; i++) {
        out[i] = (pcm[i] - 128) / 128.0;
      }
      return out;
    case 16:
      final n = pcm.lengthInBytes ~/ 2;
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
      }
      return out;
    case 24:
      final n = pcm.lengthInBytes ~/ 3;
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        final b = i * 3;
        var v = pcm[b] | (pcm[b + 1] << 8) | (pcm[b + 2] << 16);
        if (v & 0x800000 != 0) v -= 0x1000000;
        out[i] = v / 8388608.0;
      }
      return out;
    case 32:
      final n = pcm.lengthInBytes ~/ 4;
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        out[i] = view.getInt32(i * 4, Endian.little) / 2147483648.0;
      }
      return out;
    default:
      throw WavFormatException('unsupported bit depth: $bits');
  }
}

/// Writes 16 bit PCM WAV. This is the export format and the format the tiny
/// break generator in `tool/` emits.
Uint8List encodeWav(
  Float32List samples, {
  required int sampleRate,
  required int channels,
}) {
  final frameCount = samples.length ~/ channels;
  final dataBytes = frameCount * channels * 2;
  final out = Uint8List(44 + dataBytes);
  final view = ByteData.sublistView(out);

  _writeTag(out, 0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, Endian.little);
  _writeTag(out, 8, 'WAVE');
  _writeTag(out, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, _formatPcm, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * channels * 2, Endian.little); // byte rate
  view.setUint16(32, channels * 2, Endian.little); // block align
  view.setUint16(34, 16, Endian.little);
  _writeTag(out, 36, 'data');
  view.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < frameCount * channels; i++) {
    final v = (samples[i] * 32767.0).clamp(-32768.0, 32767.0).round();
    view.setInt16(44 + i * 2, v, Endian.little);
  }
  return out;
}

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes, offset, offset + 4);

void _writeTag(Uint8List bytes, int offset, String tag) {
  for (var i = 0; i < 4; i++) {
    bytes[offset + i] = tag.codeUnitAt(i);
  }
}
