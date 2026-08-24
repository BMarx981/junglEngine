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
///
/// In the Song view the chips are also the arrangement's palette: drag one
/// down into the list to drop it between two cards, or tap it and let the ADD
/// button put it on the end.
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
          // Song view, a chip is both what the ADD button adds and something
          // you can drag straight into the arrangement.
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
                    // Chosen, but the bar it is waiting for has not ended yet.
                    // It blinks rather than saying so in words: this is a chip
                    // the width of two letters in twelve languages.
                    pending: beat.id == state.pendingBeatId,
                    // Only in the Song view is there anywhere to drop one. On
                    // the grid the chips are a selector and nothing else.
                    draggable: state.inSong,
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

class _BeatChip extends StatefulWidget {
  const _BeatChip({
    required this.beat,
    required this.selected,
    required this.pending,
    required this.draggable,
    required this.onTap,
    required this.onHold,
  });

  final Beat beat;
  final bool selected;

  /// Whether this Beat has been chosen and is waiting for the bar to end. See
  /// [StudioState.pendingBeatId].
  final bool pending;

  /// Whether the chip can be carried out of the bank and dropped into the
  /// arrangement. See [BeatBar].
  final bool draggable;

  final VoidCallback onTap;
  final VoidCallback? onHold;

  @override
  State<_BeatChip> createState() => _BeatChipState();
}

class _BeatChipState extends State<_BeatChip>
    with SingleTickerProviderStateMixin {
  /// The blink of a Beat that is waiting for the bar line. Runs only while
  /// something is waiting, which is never longer than a bar.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Built here rather than lazily: a chip that never blinked would otherwise
    // build one on the way out, from dispose, where there is no ticker to have.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    if (widget.pending) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BeatChip old) {
    super.didUpdateWidget(old);
    if (widget.pending == old.pending) return;
    if (widget.pending) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onHold,
      child: widget.pending
          ? AnimatedBuilder(animation: _pulse, builder: (_, _) => _body())
          : _body(),
    );
    if (!widget.draggable) return chip;
    return Draggable<String>(
      data: widget.beat.id,
      // Vertical only, for two reasons: the bank scrolls sideways and has to
      // keep every sideways drag, and the arrangement is a list, so the only
      // thing a drop decides is how far down it goes.
      axis: Axis.vertical,
      // The feedback hangs off the finger rather than under it, so the Beat
      // being carried stays visible and the pointer position the Song view
      // measures is exactly the pointer.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: _body()),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _body()),
      onDragStarted: HapticFeedback.selectionClick,
      child: chip,
    );
  }

  Widget _body() {
    final beat = widget.beat;
    final selected = widget.selected;
    // A Beat that is waiting borrows the selected chip's outline and blinks it,
    // which reads as about to happen without borrowing the fill: the filled
    // chip stays the one you are hearing.
    final border = widget.pending
        ? Color.lerp(JungleTheme.line, JungleTheme.accent, _pulse.value)!
        : (selected ? JungleTheme.accent : JungleTheme.line);
    final foreground = selected
        ? JungleTheme.background
        : (widget.pending ? JungleTheme.accent : JungleTheme.text);
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: selected ? JungleTheme.accent : JungleTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
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
