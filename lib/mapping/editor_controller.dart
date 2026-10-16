import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../presets/preset.dart';
import 'geometry.dart';
import 'mask.dart';

class MappingEditor extends ChangeNotifier {
  MappingEditor(ProjectionPreset preset)
    : draft = preset,
      _saved = jsonEncode(preset.toJson()),
      appliedMask = preset.mask,
      applied = preset;
  ProjectionPreset draft, applied;
  BezierMask appliedMask;
  String? maskError, geometryError;
  String _saved;
  final _undo = <ProjectionPreset>[], _redo = <ProjectionPreset>[];
  ProjectionPreset? _gesture;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get dirty => jsonEncode(draft.toJson()) != _saved;
  bool get canSave => maskError == null && geometryError == null;
  void _validate() {
    maskError = validateMask(draft.mask, draft.outputSize);
    geometryError = draft.mode == MappingMode.quad
        ? validateQuad(draft.corners, draft.outputSize)
        : null;
    if (maskError == null) appliedMask = draft.mask;
    if (geometryError == null) {
      applied = draft.copyWith(mask: appliedMask);
    } else {
      applied = applied.copyWith(mask: appliedMask);
    }
  }

  String _geometry(ProjectionPreset p) => jsonEncode({
    'output': p.toJson()['output'],
    'mapping': p.toJson()['mapping'],
    'fit': p.fit.name,
  });
  ProjectionPreset _restoreGeometry(ProjectionPreset p) => draft.copyWith(
    outputSize: p.outputSize,
    displayKey: p.displayKey,
    fit: p.fit,
    flip: p.flip,
    mode: p.mode,
    center: p.center,
    scaleX: p.scaleX,
    scaleY: p.scaleY,
    rotation: p.rotation,
    corners: p.corners,
    mask: p.mask,
  );

  void change(ProjectionPreset p) {
    if (jsonEncode(p.toJson()) == jsonEncode(draft.toJson())) return;
    final geometryChanged = _geometry(p) != _geometry(draft);
    if (_gesture == null && geometryChanged) {
      _undo.add(draft);
      if (_undo.length > 100) _undo.removeAt(0);
    }
    if (geometryChanged) _redo.clear();
    draft = p;
    _validate();
    notifyListeners();
  }

  void beginGesture() {
    _gesture ??= draft;
  }

  void endGesture() {
    if (_gesture != null && _geometry(_gesture!) != _geometry(draft)) {
      _undo.add(_gesture!);
    }
    _gesture = null;
    notifyListeners();
  }

  void cancelGesture() {
    if (_gesture == null) return;
    draft = _restoreGeometry(_gesture!);
    _gesture = null;
    _validate();
    notifyListeners();
  }

  void undo() {
    if (_gesture != null) endGesture();
    if (_undo.isEmpty) return;
    _redo.add(draft);
    draft = _restoreGeometry(_undo.removeLast());
    _validate();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(draft);
    draft = _restoreGeometry(_redo.removeLast());
    _validate();
    notifyListeners();
  }

  void replace(ProjectionPreset p, {bool saved = true}) {
    draft = p;
    _undo.clear();
    _redo.clear();
    _gesture = null;
    _saved = saved ? jsonEncode(p.toJson()) : '';
    _validate();
    notifyListeners();
  }

  void markSaved() {
    _saved = jsonEncode(draft.toJson());
    notifyListeners();
  }

  void nudgeVideo(Offset pixels) => change(
    draft.copyWith(
      center:
          draft.center +
          Offset(
            pixels.dx / draft.outputSize.width,
            pixels.dy / draft.outputSize.height,
          ),
    ),
  );
  void splitSegment(int i, double t) =>
      change(draft.copyWith(mask: draft.mask.split(i, t)));
  void deleteNode(int i) {
    if (draft.mask.nodes.length <= 3) return;
    change(
      draft.copyWith(
        mask: draft.mask.copyWith(
          nodes: [...draft.mask.nodes.take(i), ...draft.mask.nodes.skip(i + 1)],
        ),
      ),
    );
  }

  void setMode(MappingMode mode) {
    if (mode == draft.mode) return;
    var corners = draft.corners;
    if (mode == MappingMode.quad) {
      final s = draft.outputSize, m = mappingMatrix(draft, s);
      corners = [
        for (final point in [
          Offset.zero,
          Offset(s.width, 0),
          Offset(s.width, s.height),
          Offset(0, s.height),
        ])
          projectPoint(m, point),
      ].map((v) => Offset(v.dx / s.width, v.dy / s.height)).toList();
      final error = validateQuad(corners, s);
      if (error != null) throw FormatException(error);
    }
    if (mode == MappingMode.affine &&
        validateQuad(corners, draft.outputSize) != null) {
      corners = applied.corners;
    }
    change(draft.copyWith(mode: mode, corners: corners));
  }
}
