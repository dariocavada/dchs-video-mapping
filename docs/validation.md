# Project validation

Validation performed on October 16, 2026 with Flutter 3.47.5 / Dart 3.13.4, Xcode 26.5, Java 21 and Android SDK 36.

## Shared checks

- `flutter analyze`: no issues.
- `flutter test`: 33 unit and widget tests passed. They cover geometry, validation, persistence, PIN access, export, watchdog, lifecycle, layout, landscape keyboards, zoom/pan, external handles, Mac Command shortcuts and container extensions during staged media imports.
- The original Android application ID and preset schema remain unchanged. Apple hosts use `dev.dariocavada.dchsVideoMapping`; storage is local to each application/container and is not migrated from another platform automatically.
- No personal Apple development team, provisioning profile, credentials or signing material is committed.

## Native integration

The same `integration_test/player_test.dart` flow runs against actual platform decoders and textures. It checks first setup, PIN access, streamed import with candidate decoder validation, affine mapping, Bézier clipping, node/handle edits, undo, saving, two playback loops, four-corner mapping and session restoration from the saved preset.

- Android: API 36 arm64 emulator, Full HD 1920 × 1080, passed.
- macOS: native Apple Silicon app on macOS 26.6.2, passed. The native bridge identifies the display and its mode; resizing or moving the window to a different display requires output confirmation before saving. Windowed editor screenshots were captured from the rendered Flutter surface, including the video texture.
- iOS: iPhone 17 Pro simulator on iOS 26.5, passed. Observed the landscape layout with the actual AVFoundation decoder and texture.
- iPadOS: iPad Pro 11-inch (M5) simulator on iOS 26.5, passed, including the 4:3 tablet layout.

The integration test uses separate `player-integration` storage and a test-only PIN; it does not configure the PIN for the standard app. The driver saves six screenshots per target in [screenshots](screenshots/), using `-android`, `-macos`, `-ios` and `-ipados` suffixes. The iPad run uses `--dart-define=SCREENSHOT_PLATFORM=ipados` so its images remain separate from the iPhone images.

```sh
flutter drive --driver=test_driver/integration_driver.dart \
  --target=integration_test/player_test.dart -d macos
flutter drive --driver=test_driver/integration_driver.dart \
  --target=integration_test/player_test.dart -d <ios-simulator-id>
flutter drive --driver=test_driver/integration_driver.dart \
  --target=integration_test/player_test.dart \
  --dart-define=SCREENSHOT_PLATFORM=ipados -d <ipad-simulator-id>
```

For Android Full HD screenshots, use a dedicated emulator and set `adb -s <emulator-id> shell wm size 1920x1080` and `adb -s <emulator-id> shell wm density 160`. Preserve existing overrides or restore the original settings after testing; do not modify a projection device for this purpose.

The standard Mac app was launched and hot reload succeeded. Setup, affine, Bézier and four-corner screenshots were visually checked.

## Build artifacts

- `flutter build apk --debug --target lib/main.dart`: standard Android APK at `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build macos --debug`: standard Mac app at `build/macos/Build/Products/Debug/DCHS Video Mapping.app`.
- `flutter build ios --simulator --debug`: standard simulator app at `build/ios/iphonesimulator/Runner.app`.
- `flutter build ios --debug --no-codesign`: unsigned device-target build at `build/ios/iphoneos/Runner.app`. This verifies device compilation; it is not an installable signed IPA or a physical-device test.

An integration run builds a test app. Rebuild the standard `lib/main.dart` target before handover. Run iOS build and integration commands sequentially because they share generated Xcode configuration.

## Physical X96 X10Pro check — October 20, 2026

- Target: `X96_X10Pro`, Android 11 / API 30, Amlogic `s5`, 32-bit `armeabi-v7a`, physical output 1920 × 1080. Connected over Wi-Fi ADB.
- Reproduced the original demo failure on the device and in `android_box_playback_test.dart`: `OMX.amlogic.avc.decoder.awesome2` rejected output buffer counts 18–21 because its non-HWC output limit is 14. Disabling Impeller alone did not fix it.
- The host now selects GLES plus SurfaceTexture only for this exact model/OS/hardware combination. With that change, the same native playback test passed: original H.264 High Full HD demo, advancing playback, two loops, pause and seek. An ADB screenshot showed the rendered test signal at 1.8 seconds. No transcoding or platform view was needed.
- `flutter analyze`: no issues. `flutter test`: all 33 unit/widget tests passed.
- The broader `player_test.dart` scenario stopped during PIN setup: `tab-mask` was still absent after its bounded wait. It did not establish physical mapping, mask, import or preset validation on this box. The video-only test above passed independently.
- Rebuilt the regular `lib/main.dart` release APK with `--build-number=6`; it retains the project's local debug signing configuration. Logs and device screenshots for this run are under the ignored `build/diagnostics/` directory.

The compatibility switch is an internal Flutter testing API, and GLES opt-out is deprecated. Recheck initialization, rendered frames and loop playback on this device when upgrading Flutter; the workaround is not a claim of compatibility for all Amlogic boxes.

## Android startup and loading screen — October 20, 2026

- Added Android-only System controls for selecting the player as Home and opening the previous launcher, plus a temporary CavadaLabs wordmark while app data loads. Other platforms hide these controls.
- `flutter test`: all 38 unit/widget tests passed, including pending/cancelled Home selection, unsupported platforms, special-permission guidance and the Android loading screen. `flutter analyze`: no issues.
- Physical native Home tests verified cancellation, acceptance, opening the previous launcher and disabling the Home entry. A forwarding Home activity reuses the existing player task instead of starting a second Flutter engine.
- Two initial reboot checks exposed firmware behavior: UID 0 explicitly opens `com.yxt.launcher`, ignoring the selected Home; a `BOOT_COMPLETED` receiver runs, but Android rejects its background activity start without the special permission.
- The affected-model setup now requests `SYSTEM_ALERT_WINDOW` through Android Settings and checks `Settings.canDrawOverlays` before reporting startup enabled. No overlay window is created. The physical integration test passed with Home selection and the permission granted through the system UI.
- Reinstalled the standard `lib/main.dart` release APK, build number 12, in place, preserving the application UID and local data. A real reboot changed the boot ID and automatically opened `MainActivity` without an ADB launch command. The system log explicitly allowed the background start because `SYSTEM_ALERT_WINDOW` was granted. A screenshot showed the saved user video with its curved mask.
- Local evidence is in ignored `build/diagnostics/android-startup-test.log` and `android-reboot-with-permission.{json,log,png}`. The generic Home approach remains firmware-dependent; this result establishes startup on the tested X96 X10Pro only.
- The subsequent standby check could not yet be completed because the box stopped responding on the network before the sleep command was sent. The existing foreground-resume handler is present; physical wake behavior remains to be verified.

## Remaining hardware and distribution checks

Physical HDMI/adapters, external mirroring, projector alignment, standby/wake, managed kiosk setup and extended playback require further final-hardware checks. Restart was verified on the X96 X10Pro as described above. iPhone/iPad validation here uses simulators. The app has one output window; there is no independent second projector window.

Android release still uses debug signing. Mac distribution signing/notarization and iOS distribution provisioning/App Store submission are not configured or verified. These source changes do not constitute an App Store or notarized binary release.
