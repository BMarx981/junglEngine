import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/studio.dart';
import '../../theme.dart';
import 'audio_import.dart';
import 'tap_tempo.dart';
import 'waveform.dart';

/// Say where the loop is and how fast it is.
///
/// The only three things this asks are the three the app cannot work out for
/// itself and must not guess: where the loop starts, how many bars it is, and
/// what tempo that makes it. Bars are load bearing, because slice divisions are
/// per bar; tempo follows from bars and length, so it is shown rather than
/// asked, and the tap button and the number field both work by moving the end
/// of the trim to where that tempo would put it.
class BreakImportScreen extends ConsumerStatefulWidget {
  const BreakImportScreen({required this.candidate, super.key});

  final ImportCandidate candidate;

  /// Returns true when a break was imported, so the caller can say so.
  static Future<bool> show(
    BuildContext context,
    ImportCandidate candidate,
  ) async {
    final used = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BreakImportScreen(candidate: candidate),
      ),
    );
    return used ?? false;
  }

  @override
  ConsumerState<BreakImportScreen> createState() => _BreakImportScreenState();
}

class _BreakImportScreenState extends ConsumerState<BreakImportScreen> {
  late TrimSelection _trim;
  late final TextEditingController _bpmField;
  final TapTempo _taps = TapTempo();
  final Stopwatch _clock = Stopwatch()..start();

  bool _previewing = false;
  bool _saving = false;

  /// Which handle a drag grabbed. Null between drags.
  bool? _draggingStart;

  int get _sampleRate => widget.candidate.clip.sampleRate;

  int get _frames => widget.candidate.frames;

  late final WaveformPeaks _peaks = WaveformPeaks.of(widget.candidate.clip);

  @override
  void initState() {
    super.initState();
    // Open on the whole file called one bar, then let the tempo readout tell
    // the user how wrong that is. Starting from the file is less work than
    // starting from nothing when the file already is the loop, which for a
    // break downloaded as a loop it usually is.
    _trim = TrimSelection(startFrame: 0, lengthFrames: _frames, bars: 1);
    _bpmField = TextEditingController(text: _bpmText);
  }

  @override
  void dispose() {
    _bpmField.dispose();
    unawaited(ref.read(studioProvider.notifier).stopAuditionClip());
    super.dispose();
  }

  double get _bpm => _trim.bpmAt(_sampleRate);

  String get _bpmText => _bpm.toStringAsFixed(1);

  bool get _bpmIsUsable =>
      _bpm >= StudioController.minBpm && _bpm <= StudioController.maxBpm;

  @override
  Widget build(BuildContext context) {
    final labelSmall = Theme.of(context).textTheme.labelSmall;
    return Scaffold(
      backgroundColor: JungleTheme.background,
      appBar: AppBar(
        backgroundColor: JungleTheme.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: JungleTheme.text),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'IMPORT BREAK',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.candidate.name.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: JungleTheme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),
              _waveform(),
              const SizedBox(height: 10),
              _previewRow(),
              const SizedBox(height: 16),
              Text('BARS', style: labelSmall),
              const SizedBox(height: 6),
              _barsRow(),
              const SizedBox(height: 16),
              Text('TEMPO', style: labelSmall),
              const SizedBox(height: 6),
              _tempoRow(),
              const SizedBox(height: 16),
              _summary(labelSmall),
              const SizedBox(height: 18),
              _useButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waveform() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              _grabHandle(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _dragHandle(details.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _releaseHandle(),
          onHorizontalDragCancel: _releaseHandle,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: JungleTheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: JungleTheme.line),
            ),
            child: CustomPaint(
              painter: WaveformPainter(
                peaks: _peaks,
                startFraction: _frames == 0 ? 0 : _trim.startFrame / _frames,
                endFraction: _frames == 0
                    ? 1
                    : (_trim.endFrame / _frames).clamp(0.0, 1.0),
                barLines: _trim.bars,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Grabs whichever handle is nearer, so there is nothing to aim at: the trim
  /// edge you meant is the one you touched closest to.
  void _grabHandle(double x, double width) {
    final startX = _trim.startFrame / _frames * width;
    final endX = _trim.endFrame / _frames * width;
    setState(() => _draggingStart = (x - startX).abs() <= (x - endX).abs());
  }

  void _dragHandle(double x, double width) {
    final grabbedStart = _draggingStart;
    if (grabbedStart == null || width <= 0) return;
    final frame = (x / width * _frames).round().clamp(0, _frames);
    setState(() {
      if (grabbedStart) {
        // Moving the start moves the loop rather than resizing it, up to the
        // point where the loop would run off the end. A break you trimmed to
        // length should not lose its length because you nudged where it starts.
        final start = frame.clamp(0, _frames - _minimumLength);
        final length = _trim.lengthFrames.clamp(
          _minimumLength,
          _frames - start,
        );
        _trim = _trim.copyWith(startFrame: start, lengthFrames: length);
      } else {
        _trim = _trim.copyWith(
          lengthFrames: (frame - _trim.startFrame).clamp(
            _minimumLength,
            _frames - _trim.startFrame,
          ),
        );
      }
      _bpmField.text = _bpmText;
    });
  }

  void _releaseHandle() {
    setState(() => _draggingStart = null);
    // Only at the end of the drag: restarting the preview on every frame of a
    // drag would be a stutter, not a preview.
    if (_previewing) unawaited(_startPreview());
  }

  /// A hundredth of a second. Below this the trim has collapsed and the tempo
  /// readout goes to nonsense.
  int get _minimumLength => (_sampleRate / 100).round();

  Widget _previewRow() {
    return Row(
      children: [
        Expanded(
          child: _Button(
            label: _previewing ? 'STOP' : 'PREVIEW LOOP',
            filled: _previewing,
            onTap: _togglePreview,
          ),
        ),
      ],
    );
  }

  Future<void> _togglePreview() async {
    if (_previewing) {
      setState(() => _previewing = false);
      await ref.read(studioProvider.notifier).stopAuditionClip();
      return;
    }
    setState(() => _previewing = true);
    await _startPreview();
  }

  Future<void> _startPreview() => ref
      .read(studioProvider.notifier)
      .auditionClip(sliceOf(widget.candidate.clip, _trim), looping: true);

  Widget _barsRow() {
    return Row(
      children: [
        for (final bars in const [1, 2, 4, 8])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Button(
                label: '$bars',
                filled: bars == _trim.bars,
                // Re-reads the same region as a different number of bars, which
                // is what "that is two bars, not one" means: the trim stays put
                // and the tempo halves.
                onTap: () => setState(() {
                  _trim = _trim.copyWith(bars: bars);
                  _bpmField.text = _bpmText;
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tempoRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: JungleTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _bpmIsUsable ? JungleTheme.line : JungleTheme.hot,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bpmField,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: _applyTypedBpm,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      color: JungleTheme.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('BPM', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: _Button(
            label: _taps.hasTempo ? 'TAP ${_taps.taps}' : 'TAP',
            filled: false,
            onTap: _tap,
          ),
        ),
      ],
    );
  }

  /// Typing a tempo moves the end of the trim to where that tempo puts it.
  ///
  /// Out of range values are left alone rather than clamped: half of "1" on the
  /// way to "170" is not a tempo anyone meant.
  void _applyTypedBpm(String text) {
    final typed = double.tryParse(text);
    if (typed == null ||
        typed < StudioController.minBpm ||
        typed > StudioController.maxBpm) {
      return;
    }
    _setBpm(typed, updateField: false);
  }

  void _tap() {
    final tapped = _taps.tap(_clock.elapsed);
    if (tapped == null) {
      setState(() {});
      return;
    }
    // Tapping in a jungle break usually means tapping the half time pulse, but
    // guessing which is exactly the kind of cleverness that gets a tempo wrong,
    // so the tap is taken at face value and the octave is the user's to fix.
    _setBpm(tapped.clamp(StudioController.minBpm, StudioController.maxBpm));
  }

  void _setBpm(double bpm, {bool updateField = true}) {
    final wanted = TrimSelection.framesFor(
      bpm: bpm,
      bars: _trim.bars,
      sampleRate: _sampleRate,
    );
    setState(() {
      _trim = _trim.copyWith(
        lengthFrames: wanted.clamp(_minimumLength, _frames - _trim.startFrame),
      );
      if (updateField) _bpmField.text = _bpmText;
    });
    if (_previewing) unawaited(_startPreview());
  }

  Widget _summary(TextStyle? style) {
    final seconds = _trim.lengthFrames / _sampleRate;
    return Column(
      children: [
        Text(
          '${_trim.bars} BAR${_trim.bars == 1 ? '' : 'S'}  '
          '${seconds.toStringAsFixed(2)}s  '
          '${_bpm.round()} BPM',
          textAlign: TextAlign.center,
          style: style,
        ),
        if (!_bpmIsUsable) ...[
          const SizedBox(height: 6),
          Text(
            'THAT IS ${_bpm.round()} BPM AT ${_trim.bars} '
            'BAR${_trim.bars == 1 ? '' : 'S'}. TRY A DIFFERENT BAR COUNT.',
            textAlign: TextAlign.center,
            style: style?.copyWith(color: JungleTheme.hot),
          ),
        ],
        if (widget.candidate.truncated) ...[
          const SizedBox(height: 6),
          Text(
            'THAT FILE WAS LONGER THAN THE IMPORT LIMIT AND WAS CUT SHORT.',
            textAlign: TextAlign.center,
            style: style,
          ),
        ],
      ],
    );
  }

  Widget _useButton() {
    return SizedBox(
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: JungleTheme.accent,
          foregroundColor: JungleTheme.background,
          disabledBackgroundColor: JungleTheme.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: _saving || !_bpmIsUsable ? null : _use,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: JungleTheme.background,
                ),
              )
            : const Text(
                'USE THIS BREAK',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
      ),
    );
  }

  Future<void> _use() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(studioProvider.notifier)
          .useImportedBreak(widget.candidate, _trim, _bpm);
      navigator.pop(true);
    } on Object catch (error) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? JungleTheme.accent : JungleTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: filled ? JungleTheme.accent : JungleTheme.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? JungleTheme.background : JungleTheme.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
