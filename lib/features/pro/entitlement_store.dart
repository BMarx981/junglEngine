import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Remembers that Pro was bought.
///
/// One flag in one file beside the project. It exists so that the app knows on
/// a plane, on the second launch, before the store has answered: without it,
/// every cold start would show a paywall over features the user already owns
/// until the network came back.
///
/// It is a cache and never the authority. The store is the authority, and it
/// overwrites this either way the moment it answers. A user who edits the file
/// has unlocked a phone app with no server behind it; there is no accounts
/// system here to defend and there is not going to be one.
class EntitlementStore {
  const EntitlementStore({this.fileName = 'junglengine-pro.json'});

  final String fileName;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  /// What was remembered last time, or false when nothing was.
  Future<bool> read() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return false;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map && decoded['pro'] == true;
    } on Object {
      return false;
    }
  }

  Future<void> write({required bool pro}) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({'pro': pro}), flush: true);
    } on Object {
      // A cache that will not write costs one paywall on the next cold start,
      // which is not worth telling the user about.
    }
  }
}
