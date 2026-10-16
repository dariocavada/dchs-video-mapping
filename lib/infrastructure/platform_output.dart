import 'package:flutter/services.dart';

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
}
