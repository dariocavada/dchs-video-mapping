import 'dart:convert';
import 'dart:io';

class HealthLog {
  HealthLog(this.root);
  final Directory root;
  Future<void> _queue = Future.value();
  Future<void> write(String event, [Object? details]) {
    final result = _queue.then((_) async {
      final dir = Directory('${root.path}/logs');
      await dir.create(recursive: true);
      final file = File('${dir.path}/player.log');
      if (await file.exists() && await file.length() > 1024 * 1024) {
        for (var i = 4; i >= 1; i--) {
          final src = File(
            '${dir.path}/player${i == 1 ? '' : '.${i - 1}'}.log',
          );
          final dst = File('${dir.path}/player.$i.log');
          if (await src.exists()) {
            if (await dst.exists()) await dst.delete();
            await src.rename(dst.path);
          }
        }
      }
      await file.writeAsString(
        '${jsonEncode({'time': DateTime.now().toUtc().toIso8601String(), 'event': event, 'details': details?.toString()})}\n',
        mode: FileMode.append,
        flush: true,
      );
    });
    // A full disk must not cause an unhandled asynchronous error on projection.
    _queue = result.catchError((Object _) {});
    return _queue;
  }
}
