import 'dart:async';
import 'dart:io';

import 'package:dchs_video_mapping/infrastructure/health_log.dart';
import 'package:dchs_video_mapping/infrastructure/platform_output.dart';
import 'package:dchs_video_mapping/mapping/editor_controller.dart';
import 'package:dchs_video_mapping/operator_ui/operator_screen.dart';
import 'package:dchs_video_mapping/playback/playback_controller.dart';
import 'package:dchs_video_mapping/presets/preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSystem(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('dchs-startup-settings-'),
    ))!;
    final playback = (await tester.runAsync(
      () async => PlaybackController(log: HealthLog(root)),
    ))!;
    final editor = MappingEditor(ProjectionPreset.initial());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.close();
      editor.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformOutput.channel, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: OperatorScreen(
          editor: editor,
          playback: playback,
          onSave: () async {},
          onProjection: () async {},
          onImport: () async {},
          onPreset: (_) async {},
          onSystem: (_) async {},
          status: '',
          outputWarning: null,
          onAcceptOutput: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tab-system')));
    await tester.pumpAndSettle();
  }

  testWidgets('startup checkbox waits for the actual Android Home choice', (
    tester,
  ) async {
    final request = Completer<Map<String, dynamic>>();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformOutput.channel, (call) async {
          calls.add(call);
          if (call.method == 'startupSet') return request.future;
          return {'supported': true, 'enabled': false};
        });
    await openSystem(tester);
    final checkbox = find.byKey(const ValueKey('android-autostart'));
    expect(checkbox, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    expect(tester.widget<CheckboxListTile>(checkbox).onChanged, isNull);
    expect(calls.last.method, 'startupSet');
    expect(calls.last.arguments, {'enabled': true});
    request.complete({'supported': true, 'enabled': true});
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled Home choice leaves automatic startup unchecked', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformOutput.channel, (_) async {
          return {'supported': true, 'enabled': false};
        });
    await openSystem(tester);
    final checkbox = find.byKey(const ValueKey('android-autostart'));
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
  });

  testWidgets('startup controls are absent on unsupported platforms', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformOutput.channel, (_) async {
          throw MissingPluginException();
        });
    await openSystem(tester);
    expect(find.byKey(const ValueKey('android-autostart')), findsNothing);
    expect(find.byKey(const ValueKey('android-open-home')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('affected box explains the required special permission', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformOutput.channel, (_) async {
          return {
            'supported': true,
            'enabled': false,
            'requiresDisplayPermission': true,
          };
        });
    await openSystem(tester);
    expect(find.textContaining('Display over other apps'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('android-autostart')),
          )
          .value,
      isFalse,
    );
  });
}
