import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/engine.dart';
import '../../models/steps.dart';
import '../../state/studio.dart';
import '../../theme.dart';

/// Which bar of the open Beat the grid is showing.
///
/// A Beat can be eight bars long, which is 128 steps: too many to hit with a
/// thumb and too many to scroll past without losing your place. So the grid
/// always shows one bar and this pages it, and while the transport runs it
/// follows the playhead so the bar you are watching is the bar you are hearing.
///
/// Nothing is drawn for a one bar Beat: there is nothing to page.
class BarStrip extends ConsumerStatefulWidget {
  const BarStrip({super.key});

  static const double height = 26;

  @override
  ConsumerState<BarStrip> createState() => _BarStripState();
}

class _BarStripState extends ConsumerState<BarStrip> {
  ValueListenable<TransportState>? _transport;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final transport = ref.read(transportProvider);
    if (identical(transport, _transport)) return;
    _transport?.removeListener(_follow);
    _transport = transport..addListener(_follow);
  }

  @override
  void dispose() {
    _transport?.removeListener(_follow);
    super.dispose();
  }

  void _follow() {
    final transport = _transport;
    if (transport == null || !transport.value.playing || !mounted) return;
    ref
        .read(studioProvider.notifier)
        .setActiveBar(transport.value.step ~/ stepsPerBar);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final bars = state.beat.bars;
    if (bars <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: BarStrip.height,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('BAR', style: Theme.of(context).textTheme.labelSmall),
          ),
          for (var bar = 0; bar < bars; bar++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _BarChip(
                  bar: bar,
                  selected: bar == state.activeBar,
                  onTap: () =>
                      ref.read(studioProvider.notifier).setActiveBar(bar),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarChip extends StatelessWidget {
  const _BarChip({
    required this.bar,
    required this.selected,
    required this.onTap,
  });

  final int bar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? JungleTheme.surfaceHigh : JungleTheme.surface,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Text(
          '${bar + 1}',
          style: TextStyle(
            color: selected ? JungleTheme.accent : JungleTheme.textDim,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
