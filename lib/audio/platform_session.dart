import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Claiming the platform audio session, which is a platform concern rather
/// than an engine one.
///
/// Neither flutter_soloud nor cpal touches it, so the app has to. Without it
/// iOS defaults to the ambient category and the ringer switch silences the
/// app: picking up a phone with the switch on and hearing nothing is not a
/// verdict on the groove.
///
/// [onInterrupt] is called when a phone call, another app or headphones being
/// pulled takes the output away. Both engines answer that the same way, by
/// stopping, because the alternative is a transport that keeps running against
/// a device nobody is listening to.
Future<void> configureAudioSession(Future<void> Function() onInterrupt) async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    session.interruptionEventStream.listen((event) {
      if (event.begin) unawaited(onInterrupt());
    });
    session.becomingNoisyEventStream.listen((_) => unawaited(onInterrupt()));
  } on Object catch (error) {
    // Not fatal: on desktop there may be no session to configure.
    debugPrint('junglengine: audio session not configured ($error)');
  }
}
