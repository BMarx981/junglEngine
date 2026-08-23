import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/studio.dart';
import '../../theme.dart';
import '../bass/sub_panel.dart';
import '../export/export_sheet.dart';

/// Everything you press while a loop is running, in thumb reach.
class ActionBar extends ConsumerWidget {
  const ActionBar({super.key});

  static const double height = 62;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studioProvider.notifier);
    final canUndo = ref.watch(studioProvider.select((s) => s.canUndo));
    // Scramble rearranges slices of a break. A Kit Beat has no slices, and the
    // M1 gate was about whether the Kit machine earns its place, not about
    // inventing a second meaning for the button.
    final isKit = ref.watch(studioProvider.select((s) => s.beat.isKit));
    final inSong = ref.watch(studioProvider.select((s) => s.inSong));
    final beatName = ref.watch(studioProvider.select((s) => s.beat.name));
    final transport = ref.watch(transportProvider);

    return Container(
      height: height,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: JungleTheme.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          ValueListenableBuilder(
            valueListenable: transport,
            builder: (context, state, _) => _PlayButton(
              playing: state.playing,
              onTap: () {
                HapticFeedback.mediumImpact();
                controller.togglePlay();
              },
            ),
          ),
          const SizedBox(width: 8),
          // The Song view is the same instrument doing a different job, so the
          // bar swaps what it offers rather than greying half of itself out.
          // Play stays where it is either way.
          if (inSong) ...[
            Expanded(
              flex: 2,
              child: _Action(
                icon: Icons.playlist_add,
                label: context.l10n.actionAddBeat(iso(beatName)),
                color: JungleTheme.accent,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  controller.addToSong();
                },
              ),
            ),
          ] else ...[
            Expanded(
              child: _Action(
                icon: Icons.shuffle,
                label: context.l10n.actionScramble,
                enabled: !isKit,
                color: JungleTheme.hot,
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.scramble();
                },
              ),
            ),
            Expanded(
              child: _Action(
                icon: Icons.undo,
                label: context.l10n.actionUndo,
                enabled: canUndo,
                onTap: controller.undo,
              ),
            ),
          ],
          Expanded(
            child: _Action(
              icon: Icons.graphic_eq,
              // SUB stays English: it labels the lane and the synth panel too,
              // and all three have to read as the same thing.
              label: 'SUB',
              color: JungleTheme.sub,
              // Still the open Beat's synth in the Song view, which is the
              // right thing to reach for while an arrangement is running.
              onTap: () => SubPanel.show(context),
            ),
          ),
          Expanded(
            child: _Action(
              icon: Icons.ios_share,
              label: context.l10n.actionExport,
              onTap: () => ExportSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        decoration: BoxDecoration(
          color: playing ? JungleTheme.accent : JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: playing ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Icon(
          playing ? Icons.stop : Icons.play_arrow,
          size: 30,
          color: playing ? JungleTheme.background : JungleTheme.accent,
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = JungleTheme.text,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? color : JungleTheme.textDim.withValues(alpha: 0.4);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: tint),
          const SizedBox(height: 3),
          // Five buttons share the width, and SCRAMBLE is already most of what
          // fits. Translations run longer, so the label shrinks to fit rather
          // than breaking the row. Scaling down keeps the geometry identical
          // in every locale, which clipping or wrapping would not.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: tint,
                fontSize: 8.5,
                letterSpacing: Theme.of(
                  context,
                ).textTheme.titleMedium?.letterSpacing,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
