import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/import/import_actions.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/models/kit_slot.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

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
    final imported = state.project.importedSlot(slot);

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
                  context.l10n.kitSlot(slot + 1),
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
              // VOL and PITCH are knob legends and stay English, matching
              // the hint on the kit grid that points at them.
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
            const SizedBox(height: 8),
            // Per slot, not per kit: replacing one hit is the thing people
            // actually want, and it leaves the other seven where the kit put
            // them. Volume and pitch belong to the Beat and stay put either way.
            Row(
              children: [
                Expanded(
                  child: _SlotButton(
                    label: imported == null
                        ? (ref.watch(proProvider).isPro
                              ? context.l10n.kitImportOneShot
                              : context.l10n.kitImportOneShotPro)
                        : context.l10n.kitReplace,
                    onTap: () => importSlot(context, ref, slot),
                  ),
                ),
                if (imported != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SlotButton(
                      label: context.l10n.kitUseKitSample,
                      onTap: () => controller.clearImportedSlot(slot),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined, like the import row in the library sheet: a door out of the sheet
/// rather than one of its controls.
class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: JungleTheme.accent),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: JungleTheme.accent,
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
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
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: JungleTheme.text),
          ),
        ),
      ],
    );
  }
}
