# Standalone project validation

Validation of the English edition performed on October 16, 2026 with Flutter 3.47.5 / Dart 3.13.4, Java 21 and Android SDK 36.

- `flutter analyze`: no issues.
- `flutter test`: 30 unit and widget tests passed. They cover geometry, validation, persistence, PIN access, export, watchdog, lifecycle, layout, the landscape keyboard, zoom/pan and external handles.
- `flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/player_test.dart -d <emulator-id>`: Android flow passed on an API 36 arm64 emulator at Full HD 1920 × 1080. Verified the actual decoder and texture, affine mapping, Bézier clipping, undo, saving, loop playback, PIN access, four-corner mapping and session restoration from the saved preset.
- `flutter build apk --debug --target lib/main.dart`: standard APK, separate from the integration test APK.
- Regenerated all six Android flow screenshots in English in [screenshots](screenshots/); visually checked setup, affine geometry, Bézier editing and four-corner calibration. Observed a horizontal layout and Material theme without additional fonts.

The Android ID is `dev.dariocavada.dchs_video_mapping`: installation and storage are independent of other applications. Presets and videos in other apps are not migrated automatically.

The integration test uses separate `player-integration` storage and a test-only PIN; it does not configure the PIN for the standard app. The driver saves screenshots in `docs/screenshots/`.

Physical testing of HDMI, the projector, device restart, managed kiosk mode and extended playback requires the target hardware. The verified APK is a debug build; production signing is not configured.
