import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/features/bass/note_names.dart';
import 'package:junglengine/features/transport/bar_strip.dart';
import 'package:junglengine/features/transport/playhead_painter.dart';
import 'package:junglengine/l10n/l10n.dart';
import 'package:junglengine/models/steps.dart';
import 'package:junglengine/models/sub_lane.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

/// Rows of the roll: every semitone the lane can hold, top note first.
const int _rowCount = subMaxSemitone - subMinSemitone + 1;

/// Tall enough to hit with a thumb without looking. The whole point of this
/// screen is that the lane on the studio screen fits two octaves into a
/// hundred pixels, which is four pixels a semitone, which is why it is
/// miserable to aim at.
const double _rowHeight = 30;

/// Where the note names sit.
const double _gutterWidth = 38;

int _rowForSemitone(int semitone) => subMaxSemitone - semitone;

int _semitoneForRow(int row) => subMaxSemitone - row;

/// The sub lane, opened out.
///
/// The lane under the drum grid stays what it is: a glance at the bassline and
/// a quick drag when you know roughly where the note goes. This is the other
/// half of that, for when you know exactly which note you want.
///
/// Pitch is a row and time is a column, so a note is placed by tapping the
/// cell it belongs in rather than by dragging a column and watching a readout.
/// The bar showing here is the bar the studio screen is showing, and while the
/// transport runs both follow the playhead together.
///
/// This adds no note properties. Pitch, glide and accent are the whole of a
/// sub note and they were the whole of it before this screen existed.
class SubEditor extends ConsumerStatefulWidget {
  const SubEditor({super.key});

  /// The note grid itself, so a test can work out where a given pitch and step
  /// landed on screen.
  static const Key rollKey = ValueKey('sub-editor-roll');

  /// How tall one semitone is, for the same reason.
  static const double rowHeight = _rowHeight;

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: JungleTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => const SubEditor(),
  );

  @override
  ConsumerState<SubEditor> createState() => _SubEditorState();
}

class _SubEditorState extends ConsumerState<SubEditor> {
  final ScrollController _scroll = ScrollController();

  /// Which column of the bar on screen the footer is editing. Held as a column
  /// rather than a step so that paging to another bar keeps the selection
  /// where the eye left it.
  int _column = 0;

  @override
  void initState() {
    super.initState();
    // Open on the first note of the bar, and put its pitch in the middle of
    // the roll. An empty bar opens on step one with the root centred.
    final state = ref.read(studioProvider);
    var semitone = 0;
    for (var i = 0; i < stepsPerBar; i++) {
      final cell = state.beat.sub.stepAt(state.windowStart + i);
      if (cell.semitone != null) {
        _column = i;
        semitone = cell.semitone!;
        break;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _centreOn(semitone));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _centreOn(int semitone) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final centre = (_rowForSemitone(semitone) + 0.5) * _rowHeight;
    _scroll.jumpTo(
      (centre - position.viewportDimension / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioProvider);
    final beat = state.beat;
    final windowStart = state.windowStart;
    final step = windowStart + _column;
    final cell = beat.sub.stepAt(step);

    // The theme puts a drag handle above every sheet and `useSafeArea` holds
    // the sheet clear of the status bar. Both come out of the height before
    // the fraction does, or a sheet asking for most of the screen quietly
    // takes all of it and there is nothing left to tap to dismiss it.
    final media = MediaQuery.of(context);

    return SizedBox(
      height:
          (media.size.height - media.padding.top - kMinInteractiveDimension) *
          0.94,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.subNotesTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: JungleTheme.sub),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: JungleTheme.textDim,
                  ),
                ),
              ],
            ),
            // Wraps rather than shrinks: it is the only line on this screen
            // that says how the screen works, and half of it is no use.
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                context.l10n.subEditorHint,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            // Paging is shared with the studio screen underneath, so closing
            // the sheet leaves you on the bar you were just editing.
            const BarStrip(),
            const SizedBox(height: 4),
            Expanded(child: _buildRoll(beat.sub, windowStart, beat.stepCount)),
            const SizedBox(height: 8),
            _Inspector(
              step: step,
              cell: cell,
              onNudge: _nudge,
              onGlide: () {
                HapticFeedback.selectionClick();
                ref.read(studioProvider.notifier).toggleTie(step);
              },
              onAccent: () {
                HapticFeedback.selectionClick();
                ref.read(studioProvider.notifier).toggleAccent(step);
              },
              onClear: () {
                HapticFeedback.selectionClick();
                ref.read(studioProvider.notifier).setSubStep(step, null);
              },
              rootMidi: beat.subRootMidi,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoll(SubLane lane, int windowStart, int totalSteps) {
    final transport = ref.watch(transportProvider);
    final rootMidi = ref.watch(
      studioProvider.select((s) => s.beat.subRootMidi),
    );

    return SingleChildScrollView(
      controller: _scroll,
      child: SizedBox(
        height: _rowCount * _rowHeight,
        // The gutter is a pitch ruler, not a time axis, so it mirrors with the
        // rest of the chrome and sits on the trailing side in Arabic. The
        // columns beside it do not: see below.
        child: Row(
          children: [
            SizedBox(
              width: _gutterWidth,
              child: Column(
                children: [
                  for (var row = 0; row < _rowCount; row++)
                    _GutterLabel(
                      midi: rootMidi + _semitoneForRow(row),
                      isRoot: _semitoneForRow(row) == 0,
                    ),
                ],
              ),
            ),
            Expanded(
              // Time runs left to right in every sequencer on earth. Step one
              // is on the left in Arabic too.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columnWidth = constraints.maxWidth / stepsPerBar;
                    return GestureDetector(
                      key: SubEditor.rollKey,
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _onCellTap(
                        (details.localPosition.dx / columnWidth).floor().clamp(
                          0,
                          stepsPerBar - 1,
                        ),
                        (details.localPosition.dy / _rowHeight).floor().clamp(
                          0,
                          _rowCount - 1,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _RollPainter(
                              steps: [
                                for (var i = 0; i < stepsPerBar; i++)
                                  lane.stepAt(windowStart + i),
                              ],
                              // What came before the bar, so a note tied over
                              // the bar line glides from where it really was.
                              previous: windowStart > 0
                                  ? lane.stepAt(windowStart - 1)
                                  : const SubStep.rest(),
                              selectedColumn: _column,
                              rootMidi: rootMidi,
                            ),
                          ),
                          CustomPaint(
                            painter: PlayheadPainter(
                              transport: transport,
                              visibleSteps: stepsPerBar,
                              totalSteps: totalSteps,
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
          ],
        ),
      ),
    );
  }

  /// One tap does one thing.
  ///
  /// Tapping an empty cell writes a note there. Tapping a note that is not the
  /// selected one selects it, so the footer's buttons act on it without the
  /// tap that reached for them erasing it. Tapping the selected note again
  /// clears it, which is the same second tap that clears a cell on the grid.
  void _onCellTap(int column, int row) {
    final state = ref.read(studioProvider);
    final step = state.windowStart + column;
    final semitone = _semitoneForRow(row);
    final cell = state.beat.sub.stepAt(step);
    HapticFeedback.selectionClick();

    if (cell.semitone == semitone) {
      if (column == _column) {
        ref.read(studioProvider.notifier).setSubStep(step, null);
      } else {
        setState(() => _column = column);
      }
      return;
    }
    setState(() => _column = column);
    ref.read(studioProvider.notifier).setSubStep(step, semitone);
  }

  /// Moves the selected note one step, following it across a bar line.
  void _nudge(int delta) {
    final state = ref.read(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final from = state.windowStart + _column;
    final to = from + delta;
    if (to < 0 || to >= state.beat.sub.steps.length) return;
    if (state.beat.sub.stepAt(from).isRest) return;
    HapticFeedback.selectionClick();
    controller.moveSubStep(from, to);
    controller.setActiveBar(to ~/ stepsPerBar);
    setState(() => _column = to % stepsPerBar);
  }
}

class _GutterLabel extends StatelessWidget {
  const _GutterLabel({required this.midi, required this.isRoot});

  final int midi;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    // Note names are ASCII in every locale by policy, so the monospace face is
    // safe here and the column of names stays a column.
    return SizedBox(
      height: _rowHeight,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Text(
            noteName(midi),
            style: JungleTheme.readout(
              fontSize: 10,
              color: isRoot
                  ? JungleTheme.sub
                  : (isBlackKey(midi)
                        ? JungleTheme.textDim.withValues(alpha: 0.55)
                        : JungleTheme.textDim),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the footer does to the selected note.
///
/// Every one of these was already possible on the lane: glide was a twenty
/// pixel strip, accent was a long press, and clearing was a tap that had to
/// land on the right column. Here they are buttons.
class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.step,
    required this.cell,
    required this.rootMidi,
    required this.onNudge,
    required this.onGlide,
    required this.onAccent,
    required this.onClear,
  });

  final int step;
  final SubStep cell;
  final int rootMidi;
  final ValueChanged<int> onNudge;
  final VoidCallback onGlide;
  final VoidCallback onAccent;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semitone = cell.semitone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.stepModStep(step % stepsPerBar + 1),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(width: 10),
            Text(
              semitone == null ? '--' : noteName(rootMidi + semitone),
              style: JungleTheme.readout(
                fontSize: 16,
                color: semitone == null ? JungleTheme.textDim : JungleTheme.sub,
              ),
            ),
            const Spacer(),
            // Earlier is to the left of later even where the words run the
            // other way, because the roll above these buttons says so.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _NudgeButton(
                    icon: Icons.chevron_left,
                    label: l10n.subMoveEarlier,
                    enabled: !cell.isRest && step > 0,
                    onTap: () => onNudge(-1),
                  ),
                  const SizedBox(width: 6),
                  _NudgeButton(
                    icon: Icons.chevron_right,
                    label: l10n.subMoveLater,
                    enabled: !cell.isRest,
                    onTap: () => onNudge(1),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InspectorButton(
                // GLIDE stays English: it is the word on the sub synth's own
                // knob, and tying a note to the one before it is what makes
                // that knob audible.
                label: 'GLIDE',
                active: cell.tie,
                // Step zero of the pattern has nothing to glide from.
                enabled: step > 0,
                onTap: onGlide,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _InspectorButton(
                label: l10n.subAccent,
                active: cell.accent,
                enabled: !cell.isRest,
                onTap: onAccent,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _InspectorButton(
                label: l10n.subClearNote,
                active: false,
                enabled: !cell.isRest,
                colour: JungleTheme.hot,
                onTap: onClear,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 46,
          height: 38,
          decoration: BoxDecoration(
            color: JungleTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: JungleTheme.line),
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? JungleTheme.text
                : JungleTheme.textDim.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _InspectorButton extends StatelessWidget {
  const _InspectorButton({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
    this.colour = JungleTheme.sub,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? colour : JungleTheme.textDim.withValues(alpha: 0.4);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? colour : JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? colour : JungleTheme.line),
        ),
        // Three buttons share one phone width and translations run longer than
        // the English, so the label scales rather than breaking the row.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: active ? JungleTheme.background : tint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: Theme.of(
                context,
              ).textTheme.titleMedium?.letterSpacing,
            ),
          ),
        ),
      ),
    );
  }
}

class _RollPainter extends CustomPainter {
  _RollPainter({
    required this.steps,
    required this.previous,
    required this.selectedColumn,
    required this.rootMidi,
  });

  /// The bar on screen.
  final List<SubStep> steps;

  /// The cell immediately before it.
  final SubStep previous;

  final int selectedColumn;
  final int rootMidi;

  @override
  void paint(Canvas canvas, Size size) {
    final columnWidth = size.width / steps.length;

    double yFor(int semitone) => (_rowForSemitone(semitone) + 0.5) * _rowHeight;

    // The keyboard, laid on its side. Black keys sit darker so a run of notes
    // can be read as an interval and not just as a stack of blocks.
    final white = Paint()..color = JungleTheme.surface;
    final black = Paint()..color = JungleTheme.background;
    for (var row = 0; row < _rowCount; row++) {
      canvas.drawRect(
        Rect.fromLTWH(0, row * _rowHeight, size.width, _rowHeight),
        isBlackKey(rootMidi + _semitoneForRow(row)) ? black : white,
      );
    }

    // Beats two and four, shaded, so the eye finds the backbeat.
    final shade = Paint()..color = Colors.white.withValues(alpha: 0.03);
    for (var step = 0; step < steps.length; step++) {
      if ((step ~/ 4).isEven) continue;
      canvas.drawRect(
        Rect.fromLTWH(step * columnWidth, 0, columnWidth, size.height),
        shade,
      );
    }

    final hairline = Paint()
      ..color = JungleTheme.line.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var row = 1; row < _rowCount; row++) {
      final y = row * _rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hairline);
    }

    // The root. Everything is read against this line.
    canvas.drawLine(
      Offset(0, yFor(0)),
      Offset(size.width, yFor(0)),
      Paint()
        ..color = JungleTheme.sub.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    // Which column the footer is talking about.
    final selectedLeft = selectedColumn * columnWidth;
    canvas.drawRect(
      Rect.fromLTWH(selectedLeft, 0, columnWidth, size.height),
      Paint()..color = JungleTheme.sub.withValues(alpha: 0.09),
    );

    final note = Paint()..color = JungleTheme.sub;
    final held = Paint()..color = JungleTheme.sub.withValues(alpha: 0.35);
    final glide = Paint()
      ..color = JungleTheme.sub.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    final accent = Paint()
      ..color = JungleTheme.text
      ..style = PaintingStyle.stroke
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
        canvas.drawLine(
          Offset(left, yFor(lastSemitone)),
          Offset(left + columnWidth * 0.5, y),
          glide,
        );
      }

      // A held cell is drawn thinner as well as dimmer, so a two step note
      // reads as one note and not as two.
      final inset = cell.semitone == null ? 8.0 : 3.0;
      final block = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + 1.5,
          y - _rowHeight / 2 + inset,
          columnWidth - 3,
          _rowHeight - inset * 2,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(block, cell.semitone == null ? held : note);
      if (cell.accent) canvas.drawRRect(block, accent);

      lastSemitone = semitone;
      sounding = true;
    }

    final line = Paint()
      ..color = JungleTheme.line
      ..strokeWidth = 1;
    for (var step = 0; step <= steps.length; step++) {
      final x = step * columnWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        step % 4 == 0
            ? line
            : (Paint()
                ..color = JungleTheme.line.withValues(alpha: 0.4)
                ..strokeWidth = 1),
      );
    }

    // The selected column's edges, over the grid lines rather than under them.
    final edge = Paint()
      ..color = JungleTheme.sub.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(selectedLeft, 0),
      Offset(selectedLeft, size.height),
      edge,
    );
    canvas.drawLine(
      Offset(selectedLeft + columnWidth, 0),
      Offset(selectedLeft + columnWidth, size.height),
      edge,
    );
  }

  @override
  bool shouldRepaint(_RollPainter old) {
    if (old.selectedColumn != selectedColumn ||
        old.rootMidi != rootMidi ||
        old.steps.length != steps.length ||
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
