import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/infrastructure/health_log.dart';
import 'package:dchs_video_mapping/mapping/editor_controller.dart';
import 'package:dchs_video_mapping/mapping/mask.dart';
import 'package:dchs_video_mapping/operator_ui/mapping_canvas.dart';
import 'package:dchs_video_mapping/operator_ui/operator_screen.dart';
import 'package:dchs_video_mapping/operator_ui/player_theme.dart';
import 'package:dchs_video_mapping/playback/playback_controller.dart';
import 'package:dchs_video_mapping/presets/preset.dart';

void main() {
  testWidgets(
    'zoom, pan and fitting the editor never change projection or undo history',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final e = MappingEditor(
            ProjectionPreset.initial().copyWith(mask: BezierMask.arch()),
          ),
          p = PlaybackController(log: HealthLog(Directory.systemTemp));
      final before = jsonEncode(e.draft.toJson());
      try {
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
              outputWarning: null,
              onAcceptOutput: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tab-mask')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('view-zoom-out')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('view-zoom-out')));
        await tester.pump();
        expect(find.text('64%'), findsOneWidget);
        final old = tester.getRect(
          find.byKey(const ValueKey('editor-output-raster')),
        );
        final canvas = tester.getRect(
          find.byKey(const ValueKey('mapping-canvas')),
        );
        expect(old.width, closeTo(canvas.width * .64, .01));
        await tester.tap(find.byKey(const ValueKey('view-pan')));
        await tester.pump();
        final drag = await tester.startGesture(canvas.center);
        await drag.moveBy(const Offset(20, 0));
        await tester.pump();
        await drag.moveBy(const Offset(70, 30));
        await tester.pump();
        await drag.up();
        await tester.pump();
        expect(
          tester
              .getRect(find.byKey(const ValueKey('editor-output-raster')))
              .left,
          greaterThan(old.left + 30),
        );
        final wheelBefore = tester.getRect(
          find.byKey(const ValueKey('editor-output-raster')),
        );
        final focal =
            canvas.topLeft + Offset(canvas.width * .7, canvas.height * .3);
        final normalized = Offset(
          (focal.dx - wheelBefore.left) / wheelBefore.width,
          (focal.dy - wheelBefore.top) / wheelBefore.height,
        );
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: focal,
            scrollDelta: const Offset(0, -20),
          ),
        );
        await tester.pump();
        final wheelAfter = tester.getRect(
          find.byKey(const ValueKey('editor-output-raster')),
        );
        expect(
          (focal.dx - wheelAfter.left) / wheelAfter.width,
          closeTo(normalized.dx, 1e-9),
        );
        expect(
          (focal.dy - wheelAfter.top) / wheelAfter.height,
          closeTo(normalized.dy, 1e-9),
        );
        await tester.tap(find.byKey(const ValueKey('view-fit-handles')));
        await tester.pump();
        expect(jsonEncode(e.draft.toJson()), before);
        expect(e.canUndo, false);
        expect(e.dirty, false);
        await tester.tap(find.byKey(const ValueKey('view-fit-output')));
        await tester.pump();
        expect(find.text('100%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await p.close();
        e.dispose();
      }
    },
  );
  testWidgets(
    'external Bezier handle stays visible and draggable at half preview scale',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var mask = BezierMask.arch();
      mask = mask.replace(
        0,
        mask.nodes[0].copyWith(outHandle: const Offset(.2, -.1)),
      );
      final e = MappingEditor(ProjectionPreset.initial().copyWith(mask: mask)),
          p = PlaybackController(log: HealthLog(Directory.systemTemp));
      var selected = 0, part = SelectedPart.outHandle;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: PlayerTheme.data,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 1000,
                  height: 562.5,
                  child: StatefulBuilder(
                    builder: (context, set) => MappingCanvas(
                      editor: e,
                      playback: p,
                      maskMode: true,
                      pattern: true,
                      showHelpers: true,
                      selected: selected,
                      part: part,
                      onSelection: (i, v) => set(() {
                        selected = i;
                        part = v;
                      }),
                      addNode: false,
                      onAdded: () {},
                      viewScale: .5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final rect = tester.getRect(
          find.byKey(const ValueKey('editor-output-raster')),
        );
        final handle =
            rect.topLeft + Offset(rect.width * .2, -rect.height * .1);
        final gesture = await tester.startGesture(handle);
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        final before = e.draft.mask.nodes[0].outHandle;
        await gesture.moveBy(const Offset(0, -28.125));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        expect(part, SelectedPart.outHandle);
        expect(
          e.draft.mask.nodes[0].outHandle.dy,
          closeTo(before.dy - .1, 1e-9),
        );
        expect(e.draft.mask.nodes[0].position, const Offset(.2, .35));
        expect(e.maskError, isNull);
        e.undo();
        expect(e.draft.mask.nodes[0].outHandle, const Offset(.2, -.1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await p.close();
        e.dispose();
      }
    },
  );
}
