import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Preserve Ctrl shortcuts and also accept the Mac Command key.
bool get isPlayerShortcutPressed =>
    HardwareKeyboard.instance.isControlPressed ||
    (defaultTargetPlatform == TargetPlatform.macOS &&
        HardwareKeyboard.instance.isMetaPressed);
