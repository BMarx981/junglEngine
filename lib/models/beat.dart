import 'chop_pattern.dart';
import 'machine_type.dart';
import 'steps.dart';
import 'sub_lane.dart';
import 'sub_patch.dart';

/// Slice divisions offered by the Chop machine. Equal division only in M0;
/// transient detection is a separate future feature.
const List<int> allowedSliceCounts = [8, 16, 32];

/// One pattern's worth of music: a drum grid plus the sub lane.
///
/// The machine type is fixed at creation. M0 only creates [MachineType.chop],
/// but Kit Beats slot in beside them without touching this shape.
class Beat {
  Beat({
    required this.id,
    required this.name,
    this.machineType = MachineType.chop,
    this.bars = 1,
    this.sliceCount = 16,
    ChopPattern? chop,
    SubLane? sub,
    this.subPatch = const SubPatch(),
    this.subRootMidi = 36,
  }) : chop = chop ?? ChopPattern.empty(bars: bars),
       sub = sub ?? SubLane.empty(bars: bars);

  final String id;
  final String name;
  final MachineType machineType;
  final int bars;

  /// Equal divisions of the project break. Chop machine only.
  final int sliceCount;

  /// The break step grid. Empty and unused on a Kit Beat.
  final ChopPattern chop;

  /// The sub lane, present on every machine type.
  final SubLane sub;
  final SubPatch subPatch;

  /// MIDI note that semitone 0 of the sub lane maps to.
  final int subRootMidi;

  int get stepCount => bars * stepsPerBar;

  Beat copyWith({
    String? id,
    String? name,
    int? sliceCount,
    ChopPattern? chop,
    SubLane? sub,
    SubPatch? subPatch,
  }) => Beat(
    id: id ?? this.id,
    name: name ?? this.name,
    machineType: machineType,
    bars: bars,
    sliceCount: sliceCount ?? this.sliceCount,
    chop: chop ?? this.chop,
    sub: sub ?? this.sub,
    subPatch: subPatch ?? this.subPatch,
    subRootMidi: subRootMidi,
  );

  /// Re-slices the break, dropping any painted slice that no longer exists.
  Beat resliced(int count) =>
      copyWith(sliceCount: count, chop: chop.clampedTo(count));

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'machine': machineType.toJson(),
    'bars': bars,
    'sliceCount': sliceCount,
    'chop': chop.toJson(),
    'sub': sub.toJson(),
    'subPatch': subPatch.toJson(),
    'subRootMidi': subRootMidi,
  };

  static Beat fromJson(Map<String, Object?> json) {
    final bars = json['bars'] is int ? json['bars']! as int : 1;
    return Beat(
      id: json['id'] as String? ?? 'beat',
      name: json['name'] as String? ?? 'Beat',
      machineType: MachineType.fromJson(json['machine']),
      bars: bars,
      sliceCount: json['sliceCount'] is int ? json['sliceCount']! as int : 16,
      chop: ChopPattern.fromJson(json['chop']),
      sub: SubLane.fromJson(json['sub']),
      subPatch: SubPatch.fromJson(json['subPatch']),
      subRootMidi: json['subRootMidi'] is int
          ? json['subRootMidi']! as int
          : 36,
    );
  }
}
