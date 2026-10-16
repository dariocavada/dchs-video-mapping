import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import '../presets/preset.dart';

class SupportArchive {
  static Future<void> write(
    Directory root,
    File destination,
    ProjectionPreset draft,
  ) {
    final rootPath = root.path,
        destinationPath = destination.path,
        json = draft.toJson();
    return Isolate.run(
      () => _ArchiveWorker.write(
        Directory(rootPath),
        File(destinationPath),
        ProjectionPreset.fromJson(json),
      ),
    );
  }
}

class _ArchiveWorker {
  static Future<void> write(
    Directory root,
    File destination,
    ProjectionPreset draft,
  ) async {
    // Stream ZIP output: video and access.json are intentionally excluded.
    final encoder = ZipFileEncoder();
    encoder.create(destination.path);
    try {
      for (final name in ['presets.json', 'presets.backup.json']) {
        final f = File('${root.path}/$name');
        if (await f.exists()) await encoder.addFile(f, name);
      }
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(draft.toJson()),
      );
      encoder.addArchiveFile(ArchiveFile('bozza.json', bytes.length, bytes));
      final logs = Directory('${root.path}/logs');
      if (await logs.exists()) {
        await for (final file in logs.list()) {
          if (file is File) {
            await encoder.addFile(file, 'logs/${file.uri.pathSegments.last}');
          }
        }
      }
    } finally {
      encoder.close();
    }
  }
}
