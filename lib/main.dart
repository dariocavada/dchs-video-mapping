import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'app/player_app.dart';
import 'operator_ui/player_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'DCHS Video Mapping',
    ], await rootBundle.loadString('LICENSE'));
    yield LicenseEntryWithLineBreaks([
      'AndroidX Media3 1.9.2',
    ], await rootBundle.loadString('assets/licenses/ANDROIDX-MEDIA3.txt'));
  });
  try {
    final support = await getApplicationSupportDirectory();
    final session = await PlayerSession.open(
      Directory('${support.path}/player'),
    );
    runApp(PlayerApp(session: session));
  } catch (e) {
    runApp(_StartupFailure(e));
  }
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure(this.error);
  final Object error;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: PlayerTheme.data,
    home: Builder(
      builder: (context) => GestureDetector(
        onLongPress: () => showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Avvio non riuscito'),
            content: const Text(
              'La configurazione locale non può essere aperta. Contattare il personale tecnico per ripristinarla.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ),
        child: const ColoredBox(color: Colors.black),
      ),
    ),
  );
}
