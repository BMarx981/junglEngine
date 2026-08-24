import 'dart:async';

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
///
/// The list is also a drop target: drag a chip out of the beat bank and the
/// arrangement opens a gap where it would land. That is the same edit the ADD
/// button makes, except the finger picks the position instead of it always
/// being the end.
class SongView extends ConsumerStatefulWidget {
  const SongView({super.key});

  @override
  ConsumerState<SongView> createState() => _SongViewState();
}

class _SongViewState extends ConsumerState<SongView> {
  /// A card plus the gap under it. Every card is the same height, so where a
  /// dropped Beat lands is arithmetic on the pointer rather than a question
  /// put to every card on screen.
  static const double _extent = _SongCard.height + _SongCard.gap;

  /// How near an edge the finger has to be before the list starts moving under
  /// it. Without this, an arrangement longer than the screen could not be
  /// dropped into at the bottom.
  static const double _edge = 56;
  static const double _edgeStep = 8;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _listKey = GlobalKey();

  /// Where a Beat held over the list would land, or null when nothing is over
  /// it. This is an index between cards, so it runs to [Song.length].
  int? _dropIndex;
  double _pointerY = 0;
  Timer? _edgeScroll;
  int _edgeDirection = 0;

  @override
  void dispose() {
    _stopEdgeScroll();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final song = state.song;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(bars: state.project.songBars, cards: song.length),
        Expanded(
          child: DragTarget<String>(
            // A chip carries a Beat id. A Beat deleted mid drag is not a drop
            // this list can honour, so it is refused rather than inserted as a
            // card that cannot draw itself.
            onWillAcceptWithDetails: (details) =>
                state.project.beatById(details.data) != null,
            onMove: (details) => _pointerMoved(details.offset),
            onLeave: (_) => _clearDrop(),
            onAcceptWithDetails: (details) {
              final index = _dropIndex ?? song.length;
              _clearDrop();
              HapticFeedback.mediumImpact();
              controller.insertIntoSong(details.data, index);
            },
            builder: (context, candidate, rejected) => Stack(
              key: _listKey,
              children: [
                Positioned.fill(
                  child: song.isEmpty
                      ? _Empty(open: _dropIndex != null)
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          scrollController: _scroll,
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
                if (_dropIndex != null && song.isNotEmpty) _dropLine(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The line drawn in the gap the dropped Beat would take. It sits in the
  /// list's own coordinates, so it has to be moved back by the scroll offset.
  Widget _dropLine() {
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    final height = _listHeight();
    final top = (_dropIndex! * _extent - offset - _SongCard.gap / 2 - 1).clamp(
      0.0,
      height > 2 ? height - 2 : 0.0,
    );
    return Positioned(left: 0, right: 0, top: top, child: const _DropLine());
  }

  double _listHeight() {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.height ?? 0;
  }

  void _pointerMoved(Offset globalPosition) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _pointerY = box.globalToLocal(globalPosition).dy;
    final index = _indexAt(_pointerY);
    if (index != _dropIndex) {
      // Every gap the finger crosses ticks, which is what makes a blind drop
      // land where it was meant to.
      HapticFeedback.selectionClick();
      setState(() => _dropIndex = index);
    }
    _runEdgeScroll(box.size.height);
  }

  int _indexAt(double y) {
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    final count = ref.read(studioProvider).song.length;
    // Rounding rather than truncating puts the boundary at a card's middle:
    // the top half of a card means before it, the bottom half after it.
    return ((offset + y) / _extent).round().clamp(0, count);
  }

  void _runEdgeScroll(double height) {
    final direction = _pointerY < _edge
        ? -1
        : (_pointerY > height - _edge ? 1 : 0);
    if (direction == _edgeDirection) return;
    _stopEdgeScroll();
    _edgeDirection = direction;
    if (direction == 0 || !_scroll.hasClients) return;
    _edgeScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) {
        _stopEdgeScroll();
        return;
      }
      final position = _scroll.position;
      final target = (position.pixels + direction * _edgeStep).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if (target == position.pixels) return;
      _scroll.jumpTo(target);
      // The finger has not moved but the cards have, so the gap it is over is
      // a different one.
      setState(() => _dropIndex = _indexAt(_pointerY));
    });
  }

  void _stopEdgeScroll() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
    _edgeDirection = 0;
  }

  void _clearDrop() {
    _stopEdgeScroll();
    if (_dropIndex == null) return;
    setState(() => _dropIndex = null);
  }
}

/// Where the Beat lands if the finger lets go now.
class _DropLine extends StatelessWidget {
  const _DropLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: JungleTheme.accent,
            borderRadius: BorderRadius.all(Radius.circular(1)),
          ),
        ),
      ),
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
  const _Empty({this.open = false});

  /// True while a Beat is held over the empty list. There is no gap to point
  /// at yet, so the whole area answers instead.
  final bool open;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: open ? JungleTheme.surface : null,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: open ? JungleTheme.accent : Colors.transparent,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            context.l10n.songEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
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

  /// Fixed, and the Song view depends on it staying fixed: a drop position is
  /// worked out from these two numbers rather than from the cards themselves.
  static const double height = 52;
  static const double gap = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studioProvider.notifier);
    final beat = this.beat;
    final bars = (beat?.bars ?? 0) * entry.repeats;

    return Padding(
      padding: const EdgeInsets.only(bottom: _SongCard.gap),
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
            height: _SongCard.height,
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
