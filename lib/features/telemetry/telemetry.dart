import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

/// Crash reports, and four counters.
///
/// Four, named here, and no more without a reason that survives being said out
/// loud. There are no accounts in this app, nothing is identified, and nothing
/// anyone makes leaves the phone: none of these events carries a project, a
/// file name, a pattern or anything a person typed. What they answer is whether
/// the Kit machine gets used, whether exports happen, and whether scramble is
/// the thing it was built to be.
enum TelemetryEvent {
  /// A Beat was created, with which machine.
  beatCreated('beat_created'),

  /// An export finished, with which of the three kinds.
  exportCompleted('export_completed'),

  /// Scramble was tapped.
  scrambleTapped('scramble_tapped'),

  /// A Beat was opened, with which machine. This is the machine type usage
  /// question: creating one Kit Beat and never opening it again is a different
  /// answer from living in it.
  beatOpened('beat_opened');

  const TelemetryEvent(this.name);

  final String name;
}

/// Where the events go.
abstract class Telemetry {
  Future<void> log(TelemetryEvent event, {Map<String, Object>? parameters});

  /// Reports an error that was caught rather than thrown.
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
}

/// The one that does nothing.
///
/// Used until Firebase is configured, on any platform without it, and in every
/// test. Analytics that cannot be switched off in a test host is analytics that
/// makes the test suite depend on a network.
class NoTelemetry implements Telemetry {
  const NoTelemetry();

  @override
  Future<void> log(TelemetryEvent event, {Map<String, Object>? parameters}) =>
      Future.value();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    // Still worth seeing while developing, even with nothing collecting it.
    debugPrint('junglengine: $reason ${reason == null ? '' : '-- '}$error');
  }
}

/// Firebase Analytics and Crashlytics.
class FirebaseTelemetry implements Telemetry {
  const FirebaseTelemetry();

  @override
  Future<void> log(
    TelemetryEvent event, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: event.name,
        parameters: parameters,
      );
    } on Object catch (error) {
      // An event that will not send is not worth a single line of the user's
      // attention, and definitely not worth failing the thing they were doing.
      debugPrint('junglengine: event not logged ($error)');
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
      );
    } on Object catch (failure) {
      debugPrint('junglengine: error not recorded ($failure)');
    }
  }
}

/// Whichever one this build has. Overridden in tests.
final telemetryProvider = Provider<Telemetry>((ref) => TelemetryBoot.active);

/// Starts Firebase, if this build can.
///
/// junglEngine ships and runs perfectly well with no Firebase behind it, and it
/// must: `DefaultFirebaseOptions.currentPlatform` throws on every platform the
/// FlutterFire CLI was not pointed at, which is all three desktops and web, and
/// a build made from a clone with no `google-services.json` has nothing for the
/// Android SDK to read. Everything here is best effort, and the app falls back
/// to [NoTelemetry] rather than refusing to open.
///
/// See docs/TELEMETRY.md for what this collects and how to check it is live.
class TelemetryBoot {
  const TelemetryBoot._();

  static Telemetry active = const NoTelemetry();

  static bool get isLive => active is FirebaseTelemetry;

  /// Brings up Firebase and points Flutter's error handlers at Crashlytics.
  ///
  /// Called from `main` before `runApp`, because an error thrown during the
  /// first frame is exactly the kind worth catching.
  static Future<void> start() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on Object catch (error) {
      debugPrint(
        'junglengine: no Firebase project configured ($error). '
        'Running without crash reporting or analytics.',
      );
      return;
    }

    active = const FirebaseTelemetry();

    try {
      // No ads, ever, means no advertising signals either. Analytics storage is
      // the only thing consented to here, and it is what carries the four
      // events; everything an advertiser would want is switched off, which is
      // what makes the line in docs/PRIVACY.md true.
      await FirebaseAnalytics.instance.setConsent(
        analyticsStorageConsentGranted: true,
        adStorageConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        adUserDataConsentGranted: false,
      );
    } on Object catch (error) {
      debugPrint('junglengine: analytics consent not set ($error)');
    }

    try {
      final crashlytics = FirebaseCrashlytics.instance;
      // Debug crashes are the developer's problem and belong in the console,
      // not in a dashboard of things real users hit.
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        previous?.call(details);
        crashlytics.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(crashlytics.recordError(error, stack, fatal: true));
        return true;
      };
    } on Object catch (error) {
      debugPrint('junglengine: crash reporting not started ($error)');
    }
  }
}
