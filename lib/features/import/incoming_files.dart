import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/import/audio_import.dart';
import 'package:junglengine/features/import/break_import_screen.dart';
import 'package:junglengine/features/import/import_actions.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/state/studio.dart';

/// Audio handed to the app from outside it.
///
/// The app is registered for audio document types on both platforms, which puts
/// it in the Open In list in Files, Safari, Mail and the messengers. That is the
/// cheapest import path there is: the file is already in the user's hand and
/// they never see a picker.
///
/// The native side queues what arrives instead of pushing it, because a file
/// can turn up before the Flutter engine exists. This drains that queue on boot
/// and every time the app comes back to the foreground, which between them
/// cover every way a file can arrive.
const MethodChannel _channel = MethodChannel('junglengine/incoming');

/// Everything waiting, leaving the native queue empty.
///
/// A platform with nothing listening has nothing waiting, which is the same
/// answer, so both failures come back as an empty list rather than an error.
Future<List<String>> takeIncomingFiles() async {
  try {
    return await _channel.invokeListMethod<String>('takePending') ?? const [];
  } on MissingPluginException {
    return const [];
  } on PlatformException catch (error) {
    debugPrint('junglengine: incoming files unavailable (${error.message})');
    return const [];
  }
}

/// Watches for incoming audio and takes the first of it to the import screen.
///
/// Wraps the studio rather than living inside it, because what it needs is a
/// [Navigator] and a lifecycle, not anything the grid knows.
class IncomingFileWatcher extends ConsumerStatefulWidget {
  const IncomingFileWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<IncomingFileWatcher> createState() =>
      _IncomingFileWatcherState();
}

class _IncomingFileWatcherState extends ConsumerState<IncomingFileWatcher>
    with WidgetsBindingObserver {
  /// Guards against a resume landing while the import screen from the last one
  /// is still up. One file at a time: this is a break importer, not a queue.
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_drain()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Opening a file from another app always brings this one forward, so a
    // resume is the one moment worth looking.
    if (lifecycle == AppLifecycleState.resumed) unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_handling) return;
    final waiting = await takeIncomingFiles();
    if (waiting.isEmpty || !mounted) return;

    _handling = true;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      // A file arriving from another app is the best moment there is to explain
      // what Pro is: the thing the user wants is already in their hand.
      if (!await requirePro(context, ref) || !mounted) return;

      // Only the first. Someone selecting eight files meant to send them
      // somewhere else; a project has one break.
      final candidate = await decodeImportedPath(
        waiting.first,
        name: waiting.first.split('/').last,
        sampleRate: ref.read(audioEngineProvider).sampleRate,
      );
      if (!mounted) return;
      await BreakImportScreen.show(context, candidate);
    } on ImportException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(importFailureMessage(l10n, error.failure))),
      );
      debugPrint('junglengine: incoming import failed ($error)');
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed)));
      debugPrint('junglengine: incoming import failed ($error)');
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
