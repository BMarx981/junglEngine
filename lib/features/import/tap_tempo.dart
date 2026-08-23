/// Tap four times, get a tempo.
///
/// BPM autodetection is parked and stays parked. A person who can hear where
/// the loop is can tap it in two seconds, and unlike a detector they are never
/// confidently wrong by a factor of two.
class TapTempo {
  /// Taps further apart than this start a new count. Two seconds is 30 BPM,
  /// well under anything this app plays, so a gap that long was a pause rather
  /// than a beat.
  static const Duration resetAfter = Duration(seconds: 2);

  /// How many taps are averaged. Four is one bar, which is how people count
  /// themselves in.
  static const int window = 4;

  final List<Duration> _taps = [];

  /// Taps recorded so far, for a UI that wants to show progress.
  int get taps => _taps.length;

  /// Whether there are enough taps for [bpm] to mean anything.
  bool get hasTempo => _taps.length >= 2;

  /// Records a tap at [at], measured from any fixed origin, and returns the
  /// tempo so far. Null until the second tap: one tap is not an interval.
  double? tap(Duration at) {
    if (_taps.isNotEmpty && at - _taps.last > resetAfter) _taps.clear();
    _taps.add(at);
    if (_taps.length > window + 1) _taps.removeAt(0);
    return bpm;
  }

  /// The average of the intervals in the window, as a tempo.
  double? get bpm {
    if (_taps.length < 2) return null;
    final span = _taps.last - _taps.first;
    if (span <= Duration.zero) return null;
    final average = span.inMicroseconds / (_taps.length - 1);
    return 60000000 / average;
  }

  void reset() => _taps.clear();
}
