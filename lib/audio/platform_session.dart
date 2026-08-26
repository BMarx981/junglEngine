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
/// It is also where the app is told that the output has been taken away and
/// given back, which is the difference between an instrument that survives a
/// phone call and one that has to be restarted after one. The three answers
/// are deliberately different sizes:
///
/// - [onStop] is headphones being pulled out. The output is fine and the route
///   has simply moved to the speaker; stopping is politeness, because nobody
///   wants a break playing out loud on a bus. Handing the device back for that
///   would be a stream teardown for a route change.
/// - [onSuspend] is an interruption beginning: a call, an alarm, another app
///   taking the session. The output is gone whether or not the app agrees, so
///   the device goes back and the transport stops.
/// - [onResume] is that interruption ending. The session is claimed again and
///   the engine takes the output. Playback does not start again by itself: a
///   call ending is not a request to play.
///
/// See docs/M4.md, stage 5.
Future<void> configureAudioSession({
  required Future<void> Function() onStop,
  required Future<void> Function() onSuspend,
  required Future<void> Function() onResume,
}) async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    session.interruptionEventStream.listen((event) {
      // Ducking is a volume change rather than a loss: the output is still
      // ours, so the answer is the one headphones being pulled gets. Stopping
      // rather than ducking, because there is no such thing as a quiet
      // sequencer step and the alternative is a groove nobody can hear
      // deciding what a break sounds like.
      if (event.type == AudioInterruptionType.duck) {
        if (event.begin) unawaited(onStop());
        return;
      }
      // Everything else takes the output away, `unknown` included: an
      // interruption that ends without saying what it was is still an output
      // this app no longer holds, and asking for it back is how it finds out
      // whether it can have it.
      if (event.begin) {
        unawaited(onSuspend());
      } else {
        unawaited(_reclaim(session, onResume));
      }
    });
    session.becomingNoisyEventStream.listen((_) => unawaited(onStop()));
  } on Object catch (error) {
    // Not fatal: on desktop there may be no session to configure.
    debugPrint('junglengine: audio session not configured ($error)');
  }
}

/// Claims the session again before the engine asks for the device.
///
/// In that order, and both allowed to fail: whatever interrupted us may still
/// hold the session, in which case the engine's open fails too and the app
/// waits for the next thing that says the output is available -- the next
/// interruption ending, or coming back to the foreground.
Future<void> _reclaim(
  AudioSession session,
  Future<void> Function() onResume,
) async {
  try {
    await session.setActive(true);
  } on Object catch (error) {
    debugPrint('junglengine: audio session not reclaimed ($error)');
  }
  await onResume();
}
