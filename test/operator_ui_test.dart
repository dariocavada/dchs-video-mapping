import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:dchs_video_mapping/app/player_app.dart';
import 'package:dchs_video_mapping/infrastructure/operator_access.dart';
import 'package:dchs_video_mapping/presets/preset_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/mapping/editor_controller.dart';
import 'package:dchs_video_mapping/presets/preset.dart';
import 'package:dchs_video_mapping/output/projection_surface.dart';
import 'package:dchs_video_mapping/operator_ui/operator_screen.dart';
import 'package:dchs_video_mapping/operator_ui/player_theme.dart';
import 'package:dchs_video_mapping/playback/playback_controller.dart';
import 'package:dchs_video_mapping/infrastructure/health_log.dart';

void main() {
  testWidgets(
    'first setup inherits Material typography and fits a small landscape viewport',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('player-setup-theme'),
      ))!;
      final log = HealthLog(root), playback = PlaybackController(log: log);
      final session = PlayerSession(
        root: root,
        repository: PresetRepository(root),
        access: (await tester.runAsync(() => OperatorAccess.load(root)))!,
        log: log,
        editor: MappingEditor(ProjectionPreset.initial()),
        playback: playback,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await session.close();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(PlayerApp(session: session));
      await tester.pump();
      final paragraph = find.text(
        'Imposta un PIN del personale, importa il video e calibra la superficie. Il filmato incluso è dimostrativo.',
      );
      final style = tester.renderObject<RenderParagraph>(paragraph).text.style!;
      final theme = Theme.of(tester.element(paragraph));
      expect(style.fontFamily, theme.textTheme.bodyMedium!.fontFamily);
      expect(style.fontSize, theme.textTheme.bodyMedium!.fontSize);
      expect(style.color, PlayerTheme.onSurface);
      expect(
        style.decoration?.contains(TextDecoration.underline) ?? false,
        false,
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 2.5;
      await tester.pump();
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byKey(const ValueKey('setup-player')));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(384));
      expect(button.top, greaterThanOrEqualTo(0));
      expect(button.bottom, lessThanOrEqualTo(216));
      await tester.pumpWidget(const SizedBox());
      await playback.close();
    },
  );

  testWidgets('PIN dialog keeps its input visible with a landscape keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('player-pin-keyboard'),
    ))!;
    final log = HealthLog(root), playback = PlaybackController(log: log);
    final session = PlayerSession(
      root: root,
      repository: PresetRepository(root),
      access: (await tester.runAsync(() => OperatorAccess.load(root)))!,
      log: log,
      editor: MappingEditor(ProjectionPreset.initial()),
      playback: playback,
    );
    try {
      await tester.pumpWidget(PlayerApp(session: session));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('setup-player')));
      await tester.pump(const Duration(milliseconds: 400));
      tester.view.viewInsets = const FakeViewPadding(bottom: 650);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final input = find.byKey(const ValueKey('dialog-input'));
      expect(tester.getSize(input).height, greaterThan(40));
      final title = tester
          .renderObject<RenderParagraph>(
            find.text('Imposta il PIN della postazione'),
          )
          .text
          .style!;
      expect(
        title.fontFamily,
        Theme.of(tester.element(input)).textTheme.headlineSmall!.fontFamily,
      );
    } finally {
      tester.view.resetViewInsets();
      await tester.pump();
      if (find.text('Annulla').evaluate().isNotEmpty) {
        await tester.tap(find.text('Annulla'));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      await session.close();
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });

  testWidgets(
    'operator layout fits Full HD and mask tab exposes node controls',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('player-ui'),
          ))!,
          e = MappingEditor(
            ProjectionPreset.initial().copyWith(
              label: 'Calibrazione della superficie con un nome abbastanza lungo da verificare il layout',
              mediaPath: 'media/video-1792087466123456.mp4',
            ),
          ),
          p = PlaybackController(log: HealthLog(root));
      await tester.pumpWidget(
        MaterialApp(
          theme: PlayerTheme.data,
          home: OperatorScreen(
            editor: e,
            playback: p,
            onSave: () async {},
            onProjection: () async {},
            onImport: () async {},
            onPreset: (_) async {},
            onSystem: (_) async {},
            status: 'Pronto',
            outputWarning:
                'Output cambiato: 1920 × 1080. Verificare la calibrazione.',
            onAcceptOutput: () {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('tab-mask')));
      await tester.pump();
      expect(find.byKey(const ValueKey('mask-enable')), findsOneWidget);
      expect(find.byKey(const ValueKey('mask-add')), findsOneWidget);
      for (final tab in ['source', 'presets', 'system', 'geometry']) {
        await tester.tap(find.byKey(ValueKey('tab-$tab')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(tester.takeException(), isNull);
      await p.close();
      await tester.runAsync(() => root.delete(recursive: true));
      e.dispose();
    },
  );
  testWidgets(
    'public output contains no operator controls even when video errors',
    (tester) async {
      final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('player-output'),
          ))!,
          p = PlaybackController(log: HealthLog(root));
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectionSurface(
            preset: ProjectionPreset.initial(),
            playback: p,
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(ClipRect), findsWidgets);
      await p.close();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
