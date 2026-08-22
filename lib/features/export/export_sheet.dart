import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../state/studio.dart';
import '../../theme.dart';
import 'wav_export.dart';

/// Renders the loop to a WAV and hands it to the share sheet.
///
/// One to eight bars, because the point is to drop the loop into whatever you
/// actually finish tracks in.
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
    final song = state.exportMode == ExportMode.song;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'EXPORT WAV',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'LOOP',
                    detail: 'BEAT ${state.beat.name.toUpperCase()}',
                    selected: !song,
                    enabled: true,
                    onTap: () => controller.setExportMode(ExportMode.loop),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label: 'SONG',
                    detail: songBars == 0
                        ? 'NOTHING ARRANGED'
                        : '$songBars BARS',
                    selected: song,
                    // Nothing to render until the arrangement has a card on it.
                    enabled: songBars > 0,
                    onTap: () => controller.setExportMode(ExportMode.song),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!song) ...[
              Text('REPEATS', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final bars in exportBarChoices)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
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
                    : const Text(
                        'RENDER AND SHARE',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song
                  ? 'The whole arrangement, $songBars bars at '
                        '${state.project.bpm.round()} BPM, 44.1 kHz 16 bit'
                  : '${state.exportRepeats * state.beat.bars} bar'
                        '${state.exportRepeats * state.beat.bars == 1 ? '' : 's'}'
                        ' at ${state.project.bpm.round()} BPM, '
                        '44.1 kHz 16 bit',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    StudioController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await controller.exportWav();
      if (result == null) return;
      navigator.pop();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.file.path, mimeType: 'audio/wav')],
          text: result.fileName,
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }
}

/// Loop or song. Two things to render and no third: a loop for the sampler you
/// finish tracks in, an arrangement for the clip you post.
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
