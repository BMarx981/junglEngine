import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/studio.dart';
import '../../theme.dart';
import '../transport/playhead_painter.dart';
import 'slice_analysis.dart';

/// The break step grid: rows are slices, columns are steps.
///
/// Tap a cell to place a slice, tap it again to clear it. Drag sideways to
/// paint a run. Vertical drags scroll, which is why painting is horizontal
/// only: the two gestures never fight.
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill the viewport when the rows fit, and scroll once they would get
        // too small to hit with a thumb.
        final rowHeight = (constraints.maxHeight / beat.sliceCount).clamp(
          ChopGrid.minRowHeight,
          ChopGrid.maxRowHeight,
        );
        final gridHeight = rowHeight * beat.sliceCount;
        final cellWidth =
            (constraints.maxWidth - ChopGrid.gutterWidth) / beat.stepCount;

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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: _GridPainter(
                            steps: beat.chop.steps,
                            sliceCount: beat.sliceCount,
                            rowHeight: rowHeight,
                            rowsPerBar: state.sliceDivision,
                          ),
                        ),
                        CustomPaint(
                          painter: PlayheadPainter(
                            transport: transport,
                            stepCount: beat.stepCount,
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

  void _cellAt(
    Offset position,
    double cellWidth,
    double rowHeight,
    void Function(int slice, int step) action,
  ) {
    final beat = ref.read(studioProvider).beat;
    final step = (position.dx / cellWidth).floor();
    final slice = (position.dy / rowHeight).floor();
    if (step < 0 || step >= beat.stepCount) return;
    if (slice < 0 || slice >= beat.sliceCount) return;
    action(slice, step);
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

  final List<int?> steps;
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
      final slice = steps[step];
      if (slice == null || slice >= sliceCount) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            step * cellWidth + 1.5,
            slice * rowHeight + 1.5,
            cellWidth - 3,
            rowHeight - 3,
          ),
          const Radius.circular(2),
        ),
        fill,
      );
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

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.rowHeight != rowHeight ||
      old.sliceCount != sliceCount ||
      old.rowsPerBar != rowsPerBar ||
      !_sameSteps(old.steps, steps);

  static bool _sameSteps(List<int?> a, List<int?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
