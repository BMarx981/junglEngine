import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:junglengine/features/export/slices_export.dart';
import 'package:junglengine/features/export/wav_export.dart';
import 'package:junglengine/features/import/import_actions.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

/// Three ways out, and no fourth.
///
/// A loop for the sampler you finish tracks in, an arrangement for the clip you
/// post, and the parts for when you want to take the beat apart somewhere with
/// a mouse. All three go straight to the share sheet: this app has no file
/// browser and does not want one.
class ExportSheet extends ConsumerWidget {
  const ExportSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: JungleTheme.surface,
    isDismissible: true,
    builder: (_) => const ExportSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final songBars = state.project.songBars;
    final mode = state.exportMode;
    final song = mode == ExportMode.song;
    final parts = mode == ExportMode.parts;
    final isPro = ref.watch(proProvider).isPro;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              parts
                  ? context.l10n.exportTitleParts
                  : context.l10n.exportTitleWav,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: context.l10n.exportModeLoop,
                    detail: context.l10n.beatLabel(
                      iso(state.beat.name.toUpperCase()),
                    ),
                    selected: mode == ExportMode.loop,
                    enabled: true,
                    onTap: () => controller.setExportMode(ExportMode.loop),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label: context.l10n.exportModeSong,
                    detail: songBars == 0
                        ? context.l10n.exportNothingArranged
                        : context.l10n.barCount(songBars),
                    selected: song,
                    // Nothing to render until the arrangement has a card on it.
                    enabled: songBars > 0,
                    onTap: () => controller.setExportMode(ExportMode.song),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // MIDI and the samples that play it, for finishing the track
                  // somewhere else. One Beat, because what a sampler wants is
                  // one instrument.
                  child: _ModeChip(
                    label: context.l10n.exportModeParts,
                    // PRO is the product name and stays English.
                    detail: isPro ? context.l10n.exportMidiSlices : 'PRO',
                    selected: parts,
                    enabled: true,
                    onTap: () => _chooseParts(context, ref, controller),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (mode == ExportMode.loop) ...[
              Text(
                context.l10n.exportRepeats,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final bars in exportBarChoices)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _BarChip(
                          bars: bars,
                          selected: bars == state.exportRepeats,
                          onTap: () => controller.setExportRepeats(bars),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: JungleTheme.accent,
                  foregroundColor: JungleTheme.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: state.exporting
                    ? null
                    : () => _export(context, controller),
                child: state.exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: JungleTheme.background,
                        ),
                      )
                    : Text(
                        parts
                            ? context.l10n.exportBuild
                            : context.l10n.exportRender,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: Theme.of(
                            context,
                          ).textTheme.titleMedium?.letterSpacing,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              // Body copy, so these read as sentences rather than as the
              // uppercase labels above them. The bar counts come from
              // barCountSentence for the same reason.
              switch (mode) {
                ExportMode.song => context.l10n.exportSongDetail(
                  context.l10n.barCountSentence(songBars),
                  state.project.bpm.round(),
                ),
                ExportMode.parts => context.l10n.exportPartsDetail(
                  iso(state.beat.name.toUpperCase()),
                  state.beat.isKit
                      ? context.l10n.exportPartsKit
                      : context.l10n.exportPartsSlices,
                  baseNote,
                ),
                ExportMode.loop => context.l10n.exportLoopDetail(
                  context.l10n.barCountSentence(
                    state.exportRepeats * state.beat.bars,
                  ),
                  state.project.bpm.round(),
                ),
              },
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Selecting the parts mode is where the Pro gate sits, rather than on the
  /// export button: finding out it is Pro after choosing what to render, and
  /// only when you press go, is the wrong order to learn it in.
  Future<void> _chooseParts(
    BuildContext context,
    WidgetRef ref,
    StudioController controller,
  ) async {
    if (!await requirePro(context, ref)) return;
    controller.setExportMode(ExportMode.parts);
  }

  Future<void> _export(
    BuildContext context,
    StudioController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    try {
      final result = await controller.exportWav();
      if (result == null) return;
      navigator.pop();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              result.file.path,
              mimeType: result.fileName.endsWith('.zip')
                  ? 'application/zip'
                  : 'audio/wav',
            ),
          ],
          text: result.fileName,
        ),
      );
    } on Object catch (error) {
      // The exception itself goes to the log, not the snack bar: it is an
      // untranslated English string and often a stack fragment.
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
      debugPrint('junglengine: export failed ($error)');
    }
  }
}

/// Loop, song or parts.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.detail,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? JungleTheme.background
        : (enabled ? JungleTheme.text : JungleTheme.textDim);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? JungleTheme.accent : JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? JungleTheme.background.withValues(alpha: 0.7)
                    : JungleTheme.textDim,
                fontSize: 7.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChip extends StatelessWidget {
  const _BarChip({
    required this.bars,
    required this.selected,
    required this.onTap,
  });

  final int bars;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? JungleTheme.accent : JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Text(
          '$bars',
          style: TextStyle(
            color: selected ? JungleTheme.background : JungleTheme.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
