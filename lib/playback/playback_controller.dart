import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../presets/preset.dart';
import '../infrastructure/health_log.dart';
import 'playback_backend.dart';
import 'watchdog.dart';

enum PlaybackPhase { empty, loading, ready, recovering, error }

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required this.log,
    PlaybackBackend Function()? createBackend,
    Duration pollInterval = const Duration(seconds: 1),
  }) : _create = createBackend ?? AndroidVideoBackend.new {
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }
  final HealthLog log;
  final PlaybackBackend Function() _create;
  final watchdog = PlaybackWatchdog();
  PlaybackBackend? backend;
  PlaybackPhase phase = PlaybackPhase.empty;
  String? diagnostic;
  File? _file;
  ProjectionPreset? _preset;
  int _generation = 0;
  bool _closed = false, _recovering = false, _opening = false;
  bool _desiredPlaying = false, _suspended = false;
  late final Timer _timer;
  final _clock = Stopwatch()..start();
  PlaybackSnapshot get snapshot =>
      backend?.snapshot ?? const PlaybackSnapshot();
  bool get visible =>
      phase == PlaybackPhase.ready && snapshot.ready && snapshot.error == null;
  Future<bool> open(
    File file,
    ProjectionPreset preset, {
    bool recovery = false,
  }) async {
    if (_closed) return false;
    final token = ++_generation, old = backend, candidate = _create();
    _opening = true;
    if (old == null || recovery) phase = PlaybackPhase.loading;
    diagnostic = null;
    notifyListeners();
    try {
      await candidate.initialize(file).timeout(const Duration(seconds: 20));
      await candidate.configure(loop: preset.loop, volume: preset.volume);
      final shouldPlay = recovery ? _desiredPlaying : preset.autoplay;
      if (shouldPlay && !_suspended) await candidate.play();
      if (token != _generation || _closed) {
        await candidate.close();
        return false;
      }
      backend = candidate;
      if (!recovery) _desiredPlaying = preset.autoplay;
      candidate.addListener(_onBackend);
      _file = file;
      _preset = preset;
      phase = PlaybackPhase.ready;
      if (!recovery) {
        watchdog.reset();
      } else {
        watchdog.restarted(_clock.elapsedMilliseconds);
      }
      old?.removeListener(_onBackend);
      await old?.close();
      unawaited(
        log.write(
          'media_open',
          '${preset.mediaPath}; ${snapshot.width}x${snapshot.height}; ${snapshot.duration}',
        ),
      );
      return true;
    } catch (e) {
      await candidate.close();
      if (token == _generation && !_closed) {
        diagnostic = 'Cannot open video: $e';
        if (old == null || recovery) phase = PlaybackPhase.error;
        unawaited(log.write('media_error', diagnostic));
      }
      return false;
    } finally {
      if (token == _generation && !_closed) {
        _opening = false;
        notifyListeners();
      }
    }
  }

  void _onBackend() {
    if (!_closed) notifyListeners();
  }

  Future<void> configure(ProjectionPreset preset) async {
    _preset = preset;
    if (backend != null) {
      await backend!.configure(loop: preset.loop, volume: preset.volume);
    }
  }

  Future<void> toggle() async {
    final b = backend;
    if (b == null) return;
    _desiredPlaying = snapshot.completed ? true : !_desiredPlaying;
    if (!_desiredPlaying) {
      await b.pause();
    } else {
      if (snapshot.completed) await b.seek(Duration.zero);
      if (!_suspended) await b.play();
    }
    watchdog.restarted(_clock.elapsedMilliseconds);
  }

  Future<void> seek(Duration value) async {
    await backend?.seek(value);
    watchdog.restarted(_clock.elapsedMilliseconds);
  }

  Future<void> suspend() async {
    _suspended = true;
    await backend?.pause();
  }

  Future<void> resume() async {
    _suspended = false;
    if (_desiredPlaying && phase == PlaybackPhase.ready) {
      await backend?.play();
    }
    watchdog.restarted(_clock.elapsedMilliseconds);
  }

  void _poll() {
    if (_closed ||
        _suspended ||
        !_desiredPlaying ||
        _recovering ||
        _opening ||
        backend == null ||
        phase == PlaybackPhase.empty) {
      return;
    }
    final action = watchdog.check(snapshot, _clock.elapsedMilliseconds);
    if (action == WatchdogAction.fail) {
      phase = PlaybackPhase.error;
      diagnostic = 'Playback stopped after three recovery attempts.';
      unawaited(backend!.pause());
      unawaited(log.write('recovery_exhausted', diagnostic));
      notifyListeners();
    }
    if (action == WatchdogAction.retry) unawaited(_recover());
  }

  Future<void> _recover() async {
    _recovering = true;
    phase = PlaybackPhase.recovering;
    notifyListeners();
    final generation = _generation;
    unawaited(log.write('recovery', 'attempt ${watchdog.attempts}'));
    await Future<void>.delayed(Duration(seconds: watchdog.delaySeconds));
    if (!_closed && generation == _generation) {
      await open(_file!, _preset!, recovery: true);
      if (phase == PlaybackPhase.error) {
        watchdog.restarted(_clock.elapsedMilliseconds);
      }
    }
    _recovering = false;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _timer.cancel();
    backend?.removeListener(_onBackend);
    await backend?.close();
    dispose();
  }
}
