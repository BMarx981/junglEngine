/// The kind of machine a [Beat] runs.
///
/// M0 only ships [chop], but the type is modelled from day one so that adding
/// the Kit machine in M1 is additive rather than a data migration.
enum MachineType {
  /// Break resequencer: rows are slices of the project break.
  chop,

  /// Step drum machine: 8 one shot slots. Ships in M1.
  kit;

  static MachineType fromJson(Object? value) {
    return MachineType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => MachineType.chop,
    );
  }

  String toJson() => name;
}
