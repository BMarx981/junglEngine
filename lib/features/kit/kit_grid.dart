import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/kit_pattern.dart';
import '../../models/kit_ref.dart';
import '../../models/steps.dart';
import '../../state/studio.dart';
import '../../theme.dart';
import '../transport/playhead_painter.dart';
import 'kit_slot_sheet.dart';

/// The Kit machine: eight one shot slots down, sixteen steps across.
///
/// Tap a cell to place a hit and tap again to walk it down: hard, medium, soft,
/// gone. Drag sideways to write that same level across a run, which also means
/// a drag that starts on a soft cell erases.
class KitGrid extends ConsumerStatefulWidget {
  const KitGrid({super.key});

  static const double gutterWidth = 46;
  static const double headerHeight = 18;
  static const double minRowHeight = 30;
  static const double maxRowHeight = 64;

  @override
  ConsumerState<KitGrid> createState() => _KitGridState();
}

class _KitGridState extends ConsumerState<KitGrid> {
  /// The level a drag is writing. Taken from the cell the drag started on, so
  /// one gesture never mixes levels.
  KitVelocity? _paintVelocity;
  bool _painting = false;
  int? _lastSlot;
  int? _lastStep;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final beat = state.beat;
    final transport = ref.watch(transportProvider);
    final windowStart = state.windowStart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: KitGrid.headerHeight,
          child: Row(
            children: [
              Text('KIT', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              // Shrinks rather than overflowing, for the same reason as the
              // sub lane hint above the bass: it is the longest string in the
              // row and the one that matters least.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    context.l10n.kitHint,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        // The pads are a time axis, so they stay left to right even in Arabic.
        // Only the body: the header above is a label and a hint, and mirrors
        // with the rest of the chrome.
        Expanded(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rowHeight = (constraints.maxHeight / kitSlotCount).clamp(
                  KitGrid.minRowHeight,
                  KitGrid.maxRowHeight,
                );
                final cellWidth =
                    (constraints.maxWidth - KitGrid.gutterWidth) / stepsPerBar;

                return SingleChildScrollView(
                  child: SizedBox(
                    height: rowHeight * kitSlotCount,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SlotGutter(
                          kitRef: state.kitRef,
                          rowHeight: rowHeight,
                          onTap: (slot) => ref
                              .read(studioProvider.notifier)
                              .auditionKitSlot(slot),
                          onHold: (slot) => KitSlotSheet.show(context, slot),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) => _tap(
                              details.localPosition,
                              cellWidth,
                              rowHeight,
                            ),
                            onHorizontalDragStart: (details) => _dragStart(
                              details.localPosition,
                              cellWidth,
                              rowHeight,
                            ),
                            onHorizontalDragUpdate: (details) => _dragUpdate(
                              details.localPosition,
                              cellWidth,
                              rowHeight,
                            ),
                            onHorizontalDragEnd: (_) => _painting = false,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: _KitPainter(
                                    cells: [
                                      for (
                                        var slot = 0;
                                        slot < kitSlotCount;
                                        slot++
                                      )
                                        [
                                          for (var i = 0; i < stepsPerBar; i++)
                                            beat.kit.velocityAt(
                                              slot,
                                              windowStart + i,
                                            ),
                                        ],
                                    ],
                                    rowHeight: rowHeight,
                                  ),
                                ),
                                CustomPaint(
                                  painter: PlayheadPainter(
                                    transport: transport,
                                    visibleSteps: stepsPerBar,
                                    totalSteps: beat.stepCount,
                                    stepOffset: windowStart,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _tap(Offset position, double cellWidth, double rowHeight) {
    final cell = _cellAt(position, cellWidth, rowHeight);
    if (cell == null) return;
    ref.read(studioProvider.notifier).cycleKitCell(cell.slot, cell.step);
  }

  void _dragStart(Offset position, double cellWidth, double rowHeight) {
    final cell = _cellAt(position, cellWidth, rowHeight);
    if (cell == null) return;
    final beat = ref.read(studioProvider).beat;
    _paintVelocity = KitVelocity.next(
      beat.kit.velocityAt(cell.slot, cell.step),
    );
    _painting = true;
    _lastSlot = cell.slot;
    _lastStep = cell.step;
    ref
        .read(studioProvider.notifier)
        .paintKitCell(cell.slot, cell.step, _paintVelocity);
  }

  void _dragUpdate(Offset position, double cellWidth, double rowHeight) {
    if (!_painting) return;
    final cell = _cellAt(position, cellWidth, rowHeight);
    if (cell == null) return;
    if (cell.slot == _lastSlot && cell.step == _lastStep) return;
    _lastSlot = cell.slot;
    _lastStep = cell.step;
    ref
        .read(studioProvider.notifier)
        .paintKitCell(cell.slot, cell.step, _paintVelocity);
  }

  /// Resolves a touch to a slot and a step of the whole pattern, not of the bar
  /// on screen.
  _Cell? _cellAt(Offset position, double cellWidth, double rowHeight) {
    final column = (position.dx / cellWidth).floor();
    final slot = (position.dy / rowHeight).floor();
    if (column < 0 || column >= stepsPerBar) return null;
    if (slot < 0 || slot >= kitSlotCount) return null;
    return _Cell(slot, ref.read(studioProvider).windowStart + column);
  }
}

class _Cell {
  const _Cell(this.slot, this.step);

  final int slot;
  final int step;
}

/// Slot names down the left. Tap to hear the slot, hold to open its volume and
/// pitch.
class _SlotGutter extends StatelessWidget {
  const _SlotGutter({
    required this.kitRef,
    required this.rowHeight,
    required this.onTap,
    required this.onHold,
  });

  final KitRef kitRef;
  final double rowHeight;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onHold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: KitGrid.gutterWidth,
      child: Column(
        children: [
          for (var slot = 0; slot < kitSlotCount; slot++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(slot);
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                onHold(slot);
              },
              // Exactly one row tall, gap included, so the pads stay lined up
              // with the rows the painter draws beside them.
              child: SizedBox(
                height: rowHeight,
                child: Container(
                  margin: const EdgeInsetsDirectional.only(end: 3, bottom: 2),
                  decoration: BoxDecoration(
                    color: JungleTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: JungleTheme.line),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    kitRef.labelAt(slot),
                    style: const TextStyle(
                      color: JungleTheme.text,
                      fontSize: 9,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KitPainter extends CustomPainter {
  _KitPainter({required this.cells, required this.rowHeight});

  /// `cells[slot][column]` for the bar on screen.
  final List<List<KitVelocity?>> cells;
  final double rowHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = cells.isEmpty ? 0 : cells.first.length;
    if (columns == 0) return;
    final cellWidth = size.width / columns;

    final shade = Paint()..color = JungleTheme.surface;
    for (var step = 0; step < columns; step++) {
      if ((step ~/ 4).isEven) continue;
      canvas.drawRect(
        Rect.fromLTWH(step * cellWidth, 0, cellWidth, size.height),
        shade,
      );
    }

    for (var slot = 0; slot < cells.length; slot++) {
      for (var step = 0; step < columns; step++) {
        final velocity = cells[slot][step];
        if (velocity == null) continue;
        // Velocity is drawn as height, so three levels are one glance apart
        // rather than three shades you have to compare.
        final fraction = switch (velocity) {
          KitVelocity.hard => 1.0,
          KitVelocity.medium => 0.66,
          KitVelocity.soft => 0.38,
        };
        final full = rowHeight - 4;
        final height = full * fraction;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              step * cellWidth + 1.5,
              slot * rowHeight + 2 + (full - height),
              cellWidth - 3,
              height,
            ),
            const Radius.circular(2),
          ),
          Paint()
            ..color = velocity == KitVelocity.hard
                ? JungleTheme.accent
                : JungleTheme.accent.withValues(alpha: 0.72),
        );
      }
    }

    final thin = Paint()
      ..color = JungleTheme.line.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = JungleTheme.line
      ..strokeWidth = 1.5;
    for (var step = 0; step <= columns; step++) {
      final x = step * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        step % 4 == 0 ? thick : thin,
      );
    }
    for (var slot = 0; slot <= cells.length; slot++) {
      final y = slot * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thin);
    }
  }

  @override
  bool shouldRepaint(_KitPainter old) {
    if (old.rowHeight != rowHeight || old.cells.length != cells.length) {
      return true;
    }
    for (var slot = 0; slot < cells.length; slot++) {
      final a = old.cells[slot];
      final b = cells[slot];
      if (a.length != b.length) return true;
      for (var step = 0; step < b.length; step++) {
        if (a[step] != b[step]) return true;
      }
    }
    return false;
  }
}
