import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/studio.dart';
import '../../theme.dart';
import '../import/import_actions.dart';
import '../pro/pro_controller.dart';
import 'break_library.dart';
import 'kit_library.dart';

/// What the project is made of: one break and one kit.
///
/// Per Beat source selection is parked, so this is a project level choice and
/// there is exactly one of each. Changing the break re-points every Chop Beat
/// at the new source at the division it was already using; anything painted
/// past the end of a shorter break is dropped.
class LibrarySheet extends ConsumerWidget {
  const LibrarySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: JungleTheme.surface,
    builder: (_) => const LibrarySheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);

    return SafeArea(
      top: false,
      // Scrolls, because the library only ever grows and a sheet that cannot
      // reach its last row is a break you cannot pick.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('BREAK', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            for (final ref_ in BreakLibrary.bundled)
              _Row(
                title: ref_.name,
                detail:
                    '${ref_.bars} BAR${ref_.bars == 1 ? '' : 'S'}  '
                    '${ref_.bpm.round()} BPM',
                selected: ref_.id == state.project.breakId,
                onTap: () => controller.setBreak(ref_.id),
              ),
            // The imported break sits in the same list as the bundled ones,
            // because by the time it is in the project it is just the break
            // this project uses. Importing a second one replaces it: still one
            // break per project.
            if (state.project.importedBreak case final imported?)
              _Row(
                title: imported.name,
                detail:
                    'YOURS  ${imported.bars} BAR'
                    '${imported.bars == 1 ? '' : 'S'}  '
                    '${imported.bpm.round()} BPM',
                selected: imported.id == state.project.breakId,
                onTap: () => controller.setBreak(imported.id),
              ),
            const SizedBox(height: 6),
            _ImportRow(
              label: state.project.importedBreak == null
                  ? 'IMPORT YOUR OWN'
                  : 'IMPORT ANOTHER',
              // Said before it is tapped, not after. A Pro feature that only
              // announces itself once you have reached for it is a trick.
              locked: !ref.watch(proProvider).isPro,
              onTap: () => importBreak(context, ref),
            ),
            const SizedBox(height: 14),
            Text('KIT', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            for (final kit in KitLibrary.bundled)
              _Row(
                title: kit.name,
                detail: kit.samples.map((s) => s.label).take(3).join(' '),
                selected: kit.id == state.project.kitId,
                onTap: () => controller.setKit(kit.id),
              ),
            const SizedBox(height: 10),
            Text(
              'ONE BREAK AND ONE KIT PER PROJECT. CHANGING THE BREAK KEEPS '
              'YOUR PATTERNS.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bring your own audio. Outlined rather than filled, because it is a door out
/// of the list rather than another thing in it.
class _ImportRow extends StatelessWidget {
  const _ImportRow({
    required this.label,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: JungleTheme.accent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: JungleTheme.accent, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: JungleTheme.accent,
                fontSize: 12,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (locked) ...[const SizedBox(width: 8), const _ProTag()],
          ],
        ),
      ),
    );
  }
}

/// Three letters, on anything that will ask for money when it is tapped.
class _ProTag extends StatelessWidget {
  const _ProTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: JungleTheme.accent,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: JungleTheme.background,
          fontSize: 9,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? JungleTheme.background : JungleTheme.text,
                    fontSize: 13,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  detail.toUpperCase(),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? JungleTheme.background.withValues(alpha: 0.75)
                        : JungleTheme.textDim,
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
