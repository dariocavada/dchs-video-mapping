import 'package:flutter/material.dart';

import '../infrastructure/platform_output.dart';

class AndroidStartupSettings extends StatefulWidget {
  const AndroidStartupSettings({super.key});

  @override
  State<AndroidStartupSettings> createState() => _AndroidStartupSettingsState();
}

class _AndroidStartupSettingsState extends State<AndroidStartupSettings>
    with WidgetsBindingObserver {
  AndroidStartupState _state = const AndroidStartupState();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final state = await PlatformOutput.startup();
      if (mounted) setState(() => _state = state);
    } catch (e) {
      _error(e);
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Android startup: $error')));
  }

  Future<void> _change(bool? enabled) async {
    if (enabled == null || _busy) return;
    setState(() => _busy = true);
    try {
      final state = await PlatformOutput.startup(enabled: enabled);
      if (mounted) setState(() => _state = state);
    } catch (e) {
      _error(e);
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openHome() async {
    try {
      await PlatformOutput.openAndroidHome();
    } catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_state.supported) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            key: const ValueKey('android-autostart'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Start automatically when the box turns on'),
            subtitle: Text(
              'Android will ask you to select this player as the Home app. '
              'The Home button will return to the player.'
              '${_state.requiresDisplayPermission ? ' This box also requires “Display over other apps”: select DCHS Video Mapping, allow access, then return here. The player does not display overlays.' : ''}',
            ),
            value: _state.enabled,
            onChanged: _busy ? null : _change,
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('android-open-home'),
          onPressed: _busy ? null : _openHome,
          icon: const Icon(Icons.home_outlined),
          label: const Text('Open Android home'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
