import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/beat.dart';
import '../../state/studio.dart';
import '../../theme.dart';

/// Tempo and slice division. The two settings that change how everything else
/// sounds, so they live at the top and nowhere else.
class TransportBar extends ConsumerWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: JungleTheme.line)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'jungl',
                style: TextStyle(
                  color: JungleTheme.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Text(
                'Engine',
                style: TextStyle(
                  color: JungleTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                state.breakRef.name.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: ref.read(studioProvider.notifier).clearPattern,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'CLEAR',
                    style: TextStyle(
                      color: JungleTheme.hot,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _BpmControl(),
              const SizedBox(width: 14),
              Expanded(child: _SliceSelector(division: state.sliceDivision)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Drag sideways to change tempo. A slider would eat the width and a text field
/// would mean a keyboard.
class _BpmControl extends ConsumerStatefulWidget {
  const _BpmControl();

  @override
  ConsumerState<_BpmControl> createState() => _BpmControlState();
}

class _BpmControlState extends ConsumerState<_BpmControl> {
  double _accumulated = 0;

  @override
  Widget build(BuildContext context) {
    final bpm = ref.watch(studioProvider.select((s) => s.project.bpm));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _accumulated = 0,
      onHorizontalDragUpdate: (details) {
        // Roughly one BPM per four logical pixels of travel.
        _accumulated += details.delta.dx / 4;
        final whole = _accumulated.truncate();
        if (whole == 0) return;
        _accumulated -= whole;
        ref.read(studioProvider.notifier).setBpm(bpm + whole);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('BPM', style: Theme.of(context).textTheme.labelSmall),
          Text(
            bpm.round().toString().padLeft(3),
            style: const TextStyle(
              color: JungleTheme.text,
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliceSelector extends ConsumerWidget {
  const _SliceSelector({required this.division});

  /// Slices per bar, not slices in total. See [allowedSliceDivisions].
  final int division;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('SLICES', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        Row(
          children: [
            for (final count in allowedSliceDivisions)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _SliceChip(
                  count: count,
                  selected: count == division,
                  onTap: () =>
                      ref.read(studioProvider.notifier).setSliceDivision(count),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SliceChip extends StatelessWidget {
  const _SliceChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? JungleTheme.accent : JungleTheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: selected ? JungleTheme.background : JungleTheme.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
