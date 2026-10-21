import 'package:dchs_video_mapping/infrastructure/platform_output.dart';
import 'package:dchs_video_mapping/operator_ui/android_startup_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android Home request can be cancelled, accepted and disabled', (
    tester,
  ) async {
    const bootCheck = bool.fromEnvironment('DCHS_BOOT_CHECK');
    final original = await PlatformOutput.startup();
    expect(original.supported, isTrue);
    expect(original.enabled, isFalse);
    if (!bootCheck) {
      addTearDown(() => PlatformOutput.startup(enabled: false));
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 520, child: AndroidStartupSettings()),
        ),
      ),
    );
    await tester.pump();

    debugPrint('DCHS_HOME_TEST: cancel the first Home request');
    final cancelled = await PlatformOutput.startup(enabled: true)
        .timeout(const Duration(seconds: 45));
    expect(cancelled.enabled, isFalse);
    debugPrint('DCHS_HOME_TEST: accept the second Home request');
    final accepted = await PlatformOutput.startup(enabled: true)
        .timeout(const Duration(seconds: 45));
    expect(accepted.enabled, isTrue);
    expect((await PlatformOutput.startup()).enabled, isTrue);
    debugPrint('DCHS_HOME_TEST: automatic startup is active');
    await PlatformOutput.openAndroidHome();
    if (bootCheck) {
      debugPrint('DCHS_HOME_TEST: leaving Home enabled for the reboot check');
      return;
    }
    final disabled = await PlatformOutput.startup(enabled: false);
    expect(disabled.enabled, isFalse);
    debugPrint('DCHS_HOME_TEST: automatic startup disabled');
  });
}
