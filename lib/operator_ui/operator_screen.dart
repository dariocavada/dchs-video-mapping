import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mapping/editor_controller.dart';
import '../mapping/mask.dart';
import '../presets/preset.dart';
import '../playback/playback_controller.dart';
import 'mapping_canvas.dart';
import 'player_theme.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({
    super.key,
    required this.editor,
    required this.playback,
    required this.onSave,
    required this.onProjection,
    required this.onImport,
    required this.onPreset,
    required this.onSystem,
    required this.status,
    required this.outputWarning,
    required this.onAcceptOutput,
  });
  final MappingEditor editor;
  final PlaybackController playback;
  final Future<void> Function() onSave, onProjection, onImport;
  final Future<void> Function(String) onPreset, onSystem;
  final String status;
  final String? outputWarning;
  final VoidCallback onAcceptOutput;
  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  String _tab = 'geometry';
  bool _pattern = false,
      _helpers = true,
      _add = false,
      _linked = true,
      _largeStep = false;
  int _selected = 0;
  double _viewScale = 1;
  Offset _viewOffset = Offset.zero;
  bool _panView = false;

  void _zoomView(double factor, [Offset focal = const Offset(.5, .5)]) {
    setState(() {
      final scale = (_viewScale * factor).clamp(.2, 4.0),
          ratio = scale / _viewScale;
      final relative = focal - const Offset(.5, .5);
      _viewOffset = relative - (relative - _viewOffset) * ratio;
      _viewScale = scale;
    });
  }

  void _fitOutput() => setState(() {
    _viewScale = 1;
    _viewOffset = Offset.zero;
    _panView = false;
  });
  void _fitHandles() {
    final points = [
      Offset.zero,
      const Offset(1, 1),
      for (final n in e.draft.mask.nodes) ...[
        n.position,
        n.inHandle,
        n.outHandle,
      ],
    ];
    final left = points.map((p) => p.dx).reduce(math.min),
        right = points.map((p) => p.dx).reduce(math.max);
    final top = points.map((p) => p.dy).reduce(math.min),
        bottom = points.map((p) => p.dy).reduce(math.max);
    final scale = (.85 / math.max(right - left, bottom - top)).clamp(.2, 4.0),
        center = Offset((left + right) / 2, (top + bottom) / 2);
    setState(() {
      _viewScale = scale;
      _viewOffset = (const Offset(.5, .5) - center) * scale;
      _panView = false;
    });
  }

  Widget _viewControls() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Vista',
        style: TextStyle(fontSize: 14, color: PlayerTheme.onSurfaceVariant),
      ),
      IconButton(
        key: const ValueKey('view-zoom-out'),
        tooltip: 'Riduci la vista dell’editor',
        onPressed: () => _zoomView(.8),
        icon: const Icon(Icons.zoom_out),
      ),
      SizedBox(
        width: 62,
        child: Text(
          '${(_viewScale * 100).round()}%',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      IconButton(
        key: const ValueKey('view-zoom-in'),
        tooltip: 'Ingrandisci la vista dell’editor',
        onPressed: () => _zoomView(1.25),
        icon: const Icon(Icons.zoom_in),
      ),
      IconButton(
        key: const ValueKey('view-fit-output'),
        tooltip: 'Inquadra output',
        onPressed: _fitOutput,
        icon: const Icon(Icons.fit_screen),
      ),
      if (_tab == 'mask')
        IconButton(
          key: const ValueKey('view-fit-handles'),
          tooltip: 'Inquadra tutte le maniglie',
          onPressed: _fitHandles,
          icon: const Icon(Icons.crop_free),
        ),
      IconButton(
        key: const ValueKey('view-pan'),
        tooltip: _panView
            ? 'Torna a modificare i punti'
            : 'Sposta solo la vista',
        isSelected: _panView,
        onPressed: () => setState(() {
          _panView = !_panView;
          _add = false;
        }),
        icon: const Icon(Icons.pan_tool_outlined),
        selectedIcon: const Icon(Icons.pan_tool),
      ),
    ],
  );

  SelectedPart _part = SelectedPart.node;
  final _focus = FocusNode();
  MappingEditor get e => widget.editor;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _select(int i, SelectedPart part) => setState(() {
    _selected = i;
    _part = part;
  });
  void _nudge(Offset delta) {
    final p = e.draft;
    if (_tab == 'mask') {
      _selected = _selected.clamp(0, p.mask.nodes.length - 1);
      final n = p.mask.nodes[_selected],
          d = Offset(
            delta.dx / p.outputSize.width,
            delta.dy / p.outputSize.height,
          );
      Offset limit(Offset v, double min, double max) =>
          Offset(v.dx.clamp(min, max), v.dy.clamp(min, max));
      final next = switch (_part) {
        SelectedPart.node => n.move(limit(n.position + d, 0, 1) - n.position),
        SelectedPart.inHandle => n.moveHandle(
          false,
          limit(n.inHandle + d, -1, 2),
        ),
        SelectedPart.outHandle => n.moveHandle(
          true,
          limit(n.outHandle + d, -1, 2),
        ),
      };
      e.change(p.copyWith(mask: p.mask.replace(_selected, next)));
    } else if (p.mode == MappingMode.quad) {
      final corners = p.corners.toList(),
          v =
              corners[_selected.clamp(0, 3)] +
              Offset(
                delta.dx / p.outputSize.width,
                delta.dy / p.outputSize.height,
              );
      corners[_selected.clamp(0, 3)] = Offset(
        v.dx.clamp(0, 1),
        v.dy.clamp(0, 1),
      );
      e.change(p.copyWith(corners: corners));
    } else {
      final v =
          p.center +
          Offset(delta.dx / p.outputSize.width, delta.dy / p.outputSize.height);
      e.change(
        p.copyWith(center: Offset(v.dx.clamp(-1, 2), v.dy.clamp(-1, 2))),
      );
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }
    final step = HardwareKeyboard.instance.isShiftPressed ? 10.0 : 1.0;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
      LogicalKeyboardKey.arrowRight => Offset(step, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -step),
      LogicalKeyboardKey.arrowDown => Offset(0, step),
      _ => null,
    };
    if (direction != null) {
      _nudge(direction);
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      HardwareKeyboard.instance.isShiftPressed ? e.redo() : e.undo();
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyS) {
      widget.onSave();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _gap([double h = 16]) => SizedBox(height: h);
  Widget _title(String text) =>
      Text(text, style: TextStyle(fontSize: 30, color: PlayerTheme.onSurface));
  Widget _note(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 18,
      color: PlayerTheme.onSurfaceVariant,
      height: 1.45,
    ),
  );
  Widget _check(
    String label,
    bool value,
    ValueChanged<bool> change, {
    Key? key,
  }) => Material(
    type: MaterialType.transparency,
    child: CheckboxListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 20)),
      value: value,
      onChanged: (v) => change(v!),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
  Widget _row(List<Widget> children) => Row(
    children: [
      for (final (i, w) in children.indexed) ...[
        if (i > 0) const SizedBox(width: 12),
        Expanded(child: w),
      ],
    ],
  );
  Widget _number(
    String label,
    double value,
    ValueChanged<double> change, {
    double min = -1e9,
    double max = 1e9,
  }) => NumberControl(
    key: ValueKey('number-$label'),
    label: label,
    value: value,
    onChanged: (v) {
      if (v >= min && v <= max) change(v);
    },
    min: min,
    max: max,
  );
  Widget _source() {
    final p = e.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('La sorgente'),
        _gap(),
        _note(p.mediaPath),
        _gap(),
        PlayerButton(
          'Scegli video locale',
          key: const ValueKey('import-video'),
          icon: Icons.folder_open,
          onPressed: () => widget.onImport(),
        ),
        _gap(),
        _note('Il file viene copiato e verificato prima di essere applicato.'),
        _gap(22),
        DropdownButtonFormField<VideoFit>(
          initialValue: p.fit,
          decoration: const InputDecoration(labelText: 'Adattamento'),
          items: const [
            DropdownMenuItem(
              value: VideoFit.contain,
              child: Text('Intero · contain'),
            ),
            DropdownMenuItem(
              value: VideoFit.cover,
              child: Text('Riempi · cover'),
            ),
            DropdownMenuItem(
              value: VideoFit.stretch,
              child: Text('Deforma · stretch'),
            ),
          ],
          onChanged: (v) => e.change(p.copyWith(fit: v)),
        ),
        _gap(),
        _check(
          'Retroproiezione · specchio',
          p.flip,
          (v) => e.change(p.copyWith(flip: v)),
        ),
        _check(
          'Avvia il video all’apertura',
          p.autoplay,
          (v) => e.change(p.copyWith(autoplay: v)),
        ),
        _gap(),
        _note(
          'MP4 H.264 / AAC · riferimento Full HD. Il supporto degli altri codec va provato sul dispositivo.',
        ),
      ],
    );
  }

  Widget _geometry() {
    final p = e.draft, s = p.outputSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Disponi il video'),
        _gap(),
        SegmentedButton<MappingMode>(
          segments: const [
            ButtonSegment(value: MappingMode.affine, label: Text('Base')),
            ButtonSegment(
              value: MappingMode.quad,
              label: Text('Quattro angoli'),
            ),
          ],
          selected: {p.mode},
          onSelectionChanged: (v) {
            try {
              e.setMode(v.first);
              _selected = 0;
            } catch (error) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$error')));
            }
          },
        ),
        _gap(24),
        if (p.mode == MappingMode.affine) ...[
          _row([
            _number(
              'Centro X · px',
              p.center.dx * s.width,
              (v) => e.change(
                p.copyWith(center: Offset(v / s.width, p.center.dy)),
              ),
              min: -s.width,
              max: s.width * 2,
            ),
            _number(
              'Centro Y · px',
              p.center.dy * s.height,
              (v) => e.change(
                p.copyWith(center: Offset(p.center.dx, v / s.height)),
              ),
              min: -s.height,
              max: s.height * 2,
            ),
          ]),
          _gap(),
          _row([
            _number(
              'Scala X · %',
              p.scaleX * 100,
              (v) => e.change(
                p.copyWith(
                  scaleX: v / 100,
                  scaleY: _linked ? v / 100 : p.scaleY,
                ),
              ),
              min: 2,
              max: 400,
            ),
            _number(
              'Scala Y · %',
              p.scaleY * 100,
              (v) => e.change(
                p.copyWith(
                  scaleY: v / 100,
                  scaleX: _linked ? v / 100 : p.scaleX,
                ),
              ),
              min: 2,
              max: 400,
            ),
          ]),
          _gap(),
          _number(
            'Rotazione · °',
            p.rotation,
            (v) => e.change(p.copyWith(rotation: v)),
            min: -180,
            max: 180,
          ),
          _check(
            'Mantieni proporzioni',
            _linked,
            (v) => setState(() {
              _linked = v;
              if (v) e.change(p.copyWith(scaleY: p.scaleX));
            }),
          ),
        ] else ...[
          _note('Angolo selezionato'),
          _gap(8),
          _row([
            for (var i = 0; i < 4; i++)
              PlayerButton(
                '${i + 1}',
                onPressed: () => _select(i, SelectedPart.node),
              ),
          ]),
          _gap(),
          _row([
            _number(
              'Angolo X · px',
              p.corners[_selected.clamp(0, 3)].dx * s.width,
              (v) {
                final c = p.corners.toList();
                c[_selected.clamp(0, 3)] = Offset(
                  v / s.width,
                  c[_selected.clamp(0, 3)].dy,
                );
                e.change(p.copyWith(corners: c));
              },
              min: 0,
              max: s.width,
            ),
            _number(
              'Angolo Y · px',
              p.corners[_selected.clamp(0, 3)].dy * s.height,
              (v) {
                final c = p.corners.toList();
                c[_selected.clamp(0, 3)] = Offset(
                  c[_selected.clamp(0, 3)].dx,
                  v / s.height,
                );
                e.change(p.copyWith(corners: c));
              },
              min: 0,
              max: s.height,
            ),
          ]),
          _gap(),
          _note(
            'Trascina un angolo. La griglia e il video condividono la stessa prospettiva.',
          ),
          _gap(12),
        ],
        _gap(),
        _nudgePad(),
        _gap(),
        _note(
          'Trascina nell’anteprima per spostare. Frecce: 1 px; Maiusc + frecce: 10 px.',
        ),
      ],
    );
  }

  Widget _mask() {
    final p = e.draft;
    _selected = _selected.clamp(0, p.mask.nodes.length - 1);
    final n = p.mask.nodes[_selected],
        s = p.outputSize,
        point = switch (_part) {
          SelectedPart.node => n.position,
          SelectedPart.inHandle => n.inHandle,
          SelectedPart.outHandle => n.outHandle,
        };
    void coordinate(Offset target) {
      final next = switch (_part) {
        SelectedPart.node => n.move(target - n.position),
        SelectedPart.inHandle => n.moveHandle(false, target),
        SelectedPart.outHandle => n.moveHandle(true, target),
      };
      e.change(p.copyWith(mask: p.mask.replace(_selected, next)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Sagoma Bézier'),
        _check(
          'Maschera attiva',
          p.mask.enabled,
          (v) => e.change(p.copyWith(mask: p.mask.copyWith(enabled: v))),
          key: const ValueKey('mask-enable'),
        ),
        _row([
          PlayerButton(
            'Arco',
            key: const ValueKey('mask-arch'),
            onPressed: () => _replaceMask(BezierMask.arch()),
          ),
          PlayerButton(
            'Rettangolo',
            onPressed: () =>
                _replaceMask(BezierMask.rectangle().copyWith(enabled: true)),
          ),
        ]),
        _gap(14),
        _row([
          PlayerButton(
            '‹',
            onPressed: () => _select(
              (_selected - 1 + p.mask.nodes.length) % p.mask.nodes.length,
              SelectedPart.node,
            ),
          ),
          Center(
            child: Text(
              'Nodo ${_selected + 1} / ${p.mask.nodes.length}',
              style: const TextStyle(fontSize: 19),
            ),
          ),
          PlayerButton(
            '›',
            onPressed: () => _select(
              (_selected + 1) % p.mask.nodes.length,
              SelectedPart.node,
            ),
          ),
        ]),
        _gap(14),
        SegmentedButton<SelectedPart>(
          segments: const [
            ButtonSegment(
              value: SelectedPart.inHandle,
              label: Text('Entrante'),
            ),
            ButtonSegment(value: SelectedPart.node, label: Text('Nodo')),
            ButtonSegment(
              value: SelectedPart.outHandle,
              label: Text('Uscente'),
            ),
          ],
          selected: {_part},
          onSelectionChanged: (v) => _select(_selected, v.first),
        ),
        _gap(18),
        _row([
          _number(
            'Punto X · px',
            point.dx * s.width,
            (v) => coordinate(Offset(v / s.width, point.dy)),
            min: _part == SelectedPart.node ? 0 : -s.width,
            max: _part == SelectedPart.node ? s.width : s.width * 2,
          ),
          _number(
            'Punto Y · px',
            point.dy * s.height,
            (v) => coordinate(Offset(point.dx, v / s.height)),
            min: _part == SelectedPart.node ? 0 : -s.height,
            max: _part == SelectedPart.node ? s.height : s.height * 2,
          ),
        ]),
        _gap(8),
        _check('Nodo morbido', n.mode == NodeMode.smooth, (v) {
          var node = n.copyWith(mode: v ? NodeMode.smooth : NodeMode.corner);
          if (v) node = node.moveHandle(true, node.outHandle);
          e.change(p.copyWith(mask: p.mask.replace(_selected, node)));
        }),
        _row([
          PlayerButton(
            _add ? 'Tocca la curva…' : 'Aggiungi nodo',
            key: const ValueKey('mask-add'),
            onPressed: p.mask.nodes.length < 32
                ? () => setState(() {
                    _add = !_add;
                    _panView = false;
                  })
                : null,
          ),
          PlayerButton(
            'Elimina nodo',
            onPressed: p.mask.nodes.length > 3
                ? () {
                    e.deleteNode(_selected);
                    setState(
                      () => _selected = _selected.clamp(
                        0,
                        e.draft.mask.nodes.length - 1,
                      ),
                    );
                  }
                : null,
          ),
        ]),
        _gap(16),
        _nudgePad(),
        _gap(14),
        _note(
          'Cerchi: nodi. Quadrati: maniglie. La curva ritaglia il video; il suo interno conserva la geometria.',
        ),
      ],
    );
  }

  Future<void> _replaceMask(BezierMask mask) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sostituire la sagoma?'),
        content: const Text('Puoi annullare questa operazione con Annulla.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Indietro'),
          ),
          TextButton(
            key: const ValueKey('confirm-mask'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sostituisci'),
          ),
        ],
      ),
    );
    if (ok == true) {
      e.change(e.draft.copyWith(mask: mask));
      setState(() {
        _selected = 0;
        _part = SelectedPart.node;
      });
    }
  }

  Widget _nudgePad() {
    final d = _largeStep ? 10.0 : 1.0;
    return Row(
      children: [
        for (final (label, delta) in [
          ('←', Offset(-d, 0)),
          ('↑', Offset(0, -d)),
          ('↓', Offset(0, d)),
          ('→', Offset(d, 0)),
        ]) ...[
          Expanded(child: PlayerButton(label, onPressed: () => _nudge(delta))),
          const SizedBox(width: 6),
        ],
        SizedBox(
          width: 86,
          child: PlayerButton(
            '${d.toInt()} px',
            onPressed: () => setState(() => _largeStep = !_largeStep),
          ),
        ),
      ],
    );
  }

  Widget _presets() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('Le calibrazioni'),
      _gap(),
      TextFormField(
        key: ValueKey('name-${e.draft.id}'),
        initialValue: e.draft.label,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Nome del preset'),
        onChanged: (v) {
          if (v.trim().isNotEmpty) e.change(e.draft.copyWith(label: v));
        },
      ),
      _gap(),
      PlayerButton(
        'Salva preset',
        onPressed: e.canSave ? () => widget.onSave() : null,
      ),
      _gap(),
      PlayerButton(
        'Carica preset',
        key: const ValueKey('load-preset'),
        onPressed: () => widget.onPreset('load'),
      ),
      _gap(),
      PlayerButton(
        'Duplica con un nuovo nome',
        onPressed: () => widget.onPreset('duplicate'),
      ),
      _gap(),
      PlayerButton(
        'Ripristina copia precedente',
        onPressed: () => widget.onPreset('previous'),
      ),
      _gap(),
      PlayerButton(
        'Azzera geometria e sagoma',
        onPressed: () => widget.onPreset('reset'),
      ),
      _gap(24),
      _note(
        'Il preset salva geometria, sagoma, video e audio. All’avvio viene richiamata l’ultima calibrazione salvata.',
      ),
    ],
  );
  Widget _system() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('La postazione'),
      _gap(),
      _note(
        'Output calibrato: ${e.draft.outputSize.width.toInt()} × ${e.draft.outputSize.height.toInt()}\n${e.draft.displayKey}',
      ),
      _gap(22),
      PlayerButton(
        'Diagnostica e log',
        onPressed: () => widget.onSystem('diagnostics'),
      ),
      _gap(),
      PlayerButton(
        'Esporta configurazione e log',
        onPressed: () => widget.onSystem('export'),
      ),
      _gap(),
      PlayerButton(
        'Cambia PIN personale',
        onPressed: () => widget.onSystem('pin'),
      ),
      _gap(),
      PlayerButton('Licenze', onPressed: () => widget.onSystem('licenses')),
      _gap(),
      PlayerButton('Stato kiosk', onPressed: () => widget.onSystem('kiosk')),
      _gap(24),
      _note(
        'Accesso dalla proiezione: tieni premuto per 3 secondi nell’angolo alto sinistro, oppure Ctrl + M, poi inserisci il PIN.',
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: ColoredBox(
        color: PlayerTheme.surface,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: AnimatedBuilder(
                animation: e,
                builder: (context, _) => Column(
                  children: [
                    Container(
                      height: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: PlayerTheme.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'DCHS Video Mapping',
                            style: TextStyle(
                              fontSize: 23,
                              color: PlayerTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 42),
                          const Expanded(
                            child: Text(
                              'Calibrazione video',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 36),
                            ),
                          ),
                          Text(
                            e.dirty ? 'Modifiche da salvare' : 'Preset salvato',
                            style: TextStyle(
                              fontSize: 18,
                              color: PlayerTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 28),
                          PlayerButton(
                            'Salva preset',
                            key: const ValueKey('save-preset'),
                            icon: Icons.save_outlined,
                            onPressed: e.canSave ? () => widget.onSave() : null,
                          ),
                          const SizedBox(width: 16),
                          PlayerButton(
                            'Solo proiezione',
                            key: const ValueKey('only-projection'),
                            icon: Icons.fullscreen,
                            onPressed: () => widget.onProjection(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 520,
                              decoration: BoxDecoration(
                                color: PlayerTheme.surfaceContainerLow,
                                border: Border.all(
                                  color: PlayerTheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 64,
                                    child: Row(
                                      children: [
                                        for (final (id, label) in [
                                          ('source', 'Video'),
                                          ('geometry', 'Geometria'),
                                          ('mask', 'Bézier'),
                                          ('presets', 'Preset'),
                                          ('system', 'Sistema'),
                                        ])
                                          Expanded(
                                            child: TextButton(
                                              key: ValueKey('tab-$id'),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.all(
                                                  0,
                                                ),
                                                foregroundColor: _tab == id
                                                    ? PlayerTheme.onSurface
                                                    : PlayerTheme
                                                          .onSurfaceVariant,
                                                backgroundColor: _tab == id
                                                    ? PlayerTheme
                                                          .secondaryContainer
                                                    : Colors.transparent,
                                                shape:
                                                    const RoundedRectangleBorder(),
                                              ),
                                              onPressed: () => setState(() {
                                                _tab = id;
                                                _selected = 0;
                                                _part = SelectedPart.node;
                                                _add = false;
                                                _panView = false;
                                              }),
                                              child: Text(
                                                label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: switch (_tab) {
                                        'source' => _source(),
                                        'mask' => _mask(),
                                        'presets' => _presets(),
                                        'system' => _system(),
                                        _ => _geometry(),
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 64,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e.draft.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 26,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        _viewControls(),
                                        const SizedBox(width: 12),
                                        FilterChip(
                                          label: const Text('Griglia'),
                                          selected: _pattern,
                                          onSelected: (v) =>
                                              setState(() => _pattern = v),
                                        ),
                                        const SizedBox(width: 12),
                                        FilterChip(
                                          label: const Text('Nodi e aiuti'),
                                          selected: _helpers,
                                          onSelected: (v) =>
                                              setState(() => _helpers = v),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio:
                                            e.draft.outputSize.aspectRatio,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: PlayerTheme.outlineVariant,
                                            ),
                                          ),
                                          child: MappingCanvas(
                                            editor: e,
                                            playback: widget.playback,
                                            viewScale: _viewScale,
                                            viewOffset: _viewOffset,
                                            panView: _panView,
                                            onViewZoom: (factor, focal) =>
                                                _zoomView(factor, focal),
                                            onViewPan: (delta) => setState(
                                              () => _viewOffset += delta,
                                            ),
                                            maskMode: _tab == 'mask',
                                            pattern: _pattern,
                                            showHelpers: _helpers,
                                            selected: _selected,
                                            part: _part,
                                            onSelection: _select,
                                            addNode: _add,
                                            onAdded: () =>
                                                setState(() => _add = false),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 76,
                                    child: Row(
                                      children: [
                                        PlayerButton(
                                          'Annulla',
                                          key: const ValueKey('undo'),
                                          icon: Icons.undo,
                                          onPressed: e.canUndo ? e.undo : null,
                                        ),
                                        const SizedBox(width: 12),
                                        PlayerButton(
                                          'Ripeti',
                                          icon: Icons.redo,
                                          onPressed: e.canRedo ? e.redo : null,
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Text(
                                            e.maskError ??
                                                e.geometryError ??
                                                widget.outputWarning ??
                                                (_add
                                                    ? 'Tocca la curva per inserire un nodo.'
                                                    : _panView
                                                    ? 'Sposta solo la vista. Il video proiettato resta fermo.'
                                                    : widget.status),
                                            maxLines: 2,
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: e.canSave
                                                  ? PlayerTheme.onSurfaceVariant
                                                  : Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                        if (widget.outputWarning != null) ...[
                                          const SizedBox(width: 12),
                                          PlayerButton(
                                            'Ricalibra output',
                                            onPressed: widget.onAcceptOutput,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _PlaybackBar(playback: widget.playback, editor: e),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class NumberControl extends StatefulWidget {
  const NumberControl({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  @override
  State<NumberControl> createState() => _NumberControlState();
}

class _NumberControlState extends State<NumberControl> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  String? _error;
  String _format(double v) => v.toStringAsFixed(2);
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _format(widget.value));
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit();
    });
  }

  @override
  void didUpdateWidget(NumberControl old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != old.value) {
      _text.text = _format(widget.value);
      _error = null;
    }
  }

  void _submit() {
    final v = double.tryParse(_text.text.replaceAll(',', '.'));
    if (v == null || !v.isFinite || v < widget.min || v > widget.max) {
      if (mounted) {
        setState(
          () => _error =
              '${widget.min.toStringAsFixed(0)} … ${widget.max.toStringAsFixed(0)}',
        );
      }
      return;
    }
    if (mounted) setState(() => _error = null);
    widget.onChanged(v);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    focusNode: _focus,
    style: const TextStyle(fontSize: 23),
    decoration: InputDecoration(labelText: widget.label, errorText: _error),
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    onSubmitted: (_) => _submit(),
  );
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({required this.playback, required this.editor});
  final PlaybackController playback;
  final MappingEditor editor;
  String _time(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: playback,
    builder: (context, _) {
      final s = playback.snapshot, p = editor.draft;
      return Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: PlayerTheme.surfaceContainerLow,
          border: Border(top: BorderSide(color: PlayerTheme.outlineVariant)),
        ),
        child: Row(
          children: [
            PlayerButton(
              s.playing ? 'Pausa' : 'Riproduci',
              key: const ValueKey('play-pause'),
              icon: s.playing ? Icons.pause : Icons.play_arrow,
              onPressed: s.ready ? () => playback.toggle() : null,
            ),
            const SizedBox(width: 20),
            Text(
              '${_time(s.position)} / ${_time(s.duration)}',
              style: const TextStyle(fontSize: 19),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Slider(
                value: math
                    .min(
                      s.position.inMilliseconds.toDouble(),
                      s.duration.inMilliseconds.toDouble(),
                    )
                    .clamp(
                      0,
                      math.max(1, s.duration.inMilliseconds.toDouble()),
                    ),
                max: math.max(1, s.duration.inMilliseconds.toDouble()),
                onChanged: s.ready
                    ? (v) => playback.seek(Duration(milliseconds: v.toInt()))
                    : null,
              ),
            ),
            const SizedBox(width: 20),
            FilterChip(
              label: const Text('Loop'),
              selected: p.loop,
              onSelected: (v) {
                editor.change(p.copyWith(loop: v));
                playback.configure(editor.draft);
              },
            ),
            const SizedBox(width: 18),
            IconButton(
              tooltip: p.volume == 0 ? 'Attiva audio' : 'Muto',
              onPressed: () {
                editor.change(p.copyWith(volume: p.volume == 0 ? .5 : 0));
                playback.configure(editor.draft);
              },
              icon: Icon(p.volume == 0 ? Icons.volume_off : Icons.volume_up),
            ),
            SizedBox(
              width: 140,
              child: Slider(
                value: p.volume,
                onChanged: (v) {
                  editor.change(p.copyWith(volume: v));
                  playback.configure(editor.draft);
                },
              ),
            ),
            Text(
              '${(p.volume * 100).round()}%',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 18),
            Text(
              '${p.outputSize.width.toInt()} × ${p.outputSize.height.toInt()}',
              style: TextStyle(
                fontSize: 18,
                color: PlayerTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}
