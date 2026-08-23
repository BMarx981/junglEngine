import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/beat.dart';
import '../../state/studio.dart';
import '../../theme.dart';
import 'new_beat_sheet.dart';

/// The beat bank.
///
/// Every Beat in the project, in order, with duplicate right next to them:
/// the workflow this is built around is make one, copy it, change two things.
/// Tap a chip to open that Beat, hold one to delete it.
///
/// This is the bank, not the Song: it is every Beat that exists, in the order
/// they were made. The button on the left is the way over to the arrangement,
/// which is where order and repeats are decided.
class BeatBar extends ConsumerWidget {
  const BeatBar({super.key});

  static const double height = 38;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);

    return Container(
      height: BeatBar.height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: JungleTheme.line)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 3, 6, 5),
      child: Row(
        children: [
          // The way between the grid and the arrangement, and back. It sits
          // next to the chips because the bank is the palette for both: in the
          // Song view, tapping a chip is choosing what the ADD button adds.
          _BankButton(
            icon: state.inSong ? Icons.grid_on : Icons.queue_music,
            label: state.inSong
                ? context.l10n.beatBarGrid
                : context.l10n.beatBarSong,
            onTap: () {
              HapticFeedback.selectionClick();
              controller.setView(
                state.inSong ? StudioView.pattern : StudioView.song,
              );
            },
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final beat in state.project.beats)
                  _BeatChip(
                    beat: beat,
                    selected: beat.id == state.activeBeatId,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.selectBeat(beat.id);
                    },
                    onHold: state.project.beats.length > 1
                        ? () => _confirmDelete(context, controller, beat)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _BankButton(
            icon: Icons.content_copy,
            label: context.l10n.beatBarDup,
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.duplicateActiveBeat();
            },
          ),
          const SizedBox(width: 4),
          _BankButton(
            icon: Icons.add,
            label: context.l10n.beatBarNew,
            onTap: () => NewBeatSheet.show(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    StudioController controller,
    Beat beat,
  ) async {
    HapticFeedback.mediumImpact();
    final delete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: JungleTheme.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                // Composed here rather than as one key: the separator is two
                // spaces, there is no grammar between the parts, and the
                // machine name is English in every locale.
                '${sheetContext.l10n.beatLabel(iso(beat.name.toUpperCase()))}  '
                '${machineTypeLabel(beat.machineType)}  '
                '${sheetContext.l10n.barCount(beat.bars)}',
                style: Theme.of(sheetContext).textTheme.labelMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: JungleTheme.hot,
                    foregroundColor: JungleTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(
                    sheetContext.l10n.beatBarDelete,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: Theme.of(
                        sheetContext,
                      ).textTheme.titleMedium?.letterSpacing,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (delete ?? false) controller.deleteBeat(beat.id);
  }
}

class _BeatChip extends StatelessWidget {
  const _BeatChip({
    required this.beat,
    required this.selected,
    required this.onTap,
    required this.onHold,
  });

  final Beat beat;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onHold;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? JungleTheme.background : JungleTheme.text;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onHold,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 5),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: selected ? JungleTheme.accent : JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              // The machine is fixed for the Beat's life, so it belongs on the
              // chip: which grid a tap opens should never be a surprise.
              beat.isKit ? Icons.grid_view : Icons.content_cut,
              size: 12,
              color: foreground,
            ),
            const SizedBox(width: 5),
            Text(
              beat.name,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${beat.bars}',
              style: TextStyle(
                color: selected
                    ? JungleTheme.background.withValues(alpha: 0.7)
                    : JungleTheme.textDim,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankButton extends StatelessWidget {
  const _BankButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: JungleTheme.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: JungleTheme.text),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: JungleTheme.text,
                fontSize: 9,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
