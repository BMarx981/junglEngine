import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sub_lane.dart';
import '../../state/studio.dart';
import '../../theme.dart';
import '../transport/playhead_painter.dart';
import 'note_names.dart';

/// The sub lane.
///
/// Drag a column up and down to set its pitch. Tap a column that already has a
/// note to clear it. The strip along the bottom ties a cell to the one before
/// it, which is how you get glide.
class SubLaneView extends ConsumerStatefulWidget {
  const SubLaneView({super.key});

  static const double pitchHeight = 104;
  static const double tieHeight = 20;
  static const double headerHeight = 22;

  static const double totalHeight = pitchHeight + tieHeight + headerHeight;

  @override
  ConsumerState<SubLaneView> createState() => _SubLaneViewState();
}

class _SubLaneViewState extends ConsumerState<SubLaneView> {
  int? _dragStep;
  int? _dragSemitone;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final beat = state.beat;
    final transport = ref.watch(transportProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: SubLaneView.headerHeight,
          child: Row(
            children: [
              const SizedBox(width: 4),
              Text('SUB', style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: JungleTheme.sub)),
              const Spacer(),
              Text(
                _dragSemitone != null
                    ? noteName(beat.subRootMidi + _dragSemitone!)
                    : 'DRAG A COLUMN FOR PITCH',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _dragSemitone != null
                      ? JungleTheme.sub
                      : JungleTheme.textDim,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        SizedBox(
          height: SubLaneView.pitchHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth = constraints.maxWidth / beat.stepCount;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    _onTap(details.localPosition, columnWidth, constraints.maxHeight),
                onVerticalDragStart: (details) => _onDragStart(
                  details.localPosition,
                  columnWidth,
                  constraints.maxHeight,
                ),
                onVerticalDragUpdate: (details) =>
                    _onDragUpdate(details.localPosition, constraints.maxHeight),
                onVerticalDragEnd: (_) => setState(() {
                  _dragStep = null;
                  _dragSemitone = null;
                }),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _SubLanePainter(
                        steps: beat.sub.steps,
                        stepCount: beat.stepCount,
                      ),
                    ),
                    CustomPaint(
                      painter: PlayheadPainter(
                        transport: transport,
                        stepCount: beat.stepCount,
                        color: JungleTheme.sub,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _TieStrip(lane: beat.sub, stepCount: beat.stepCount),
      ],
    );
  }

  int _stepAt(double dx, double columnWidth) =>
      (dx / columnWidth).floor().clamp(0, ref.read(studioProvider).beat.stepCount - 1);

  /// Top of the lane is +12, bottom is -12.
  static int _semitoneAt(double dy, double height) {
    final t = (1 - (dy / height)).clamp(0.0, 1.0);
    final range = subMaxSemitone - subMinSemitone;
    return (subMinSemitone + (t * range).round()).clamp(
      subMinSemitone,
      subMaxSemitone,
    );
  }

  void _onTap(Offset position, double columnWidth, double height) {
    final step = _stepAt(position.dx, columnWidth);
    final controller = ref.read(studioProvider.notifier);
    final existing = ref.read(studioProvider).beat.sub.stepAt(step);
    if (existing.semitone != null) {
      controller.setSubStep(step, null);
    } else {
      controller.setSubStep(step, _semitoneAt(position.dy, height));
    }
  }

  void _onDragStart(Offset position, double columnWidth, double height) {
    final step = _stepAt(position.dx, columnWidth);
    final semitone = _semitoneAt(position.dy, height);
    setState(() {
      _dragStep = step;
      _dragSemitone = semitone;
    });
    ref.read(studioProvider.notifier).setSubStep(step, semitone);
  }

  /// The column is locked at drag start, so a vertical drag only ever changes
  /// pitch and never smears the note sideways.
  void _onDragUpdate(Offset position, double height) {
    final step = _dragStep;
    if (step == null) return;
    final semitone = _semitoneAt(position.dy, height);
    if (semitone == _dragSemitone) return;
    setState(() => _dragSemitone = semitone);
    ref.read(studioProvider.notifier).setSubStep(step, semitone);
  }
}

class _TieStrip extends ConsumerWidget {
  const _TieStrip({required this.lane, required this.stepCount});

  final SubLane lane;
  final int stepCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: SubLaneView.tieHeight,
      child: Row(
        children: [
          for (var step = 0; step < stepCount; step++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: step == 0
                    ? null
                    : () => ref.read(studioProvider.notifier).toggleTie(step),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
                  decoration: BoxDecoration(
                    color: lane.stepAt(step).tie
                        ? JungleTheme.sub.withValues(alpha: 0.85)
                        : JungleTheme.surface,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: step % 4 == 0
                          ? JungleTheme.line
                          : JungleTheme.line.withValues(alpha: 0.4),
                    ),
                  ),
                  child: lane.stepAt(step).tie
                      ? const Icon(
                          Icons.link,
                          size: 11,
                          color: JungleTheme.background,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubLanePainter extends CustomPainter {
  _SubLanePainter({required this.steps, required this.stepCount});

  final List<SubStep> steps;
  final int stepCount;

  @override
  void paint(Canvas canvas, Size size) {
    final columnWidth = size.width / stepCount;
    final range = (subMaxSemitone - subMinSemitone).toDouble();

    double yFor(int semitone) =>
        size.height * (1 - (semitone - subMinSemitone) / range);

    final shade = Paint()..color = JungleTheme.surface;
    for (var step = 0; step < stepCount; step++) {
      if ((step ~/ 4).isEven) continue;
      canvas.drawRect(
        Rect.fromLTWH(step * columnWidth, 0, columnWidth, size.height),
        shade,
      );
    }

    // The root. Everything is read against this line.
    canvas.drawLine(
      Offset(0, yFor(0)),
      Offset(size.width, yFor(0)),
      Paint()
        ..color = JungleTheme.line
        ..strokeWidth = 1,
    );

    final note = Paint()..color = JungleTheme.sub;
    final held = Paint()..color = JungleTheme.sub.withValues(alpha: 0.45);
    final glide = Paint()
      ..color = JungleTheme.sub.withValues(alpha: 0.7)
      ..strokeWidth = 2;

    var lastSemitone = 0;
    var sounding = false;

    for (var step = 0; step < steps.length && step < stepCount; step++) {
      final cell = steps[step];
      final left = step * columnWidth;

      if (cell.semitone == null && !cell.tie) {
        sounding = false;
        continue;
      }

      final semitone = cell.semitone ?? lastSemitone;
      final y = yFor(semitone);

      if (cell.tie && sounding && cell.semitone != null) {
        // Draw the slide from where the last note sat to where this one lands.
        canvas.drawLine(
          Offset(left, yFor(lastSemitone)),
          Offset(left + columnWidth * 0.5, y),
          glide,
        );
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 1.5, y - 3, columnWidth - 3, 6),
          const Radius.circular(3),
        ),
        cell.semitone == null ? held : note,
      );

      lastSemitone = semitone;
      sounding = true;
    }

    final line = Paint()
      ..color = JungleTheme.line.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var step = 0; step <= stepCount; step++) {
      final x = step * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_SubLanePainter old) {
    if (old.stepCount != stepCount || old.steps.length != steps.length) {
      return true;
    }
    for (var i = 0; i < steps.length; i++) {
      if (old.steps[i].semitone != steps[i].semitone ||
          old.steps[i].tie != steps[i].tie) {
        return true;
      }
    }
    return false;
  }
}
