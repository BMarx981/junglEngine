import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:junglengine/audio/engine.dart';
import 'package:junglengine/audio/lira_engine.dart';
import 'package:junglengine/state/studio.dart';
import 'package:junglengine/theme.dart';

/// The M4 readout: what an edit costs, on the phone.
///
/// Stage 3 answers the gate on a device, and the first number it needs is the
/// wait between painting a step and hearing it. Both engines measure it and
/// report it through [AudioEngine.editLatency]; this is how it is read off a
/// phone that is not plugged into anything. It sits over the top right corner,
/// which is a small piece of the screen the measuring is not using.
///
/// Never in a build nobody asked for: `--dart-define=JE_LATENCY_HUD=true`, and
/// [showLatencyHud] is the only thing that puts it on screen. Deliberately
/// untranslated, for the same reason `--dart-define=JE_LOCALE` is debug only:
/// this is an instrument, not surface area, and it goes when the gate is
/// answered. See docs/M4.md.
class LatencyHud extends ConsumerStatefulWidget {
  const LatencyHud({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LatencyHud> createState() => _LatencyHudState();
}

class _LatencyHudState extends ConsumerState<LatencyHud> {
  /// Enough measurements for a median to mean something and few enough that a
  /// run of taps a minute ago is not still dragging it about.
  static const int _window = 64;

  final List<EditLatency> _samples = [];

  ValueListenable<EditLatency?>? _source;
  ValueListenable<TransportState>? _transport;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(audioEngineProvider);
    _source = engine.editLatency..addListener(_onEdit);
    _transport = engine.transport..addListener(_onTransport);
  }

  @override
  void dispose() {
    _source?.removeListener(_onEdit);
    _transport?.removeListener(_onTransport);
    super.dispose();
  }

  /// Rebuilds when playback starts or stops, and at no other time.
  ///
  /// Not for the playhead, which this does not draw: for the rate in the
  /// header. The Lira engine does not know what rate it is running at until
  /// the device has told it, which is after this widget first built, and a
  /// readout showing 44100 next to a device running at 48000 is exactly the
  /// wrong thing to be wrong about here.
  void _onTransport() {
    final playing = _transport?.value.playing ?? false;
    if (playing == _playing) return;
    setState(() => _playing = playing);
  }

  void _onEdit() {
    final latest = _source?.value;
    if (latest == null) return;
    setState(() {
      _samples.add(latest);
      if (_samples.length > _window) _samples.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.read(audioEngineProvider);
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            // Time and numbers, in a layout that mirrors around it. The
            // readout is ASCII either way, so pin it.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GestureDetector(
                onTap: () => setState(_samples.clear),
                child: _Readout(
                  engine: engine is LiraAudioEngine ? 'LIRA' : 'SOLOUD',
                  sampleRate: engine.sampleRate,
                  samples: _samples,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.engine,
    required this.sampleRate,
    required this.samples,
  });

  final String engine;
  final int sampleRate;
  final List<EditLatency> samples;

  @override
  Widget build(BuildContext context) {
    final totals = samples
        .map((s) => s.total.inMicroseconds / 1000)
        .toList(growable: false);
    // The two halves are worth seeing apart: EDIT is the whole wait and CALL
    // is the part of it that was Dart's, and only what is left over is what
    // the two engines actually differ on.
    final calls = samples
        .map((s) => s.callMicros / 1000)
        .toList(growable: false);

    // Above `home` rather than inside it, so there is no Material and no
    // inherited text style up here. This is what gives it both.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: JungleTheme.surface.withValues(alpha: 0.88),
          border: Border.all(color: JungleTheme.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _line('$engine $sampleRate', JungleTheme.accent),
            _line('EDIT ${_stat(totals)}', JungleTheme.text),
            _line('CALL ${_stat(calls)}', JungleTheme.textDim),
            _line('N ${samples.length}', JungleTheme.textDim),
          ],
        ),
      ),
    );
  }

  /// Median and worst, in milliseconds. The median is what an edit usually
  /// costs and the worst is what it costs when the block boundary, the timer
  /// and the thumb line up badly, which on the flutter_soloud engine is the
  /// whole queue.
  static String _stat(List<double> values) {
    if (values.isEmpty) return '--';
    final sorted = List<double>.of(values)..sort();
    final median = sorted[sorted.length ~/ 2];
    final worst = sorted.last;
    return '${_ms(median)} / ${_ms(worst)}';
  }

  static String _ms(double value) =>
      '${value.toStringAsFixed(value < 10 ? 2 : 1)}ms';

  static Widget _line(String text, Color color) => Text(
    text,
    style: JungleTheme.readout(fontSize: 11, color: color, height: 1.5),
  );
}

/// Wraps [child] in the readout when the define asks for it, and hands it
/// straight back when it does not. One line in `app.dart`, and no widget in
/// the tree at all in a build without the flag.
Widget withLatencyHud(Widget child) =>
    showLatencyHud ? LatencyHud(child: child) : child;
