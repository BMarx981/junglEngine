import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/grid/slice_analysis.dart';
import 'package:junglengine/features/grid/step_mod_sheet.dart';
import 'package:junglengine/features/transport/playhead_painter.dart';
import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/step_mod.dart';
import 'package:junglengine/models/steps.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

/// The break step grid: rows are slices, columns are steps.
///
/// Tap a cell to place a slice, tap it again to clear it. Drag sideways to
/// paint a run. Vertical drags scroll, which is why painting is horizontal
/// only: the two gestures never fight.
///
/// One bar at a time, always sixteen columns wide. A longer Beat is paged with
/// the bar strip rather than squeezed, because a cell you cannot hit is not a
/// cell.
class ChopGrid extends ConsumerStatefulWidget {
  const ChopGrid({super.key});

  static const double gutterWidth = 28;
  static const double minRowHeight = 22;
  static const double maxRowHeight = 72;

  @override
  ConsumerState<ChopGrid> createState() => _ChopGridState();
}

class _ChopGridState extends ConsumerState<ChopGrid> {
  int? _lastPaintedStep;
  int? _lastPaintedSlice;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final beat = state.beat;
    final transport = ref.watch(transportProvider);
    final windowStart = state.windowStart;

    // Time runs left to right, in Arabic as much as anywhere else: every
    // sequencer a producer has ever used reads that way, and the playhead
    // sweeping backwards would be a bug, not a translation. The lock lives
    // here rather than at the screen so a later layout change cannot drop it,
    // and the slice gutter stays on the left where _cellAt's hit test maths
    // expects it.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fill the viewport when the rows fit, and scroll once they would get
          // too small to hit with a thumb.
          final rowHeight = (constraints.maxHeight / beat.sliceCount).clamp(
            ChopGrid.minRowHeight,
            ChopGrid.maxRowHeight,
          );
          final gridHeight = rowHeight * beat.sliceCount;
          final cellWidth =
              (constraints.maxWidth - ChopGrid.gutterWidth) / stepsPerBar;

          return SingleChildScrollView(
            child: SizedBox(
              height: gridHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SliceGutter(
                    sliceCount: beat.sliceCount,
                    rowsPerBar: state.sliceDivision,
                    rowHeight: rowHeight,
                    analysis: state.analysis,
                    onTapSlice: (slice) =>
                        ref.read(studioProvider.notifier).auditionSlice(slice),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _cellAt(
                        details.localPosition,
                        cellWidth,
                        rowHeight,
                        (slice, step) => ref
                            .read(studioProvider.notifier)
                            .toggleCell(slice, step),
                      ),
                      onHorizontalDragStart: (details) {
                        _lastPaintedStep = null;
                        _lastPaintedSlice = null;
                        _paintAt(details.localPosition, cellWidth, rowHeight);
                      },
                      onHorizontalDragUpdate: (details) =>
                          _paintAt(details.localPosition, cellWidth, rowHeight),
                      onHorizontalDragEnd: (_) {
                        _lastPaintedStep = null;
                        _lastPaintedSlice = null;
                      },
                      // Hold a cell that has something on it to reverse it,
                      // retrigger it, pitch it down or halve its speed.
                      onLongPressStart: (details) => _cellAt(
                        details.localPosition,
                        cellWidth,
                        rowHeight,
                        (slice, step) {
                          if (beat.chop.sliceAt(step) != slice) return;
                          HapticFeedback.mediumImpact();
                          StepModSheet.show(context, step);
                        },
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _GridPainter(
                              steps: [
                                for (var i = 0; i < stepsPerBar; i++)
                                  beat.chop.stepAt(windowStart + i),
                              ],
                              sliceCount: beat.sliceCount,
                              rowHeight: rowHeight,
                              rowsPerBar: state.sliceDivision,
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
    );
  }

  void _paintAt(Offset position, double cellWidth, double rowHeight) {
    _cellAt(position, cellWidth, rowHeight, (slice, step) {
      if (_lastPaintedStep == step && _lastPaintedSlice == slice) return;
      _lastPaintedStep = step;
      _lastPaintedSlice = slice;
      ref.read(studioProvider.notifier).paintCell(slice, step);
    });
  }

  /// Resolves a touch to a slice and a step of the whole pattern, not of the
  /// bar on screen.
  void _cellAt(
    Offset position,
    double cellWidth,
    double rowHeight,
    void Function(int slice, int step) action,
  ) {
    final state = ref.read(studioProvider);
    final column = (position.dx / cellWidth).floor();
    final slice = (position.dy / rowHeight).floor();
    if (column < 0 || column >= stepsPerBar) return;
    if (slice < 0 || slice >= state.beat.sliceCount) return;
    action(slice, state.windowStart + column);
  }
}

/// Slice numbers down the left, tinted by what the slice sounds like, so a
/// 32 division grid is still readable. Tap one to hear it.
class _SliceGutter extends StatelessWidget {
  const _SliceGutter({
    required this.sliceCount,
    required this.rowsPerBar,
    required this.rowHeight,
    required this.analysis,
    required this.onTapSlice,
  });

  final int sliceCount;
  final int rowsPerBar;
  final double rowHeight;
  final SliceAnalysis? analysis;
  final ValueChanged<int> onTapSlice;

  @override
  Widget build(BuildContext context) {
    final kicks = analysis?.kicks.toSet() ?? const <int>{};
    final snares = analysis?.snares.toSet() ?? const <int>{};

    return SizedBox(
      width: ChopGrid.gutterWidth,
      child: Column(
        children: [
          for (var slice = 0; slice < sliceCount; slice++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapSlice(slice),
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      color: kicks.contains(slice)
                          ? JungleTheme.kickTint
                          : snares.contains(slice)
                          ? JungleTheme.snareTint
                          : JungleTheme.ghostTint,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${slice + 1}',
                          style: TextStyle(
                            // The first slice of each bar reads brighter, so a
                            // long grid can be scanned rather than counted.
                            color: rowsPerBar > 0 && slice % rowsPerBar == 0
                                ? JungleTheme.text
                                : JungleTheme.textDim,
                            fontSize: rowHeight < 26 ? 8 : 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.steps,
    required this.sliceCount,
    required this.rowHeight,
    required this.rowsPerBar,
  });

  /// The bar on screen: one entry per column.
  final List<ChopStep?> steps;

  final int sliceCount;
  final double rowHeight;

  /// Slices in one bar of the break. A four bar break at 16 divisions is 64
  /// rows, which needs a landmark every bar to be navigable.
  final int rowsPerBar;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / steps.length;

    // Alternate beat groups so you can count to four without thinking.
    final shade = Paint()..color = JungleTheme.surface;
    for (var step = 0; step < steps.length; step++) {
      if ((step ~/ 4).isEven) continue;
      canvas.drawRect(
        Rect.fromLTWH(step * cellWidth, 0, cellWidth, size.height),
        shade,
      );
    }

    final fill = Paint()..color = JungleTheme.accent;
    for (var step = 0; step < steps.length; step++) {
      final cell = steps[step];
      if (cell == null || cell.slice >= sliceCount) continue;
      final rect = Rect.fromLTWH(
        step * cellWidth + 1.5,
        cell.slice * rowHeight + 1.5,
        cellWidth - 3,
        rowHeight - 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        fill,
      );
      // A modified step is the same cell with its letter cut out of it, so the
      // pattern still reads as a pattern and the modifier reads as an edit to
      // one hit rather than a second row of information.
      if (!cell.mod.isNone) _paintGlyph(canvas, rect, cell.mod);
    }

    final thin = Paint()
      ..color = JungleTheme.line.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = JungleTheme.line
      ..strokeWidth = 1.5;
    for (var step = 0; step <= steps.length; step++) {
      final x = step * cellWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        step % 4 == 0 ? thick : thin,
      );
    }
    for (var slice = 0; slice <= sliceCount; slice++) {
      final y = slice * rowHeight;
      final startsBar = rowsPerBar > 0 && slice % rowsPerBar == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        startsBar ? thick : thin,
      );
    }
  }

  /// Draws the modifier's letter inside the cell, dark on the accent fill.
  /// Skipped when the row is too short to hold a legible one: a smear of ink is
  /// worse than no marking.
  void _paintGlyph(Canvas canvas, Rect cell, StepMod mod) {
    final size = (rowHeight * 0.5).clamp(0.0, cell.width * 0.8);
    if (size < 7) return;
    final painter = TextPainter(
      text: TextSpan(
        text: stepModGlyph(mod),
        style: TextStyle(
          color: JungleTheme.background,
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        cell.center.dx - painter.width / 2,
        cell.center.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.rowHeight != rowHeight ||
      old.sliceCount != sliceCount ||
      old.rowsPerBar != rowsPerBar ||
      !_sameSteps(old.steps, steps);

  static bool _sameSteps(List<ChopStep?> a, List<ChopStep?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
