import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sub_patch.dart';
import '../../state/studio.dart';
import '../../theme.dart';

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
                  'SUB SYNTH',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: JungleTheme.sub,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    controller.clearSub();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'CLEAR LANE',
                    style: TextStyle(
                      color: JungleTheme.hot,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            for (var i = 0; i < SubPatch.parameterNames.length; i++)
              _ParameterRow(
                label: SubPatch.parameterNames[i],
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
            textAlign: TextAlign.right,
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
