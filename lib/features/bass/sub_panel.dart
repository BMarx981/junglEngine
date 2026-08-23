import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/sub_patch.dart';
import '../../state/studio.dart';
import '../../theme.dart';

/// What the five knobs are called, in order.
///
/// Synth parameter names, so they stay English in every locale: these are the
/// words printed on the panel of every hardware synth a producer has touched,
/// and translating them would make the instrument harder to read, not easier.
const List<String> subParameterLabels = [
  'TONE',
  'CUTOFF',
  'DRIVE',
  'DECAY',
  'GLIDE',
];

/// The sub synth's controls. All five of them.
///
/// Sine to triangle, one lowpass, drive, amp envelope, glide. The spec ceiling
/// is in CLAUDE.md and this sheet is the whole of it.
class SubPanel extends ConsumerWidget {
  const SubPanel({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: JungleTheme.surface,
    builder: (_) => const SubPanel(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patch = ref.watch(studioProvider.select((s) => s.beat.subPatch));
    final controller = ref.read(studioProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.subTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: JungleTheme.sub),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    controller.clearSub();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    context.l10n.subClearLane,
                    style: const TextStyle(
                      color: JungleTheme.hot,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            for (var i = 0; i < SubPatch.parameterCount; i++)
              _ParameterRow(
                label: subParameterLabels[i],
                value: patch.parameter(i),
                onChanged: (v) => controller.setSubParameter(i, v),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: JungleTheme.sub,
              inactiveTrackColor: JungleTheme.line,
              thumbColor: JungleTheme.sub,
              overlayColor: JungleTheme.sub.withValues(alpha: 0.14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            (value * 100).round().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: JungleTheme.textDim,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
