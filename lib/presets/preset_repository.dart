import 'dart:convert';
import 'dart:io';

import 'preset.dart';

class PresetRepository {
  PresetRepository(this.root, {this.beforeCommit});
  final Directory root;
  final Future<void> Function()? beforeCommit;
  Future<void> _queue = Future.value();
  bool recovered = false;
  String? warning;
  File _file(String name) => File('${root.path}/$name');
  Future<Map<String, dynamic>?> _read(String name) async {
    try {
      final f = _file(name);
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (j['schemaVersion'] != 1) {
        throw const FormatException('Unsupported archive version');
      }
      final list = (j['presets'] as List)
          .map(
            (p) =>
                ProjectionPreset.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList();
      if (list.isEmpty ||
          list.map((p) => p.id).toSet().length != list.length ||
          !list.any((p) => p.id == j['activeId'])) {
        throw const FormatException('Invalid preset archive');
      }
      return j;
    } catch (e) {
      warning = 'Cannot read archive $name: $e';
      return null;
    }
  }

  Future<Map<String, dynamic>?> _current() async {
    final primary = await _read('presets.json');
    if (primary != null) {
      recovered = false;
      return primary;
    }
    final backup = await _read('presets.backup.json');
    recovered = backup != null;
    return backup;
  }

  List<ProjectionPreset> _presets(Map<String, dynamic>? j) => j == null
      ? []
      : (j['presets'] as List)
            .map(
              (p) => ProjectionPreset.fromJson(
                Map<String, dynamic>.from(p as Map),
              ),
            )
            .toList();
  Future<ProjectionPreset?> loadActive() async {
    final j = await _current();
    if (j == null) return null;
    return _presets(j).firstWhere((p) => p.id == j['activeId']);
  }

  Future<List<ProjectionPreset>> list() async => _presets(await _current());
  Future<void> _serial(Future<void> Function() fn) {
    final result = _queue.then((_) => fn());
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> save(ProjectionPreset p) => _serial(() async {
    p.validate();
    final media = File('${root.path}/${p.mediaPath}');
    if (!await media.exists() || await media.length() == 0) {
      throw const FileSystemException('The preset video is unavailable.');
    }
    await root.create(recursive: true);
    final old = await _current(), presets = _presets(old);
    final updated = [...presets.where((v) => v.id != p.id), p];
    final data = jsonEncode({
      'schemaVersion': 1,
      'activeId': p.id,
      'presets': updated.map((v) => v.toJson()).toList(),
    });
    final temp = _file('presets.tmp');
    await temp.writeAsString(data, flush: true);
    if (beforeCommit != null) await beforeCommit!();
    // Copy the validated snapshot, including a recovered backup. Never rotate a
    // corrupt primary over the only good backup.
    if (old != null) {
      await _file('presets.backup.tmp')
          .writeAsString(jsonEncode(old), flush: true);
      await _file('presets.backup.tmp')
          .rename(_file('presets.backup.json').path);
    }
    await temp.rename(_file('presets.json').path);
    recovered = false;
  });
  Future<void> activate(String id) async {
    final presets = await list();
    await save(presets.firstWhere((p) => p.id == id));
  }

  Future<ProjectionPreset> previous() async {
    final j = await _read('presets.backup.json');
    if (j == null) {
      throw const FormatException('No valid previous copy.');
    }
    return _presets(j).firstWhere((p) => p.id == j['activeId']);
  }
}
