# Telemetry

Crash reports and four counters. That is the whole of it.

There are no accounts in junglEngine, nothing is identified, and nothing anyone
makes leaves the phone. No project, file name, pattern, break, or anything a
person typed is ever attached to an event. `docs/PRIVACY.md` says this to
users; this file is the engineering version.

Code: `lib/features/telemetry/telemetry.dart`. Call sites: `lib/state/studio.dart`.

## The four events

| Event | When | Parameters |
| --- | --- | --- |
| `beat_created` | A Beat is made | `machine` (`chop`/`kit`), `bars` |
| `beat_opened` | A Beat is opened | `machine` |
| `export_completed` | An export finishes | `kind` (`loop`/`song`/`parts`), plus `bars` or `machine` |
| `scramble_tapped` | Scramble is tapped | none |

Between them they answer three questions and no others: does the Kit machine
get used or only made, do exports actually happen, and is scramble the thing it
was built to be. `beat_created` and `beat_opened` are both here on purpose,
because making one Kit Beat and never returning to it is a different answer
from living in it.

**Adding a fifth event needs a reason that survives being said out loud.** Add
the enum case in `TelemetryEvent`, add the row above, and check whether
`docs/PRIVACY.md` still tells the truth.

## What is switched off

`TelemetryBoot.start` calls `setConsent` with analytics storage granted and all
three advertising flags denied: ad storage, ad personalization signals, and ad
user data. No ads ever means no advertising signals either. The GA4 property
should have Google signals and ad personalization off as well, so that the
console agrees with the client.

Crashlytics collection is off in debug (`setCrashlyticsCollectionEnabled(!kDebugMode)`).
A crash you caused while developing belongs in the console you are looking at,
not in a dashboard of things real users hit.

## The two implementations

`NoTelemetry` does nothing and is the default. `FirebaseTelemetry` sends. Which
one is live is decided once, at boot, by whether `Firebase.initializeApp`
succeeds, and read through `telemetryProvider`.

Every path in `FirebaseTelemetry` swallows its own failures to a `debugPrint`.
An event that will not send is not worth a line of the user's attention and
definitely not worth failing the export they were doing.

Firebase does not come up on desktop or web, because the FlutterFire CLI was
only pointed at iOS and Android, and `DefaultFirebaseOptions.currentPlatform`
throws for the rest. That is caught, and the app opens on `NoTelemetry`.

## Tests

Tests must never touch the network, and none of them do: `TelemetryBoot.start`
is only ever called from `main`, which the test host does not run, so
`TelemetryBoot.active` is still `NoTelemetry` and `telemetryProvider` hands it
out. No test overrides anything today, and none needs to.

That safety is a consequence of where `start` is called from rather than
something a test asserts. If `start` ever moves out of `main`, override the
provider explicitly:

```dart
ProviderScope(
  overrides: [telemetryProvider.overrideWithValue(const NoTelemetry())],
  child: ...,
)
```

The same override, pointed at a recording fake, is how you would assert that an
event fires.

## Checking it is live

On a debug run against a real device:

- `TelemetryBoot.isLive` is `true`.
- The log has **no** line reading `no Firebase project configured`.
- Analytics DebugView shows the events. It needs debug mode switched on for the
  device first, otherwise events batch for up to an hour and DebugView stays
  empty:
  - Android: `adb shell setprop debug.firebase.analytics.app app.hawkstreak.junglengine`
  - iOS: add `-FIRAnalyticsDebugEnabled` to the scheme's launch arguments.
- Crashlytics needs one real crash from a **release or profile** build before
  the dashboard leaves its setup screen. Debug builds do not report, by design.

## Regenerating the config

```sh
flutterfire configure --project=junglengine
```

Rewrites `lib/firebase_options.dart`, `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist` and `firebase.json`. Re-run it after
adding a platform or after enabling Analytics on a project that did not have
it, because a config generated before the GA4 link leaves events silently going
nowhere while Crashlytics keeps working.
