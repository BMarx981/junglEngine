import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // M1 gate is about whether the Kit machine earns its place, not about
    // inventing a second meaning for the button.
    final isKit = ref.watch(studioProvider.select((s) => s.beat.isKit));
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
          Expanded(
            child: _Action(
              icon: Icons.shuffle,
              label: 'SCRAMBLE',
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
              label: 'UNDO',
              enabled: canUndo,
              onTap: controller.undo,
            ),
          ),
          Expanded(
            child: _Action(
              icon: Icons.graphic_eq,
              label: 'SUB',
              color: JungleTheme.sub,
              onTap: () => SubPanel.show(context),
            ),
          ),
          Expanded(
            child: _Action(
              icon: Icons.ios_share,
              label: 'EXPORT',
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
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 8.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
