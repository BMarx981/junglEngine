import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/bass/sub_lane_view.dart';
import 'package:junglengine/features/grid/chop_grid.dart';
import 'package:junglengine/features/kit/kit_grid.dart';
import 'package:junglengine/features/song/beat_bar.dart';
import 'package:junglengine/features/song/song_view.dart';
import 'package:junglengine/features/transport/action_bar.dart';
import 'package:junglengine/features/transport/bar_strip.dart';
import 'package:junglengine/features/transport/transport_bar.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

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
          StudioStatus.loading => _Message(
            text: context.l10n.studioLoadingBreak,
          ),
          StudioStatus.failed => _Message(
            // The underlying error is a raw exception string in English, and in
            // a right to left layout it reads as debris. It goes to the log,
            // and on screen only while debugging.
            text: kDebugMode
                ? '${context.l10n.studioEngineFailed}\n\n'
                      '${ref.watch(studioProvider).errorMessage ?? ''}'
                : context.l10n.studioEngineFailed,
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
    final inSong = ref.watch(studioProvider.select((s) => s.inSong));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TransportBar(),
        // The bank is on screen in both views: on the grid it says what you are
        // editing, in the Song view it is the palette the arrangement is built
        // from, by the ADD button or by dragging a chip into the list.
        const BeatBar(),
        // The arrangement replaces the grid and the sub lane rather than
        // sitting on top of them: the Song view is about order and repeats, and
        // nothing on it is written a step at a time.
        if (inSong) ...[
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: SongView(),
            ),
          ),
        ] else ...[
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
        ],
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
