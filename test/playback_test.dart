import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/playback/playback_backend.dart';
import 'package:dchs_video_mapping/playback/playback_controller.dart';
import 'package:dchs_video_mapping/playback/watchdog.dart';
import 'package:dchs_video_mapping/presets/preset.dart';
import 'package:dchs_video_mapping/infrastructure/health_log.dart';

class FakeBackend extends PlaybackBackend {
  bool bad = false, disposed = false;
  double volume = -1;
  bool loop = false;
  PlaybackSnapshot current = const PlaybackSnapshot();
  @override
  PlaybackSnapshot get snapshot => current;
  @override
  Widget get surface => const SizedBox();
  @override
  Future<void> initialize(File file) async {
    if (bad) throw const FormatException('codec');
    current = const PlaybackSnapshot(
      ready: true,
      width: 1920,
      height: 1080,
      duration: Duration(seconds: 4),
    );
  }

  @override
  Future<void> play() async {
    current = PlaybackSnapshot(
      ready: true,
      playing: true,
      duration: current.duration,
    );
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    current = PlaybackSnapshot(
      ready: true,
      playing: false,
      duration: current.duration,
    );
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> configure({required bool loop, required double volume}) async {
    this.loop = loop;
    this.volume = volume;
  }

  @override
  Future<void> close() async {
    disposed = true;
    dispose();
  }
}

void main() {
  test('failed candidate preserves running video and loop/volume applied before play', () async {
    final dir = await Directory.systemTemp.createTemp('player-playback');
    final instances = <FakeBackend>[];
    final c = PlaybackController(
      log: HealthLog(dir),
      createBackend: () {
        final b = FakeBackend()..bad = instances.isNotEmpty;
        instances.add(b);
        return b;
      },
      pollInterval: const Duration(days: 1),
    );
    expect(await c.open(File('first'), ProjectionPreset.initial()), true);
    expect(c.snapshot.playing, true);
    expect(instances.first.loop, true);
    expect(instances.first.volume, 0);
    expect(await c.open(File('bad'), ProjectionPreset.initial()), false);
    expect(c.backend, same(instances.first));
    expect(c.snapshot.playing, true);
    expect(instances.last.disposed, true);
    await c.close();
    await dir.delete(recursive: true);
  });
  test('manual pause survives lifecycle and manual play overrides startup autoplay', () async {
    final root = await Directory.systemTemp.createTemp('player-intent');
    final c = PlaybackController(
      log: HealthLog(root),
      createBackend: FakeBackend.new,
    );
    await c.open(File('first'), ProjectionPreset.initial());
    await c.toggle();
    await c.suspend();
    await c.resume();
    expect(c.snapshot.playing, false);
    await c.open(
      File('second'),
      ProjectionPreset.initial().copyWith(autoplay: false),
    );
    await c.toggle();
    await c.suspend();
    await c.resume();
    expect(c.snapshot.playing, true);
    await c.close();
    await root.delete(recursive: true);
  });
  test('watchdog preserves manual play with autoplay off and pause during recovery', () async {
    for (final pauseDuringRecovery in [false, true]) {
      final root = await Directory.systemTemp.createTemp('player-recovery');
      final instances = <FakeBackend>[];
      final c = PlaybackController(
        log: HealthLog(root),
        pollInterval: const Duration(milliseconds: 10),
        createBackend: () {
          final b = FakeBackend();
          instances.add(b);
          return b;
        },
      );
      await c.open(
        File('video'),
        ProjectionPreset.initial().copyWith(autoplay: false),
      );
      await c.toggle();
      instances.first.current = const PlaybackSnapshot(
        ready: true,
        playing: true,
        error: 'decoder stalled',
      );
      for (var i = 0; i < 50 && c.phase != PlaybackPhase.recovering; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(c.phase, PlaybackPhase.recovering);
      if (pauseDuringRecovery) await c.toggle();
      for (var i = 0; i < 150 && instances.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(instances.length, 2);
      expect(c.snapshot.playing, !pauseDuringRecovery);
      await c.close();
      await root.delete(recursive: true);
    }
  });

  test('one play click restarts a completed non-loop video', () async {
    final root = await Directory.systemTemp.createTemp('player-complete'),
        b = FakeBackend();
    final c = PlaybackController(log: HealthLog(root), createBackend: () => b);
    await c.open(
      File('video'),
      ProjectionPreset.initial().copyWith(loop: false),
    );
    b.current = const PlaybackSnapshot(
      ready: true,
      playing: false,
      completed: true,
      position: Duration(seconds: 4),
      duration: Duration(seconds: 4),
    );
    await c.toggle();
    expect(c.snapshot.playing, true);
    await c.close();
    await root.delete(recursive: true);
  });
}
