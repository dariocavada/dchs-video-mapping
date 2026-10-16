import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/infrastructure/support_archive.dart';
import 'package:dchs_video_mapping/presets/preset.dart';

void main() {
  test(
    'support export contains config and logs, excludes PIN and videos',
    () async {
      final root = await Directory.systemTemp.createTemp('player-export');
      await Directory('${root.path}/logs').create();
      await File('${root.path}/logs/player.log').writeAsString('startup');
      await File('${root.path}/presets.json').writeAsString('configuration');
      await File('${root.path}/access.json').writeAsString('private hash');
      await Directory('${root.path}/media').create();
      await File('${root.path}/media/demo.mp4').writeAsBytes([1, 2, 3]);
      final zip = File('${root.path}/support.zip');
      await SupportArchive.write(root, zip, ProjectionPreset.initial());
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      expect(archive.files.map((f) => f.name).toSet(), {
        'presets.json',
        'draft.json',
        'logs/player.log',
      });
      await root.delete(recursive: true);
    },
  );
}
