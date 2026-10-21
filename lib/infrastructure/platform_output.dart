import 'package:flutter/services.dart';

class AndroidStartupState {
  const AndroidStartupState({
    this.supported = false,
    this.enabled = false,
    this.requiresDisplayPermission = false,
  });
  final bool supported;
  final bool enabled;
  final bool requiresDisplayPermission;
}

class PlatformOutput {
  static const channel = MethodChannel('dchs_video_mapping/platform');
  static Future<String> displayKey() async {
    try {
      final j = await channel.invokeMapMethod<String, dynamic>('output');
      return j?['key'] as String? ?? 'display-unknown';
    } on MissingPluginException {
      return 'display-unknown';
    }
  }

  static Future<bool> kiosk(String action) async {
    try {
      return await channel.invokeMethod<bool>(action) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<AndroidStartupState> startup({bool? enabled}) async {
    try {
      final state = await channel.invokeMapMethod<String, dynamic>(
        enabled == null ? 'startupStatus' : 'startupSet',
        enabled == null ? null : {'enabled': enabled},
      );
      return AndroidStartupState(
        supported: state?['supported'] == true,
        enabled: state?['enabled'] == true,
        requiresDisplayPermission: state?['requiresDisplayPermission'] == true,
      );
    } on MissingPluginException {
      return const AndroidStartupState();
    }
  }

  static Future<void> openAndroidHome() =>
      channel.invokeMethod('openAndroidHome');
}
