import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/step_mod.dart';
import '../../state/studio.dart';
import '../../theme.dart';

/// What a marked cell shows on the grid. One character, because a cell is about
/// as wide as a thumbnail and there is no room for a word.
String stepModGlyph(StepMod mod) => switch (mod) {
  StepMod.none => '',
  StepMod.reverse => 'R',
  StepMod.retrigger => '4',
  StepMod.pitchDown => '▼',
  StepMod.halfSpeed => '½',
};

/// The per step modifier picker, opened by holding a cell that has a slice on
/// it.
///
/// Four modifiers and off. These are the edits that used to mean cutting the
/// sample up by hand, and they are per step because that is where they are
/// heard: one reversed snare in a bar, not a reversed pattern.
class StepModSheet extends ConsumerWidget {
  const StepModSheet({required this.step, super.key});

  final int step;

  static Future<void> show(BuildContext context, int step) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: JungleTheme.surface,
        builder: (_) => StepModSheet(step: step),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final cell = state.beat.chop.stepAt(step);
    final slice = cell?.slice;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'STEP ${step % 16 + 1}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 10),
                Text(
                  slice == null ? 'EMPTY' : 'SLICE ${slice + 1}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final mod in StepMod.values)
              _Option(
                mod: mod,
                selected: (cell?.mod ?? StepMod.none) == mod,
                enabled: cell != null,
                onTap: () {
                  controller.setStepMod(step, mod);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.mod,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final StepMod mod;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? JungleTheme.background : JungleTheme.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? JungleTheme.accent : JungleTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? JungleTheme.accent : JungleTheme.line,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  stepModGlyph(mod),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                mod.isNone ? 'PLAIN' : mod.label,
                style: TextStyle(
                  color: enabled
                      ? foreground
                      : JungleTheme.textDim.withValues(alpha: 0.5),
                  fontSize: 13,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
