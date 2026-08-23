import AVFoundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

/// Decodes audio files to interleaved 32 bit float PCM with AVFoundation.
///
/// `AVAudioFile` reads MP3, M4A, AAC, ALAC, FLAC, AIFF and WAV through the
/// same interface, and its `processingFormat` is always deinterleaved float at
/// the file's own sample rate. All this has to do is interleave.
public class JunglengineDecodePlugin: NSObject, FlutterPlugin {
  /// Frames per read. Large enough that a four bar break is a couple of passes,
  /// small enough that the scratch buffer stays off the "why is this app using
  /// 200 MB" list.
  private static let chunkFrames: AVAudioFrameCount = 65536

  public static func register(with registrar: FlutterPluginRegistrar) {
    // The registrar hands out its messenger as a method on iOS and a property
    // on macOS. Same object, two spellings.
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "junglengine_decode", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(JunglengineDecodePlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "decodeFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      result(
        FlutterError(
          code: "bad_arguments", message: "decodeFile needs a path", details: nil))
      return
    }
    let maxFrames = AVAudioFramePosition(args["maxFrames"] as? Int ?? 0)

    // Decoding a long file is seconds of work. The platform thread is not the
    // place for it.
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let decoded = try JunglengineDecodePlugin.decode(path: path, maxFrames: maxFrames)
        DispatchQueue.main.async { result(decoded) }
      } catch let error as NSError {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "decode_failed",
              message: error.localizedDescription,
              details: nil))
        }
      }
    }
  }

  private static func decode(path: String, maxFrames: AVAudioFramePosition) throws -> [String: Any]
  {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.isReadableFile(atPath: path) else {
      throw NSError(
        domain: "junglengine_decode", code: 3,
        userInfo: [NSLocalizedDescriptionKey: "cannot read \(path)"])
    }
    let file: AVAudioFile
    do {
      file = try AVAudioFile(forReading: url)
    } catch {
      throw NSError(
        domain: "junglengine_decode", code: 4,
        userInfo: [
          NSLocalizedDescriptionKey:
            "AVAudioFile could not open \(url.lastPathComponent): "
            + "\(error.localizedDescription)"
        ])
    }
    let format = file.processingFormat
    let channels = Int(format.channelCount)
    guard channels > 0, format.sampleRate > 0 else {
      throw NSError(
        domain: "junglengine_decode", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "file has no usable audio format"])
    }

    // The loop is bounded by the file rather than by reads coming back empty,
    // because AVAudioFile throws at the end of the file instead of returning
    // no frames. The cap is applied to what is read, not to what is decoded
    // and then thrown away.
    let available = file.length
    let limit = maxFrames > 0 ? min(maxFrames, available) : available
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
      throw NSError(
        domain: "junglengine_decode", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "could not allocate a decode buffer"])
    }

    var pcm = Data()
    var written: AVAudioFramePosition = 0
    var scratch = [Float](repeating: 0, count: Int(chunkFrames) * channels)

    while written < limit {
      let wanted = min(AVAudioFramePosition(chunkFrames), limit - written)
      do {
        try file.read(into: buffer, frameCount: AVAudioFrameCount(wanted))
      } catch {
        throw NSError(
          domain: "junglengine_decode", code: 5,
          userInfo: [
            NSLocalizedDescriptionKey:
              "decode failed \(written) frames in: \(error.localizedDescription)"
          ])
      }
      let frames = Int(buffer.frameLength)
      if frames == 0 { break }

      if format.isInterleaved {
        // Not what processingFormat gives us, but a format is a format.
        guard let source = buffer.floatChannelData?[0] else { break }
        scratch.withUnsafeMutableBufferPointer { destination in
          destination.baseAddress!.update(from: source, count: frames * channels)
        }
      } else {
        guard let source = buffer.floatChannelData else { break }
        scratch.withUnsafeMutableBufferPointer { destination in
          for channel in 0..<channels {
            let plane = source[channel]
            for frame in 0..<frames {
              destination[frame * channels + channel] = plane[frame]
            }
          }
        }
      }

      scratch.withUnsafeBufferPointer { pointer in
        pcm.append(
          UnsafeBufferPointer(rebasing: pointer.prefix(frames * channels)))
      }
      written += AVAudioFramePosition(frames)
    }

    return [
      "pcm": FlutterStandardTypedData(bytes: pcm),
      "channels": channels,
      "sampleRate": Int(format.sampleRate.rounded()),
      "truncated": available > written,
    ]
  }
}
