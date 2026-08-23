import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/studio.dart';
import '../../theme.dart';
import '../pro/paywall.dart';
import '../pro/pro_controller.dart';
import 'audio_import.dart';
import 'break_import_screen.dart';

/// The two ways audio gets into a project, from the buttons that start them.
///
/// Both are the same three steps: pick, decode, place. Decoding is seconds of
/// work on a phone, so both put a spinner up while it happens, because an
/// import that looks like nothing happened gets tapped again.

/// Picks a file, trims it, and makes it the project break.
///
/// Returns true when a break was actually imported, which is not the same as
/// the user having picked a file: they can still back out of the trim screen.
Future<bool> importBreak(BuildContext context, WidgetRef ref) async {
  if (!await requirePro(context, ref)) return false;
  if (!context.mounted) return false;
  final candidate = await _pickAndDecode(context, ref);
  if (candidate == null || !context.mounted) return false;
  return BreakImportScreen.show(context, candidate);
}

/// The gate in front of every Pro feature.
///
/// Shows the paywall at the moment someone reaches for the thing, which is the
/// only moment it is worth showing, and returns whether they came out of it
/// with Pro. Buying is the whole of it: there is no trial and no metering.
Future<bool> requirePro(BuildContext context, WidgetRef ref) async {
  if (ref.read(proProvider).isPro) return true;
  return Paywall.show(context);
}

/// Picks a file and puts it in a Kit slot.
///
/// No trim screen: a one shot is one hit, so it is trimmed at both ends,
/// levelled and dropped straight in. The slot plays it as soon as it lands,
/// which is the only confirmation this needs.
Future<bool> importSlot(BuildContext context, WidgetRef ref, int slot) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await requirePro(context, ref)) return false;
  if (!context.mounted) return false;
  final candidate = await _pickAndDecode(context, ref);
  if (candidate == null) return false;
  try {
    await ref.read(studioProvider.notifier).importSlotSample(slot, candidate);
    return true;
  } on Object catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $error')));
    return false;
  }
}

/// Opens the picker, then decodes what comes back behind a spinner.
///
/// Returns null when the user backed out, which is not a failure and puts
/// nothing on screen.
Future<ImportCandidate?> _pickAndDecode(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final sampleRate = ref.read(audioEngineProvider).sampleRate;

  final picked = await _guarded(messenger, chooseAudioFile);
  if (picked == null || !context.mounted) return null;

  // An overlay entry rather than a dialog. Putting it up and taking it down are
  // both synchronous and both name the thing they act on, where popping a route
  // means popping whatever is on top: the sheet this was started from, if the
  // dialog had not finished building yet.
  final overlay = Overlay.of(context, rootOverlay: true);
  final busy = OverlayEntry(builder: (_) => const _ImportBusy());
  overlay.insert(busy);
  try {
    return await _guarded(
      messenger,
      () => decodePicked(picked, sampleRate: sampleRate),
    );
  } finally {
    busy.remove();
  }
}

/// Runs [action], turning the two things that go wrong into a snack bar.
///
/// A file that will not decode says so in its own words, because "unsupported
/// format" and "that file is too short to chop" send the user to different
/// next moves.
Future<T?> _guarded<T>(
  ScaffoldMessengerState messenger,
  Future<T?> Function() action,
) async {
  try {
    return await action();
  } on ImportException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return null;
  } on Object catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $error')));
    return null;
  }
}

/// A spinner over the whole screen while a file is decoded, and a barrier under
/// it so nothing gets tapped twice while it is up.
class _ImportBusy extends StatelessWidget {
  const _ImportBusy();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ModalBarrier(
        color: JungleTheme.background.withValues(alpha: 0.82),
        dismissible: false,
      ),
      const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: JungleTheme.accent,
          ),
        ),
      ),
    ],
  );
}
