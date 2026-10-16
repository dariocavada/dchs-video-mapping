import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/presets/preset.dart';
import 'package:dchs_video_mapping/presets/preset_repository.dart';
import 'package:dchs_video_mapping/infrastructure/media_import.dart';
import 'package:dchs_video_mapping/infrastructure/operator_access.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('dchs-video-mapping-test');
    await Directory('${root.path}/media').create();
    await File('${root.path}/media/demo.mp4').writeAsBytes([1, 2, 3]);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'fallback remains recoverable after a second failed/corrupt revision',
    () async {
      final r = PresetRepository(root), p = ProjectionPreset.initial();
      await r.save(p);
      await r.save(p.copyWith(label: 'Secondo'));
      await File('${root.path}/presets.json').writeAsString('{broken');
      expect((await r.loadActive())!.label, 'Postazione 01');
      await r.save(p.copyWith(label: 'Terzo'));
      await File('${root.path}/presets.json').writeAsString('{broken again');
      expect((await r.loadActive())!.label, 'Postazione 01');
    },
  );
  test(
    'failed commit and missing video do not replace valid active preset',
    () async {
      final p = ProjectionPreset.initial();
      await PresetRepository(root).save(p);
      final failing = PresetRepository(
        root,
        beforeCommit: () async {
          throw const FileSystemException('disk full');
        },
      );
      await expectLater(
        failing.save(p.copyWith(label: 'Mai salvato')),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await PresetRepository(root).loadActive())!.label,
        'Postazione 01',
      );
      await expectLater(
        PresetRepository(root).save(p.copyWith(mediaPath: 'media/missing.mp4')),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
  test('multiple presets survive duplicate and active selection', () async {
    final r = PresetRepository(root);
    await r.save(ProjectionPreset.initial());
    await r.save(
      ProjectionPreset.initial().copyWith(id: 'secondo', label: 'Secondo'),
    );
    expect((await r.list()).length, 2);
    await r.activate('postazione-01');
    expect((await r.loadActive())!.id, 'postazione-01');
  });
  test(
    'media validation failure removes candidate and preserves original',
    () async {
      final importer = MediaImporter(root);
      await expectLater(
        importer.import(
          Stream.value([9, 8, 7]),
          'mp4',
          validate: (_) async {
            throw const FormatException('bad codec');
          },
        ),
        throwsFormatException,
      );
      expect(await File('${root.path}/media/demo.mp4').readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect((await Directory('${root.path}/media').list().toList()).length, 1);
      final path = await importer.import(
        Stream.value([5, 6]),
        'mp4',
        validate: (f) async {
          expect(await f.readAsBytes(), [5, 6]);
        },
      );
      expect(path, startsWith('media/'));
      expect(await File('${root.path}/$path').readAsBytes(), [5, 6]);
    },
  );
  test('PIN is private, no default, verification survives reload', () async {
    final a = await OperatorAccess.load(root);
    expect(a.isSet, false);
    expect(await a.verify('123456'), false);
    await a.setPin('492681');
    expect(await a.verify('492681'), true);
    expect(await a.verify('999999'), false);
    final raw = await File('${root.path}/access.json').readAsString();
    expect(raw, isNot(contains('492681')));
    expect(jsonDecode(raw)['hash'], isNotNull);
    expect(await (await OperatorAccess.load(root)).verify('492681'), true);
  });
}
