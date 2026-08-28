import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/import/import_actions.dart';
import 'package:junglengine/features/library/pack.dart';
import 'package:junglengine/features/pro/pro_controller.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

/// What the project is made of: one break and one kit.
///
/// Per Beat source selection is parked, so this is a project level choice and
/// there is exactly one of each. Changing the break re-points every Chop Beat
/// at the new source at the division it was already using; anything painted
/// past the end of a shorter break is dropped.
///
/// Content is grouped by pack, and a row from a Pro pack asks for money before
/// it will switch. The gate is here, on picking, and nowhere else: a project
/// already pointing at a pack break goes on playing it whatever the store says.
/// See `isLocked` in pack.dart for why.
class LibrarySheet extends ConsumerWidget {
  const LibrarySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: JungleTheme.surface,
    // Scroll controlled so the sheet is as tall as the library needs rather
    // than the 9/16 of the screen a plain one is capped at. It scrolls either
    // way, but with two packs in it the cap put the last kit below the fold,
    // and a row nobody scrolls to is a row nobody buys.
    //
    // Capped at 85% all the same, so there is always a strip of scrim to tap.
    // A sheet that reaches the top of a short phone can only be dismissed by a
    // swipe nobody told the user about, which is the state the sub editor grew
    // its close button to get out of.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => const LibrarySheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final isPro = ref.watch(proProvider).isPro;

    /// Picks something out of a pack, showing the paywall first when the pack
    /// is locked. Nothing changes if the user backs out of it.
    Future<void> pick(bool locked, Future<void> Function() apply) async {
      if (locked && !await requirePro(context, ref)) return;
      await apply();
    }

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
            Text(
              context.l10n.libraryBreak,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            for (final pack in PackLibrary.all)
              if (pack.breaks.isNotEmpty) ...[
                _PackHeading(pack.name),
                for (final ref_ in pack.breaks)
                  _Row(
                    title: ref_.name,
                    detail:
                        '${context.l10n.barCount(ref_.bars)}  '
                        '${ref_.bpm.round()} BPM',
                    selected: ref_.id == state.project.breakId,
                    locked: isLocked(pack, isPro: isPro),
                    onTap: () => pick(
                      isLocked(pack, isPro: isPro),
                      () => controller.setBreak(ref_.id),
                    ),
                  ),
              ],
            // The imported break sits in the same list as the bundled ones,
            // because by the time it is in the project it is just the break
            // this project uses. Importing a second one replaces it: still one
            // break per project. It belongs to no pack, because nothing the
            // user brought in is ever shipped.
            if (state.project.importedBreak case final imported?)
              _Row(
                title: imported.name,
                detail:
                    '${context.l10n.libraryYours}  '
                    '${context.l10n.barCount(imported.bars)}  '
                    '${imported.bpm.round()} BPM',
                selected: imported.id == state.project.breakId,
                onTap: () => controller.setBreak(imported.id),
              ),
            const SizedBox(height: 6),
            _ImportRow(
              label: state.project.importedBreak == null
                  ? context.l10n.libraryImportFirst
                  : context.l10n.libraryImportAnother,
              // Said before it is tapped, not after. A Pro feature that only
              // announces itself once you have reached for it is a trick.
              locked: !isPro,
              onTap: () => importBreak(context, ref),
            ),
            const SizedBox(height: 14),
            Text('KIT', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            for (final pack in PackLibrary.all)
              if (pack.kits.isNotEmpty) ...[
                _PackHeading(pack.name),
                for (final kit in pack.kits)
                  _Row(
                    title: kit.name,
                    detail: kit.samples.map((s) => s.label).take(3).join(' '),
                    selected: kit.id == state.project.kitId,
                    locked: isLocked(pack, isPro: isPro),
                    onTap: () => pick(
                      isLocked(pack, isPro: isPro),
                      () => controller.setKit(kit.id),
                    ),
                  ),
              ],
            const SizedBox(height: 10),
            Text(
              context.l10n.libraryNote,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The name of a pack, over the rows that came in it.
///
/// A proper noun, so it is not in the ARB files and is not translated, the same
/// way the app's own name is not.
class _PackHeading extends StatelessWidget {
  const _PackHeading(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 2),
      child: Text(
        name.toUpperCase(),
        style: const TextStyle(
          color: JungleTheme.textDim,
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
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
    this.locked = false,
  });

  final String title;
  final String detail;
  final bool selected;

  /// Whether tapping this asks for money. The tag goes on the row and not just
  /// on the pack heading, because the sheet scrolls and a heading that has gone
  /// off the top is not a warning.
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title_ = selected
        ? JungleTheme.background
        : (locked ? JungleTheme.textDim : JungleTheme.text);
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
                    color: title_,
                    fontSize: 13,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (locked && !selected) ...[
                const SizedBox(width: 8),
                const _ProTag(),
              ],
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  detail.toUpperCase(),
                  textAlign: TextAlign.end,
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
