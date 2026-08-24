import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:junglengine/models/project.dart';

/// Local project persistence. One file, JSON, no cloud and no accounts.
///
/// The project is the app's whole document, and it is small: a few hundred
/// integers per Beat. Writing all of it on every change is simpler than any
/// incremental scheme and is still far cheaper than a frame.
class ProjectStore {
  const ProjectStore({this.fileName = 'junglengine-project.json'});

  final String fileName;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  /// The saved project, or null when there is nothing saved yet.
  ///
  /// A file that will not parse is treated as nothing saved. Losing a project
  /// is bad; refusing to open the app because of one bad byte is worse.
  Future<Project?> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      return Project.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  /// Writes to a temp file and renames it over the real one, so a save that is
  /// interrupted leaves the previous project intact rather than half a file.
  Future<void> save(Project project) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
    await temp.rename(file.path);
  }
}
