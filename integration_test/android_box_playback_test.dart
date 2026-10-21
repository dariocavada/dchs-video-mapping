import 'dart:io';

import 'package:dchs_video_mapping/playback/playback_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full HD H.264 demo renders and loops on the physical decoder', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('dchs-decoder-test-');
    final backend = NativeVideoBackend();
    addTearDown(() async {
      await backend.close();
      await root.delete(recursive: true);
    });
    final data = await rootBundle.load('assets/demo.mp4');
    final video = File('${root.path}/demo.mp4');
    await video.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );

    await backend.initialize(video).timeout(const Duration(seconds: 20));
    expect(backend.snapshot.ready, isTrue);
    expect(backend.snapshot.width, 1920);
    expect(backend.snapshot.height, 1080);
    await backend.configure(loop: true, volume: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: backend.surface)),
      ),
    );
    await backend.play();

    var loops = 0;
    var advanced = false;
    var previous = Duration.zero;
    final clock = Stopwatch()..start();
    while (clock.elapsed < const Duration(seconds: 12) && loops < 2) {
      await tester.pump(const Duration(milliseconds: 100));
      final snapshot = backend.snapshot;
      expect(snapshot.error, isNull);
      if (snapshot.position > previous) advanced = true;
      if (previous - snapshot.position > const Duration(seconds: 1)) loops++;
      previous = snapshot.position;
    }
    expect(advanced, isTrue, reason: 'The native playback clock must advance.');
    expect(loops, greaterThanOrEqualTo(2));
    expect(backend.snapshot.playing, isTrue);
    await backend.pause();
    await backend.seek(const Duration(seconds: 1));
    expect(backend.snapshot.error, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
