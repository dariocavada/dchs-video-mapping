import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/app/player_app.dart';
import 'package:dchs_video_mapping/infrastructure/health_log.dart';
import 'package:dchs_video_mapping/infrastructure/operator_access.dart';
import 'package:dchs_video_mapping/mapping/editor_controller.dart';
import 'package:dchs_video_mapping/operator_ui/operator_screen.dart';
import 'package:dchs_video_mapping/playback/playback_controller.dart';
import 'package:dchs_video_mapping/presets/preset.dart';
import 'package:dchs_video_mapping/presets/preset_repository.dart';

void main() {
  testWidgets('Mac Command shortcuts save and undo/redo calibration', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final editor = MappingEditor(ProjectionPreset.initial());
    final playback = PlaybackController(log: HealthLog(Directory.systemTemp));
    var saves = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: OperatorScreen(
            editor: editor,
            playback: playback,
            onSave: () async {
              saves++;
            },
            onProjection: () async {},
            onImport: () async {},
            onPreset: (_) async {},
            onSystem: (_) async {},
            status: 'Ready',
            outputWarning: null,
            onAcceptOutput: () {},
          ),
        ),
      );
      await tester.pump();
      final original = editor.draft.center;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(editor.draft.center, isNot(original));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.pump();
      expect(editor.draft.center, original);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(editor.draft.center.dx, closeTo(original.dx + 1 / 1920, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(saves, 1);
      // Preserve the existing Ctrl shortcuts on desktop keyboards.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(saves, 2);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      await playback.close();
    }
  });

  testWidgets('Mac Command M opens staff access from the public output', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('player-mac-access'),
    ))!;
    final log = HealthLog(root);
    final session = PlayerSession(
      root: root,
      repository: PresetRepository(root),
      access: (await tester.runAsync(() => OperatorAccess.load(root)))!,
      log: log,
      editor: MappingEditor(ProjectionPreset.initial()),
      playback: PlaybackController(log: log),
    );
    try {
      await tester.pumpWidget(PlayerApp(session: session));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dialog-input')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
      await session.close();
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });
}
