class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.ready = false,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.width = 0,
    this.height = 0,
  });
  final bool ready, playing, buffering, completed;
  final Duration position, duration;
  final String? error;
  final double width, height;
}

enum WatchdogAction { none, retry, fail }

class PlaybackWatchdog {
  int attempts = 0;
  int? _lastProgress;
  Duration? _position;
  bool _waiting = false;
  int get delaySeconds => 1 << (attempts - 1).clamp(0, 2);
  void reset() {
    attempts = 0;
    _lastProgress = null;
    _position = null;
    _waiting = false;
  }

  void restarted(int now) {
    _lastProgress = now;
    _waiting = false;
  }

  WatchdogAction check(PlaybackSnapshot s, int now) {
    if (_waiting) return WatchdogAction.none;
    if (s.error != null) {
      return _failure();
    }
    if (!s.ready || !s.playing || s.buffering || s.completed) {
      _lastProgress = now;
      _position = s.position;
      return WatchdogAction.none;
    }
    if (_position != s.position || _lastProgress == null) {
      _position = s.position;
      _lastProgress = now;
      return WatchdogAction.none;
    }
    if (now - _lastProgress! > 5000) return _failure();
    return WatchdogAction.none;
  }

  WatchdogAction _failure() {
    if (attempts >= 3) {
      _waiting = true;
      return WatchdogAction.fail;
    }
    attempts++;
    _waiting = true;
    return WatchdogAction.retry;
  }
}
