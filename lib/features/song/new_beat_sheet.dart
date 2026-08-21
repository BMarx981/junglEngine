import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/beat.dart';
import '../../models/machine_type.dart';
import '../../state/studio.dart';
import '../../theme.dart';

/// The two choices that are fixed for a Beat's lifetime: which machine it runs
/// and how long it is.
///
/// They are asked once, here, because both of them decide the shape of the
/// pattern data. Changing either afterwards would mean throwing away what was
/// written on it.
class NewBeatSheet extends ConsumerStatefulWidget {
  const NewBeatSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: JungleTheme.surface,
    builder: (_) => const NewBeatSheet(),
  );

  @override
  ConsumerState<NewBeatSheet> createState() => _NewBeatSheetState();
}

class _NewBeatSheetState extends ConsumerState<NewBeatSheet> {
  MachineType _machine = MachineType.chop;
  int _bars = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('NEW BEAT', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 14),
            Text('MACHINE', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _Choice(
                    label: 'CHOP',
                    detail: 'RESEQUENCE THE BREAK',
                    selected: _machine == MachineType.chop,
                    onTap: () => setState(() => _machine = MachineType.chop),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Choice(
                    label: 'KIT',
                    detail: 'EIGHT ONE SHOTS',
                    selected: _machine == MachineType.kit,
                    onTap: () => setState(() => _machine = MachineType.kit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('LENGTH', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final bars in allowedBarLengths)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Choice(
                        label: '$bars',
                        detail: bars == 1 ? 'BAR' : 'BARS',
                        selected: bars == _bars,
                        onTap: () => setState(() => _bars = bars),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: JungleTheme.accent,
                  foregroundColor: JungleTheme.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  ref.read(studioProvider.notifier).addBeat(_machine, _bars);
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'CREATE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? JungleTheme.accent : JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? JungleTheme.background : JungleTheme.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? JungleTheme.background.withValues(alpha: 0.7)
                    : JungleTheme.textDim,
                fontSize: 7.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
