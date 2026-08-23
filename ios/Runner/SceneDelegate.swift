import Flutter
import UIKit

/// Audio arriving from outside the app.
///
/// Registering for audio document types is what puts junglEngine in the "Open
/// in" list in Files, Safari, Mail and the messengers, which is the cheapest
/// possible import path: the file is already in the user's hand.
///
/// Incoming URLs are copied out and queued rather than pushed at Dart, because
/// a file can arrive before the engine exists. Dart asks for what is waiting
/// when it boots and again every time the app comes back to the foreground,
/// and opening a file always does one or the other.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    IncomingFiles.shared.take(connectionOptions.urlContexts)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    IncomingFiles.shared.take(urlContexts)
    super.scene(scene, openURLContexts: urlContexts)
  }
}

/// The queue of files waiting to be imported, and the channel Dart drains it
/// through.
class IncomingFiles: NSObject {
  static let shared = IncomingFiles()

  static let channelName = "junglengine/incoming"

  private var pending: [String] = []
  private let lock = NSLock()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "takePending" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(shared.drain())
    }
  }

  func take(_ contexts: Set<UIOpenURLContext>) {
    for context in contexts {
      if let path = IncomingFiles.copyIn(context.url) {
        lock.lock()
        pending.append(path)
        lock.unlock()
      }
    }
  }

  /// Everything waiting, and the queue is empty afterwards.
  func drain() -> [String] {
    lock.lock()
    defer { lock.unlock() }
    let waiting = pending
    pending = []
    return waiting
  }

  /// Copies an incoming file somewhere the app can definitely read it later.
  ///
  /// A URL handed over by another app is only readable for the length of the
  /// call, and only inside a security scope. Copying now costs one pass over a
  /// few megabytes and removes every question about when it stops working.
  private static func copyIn(_ url: URL) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let inbox = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("junglengine-incoming", isDirectory: true)
    let destination = inbox.appendingPathComponent(url.lastPathComponent)
    do {
      try FileManager.default.createDirectory(
        at: inbox, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.copyItem(at: url, to: destination)
      return destination.path
    } catch {
      NSLog("junglengine: could not take in \(url.lastPathComponent): \(error)")
      return nil
    }
  }
}
