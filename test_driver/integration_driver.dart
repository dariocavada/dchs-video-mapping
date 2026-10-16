import 'dart:async';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await runZoned(
    () => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final folder = Directory('docs/screenshots');
        await folder.create(recursive: true);
        await File('${folder.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
      responseDataCallback: (_) async {},
    ),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!line.startsWith('result ')) parent.print(zone, line);
      },
    ),
  );
}
