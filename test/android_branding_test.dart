import 'dart:async';
import 'dart:io';

import 'package:dchs_video_mapping/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android shows CavadaLabs while local storage is opening', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final path = Completer<String>();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => path.future);
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.runAsync(app.main);
    await tester.pump();
    expect(find.text('CavadaLabs'), findsOneWidget);
    // A failed load must leave the brand screen and use the existing recovery UI.
    path.completeError(const FileSystemException('Test storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('CavadaLabs'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
