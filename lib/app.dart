import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/studio_screen.dart';
import 'state/studio.dart';
import 'theme.dart';

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'junglEngine',
      debugShowCheckedModeBanner: false,
      theme: JungleTheme.build(),
      home: const StudioScreen(),
    );
  }
}
