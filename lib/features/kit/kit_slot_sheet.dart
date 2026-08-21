import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/kit_slot.dart';
import '../../state/studio.dart';
import '../../theme.dart';

/// One Kit slot's controls: volume and pitch.
///
/// That is the whole of it. No per slot effects, no choke group, no second
/// page. See the Kit machine spec in CLAUDE.md.
class KitSlotSheet extends ConsumerWidget {
  const KitSlotSheet({required this.slot, super.key});

  final int slot;

  static Future<void> show(BuildContext context, int slot) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: JungleTheme.surface,
        builder: (_) => KitSlotSheet(slot: slot),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final settings = state.beat.slot(slot);

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
                  state.kitRef.labelAt(slot),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  'SLOT ${slot + 1}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => controller.auditionKitSlot(slot),
                  icon: const Icon(
                    Icons.play_arrow,
                    color: JungleTheme.accent,
                    size: 22,
                  ),
                ),
              ],
            ),
            _Row(
              label: 'VOL',
              value: settings.volume,
              display: '${(settings.volume * 100).round()}',
              onChanged: (v) => controller.setSlotVolume(slot, v),
              onSettled: () => controller.auditionKitSlot(slot),
            ),
            _Row(
              label: 'PITCH',
              value:
                  (settings.pitch - KitSlot.minPitch) /
                  (KitSlot.maxPitch - KitSlot.minPitch),
              display: settings.pitch > 0
                  ? '+${settings.pitch}'
                  : '${settings.pitch}',
              divisions: KitSlot.maxPitch - KitSlot.minPitch,
              onChanged: (v) => controller.setSlotPitch(
                slot,
                (KitSlot.minPitch + v * (KitSlot.maxPitch - KitSlot.minPitch))
                    .round(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.display,
    required this.onChanged,
    this.divisions,
    this.onSettled,
  });

  final String label;
  final double value;
  final String display;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final VoidCallback? onSettled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: JungleTheme.accent,
              inactiveTrackColor: JungleTheme.line,
              thumbColor: JungleTheme.accent,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onSettled == null ? null : (_) => onSettled!(),
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: JungleTheme.text),
          ),
        ),
      ],
    );
  }
}
