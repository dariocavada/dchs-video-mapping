import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../infrastructure/health_log.dart';
import '../infrastructure/support_archive.dart';
import '../infrastructure/media_import.dart';
import '../infrastructure/operator_access.dart';
import '../infrastructure/platform_output.dart';
import '../mapping/editor_controller.dart';
import '../playback/playback_backend.dart';
import '../playback/playback_controller.dart';
import '../presets/preset.dart';
import '../presets/preset_repository.dart';
import '../output/projection_surface.dart';
import '../operator_ui/operator_screen.dart';
import '../operator_ui/player_theme.dart';
import '../operator_ui/text_prompt_dialog.dart';

class PlayerSession {
  PlayerSession({
    required this.root,
    required this.repository,
    required this.access,
    required this.log,
    required this.editor,
    required this.playback,
    this.startupWarning,
  });
  final Directory root;
  final PresetRepository repository;
  final OperatorAccess access;
  final HealthLog log;
  final MappingEditor editor;
  final PlaybackController playback;
  final String? startupWarning;
  static Future<PlayerSession> open(Directory root) async {
    await root.create(recursive: true);
    final repository = PresetRepository(root),
        access = await OperatorAccess.load(root),
        log = HealthLog(root);
    final preset = await repository.loadActive();
    var warning = repository.warning;
    if (preset == null &&
        (await File('${root.path}/presets.json').exists() ||
            await File('${root.path}/presets.backup.json').exists())) {
      warning = 'Nessun preset valido: ripristinare la configurazione dal personale tecnico.';
    }
    if (preset == null && warning == null) {
      final demo = File('${root.path}/media/demo.mp4');
      await demo.parent.create(recursive: true);
      if (!await demo.exists()) {
        final data = await rootBundle.load('assets/demo.mp4');
        final temp = File('${demo.path}.tmp');
        await temp.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        await temp.rename(demo.path);
      }
    }
    final p = preset ?? ProjectionPreset.initial(),
        playback = PlaybackController(log: log);
    await log.write('startup', 'DCHS Video Mapping 1.0.0+1; preset ${p.id}');
    if (warning == null || preset != null) {
      await playback.open(File('${root.path}/${p.mediaPath}'), p);
    }
    return PlayerSession(
      root: root,
      repository: repository,
      access: access,
      log: log,
      editor: MappingEditor(p),
      playback: playback,
      startupWarning: warning,
    );
  }

  Future<void> close() async {
    editor.dispose();
    await playback.close();
  }
}

class PlayerApp extends StatelessWidget {
  const PlayerApp({super.key, required this.session});
  final PlayerSession session;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DCHS Video Mapping',
    debugShowCheckedModeBanner: false,
    theme: PlayerTheme.data,
    home: _PlayerHost(session: session),
  );
}

class _PlayerHost extends StatefulWidget {
  const _PlayerHost({required this.session});
  final PlayerSession session;
  @override
  State<_PlayerHost> createState() => _PlayerHostState();
}

class _PlayerHostState extends State<_PlayerHost> with WidgetsBindingObserver {
  PlayerSession get s => widget.session;
  bool _operator = false,
      _busy = false,
      _dialog = false,
      _metricsPending = true;
  String _status = 'MP4 dimostrativo · calibrazione da verificare in sala';
  String? _outputWarning;
  Size? _actualSize;
  String _actualKey = '';
  Timer? _hold;
  Offset? _holdStart;
  int _metricsToken = 0;
  final _rootFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    s.editor.addListener(_editorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureOutput());
  }

  void _editorChanged() {
    if (mounted) {
      setState(() {
        if (_actualSize != null) {
          final p = s.editor.draft;
          _outputWarning =
              p.outputSize != _actualSize ||
                  (p.displayKey.isNotEmpty && p.displayKey != _actualKey)
              ? 'Output cambiato: ${_actualSize!.width.toInt()} × ${_actualSize!.height.toInt()}. La calibrazione richiede una verifica.'
              : null;
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.editor.removeListener(_editorChanged);
    _hold?.cancel();
    _rootFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) {
      setState(() => _metricsPending = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureOutput());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(s.playback.resume());
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
      unawaited(_measureOutput());
    } else if (state == AppLifecycleState.paused) {
      unawaited(s.playback.suspend());
    }
  }

  Future<void> _measureOutput() async {
    if (!mounted) return;
    final token = ++_metricsToken,
        view = View.of(context),
        size = view.physicalSize;
    if (size.isEmpty) return;
    final key = await PlatformOutput.displayKey();
    if (!mounted || token != _metricsToken) return;
    final p = s.editor.draft;
    setState(() {
      _actualSize = size;
      _actualKey = key;
      _metricsPending = false;
      _outputWarning =
          p.outputSize != size ||
              (p.displayKey.isNotEmpty && p.displayKey != key)
          ? 'Output cambiato: ${size.width.toInt()} × ${size.height.toInt()}. La calibrazione richiede una verifica.'
          : null;
    });
    await s.log.write(
      'output',
      '$key; ${size.width}x${size.height}; mismatch=${_outputWarning != null}',
    );
  }

  Future<void> _message(String title, String body) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 560, child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<String?> _text(
    String title, {
    String initial = '',
    bool pin = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) => PlayerTextPrompt(title: title, initial: initial, pin: pin),
  );

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: SizedBox(width: 560, child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Indietro'),
            ),
            TextButton(
              key: const ValueKey('confirm-action'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _access() async {
    if (_dialog || _operator || _busy) return;
    _dialog = true;
    try {
      final pin = await _text(
        s.access.isSet
            ? 'Accesso del personale'
            : 'Imposta il PIN della postazione',
        pin: true,
      );
      if (pin == null) return;
      if (!s.access.isSet) {
        final second = await _text('Ripeti il nuovo PIN', pin: true);
        if (second != pin) {
          await _message('PIN non confermato', 'I due PIN devono coincidere.');
          return;
        }
        await s.access.setPin(pin);
      } else if (!await s.access.verify(pin)) {
        await _message(
          'Accesso non riuscito',
          'PIN non valido. Dopo cinque tentativi attendere 30 secondi.',
        );
        return;
      }
      if (mounted) setState(() => _operator = true);
    } catch (e) {
      await _message('Accesso non riuscito', _friendly(e));
    } finally {
      _dialog = false;
    }
  }

  String _friendly(Object e) => e is FormatException
      ? e.message.toString()
      : e is FileSystemException
      ? 'Operazione sui file non riuscita. Controllare spazio disponibile e contenuto.'
      : e.toString();
  Future<void> _work(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      await s.log.write('operator_error', e);
      await _message('Operazione non completata', _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_operator) return;
    await _work(() async {
      if (!s.editor.canSave) {
        throw FormatException(s.editor.maskError ?? s.editor.geometryError!);
      }
      if (_outputWarning != null || _metricsPending) {
        throw const FormatException(
          'Confermare prima la calibrazione del nuovo output.',
        );
      }
      final p = s.editor.draft.copyWith(displayKey: _actualKey);
      await s.repository.save(p);
      s.editor.change(p);
      s.editor.markSaved();
      await s.playback.configure(p);
      setState(() => _status = 'Preset salvato · ${p.label}');
      await s.log.write('preset_saved', p.id);
    });
  }

  Future<void> _projection() async {
    if (!_operator || _busy) return;
    if (!s.editor.canSave) {
      await _message(
        'Sagoma da correggere',
        s.editor.maskError ?? s.editor.geometryError!,
      );
      return;
    }
    if (_outputWarning != null) {
      await _message(
        'Output da ricalibrare',
        'Verificare la griglia, poi confermare “Ricalibra output”.',
      );
      return;
    }
    if (s.editor.dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Modifiche non salvate'),
          content: const Text('Al riavvio viene usato il preset salvato.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Indietro'),
            ),
            TextButton(
              key: const ValueKey('project-draft'),
              onPressed: () => Navigator.pop(c, 'draft'),
              child: const Text('Proietta la bozza'),
            ),
            TextButton(
              key: const ValueKey('save-and-project'),
              onPressed: () => Navigator.pop(c, 'save'),
              child: const Text('Salva e proietta'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'save') {
        await _save();
        if (s.editor.dirty) return;
      }
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await PlatformOutput.kiosk('start');
    if (mounted) setState(() => _operator = false);
  }

  Future<void> _acceptOutput() async {
    if (!_operator || _actualSize == null) return;
    if (!await _confirm(
      'Usare questo output?',
      'La geometria normalizzata verrà riferita al nuovo raster. Verificare griglia e sagoma sulla superficie prima di salvare.',
    )) {
      return;
    }
    s.editor.change(
      s.editor.draft.copyWith(outputSize: _actualSize, displayKey: _actualKey),
    );
    await _measureOutput();
  }

  Future<void> _import() async {
    if (!_operator) return;
    await _work(() async {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Video',
            mimeTypes: ['video/*'],
            extensions: ['mp4', 'mov', 'm4v', 'mkv', 'webm'],
          ),
        ],
      );
      if (file == null) return;
      final extension = file.name.contains('.')
          ? file.name.split('.').last
          : 'mp4';
      final relative = await MediaImporter(s.root).import(
        file.openRead(),
        extension,
        validate: (f) async {
          final candidate = AndroidVideoBackend();
          try {
            await candidate.initialize(f).timeout(const Duration(seconds: 20));
          } finally {
            await candidate.close();
          }
        },
      );
      final next = s.editor.draft.copyWith(mediaPath: relative);
      if (!await s.playback.open(File('${s.root.path}/$relative'), next)) {
        throw const FormatException(
          'Il nuovo video non è stato applicato. Il precedente resta attivo.',
        );
      }
      s.editor.change(next);
      setState(
        () => _status = 'Video importato: ${file.name} · salvare il preset.',
      );
    });
  }

  Future<bool> _discardDraft() async =>
      !s.editor.dirty ||
      await _confirm(
        'Abbandonare la bozza?',
        'La calibrazione salvata rimane disponibile. Le modifiche non salvate verranno abbandonate.',
      );
  Future<void> _preset(String action) async {
    if (!_operator) return;
    if (action == 'duplicate') {
      final name = await _text(
        'Nome della copia',
        initial: '${s.editor.draft.label} · copia',
      );
      if (name == null || name.trim().isEmpty) return;
      await _work(() async {
        final p = s.editor.draft.copyWith(
          id: 'preset-${DateTime.now().microsecondsSinceEpoch}',
          label: name,
        );
        await s.repository.save(p);
        s.editor.replace(p);
        setState(() => _status = 'Copia salvata');
      });
      return;
    }
    if (action == 'reset') {
      if (!await _confirm(
        'Azzera la calibrazione?',
        'Il video e gli altri preset vengono conservati. Puoi annullare questa modifica.',
      )) {
        return;
      }
      final p = s.editor.draft, base = ProjectionPreset.initial();
      s.editor.change(
        p.copyWith(
          mode: base.mode,
          center: base.center,
          scaleX: 1,
          scaleY: 1,
          rotation: 0,
          corners: base.corners,
          mask: base.mask,
        ),
      );
      return;
    }
    if (!await _discardDraft()) return;
    await _work(() async {
      ProjectionPreset? p;
      if (action == 'previous') {
        p = await s.repository.previous();
      } else {
        final all = await s.repository.list();
        if (all.isEmpty) throw const FormatException('Nessun preset salvato.');
        if (!mounted) return;
        p = await showDialog<ProjectionPreset>(
          context: context,
          builder: (c) => _PresetPicker(all),
        );
      }
      if (p == null) return;
      if (!await s.playback.open(File('${s.root.path}/${p.mediaPath}'), p)) {
        throw const FormatException(
          'Video del preset non disponibile. Il precedente resta attivo.',
        );
      }
      // Loading previews the selected preset. Only explicit save changes startup.
      s.editor.replace(p, saved: false);
      if (action == 'previous') {
        s.editor.change(p.copyWith(label: '${p.label} · ripristinato'));
      }
      setState(
        () => _status =
            '${p!.label} caricato · premi Salva per usarlo all’avvio.',
      );
      await _measureOutput();
    });
  }

  Future<void> _system(String action) async {
    if (!_operator) return;
    if (action == 'licenses') {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Theme(
              data: PlayerTheme.data,
              child: const LicensePage(
                applicationName: 'DCHS Video Mapping',
                applicationVersion: '1.0.0+1',
              ),
            ),
          ),
        );
      }
      return;
    }
    if (action == 'pin') {
      final old = await _text('PIN attuale', pin: true);
      if (old == null) return;
      if (!await s.access.verify(old)) {
        await _message('PIN non valido', 'Il PIN non è stato modificato.');
        return;
      }
      final pin = await _text('Nuovo PIN', pin: true);
      if (pin == null) return;
      final second = await _text('Ripeti il nuovo PIN', pin: true);
      if (pin != second) {
        await _message('PIN non confermato', 'Il PIN non è stato modificato.');
        return;
      }
      await _work(() async {
        await s.access.setPin(pin);
      });
      return;
    }
    if (action == 'kiosk') {
      final locked = await PlatformOutput.kiosk('status');
      await _message(
        'Stato kiosk',
        locked
            ? 'Lock task attivo. L’uscita richiede la procedura autorizzata del DPC.'
            : 'Lock task non attivo. Il dispositivo deve essere gestito da un DPC che autorizza dev.dariocavada.dchs_video_mapping.',
      );
      return;
    }
    if (action == 'diagnostics') {
      final p = s.editor.draft, v = s.playback.snapshot;
      await _message(
        'Diagnostica',
        'App 1.0.0+1 · ${s.playback.phase.name}\nPreset: ${p.label}\nVideo: ${v.width.toInt()} × ${v.height.toInt()}, durata ${v.duration}\nPosizione: ${v.position}\nOutput: $_actualKey\n${_actualSize?.width.toInt()} × ${_actualSize?.height.toInt()}\nTentativi recupero: ${s.playback.watchdog.attempts} / 3\n${s.playback.diagnostic ?? s.startupWarning ?? s.repository.warning ?? 'Nessun errore registrato.'}',
      );
      return;
    }
    if (action == 'export') {
      await _work(() async {
        final temp = await getTemporaryDirectory(),
            file = File(
              '${temp.path}/dchs-video-mapping-${DateTime.now().millisecondsSinceEpoch}.zip',
            );
        await s.log.write(
          'export',
          'configurazione e log; media e PIN esclusi',
        );
        await SupportArchive.write(s.root, file, s.editor.draft);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/zip')],
            subject: 'DCHS Video Mapping · configurazione e log',
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = !_metricsPending && _outputWarning == null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _operator) unawaited(_projection());
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.keyM &&
              HardwareKeyboard.instance.isControlPressed) {
            unawaited(_access());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_operator)
              OperatorScreen(
                editor: s.editor,
                playback: s.playback,
                onSave: _save,
                onProjection: _projection,
                onImport: _import,
                onPreset: _preset,
                onSystem: _system,
                status: s.playback.diagnostic ?? s.startupWarning ?? _status,
                outputWarning: _outputWarning,
                onAcceptOutput: () => unawaited(_acceptOutput()),
              )
            else
              MouseRegion(
                cursor: SystemMouseCursors.none,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if (event.localPosition.dx < 100 &&
                        event.localPosition.dy < 100) {
                      _holdStart = event.localPosition;
                      _hold?.cancel();
                      _hold = Timer(
                        const Duration(seconds: 3),
                        () => unawaited(_access()),
                      );
                    }
                  },
                  onPointerMove: (event) {
                    if (_holdStart != null &&
                        (event.localPosition - _holdStart!).distance > 20) {
                      _hold?.cancel();
                    }
                  },
                  onPointerUp: (_) => _hold?.cancel(),
                  onPointerCancel: (_) => _hold?.cancel(),
                  child: ProjectionSurface(
                    key: const ValueKey('public-output'),
                    preset: s.editor.applied,
                    playback: s.playback,
                    outputAllowed: allowed,
                  ),
                ),
              ),
            if (!s.access.isSet && !_operator)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Material(
                      key: const ValueKey('player-setup-card'),
                      color: PlayerTheme.surfaceContainerLow,
                      textStyle: Theme.of(context).textTheme.bodyMedium!
                          .copyWith(decoration: TextDecoration.none),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: PlayerTheme.outlineVariant),
                      ),
                      child: SizedBox(
                        width: 620,
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'DCHS Video Mapping',
                                style: TextStyle(
                                  fontSize: 26,
                                  color: PlayerTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Prepara la postazione',
                                style: TextStyle(fontSize: 32),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Imposta un PIN del personale, importa il video e calibra la superficie. Il filmato incluso è dimostrativo.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              PlayerButton(
                                'Configura il player',
                                key: const ValueKey('setup-player'),
                                onPressed: () => unawaited(_access()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_busy && _operator)
              ColoredBox(
                color: Color(0xaa000000),
                child: Center(
                  child: CircularProgressIndicator(color: PlayerTheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetPicker extends StatefulWidget {
  const _PresetPicker(this.presets);
  final List<ProjectionPreset> presets;
  @override
  State<_PresetPicker> createState() => _PresetPickerState();
}

class _PresetPickerState extends State<_PresetPicker> {
  int page = 0;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Carica una calibrazione'),
    content: SizedBox(
      width: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in widget.presets.skip(page * 6).take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: PlayerButton(
                  p.label,
                  onPressed: () => Navigator.pop(context, p),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: page > 0 ? () => setState(() => page--) : null,
                child: const Text('Precedenti'),
              ),
              Text('${page + 1} / ${(widget.presets.length / 6).ceil()}'),
              TextButton(
                onPressed: (page + 1) * 6 < widget.presets.length
                    ? () => setState(() => page++)
                    : null,
                child: const Text('Successivi'),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
    ],
  );
}
