# Shipping M3

Everything in M3 is built and tested. What is left needs accounts, consoles and
a pair of ears, which is to say it needs Brian. This is that list, in the order
it wants doing.

## 1. Clear the bundled audio

`LICENSING.md` still has one row reading UNCLEARED: `dnb-full02-170`, which is
the default break and therefore the one in every M0 export.

Either write its provenance into the Origin cell, or drop it:

```dart
// lib/features/library/break_library.dart
// Remove the BreakRef, delete assets/breaks/DnB_full02_loop_170.wav, and
// hawkstreak-amenish-170 becomes the default again.
```

Nothing else in the code changes either way. **No store build goes out while
that row says UNCLEARED.**

## 2. Firebase

Crash reporting and the four analytics events are written and wired. They do
nothing until there is a project behind them, and the app runs perfectly well
without one: `TelemetryBoot.start` catches the failure and falls back to
`NoTelemetry`.

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project>
```

That writes `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`
and `android/app/google-services.json`. Then:

- Add the Google services Gradle plugin to `android/app/build.gradle.kts`:
  `id("com.google.gms.google-services")`, and the Crashlytics plugin
  `id("com.google.firebase.crashlytics")` if you want native symbol upload.
- Change `Firebase.initializeApp()` in `lib/features/telemetry/telemetry.dart`
  to `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

Check it landed: `TelemetryBoot.isLive` is true, and a debug run logs no "no
Firebase project configured" line. Crash collection is off in debug on purpose.

**Do not commit `google-services.json` or `GoogleService-Info.plist` to a public
repo.**

## 3. The Pro product

The purchase flow is complete and tested against a fake store. It needs a real
product to sell.

- App Store Connect: a **non consumable** with product id
  `app.hawkstreak.junglengine.pro`. Fill in the localised name, description and
  price tier, attach a review screenshot, and submit it with the build.
- Play Console: an **in app product** with the same id.
- Both need paid application agreements signed and tax details filled in, or
  the product never reaches the device and the paywall reads "not available
  right now".

Until then, the paywall has a debug only unlock, compiled out of release
builds. Test the real thing with a sandbox account on iOS and a licence tester
on Android before submitting.

## 4. Verify the parts export in Reason 13

MILESTONES.md asks for this by name, and it is the one thing in M3 that unit
tests cannot finish. The MIDI is checked byte for byte by
`test/features/slices_export_test.dart`, which parses the file back and checks
every note, so what is left is whether Reason likes it.

1. Export PARTS from a Chop Beat with at least one reversed step and one
   retrigger, and from a Kit Beat with slot volume and pitch moved.
2. In Reason 13, drop `samples/` on NN-XT and the `.mid` on a track. Check the
   mapping starts at the note the README names and that the pattern plays back
   as the phone did.
3. Do the same with Kong, pad by pad.
4. If either mapping is off by a note, the base is `baseNote` in
   `lib/features/export/slices_export.dart` and the README text is generated
   from the same constant.

## 5. Icon and store copy

- The icon is generated: `dart run tool/make_icon.dart`. Change the pattern in
  `_slicePerStep` if you want a different scatter.
- Store listing copy is in `docs/STORE.md`. Screenshots and the app preview are
  the six shots listed there.
- Publish `docs/PRIVACY.md` at a public URL and put that URL in both consoles.
  A file in a repo is not a privacy policy URL as far as either store is
  concerned.

## 6. Signing

- iOS: a distribution certificate and provisioning profile, and
  `ios/Runner.xcodeproj` is still on automatic signing with no team set.
- Android: `android/app/build.gradle.kts` still signs release with the debug
  keys. Make an upload keystore and point a `signingConfigs.release` at it
  before uploading anything.

## 7. Deployment targets

M3 raised the iOS minimum to **15.0**, because `firebase_analytics` requires
it. Android minimum is **24**, set by the platform decoder's use of
`MediaFormat.KEY_PCM_ENCODING`. Both are in the pubspec's transitive
requirements now, so lowering either one means dropping a dependency.

## The gate

> Would you pay for Pro if someone else shipped this? If hesitation, find the
> one missing thing, add only that, then ship.

Answer it on a phone, with a break you brought yourself, after step 3 and 4 are
done. Store submission is the exit of M3, not a separate milestone.
