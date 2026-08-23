# junglengine_decode

Platform audio decoding for junglEngine. Files in, interleaved 32 bit float PCM
out, at the file's own sample rate and channel count.

The app decodes WAV itself in Dart, because a WAV is already interleaved PCM
once the header is read. Everything else -- MP3, M4A, AAC, ALAC, FLAC, AIFF,
Ogg -- goes through the decoders the phone already has:

- iOS and macOS: `AVAudioFile`, whose `processingFormat` is deinterleaved float
  at the file's rate. The plugin interleaves it and hands it back.
- Android: `MediaExtractor` plus `MediaCodec`, asking for `ENCODING_PCM_FLOAT`
  and converting from 16 or 8 bit when the decoder declines.

Nothing here resamples or folds channels. The caller knows what its mixer wants
and already has the code to conform a clip to it.

```dart
final decoded = await decodeAudioFile(path, maxFrames: 44100 * 120);
```

`maxFrames` caps the decode so that picking a two hour podcast by mistake costs
a second, not the process. Anything that hits the cap comes back with
`truncated` set.

On a platform with no implementation, `decodeAudioFile` throws
`AudioDecodeUnavailable` rather than failing loudly, so callers can fall back to
the Dart WAV path.
