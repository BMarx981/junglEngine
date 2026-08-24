import 'package:junglengine/models/chop_pattern.dart';
import 'package:junglengine/models/kit_pattern.dart';
import 'package:junglengine/models/kit_slot.dart';
import 'package:junglengine/models/machine_type.dart';
import 'package:junglengine/models/steps.dart';
import 'package:junglengine/models/sub_lane.dart';
import 'package:junglengine/models/sub_patch.dart';

/// Slice divisions offered by the Chop machine, **per bar of the break**.
///
/// Per bar rather than per break, because that is the only reading where the
/// numbers mean note values: 16 is always a sixteenth note, whether the break
/// is one bar or four. Dividing a four bar break into 16 would give quarter
/// notes, which cannot chop.
///
/// Equal division only in M0; transient detection is a separate future feature.
const List<int> allowedSliceDivisions = [8, 16, 32];

/// Lengths a Beat can be created at, in bars. Fixed at creation: a Beat's
/// timeline never changes under the pattern that was written on it.
const List<int> allowedBarLengths = [1, 2, 4, 8];

/// One pattern's worth of music: a drum grid plus the sub lane.
///
/// The machine type is fixed at creation. A Chop Beat resequences the project
/// break; a Kit Beat plays the project kit's one shots. Both carry the sub lane
/// and both are just Beats to the Song.
class Beat {
  Beat({
    required this.id,
    required this.name,
    this.machineType = MachineType.chop,
    this.bars = 1,
    this.sliceCount = 16,
    ChopPattern? chop,
    KitPattern? kit,
    List<KitSlot>? kitSlots,
    SubLane? sub,
    this.subPatch = const SubPatch(),
    this.subRootMidi = 36,
    double swing = 0,
  }) : swing = swing < 0 ? 0 : (swing > 1 ? 1 : swing),
       chop = chop ?? ChopPattern.empty(bars: bars),
       kit = kit ?? KitPattern.empty(bars: bars),
       kitSlots = kitSlots ?? KitSlot.defaults(kitSlotCount),
       sub = sub ?? SubLane.empty(bars: bars);

  final String id;
  final String name;
  final MachineType machineType;
  final int bars;

  /// Total equal divisions of the project break, across all of its bars. The
  /// user picks a per bar division from [allowedSliceDivisions] and this is
  /// that multiplied by the break's bar count. Chop machine only.
  final int sliceCount;

  /// The break step grid. Empty and unused on a Kit Beat.
  final ChopPattern chop;

  /// The one shot grid. Empty and unused on a Chop Beat.
  final KitPattern kit;

  /// Volume and pitch per Kit slot. Per Beat rather than per project, because
  /// the workflow is duplicate and tweak: a variation gets to retune its kit.
  final List<KitSlot> kitSlots;

  /// The sub lane, present on every machine type.
  final SubLane sub;
  final SubPatch subPatch;

  /// MIDI note that semitone 0 of the sub lane maps to.
  final int subRootMidi;

  /// Swing, 0..1, applied to every odd sixteenth of this Beat.
  ///
  /// Global per Beat and nothing finer, because this is the answer to triplet
  /// feel before triplet grids exist: one control that leans the whole pattern,
  /// not a per step nudge. 0 is straight, 1 is a hard triplet shuffle. See
  /// [swingOffsetFraction] for what the number means in time.
  final double swing;

  /// How far an odd step is pushed late, as a fraction of one step.
  ///
  /// 0.5 at full swing, which puts the offbeat two thirds of the way through
  /// the pair: the same place a 75% swing lands on a drum machine.
  double get swingOffsetFraction => swing * 0.5;

  /// Swing as a producer reads it: 50% is straight, 75% is triplets.
  int get swingPercent => 50 + (swing * 25).round();

  int get stepCount => bars * stepsPerBar;

  bool get isChop => machineType == MachineType.chop;

  bool get isKit => machineType == MachineType.kit;

  /// Whether the drum machine, whichever one this Beat runs, has nothing on it.
  bool get drumsAreEmpty => isKit ? kit.isEmpty : chop.isEmpty;

  KitSlot slot(int index) => (index >= 0 && index < kitSlots.length)
      ? kitSlots[index]
      : const KitSlot();

  Beat copyWith({
    String? id,
    String? name,
    int? sliceCount,
    ChopPattern? chop,
    KitPattern? kit,
    List<KitSlot>? kitSlots,
    SubLane? sub,
    SubPatch? subPatch,
    double? swing,
  }) => Beat(
    id: id ?? this.id,
    name: name ?? this.name,
    machineType: machineType,
    bars: bars,
    sliceCount: sliceCount ?? this.sliceCount,
    chop: chop ?? this.chop,
    kit: kit ?? this.kit,
    kitSlots: kitSlots ?? this.kitSlots,
    sub: sub ?? this.sub,
    subPatch: subPatch ?? this.subPatch,
    subRootMidi: subRootMidi,
    swing: swing ?? this.swing,
  );

  Beat withSlot(int index, KitSlot value) {
    if (index < 0 || index >= kitSlots.length) return this;
    return copyWith(
      kitSlots: List<KitSlot>.unmodifiable([
        for (var i = 0; i < kitSlots.length; i++)
          i == index ? value : kitSlots[i],
      ]),
    );
  }

  /// Re-slices the break, dropping any painted slice that no longer exists.
  Beat resliced(int count) =>
      copyWith(sliceCount: count, chop: chop.clampedTo(count));

  /// A full copy under a new identity. Duplicate is the core workflow, so this
  /// carries everything: both grids, the sub lane, the patch and the slots.
  Beat duplicate({required String id, required String name}) =>
      copyWith(id: id, name: name);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'machine': machineType.toJson(),
    'bars': bars,
    'sliceCount': sliceCount,
    'chop': chop.toJson(),
    'kit': kit.toJson(),
    'kitSlots': [for (final s in kitSlots) s.toJson()],
    'sub': sub.toJson(),
    'subPatch': subPatch.toJson(),
    'subRootMidi': subRootMidi,
    'swing': swing,
  };

  static Beat fromJson(Map<String, Object?> json) {
    final rawBars = json['bars'];
    final bars = rawBars is int && allowedBarLengths.contains(rawBars)
        ? rawBars
        : 1;
    final rawSlots = json['kitSlots'];
    return Beat(
      id: json['id'] as String? ?? 'beat',
      name: json['name'] as String? ?? 'Beat',
      machineType: MachineType.fromJson(json['machine']),
      bars: bars,
      sliceCount: json['sliceCount'] is int ? json['sliceCount']! as int : 16,
      chop: ChopPattern.fromJson(json['chop'], bars: bars),
      kit: KitPattern.fromJson(json['kit'], bars: bars),
      kitSlots: List<KitSlot>.unmodifiable([
        for (var i = 0; i < kitSlotCount; i++)
          KitSlot.fromJson(
            rawSlots is List && i < rawSlots.length ? rawSlots[i] : null,
          ),
      ]),
      sub: SubLane.fromJson(json['sub'], bars: bars),
      subPatch: SubPatch.fromJson(json['subPatch']),
      subRootMidi: json['subRootMidi'] is int
          ? json['subRootMidi']! as int
          : 36,
      swing: json['swing'] is num ? (json['swing']! as num).toDouble() : 0,
    );
  }
}
