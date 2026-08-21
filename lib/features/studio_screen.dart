import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/studio.dart';
import '../theme.dart';
import 'bass/sub_lane_view.dart';
import 'grid/chop_grid.dart';
import 'kit/kit_grid.dart';
import 'song/beat_bar.dart';
import 'transport/action_bar.dart';
import 'transport/bar_strip.dart';
import 'transport/transport_bar.dart';

/// The only screen there is.
///
/// Load break, pick a machine, paint, loop, export. No settings, no onboarding,
/// no navigation: the beat bank swaps what the grid is showing, it does not
/// push a page.
class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(studioProvider.select((s) => s.status));

    return Scaffold(
      body: SafeArea(
        child: switch (status) {
          StudioStatus.loading => const _Message(text: 'LOADING BREAK'),
          StudioStatus.failed => _Message(
            text:
                'AUDIO ENGINE FAILED\n\n'
                '${ref.watch(studioProvider).errorMessage ?? ''}',
            color: JungleTheme.hot,
          ),
          StudioStatus.ready => const _Studio(),
        },
      ),
    );
  }
}

class _Studio extends ConsumerWidget {
  const _Studio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Which machine the open Beat runs decides the grid, and nothing else on
    // the screen. Transport, sub lane and export are shared by both.
    final isKit = ref.watch(studioProvider.select((s) => s.beat.isKit));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TransportBar(),
        const BeatBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: isKit ? const KitGrid() : const ChopGrid(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: BarStrip(),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: SubLaneView(),
        ),
        const SizedBox(height: 6),
        const ActionBar(),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.color = JungleTheme.textDim});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 12,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
