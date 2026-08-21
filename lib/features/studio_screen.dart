import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/studio.dart';
import '../theme.dart';
import 'bass/sub_lane_view.dart';
import 'grid/chop_grid.dart';
import 'transport/action_bar.dart';
import 'transport/transport_bar.dart';

/// The only screen there is.
///
/// Load break, slice, paint, loop, export. No settings, no onboarding, no
/// navigation. If something wants a second screen in M0, it does not ship.
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

class _Studio extends StatelessWidget {
  const _Studio();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransportBar(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: ChopGrid(),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: SubLaneView(),
        ),
        SizedBox(height: 6),
        ActionBar(),
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
