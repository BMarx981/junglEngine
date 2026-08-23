import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Where imported audio lives.
///
/// One flat directory beside the project file, holding 16 bit WAVs written at
/// import time. Files are named, never pathed, in the project JSON: the
/// documents directory moves between launches on iOS, so an absolute path
/// stored yesterday points nowhere today.
///
/// Nothing here decodes or trims. By the time a clip reaches [write] it is
/// already the loop, at the engine's rate, and this only has to put it
/// somewhere it will still be after a restart.
class ImportStore {
  const ImportStore({this.directoryName = 'imports'});

  final String directoryName;

  /// Where imported audio goes.
  ///
  /// Only [write] creates it. Reading and sweeping a directory that is not
  /// there have nothing to do, and a project with no imports should never leave
  /// an empty folder behind to explain.
  Future<Directory> directory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/$directoryName');
  }

  /// Absolute path of a file named in the project.
  Future<String> pathOf(String fileName) async =>
      '${(await directory()).path}/$fileName';

  /// Whether a file the project points at is actually still there. A project
  /// that outlived its audio opens on a bundled break rather than failing.
  Future<bool> exists(String fileName) async =>
      File(await pathOf(fileName)).existsSync();

  /// Writes [bytes] under a name derived from [baseName] and returns the name.
  ///
  /// [stamp] makes the name unique. Importing the same file twice is a normal
  /// thing to do -- different trim, different tempo -- and the second one must
  /// not land on top of the first, which the project may still be using.
  Future<String> write(
    String baseName,
    Uint8List bytes, {
    required int stamp,
  }) async {
    final imports = await directory();
    if (!imports.existsSync()) await imports.create(recursive: true);
    final fileName = '${slug(baseName)}-$stamp.wav';
    final file = File('${imports.path}/$fileName');
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    return fileName;
  }

  /// Deletes everything in the directory that [keep] does not name.
  ///
  /// Imported audio is only ever reachable through the project, so a file the
  /// project stopped pointing at is unreachable, not spare. Swapping breaks a
  /// few times should not quietly fill a phone.
  Future<void> sweep(Iterable<String> keep) async {
    final wanted = keep.toSet();
    final imports = await directory();
    if (!imports.existsSync()) return;
    for (final entry in imports.listSync()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (wanted.contains(name)) continue;
      try {
        entry.deleteSync();
      } on Object {
        // A file that will not delete is a wasted megabyte, not a failure the
        // user needs to hear about.
      }
    }
  }

  /// File name safe, lower case, and short enough to stay readable.
  static String slug(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r'\.[a-z0-9]{1,5}$'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (cleaned.isEmpty) return 'import';
    return cleaned.length <= 32 ? cleaned : cleaned.substring(0, 32);
  }

  /// The name an imported file gets in the UI: the file's own name, tidied,
  /// with the extension dropped.
  static String displayName(String fileName) {
    final base = fileName.split('/').last.split('\\').last;
    final stripped = base.replaceAll(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '').trim();
    if (stripped.isEmpty) return 'Imported';
    return stripped.length <= 24 ? stripped : stripped.substring(0, 24);
  }

  /// The gutter label for an imported one shot. Four characters, upper case,
  /// because that is what fits beside the Kit grid.
  static String slotLabel(String fileName) {
    final letters = displayName(
      fileName,
    ).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (letters.isEmpty) return 'USER';
    return letters.length <= 4 ? letters : letters.substring(0, 4);
  }
}
