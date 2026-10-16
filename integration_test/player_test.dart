import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dchs_video_mapping/app/player_app.dart';
import 'package:dchs_video_mapping/mapping/geometry.dart';
import 'package:dchs_video_mapping/infrastructure/media_import.dart';
import 'package:dchs_video_mapping/playback/playback_backend.dart';
import 'package:dchs_video_mapping/presets/preset.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android video texture: affine, Bezier, quad, loop, PIN and persisted startup',
    (tester) async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final support = await getApplicationSupportDirectory(),
          root = Directory('${support.path}/player-integration');
      if (await root.exists()) await root.delete(recursive: true);
      final session = await PlayerSession.open(root);
      await tester.pumpWidget(PlayerApp(session: session));
      Future<void> frames([int ms = 400]) async {
        await tester.pump(Duration(milliseconds: ms));
        await tester.pump();
      }

      await frames();
      expect(find.byKey(const ValueKey('setup-player')), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await frames();
      await binding.takeScreenshot('00-player-setup-android');
      await tester.tap(find.byKey(const ValueKey('setup-player')));
      await frames();
      await tester.enterText(
        find.byKey(const ValueKey('dialog-input')),
        '628491',
      );
      await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
      await frames(700);
      await tester.enterText(
        find.byKey(const ValueKey('dialog-input')),
        '628491',
      );
      await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
      for (
        var i = 0;
        i < 30 && find.byKey(const ValueKey('tab-mask')).evaluate().isEmpty;
        i++
      ) {
        await frames(200);
      }
      expect(find.byKey(const ValueKey('tab-mask')), findsOneWidget);
      // A test device may use a raster different from the initial preset.
      final recalibrate = find.text('Ricalibra output');
      if (recalibrate.evaluate().isNotEmpty) {
        await tester.tap(recalibrate);
        await frames();
        await tester.tap(find.byKey(const ValueKey('confirm-action')));
        await frames();
      }
      expect(session.playback.visible, true);
      final imported = await MediaImporter(root).import(
        File('${root.path}/media/demo.mp4').openRead(),
        'mp4',
        validate: (file) async {
          final b = AndroidVideoBackend();
          try {
            await b.initialize(file);
          } finally {
            await b.close();
          }
        },
      );
      final importedPreset = session.editor.draft.copyWith(mediaPath: imported);
      expect(
        await session.playback.open(
          File('${root.path}/$imported'),
          importedPreset,
        ),
        true,
      );
      session.editor.change(importedPreset);
      expect(imported, isNot('media/demo.mp4'));

      final before = session.playback.snapshot.position;
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await frames(50);
      expect(session.playback.snapshot.position, isNot(before));
      await frames();
      await binding.takeScreenshot('01-player-geometria-android');
      await tester.tap(find.byKey(const ValueKey('tab-mask')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('mask-arch')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('confirm-mask')));
      await frames();
      expect(session.editor.draft.mask.enabled, true);
      final rect = tester.getRect(find.byKey(const ValueKey('mapping-canvas')));
      final original = session.editor.draft.mask.nodes.first.position;
      final gesture = await tester.startGesture(
        rect.topLeft +
            Offset(original.dx * rect.width, original.dy * rect.height),
      );
      await gesture.moveBy(const Offset(20, 0));
      await frames(30);
      await gesture.moveBy(const Offset(35, 10));
      await frames(30);
      await gesture.up();
      await frames();
      expect(session.editor.draft.mask.nodes.first.position, isNot(original));
      await tester.tap(find.byKey(const ValueKey('undo')));
      await frames();
      expect(session.editor.draft.mask.nodes.first.position, original);
      await tester.tap(find.text('Uscente'));
      await frames();
      final handle = session.editor.draft.mask.nodes.first.outHandle;
      await tester.tap(find.text('↑'));
      await frames();
      expect(
        session.editor.draft.mask.nodes.first.outHandle.dy,
        closeTo(handle.dy - 1 / 1080, 1e-9),
      );
      await tester.tap(find.byKey(const ValueKey('mask-add')));
      await frames();
      final at = session.editor.draft.mask.at(0, .5);
      await tester.tapAt(
        rect.topLeft + Offset(at.dx * rect.width, at.dy * rect.height),
      );
      await frames();
      expect(session.editor.draft.mask.nodes.length, 5);
      expect(session.editor.canSave, true);
      await binding.takeScreenshot('02-player-maschera-bezier-android');
      await tester.tap(find.byKey(const ValueKey('save-preset')));
      await frames();
      for (var i = 0; i < 20 && session.editor.dirty; i++) {
        await frames(200);
      }
      expect(session.editor.dirty, false);
      final saved = await session.repository.loadActive();
      expect(saved!.mask.toJson(), session.editor.draft.mask.toJson());
      await tester.tap(find.byKey(const ValueKey('only-projection')));
      await frames();
      expect(find.byKey(const ValueKey('public-output')), findsOneWidget);
      expect(find.text('Salva preset'), findsNothing);
      await binding.takeScreenshot('03-player-proiezione-bezier-android');
      // Curve affects clipping only: source affine mapping remains identity.
      final m = mappingMatrix(
        session.editor.draft,
        session.editor.draft.outputSize,
      );
      expect(
        (projectPoint(m, const Offset(960, 540)) - const Offset(960, 540))
            .distance,
        lessThan(.5),
      );
      var wraps = 0, previous = session.playback.snapshot.position;
      for (var i = 0; i < 65 && wraps < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
        await frames(10);
        final pos = session.playback.snapshot.position;
        if (pos < previous) wraps++;
        previous = pos;
      }
      expect(wraps, 2);
      expect(session.playback.diagnostic, isNull);
      // Reserved access requires the configured PIN.
      final held = await tester.startGesture(const Offset(35, 35));
      await frames(3200);
      await held.up();
      await frames();
      await tester.enterText(
        find.byKey(const ValueKey('dialog-input')),
        '628491',
      );
      await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
      for (
        var i = 0;
        i < 30 && find.byKey(const ValueKey('tab-geometry')).evaluate().isEmpty;
        i++
      ) {
        await frames(200);
      }
      expect(find.byKey(const ValueKey('tab-geometry')), findsOneWidget);
      session.editor.setMode(MappingMode.quad);
      session.editor.change(
        session.editor.draft.copyWith(
          corners: const [
            Offset(.08, .06),
            Offset(.92, .13),
            Offset(.86, .94),
            Offset(.14, .88),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tab-geometry')));
      await frames();
      expect(session.editor.canSave, true);
      await binding.takeScreenshot('04-player-quattro-angoli-android');
      // Actual animated texture, not a substitute pattern, is rendered through H.
      await tester.tap(find.byKey(const ValueKey('save-preset')));
      await frames();
      for (var i = 0; i < 20 && session.editor.dirty; i++) {
        await frames(200);
      }
      expect(session.editor.dirty, false);
      await tester.tap(find.byKey(const ValueKey('only-projection')));
      await frames();
      await binding.takeScreenshot('05-player-proiezione-quad-android');
      final reopen = await session.repository.loadActive();
      expect(reopen!.mode, MappingMode.quad);
      expect(reopen.corners, const [
        Offset(.08, .06),
        Offset(.92, .13),
        Offset(.86, .94),
        Offset(.14, .88),
      ]);
      await tester.pumpWidget(const SizedBox());
      await session.close();
      final restarted = await PlayerSession.open(root);
      await tester.pumpWidget(PlayerApp(session: restarted));
      await frames();
      expect(find.byKey(const ValueKey('public-output')), findsOneWidget);
      expect(restarted.editor.draft.mode, MappingMode.quad);
      expect(restarted.playback.snapshot.playing, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await restarted.close();
    },
  );
}
