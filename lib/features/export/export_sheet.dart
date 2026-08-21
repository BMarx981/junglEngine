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
            Text('LENGTH', style: Theme.of(context).textTheme.labelSmall),
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
              '${state.exportRepeats} bar'
              '${state.exportRepeats == 1 ? '' : 's'} at '
              '${state.project.bpm.round()} BPM, 44.1 kHz 16 bit',
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
