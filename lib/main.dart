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
    if (Platform.isAndroid) {
      yield LicenseEntryWithLineBreaks([
        'AndroidX Media3 1.9.2',
      ], await rootBundle.loadString('assets/licenses/ANDROIDX-MEDIA3.txt'));
    }
  });
  final player = _openPlayer();
  if (defaultTargetPlatform == TargetPlatform.android) {
    runApp(
      FutureBuilder<Widget>(
        future: player,
        builder: (context, snapshot) =>
            snapshot.data ?? const _AndroidLoading(),
      ),
    );
  } else {
    runApp(await player);
  }
}

Future<Widget> _openPlayer() async {
  try {
    final support = await getApplicationSupportDirectory();
    final session = await PlayerSession.open(
      Directory('${support.path}/player'),
    );
    return PlayerApp(session: session);
  } catch (e) {
    return _StartupFailure(e);
  }
}

class _AndroidLoading extends StatelessWidget {
  const _AndroidLoading();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'CavadaLabs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    ),
  );
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
            title: const Text('Startup failed'),
            content: const Text(
              'The local configuration could not be opened. Contact technical staff to restore it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        child: const ColoredBox(color: Colors.black),
      ),
    ),
  );
}
