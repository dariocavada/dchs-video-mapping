import 'package:flutter/material.dart';

/// Material 3 defaults, using the same seed as the Flutter app template.
abstract final class PlayerTheme {
  static final ThemeData data = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    useMaterial3: true,
  );
  static Color get surface => data.scaffoldBackgroundColor;
  static Color get surfaceContainerLow => data.colorScheme.surfaceContainerLow;
  static Color get secondaryContainer => data.colorScheme.secondaryContainer;
  static Color get onSurface => data.colorScheme.onSurface;
  static Color get primary => data.colorScheme.primary;
  static Color get onSurfaceVariant => data.colorScheme.onSurfaceVariant;
  static Color get outlineVariant => data.colorScheme.outlineVariant;
}

class PlayerButton extends StatelessWidget {
  const PlayerButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final text = Text(label, overflow: TextOverflow.ellipsis);
    return icon == null
        ? OutlinedButton(onPressed: onPressed, child: text)
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: text,
          );
  }
}
