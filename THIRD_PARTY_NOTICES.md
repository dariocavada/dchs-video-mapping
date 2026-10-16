# Third-party components

The MIT license for this project does not replace dependency licenses.

- Flutter and Dart: BSD licenses, with attributions included in the SDKs and the Flutter license registry.
- `video_player`, `video_player_android`, `file_selector`, `path_provider`, `share_plus`, `vector_math`: BSD-3-Clause.
- `cryptography`: Apache-2.0.
- `archive`: MIT.
- AndroidX Media3: Apache-2.0; the license text is included in `assets/licenses/ANDROIDX-MEDIA3.txt` and displayed in the app.

Dependencies and resolved versions are listed in `pubspec.lock`. **System → Licenses** displays the license texts registered by Flutter packages and the included native Media3 text. When distributing binaries, also retain the notices for native Android/AndroidX dependencies included in the build.

`assets/demo.mp4` is a test signal generated with FFmpeg (`testsrc2`), with no third-party editorial content or media. The command to regenerate it is in the README. No additional fonts are distributed.
