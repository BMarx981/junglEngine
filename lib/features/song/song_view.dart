import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/engine.dart';
import '../../l10n/l10n.dart';
import '../../models/beat.dart';
import '../../models/song.dart';
import '../../state/studio.dart';
import '../../theme.dart';

/// The arrangement: a vertical list of Beat cards, top to bottom, each with a
/// repeat count.
///
/// A list, not a timeline. There are no free positions, nothing overlaps and
/// nothing is measured in pixels per bar: a card follows the one above it and
/// plays the number of times its stepper says. Drag a card to move it, tap it
/// to open that Beat's grid.
class SongView extends ConsumerWidget {
  const SongView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final song = state.song;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(bars: state.project.songBars, cards: song.length),
        Expanded(
          child: song.isEmpty
              ? const _Empty()
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: song.length,
                  onReorderItem: (from, to) {
                    HapticFeedback.selectionClick();
                    controller.moveSongEntry(from, to);
                  },
                  itemBuilder: (context, index) {
                    final entry = song.entries[index];
                    return _SongCard(
                      key: ValueKey('${index}_${entry.beatId}'),
                      index: index,
                      entry: entry,
                      beat: state.project.beatForEntry(entry),
                      transport: ref.watch(transportProvider),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bars, required this.cards});

  final int bars;
  final int cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Row(
        children: [
          Text(
            context.l10n.songTitle,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: JungleTheme.accent),
          ),
          const Spacer(),
          Text(
            // Two counts side by side, joined by spacing rather than grammar,
            // so they stay two keys. One key with two nested plurals would be
            // a trap for every translator who opened it.
            '${context.l10n.cardCount(cards)}   ${context.l10n.barCount(bars)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Text(
          context.l10n.songEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

/// One card. The Beat it points at, how many times it plays, and the two
/// gestures that matter: drag to move, tap to open.
class _SongCard extends ConsumerWidget {
  const _SongCard({
    required this.index,
    required this.entry,
    required this.beat,
    required this.transport,
    super.key,
  });

  final int index;
  final SongEntry entry;

  /// Null when the entry points at a Beat that has been deleted. That should
  /// not happen, because deleting a Beat prunes the song, but a card that
  /// cannot draw itself is better than a screen that will not build.
  final Beat? beat;

  final ValueListenable<TransportState> transport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studioProvider.notifier);
    final beat = this.beat;
    final bars = (beat?.bars ?? 0) * entry.repeats;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ValueListenableBuilder(
        valueListenable: transport,
        builder: (context, state, child) {
          final playing = state.playing && state.entryIndex == index;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: playing ? JungleTheme.surfaceHigh : JungleTheme.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: playing ? JungleTheme.accent : JungleTheme.line,
              ),
            ),
            child: child,
          );
        },
        // The card's own row is locked: the drag handle, the beat, the repeat
        // stepper and the remove button keep one order everywhere, so the
        // stepper's minus never swaps sides with its plus. The header, the
        // empty state and the bar below all mirror normally.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: JungleTheme.textDim,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: beat == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            controller.openBeatFromSong(beat.id);
                          },
                    child: Row(
                      children: [
                        Icon(
                          beat == null
                              ? Icons.help_outline
                              : (beat.isKit
                                    ? Icons.grid_view
                                    : Icons.content_cut),
                          size: 14,
                          color: JungleTheme.text,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          beat?.name ?? '?',
                          style: const TextStyle(
                            color: JungleTheme.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.barCount(bars),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                _Stepper(
                  repeats: entry.repeats,
                  onChanged: (value) => controller.setSongRepeats(index, value),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    controller.removeSongEntry(index);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close, size: 16, color: JungleTheme.hot),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How many times the card plays. A stepper rather than a field: this is a
/// number between one and sixteen and it gets set with a thumb.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.repeats, required this.onChanged});

  final int repeats;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          enabled: repeats > SongEntry.minRepeats,
          onTap: () => onChanged(repeats - 1),
        ),
        SizedBox(
          width: 30,
          child: Text(
            // The multiplier x is notation, not a word, and it is read the
            // same way in every locale this ships to.
            '${repeats}x',
            textAlign: TextAlign.center,
            style: JungleTheme.readout(
              fontSize: 14,
              color: JungleTheme.text,
              height: 1,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          enabled: repeats < SongEntry.maxRepeats,
          onTap: () => onChanged(repeats + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: JungleTheme.line),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled
              ? JungleTheme.text
              : JungleTheme.textDim.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
