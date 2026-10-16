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

## Remaining hardware and distribution checks

Physical HDMI/adapters, external mirroring, projector alignment, device restart, managed kiosk setup and extended playback require the final hardware. iPhone/iPad validation here uses simulators. The app has one output window; there is no independent second projector window.

Android release still uses debug signing. Mac distribution signing/notarization and iOS distribution provisioning/App Store submission are not configured or verified. These source changes do not constitute an App Store or notarized binary release.
