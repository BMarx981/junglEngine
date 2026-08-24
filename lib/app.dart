import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/import/incoming_files.dart';
import 'package:junglengine/features/studio_screen.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

/// Forces a locale in debug builds, so one device can be walked through all
/// twelve without the app growing a language picker it does not want.
/// Empty in every release build, because nothing passes the define there.
const String _localeOverride = String.fromEnvironment('JE_LOCALE');

class JungleApp extends ConsumerStatefulWidget {
  const JungleApp({super.key});

  @override
  ConsumerState<JungleApp> createState() => _JungleAppState();
}

class _JungleAppState extends ConsumerState<JungleApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // The block feeder cannot keep a stream fed while the app is backgrounded,
    // so stop rather than let it underrun and stutter on return.
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      ref.read(audioEngineProvider).stop();
      // Backgrounding is the last moment there reliably is: the OS can kill the
      // app from the switcher without another callback.
      ref.read(studioProvider.notifier).flushSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: junglengineLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: kDebugMode && _localeOverride.isNotEmpty
          ? Locale(_localeOverride)
          : null,
      // MaterialApp resolves the locale below this widget, so `theme:` cannot
      // see it. Arabic needs the letter spacing off or its letters stop
      // joining, and CJK does not want the tracking either.
      builder: (context, child) => Theme(
        data: JungleTheme.build(Localizations.localeOf(context)),
        child: child!,
      ),
      // Wrapped rather than built in, because taking in a file that another app
      // handed over needs a Navigator and a lifecycle, not anything the studio
      // knows about.
      home: const IncomingFileWatcher(child: StudioScreen()),
    );
  }
}
