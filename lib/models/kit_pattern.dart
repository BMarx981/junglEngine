import 'steps.dart';

/// Slots in a Kit machine. Eight, and that is the ceiling: see the Kit machine
/// spec in CLAUDE.md.
const int kitSlotCount = 8;

/// How hard a step hits.
///
/// Three levels, not 128. A tracker grid you play with a thumb needs velocities
/// you can see and cycle through, not a value you have to dial in.
enum KitVelocity {
  soft(0.40),
  medium(0.70),
  hard(1.00);

  const KitVelocity(this.gain);

  /// Multiplier applied to the slot's volume when this step fires.
  final double gain;

  /// Tap order: an empty cell places the loudest hit, and further taps walk it
  /// down and then off. Main hits are one tap, ghosts are three.
  static KitVelocity? next(KitVelocity? current) => switch (current) {
    null => KitVelocity.hard,
    KitVelocity.hard => KitVelocity.medium,
    KitVelocity.medium => KitVelocity.soft,
    KitVelocity.soft => null,
  };

  int toJson() => index + 1;

  static KitVelocity? fromJson(Object? value) {
    if (value is! int || value < 1 || value > KitVelocity.values.length) {
      return null;
    }
    return KitVelocity.values[value - 1];
  }
}

/// The Kit machine's grid: eight slots down, steps across.
///
/// Polyphonic across slots, unlike the Chop grid: every slot can fire on the
/// same step. No choke groups, so nothing here cancels anything else.
class KitPattern {
  KitPattern(this.slots);

  /// `slots[slot][step]`, `null` where the slot does not fire.
  final List<List<KitVelocity?>> slots;

  KitPattern.empty({int bars = 1})
    : slots = List<List<KitVelocity?>>.unmodifiable([
        for (var slot = 0; slot < kitSlotCount; slot++)
          List<KitVelocity?>.filled(bars * stepsPerBar, null, growable: false),
      ]);

  /// A plain kick, backbeat and eighth note hats, repeated over every bar.
  ///
  /// A new Kit Beat that played silence would be a dead end: you would have to
  /// program before you could hear anything. This is the Kit machine's
  /// equivalent of the Chop machine opening on the break itself.
  factory KitPattern.starter({int bars = 1}) {
    var pattern = KitPattern.empty(bars: bars);
    for (var bar = 0; bar < bars; bar++) {
      final base = bar * stepsPerBar;
      for (final step in [0, 10]) {
        pattern = pattern.withCell(0, base + step, KitVelocity.hard);
      }
      for (final step in [4, 12]) {
        pattern = pattern.withCell(1, base + step, KitVelocity.hard);
      }
      for (var step = 0; step < stepsPerBar; step += 2) {
        pattern = pattern.withCell(
          4,
          base + step,
          step % 4 == 0 ? KitVelocity.medium : KitVelocity.soft,
        );
      }
    }
    return pattern;
  }

  int get stepCount => slots.isEmpty ? 0 : slots.first.length;

  int get bars => stepCount ~/ stepsPerBar;

  bool get isEmpty =>
      slots.every((row) => row.every((velocity) => velocity == null));

  KitVelocity? velocityAt(int slot, int step) {
    if (slot < 0 || slot >= slots.length) return null;
    final row = slots[slot];
    return (step >= 0 && step < row.length) ? row[step] : null;
  }

  bool slotIsEmpty(int slot) =>
      slot < 0 ||
      slot >= slots.length ||
      slots[slot].every((velocity) => velocity == null);

  KitPattern withCell(int slot, int step, KitVelocity? velocity) {
    if (slot < 0 || slot >= slots.length) return this;
    if (step < 0 || step >= slots[slot].length) return this;
    final next = [
      for (var s = 0; s < slots.length; s++)
        s == slot ? List<KitVelocity?>.of(slots[s]) : slots[s],
    ];
    next[slot][step] = velocity;
    return KitPattern(
      List<List<KitVelocity?>>.unmodifiable([
        for (final row in next) List<KitVelocity?>.unmodifiable(row),
      ]),
    );
  }

  /// Tap behaviour: hard, then medium, then soft, then empty again.
  KitPattern cycled(int slot, int step) =>
      withCell(slot, step, KitVelocity.next(velocityAt(slot, step)));

  KitPattern cleared() => KitPattern.empty(bars: bars);

  List<Object?> toJson() => [
    for (final row in slots) [for (final v in row) v?.toJson() ?? 0],
  ];

  static KitPattern fromJson(Object? json, {int bars = 1}) {
    if (json is! List) return KitPattern.empty(bars: bars);
    final steps = bars * stepsPerBar;
    return KitPattern(
      List<List<KitVelocity?>>.unmodifiable([
        for (var slot = 0; slot < kitSlotCount; slot++)
          List<KitVelocity?>.unmodifiable([
            for (var step = 0; step < steps; step++)
              KitVelocity.fromJson(_cell(json, slot, step)),
          ]),
      ]),
    );
  }

  static Object? _cell(List<Object?> json, int slot, int step) {
    if (slot >= json.length) return null;
    final row = json[slot];
    if (row is! List || step >= row.length) return null;
    return row[step];
  }
}
