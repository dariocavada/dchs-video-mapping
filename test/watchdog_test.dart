import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/playback/watchdog.dart';

void main() {
  test('stall triggers at five seconds then bounded increasing backoff', () {
    final w = PlaybackWatchdog();
    const s = PlaybackSnapshot(ready: true, playing: true);
    expect(w.check(s, 0), WatchdogAction.none);
    expect(w.check(s, 5000), WatchdogAction.none);
    expect(w.check(s, 5001), WatchdogAction.retry);
    w.restarted(6001);
    expect(w.check(s, 11002), WatchdogAction.retry);
    w.restarted(13002);
    expect(w.check(s, 18003), WatchdogAction.retry);
    w.restarted(22003);
    expect(w.check(s, 27004), WatchdogAction.fail);
  });
  test('pause buffering completion and loop rewind never count as stall', () {
    final w = PlaybackWatchdog();
    for (final (i, s) in const [
      PlaybackSnapshot(ready: true, playing: false),
      PlaybackSnapshot(ready: true, playing: true, buffering: true),
      PlaybackSnapshot(ready: true, playing: true, completed: true),
    ].indexed) {
      expect(w.check(s, (i + 1) * 100000), WatchdogAction.none);
    }
    expect(
      w.check(
        const PlaybackSnapshot(
          ready: true,
          playing: true,
          position: Duration(seconds: 3),
        ),
        400000,
      ),
      WatchdogAction.none,
    );
    expect(
      w.check(
        const PlaybackSnapshot(
          ready: true,
          playing: true,
          position: Duration.zero,
        ),
        404000,
      ),
      WatchdogAction.none,
    );
  });
}
