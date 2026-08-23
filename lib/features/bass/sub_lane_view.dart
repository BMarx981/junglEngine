import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/steps.dart';
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
///
/// It shows the same bar the drum grid above it is showing, so a bassline is
/// always written against the drums it is under.
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
    final windowStart = state.windowStart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: SubLaneView.headerHeight,
          child: Row(
            children: [
              const SizedBox(width: 4),
              Text(
                'SUB',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: JungleTheme.sub),
              ),
              const Spacer(),
              // The hint is the longest thing in this row and the least
              // important, so it shrinks to fit. Scaling down rather than
              // ellipsising because half a hint helps nobody.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    _dragSemitone != null
                        ? noteName(beat.subRootMidi + _dragSemitone!)
                        : context.l10n.subHint,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _dragSemitone != null
                          ? JungleTheme.sub
                          : JungleTheme.textDim,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        // The note columns are a time axis and stay left to right. The header
        // above mirrors with the rest of the chrome.
        SizedBox(
          height: SubLaneView.pitchHeight,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = constraints.maxWidth / stepsPerBar;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _onTap(
                    details.localPosition,
                    columnWidth,
                    constraints.maxHeight,
                  ),
                  onVerticalDragStart: (details) => _onDragStart(
                    details.localPosition,
                    columnWidth,
                    constraints.maxHeight,
                  ),
                  onVerticalDragUpdate: (details) => _onDragUpdate(
                    details.localPosition,
                    constraints.maxHeight,
                  ),
                  onVerticalDragEnd: (_) => setState(() {
                    _dragStep = null;
                    _dragSemitone = null;
                  }),
                  // Hold a note to accent it: the filter opens on that note and
                  // nothing else about it changes.
                  onLongPressStart: (details) {
                    final step = _stepAt(details.localPosition.dx, columnWidth);
                    if (beat.sub.stepAt(step).isRest) return;
                    HapticFeedback.selectionClick();
                    ref.read(studioProvider.notifier).toggleAccent(step);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _SubLanePainter(
                          steps: [
                            for (var i = 0; i < stepsPerBar; i++)
                              beat.sub.stepAt(windowStart + i),
                          ],
                          // The cell before the window, so a note tied across a
                          // bar line is drawn gliding from where it really came
                          // from rather than from the root.
                          previous: windowStart > 0
                              ? beat.sub.stepAt(windowStart - 1)
                              : const SubStep.rest(),
                        ),
                      ),
                      CustomPaint(
                        painter: PlayheadPainter(
                          transport: transport,
                          visibleSteps: stepsPerBar,
                          totalSteps: beat.stepCount,
                          stepOffset: windowStart,
                          color: JungleTheme.sub,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: _TieStrip(lane: beat.sub, windowStart: windowStart),
        ),
      ],
    );
  }

  /// Column on screen to step of the whole pattern.
  int _stepAt(double dx, double columnWidth) {
    final column = (dx / columnWidth).floor().clamp(0, stepsPerBar - 1);
    return ref.read(studioProvider).windowStart + column;
  }

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
  const _TieStrip({required this.lane, required this.windowStart});

  final SubLane lane;
  final int windowStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: SubLaneView.tieHeight,
      child: Row(
        children: [
          for (var column = 0; column < stepsPerBar; column++)
            Expanded(
              child: _TieCell(
                step: windowStart + column,
                column: column,
                tied: lane.stepAt(windowStart + column).tie,
              ),
            ),
        ],
      ),
    );
  }
}

class _TieCell extends ConsumerWidget {
  const _TieCell({
    required this.step,
    required this.column,
    required this.tied,
  });

  final int step;
  final int column;
  final bool tied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Step zero has nothing before it to glide from.
      onTap: step == 0
          ? null
          : () => ref.read(studioProvider.notifier).toggleTie(step),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
        decoration: BoxDecoration(
          color: tied
              ? JungleTheme.sub.withValues(alpha: 0.85)
              : JungleTheme.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: column % 4 == 0
                ? JungleTheme.line
                : JungleTheme.line.withValues(alpha: 0.4),
          ),
        ),
        child: tied
            ? const Icon(Icons.link, size: 11, color: JungleTheme.background)
            : null,
      ),
    );
  }
}

class _SubLanePainter extends CustomPainter {
  _SubLanePainter({required this.steps, required this.previous});

  /// The bar on screen.
  final List<SubStep> steps;

  /// The cell immediately before it.
  final SubStep previous;

  @override
  void paint(Canvas canvas, Size size) {
    final columnWidth = size.width / steps.length;
    final range = (subMaxSemitone - subMinSemitone).toDouble();

    double yFor(int semitone) =>
        size.height * (1 - (semitone - subMinSemitone) / range);

    final shade = Paint()..color = JungleTheme.surface;
    for (var step = 0; step < steps.length; step++) {
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

    var lastSemitone = previous.semitone ?? 0;
    var sounding = !previous.isRest;

    for (var step = 0; step < steps.length; step++) {
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

      // An accented note is drawn thicker, because that is what it sounds
      // like: the same note, further open, speaking over the drums.
      final thickness = cell.accent ? 10.0 : 6.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left + 1.5,
            y - thickness / 2,
            columnWidth - 3,
            thickness,
          ),
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
    for (var step = 0; step <= steps.length; step++) {
      final x = step * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_SubLanePainter old) {
    if (old.steps.length != steps.length ||
        old.previous.semitone != previous.semitone ||
        old.previous.tie != previous.tie) {
      return true;
    }
    for (var i = 0; i < steps.length; i++) {
      if (old.steps[i].semitone != steps[i].semitone ||
          old.steps[i].tie != steps[i].tie ||
          old.steps[i].accent != steps[i].accent) {
        return true;
      }
    }
    return false;
  }
}
