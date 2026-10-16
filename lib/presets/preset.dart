import 'dart:ui';

import '../mapping/mask.dart';
import '../mapping/geometry.dart';

enum MappingMode { affine, quad }

enum VideoFit { contain, cover, stretch }

class ProjectionPreset {
  ProjectionPreset({
    required this.id,
    required this.label,
    required this.mediaPath,
    required this.outputSize,
    required this.displayKey,
    required this.mask,
    this.fit = VideoFit.contain,
    this.loop = true,
    this.autoplay = true,
    this.volume = 0,
    this.flip = false,
    this.mode = MappingMode.affine,
    this.center = const Offset(.5, .5),
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    List<Offset> corners = const [
      Offset(0, 0),
      Offset(1, 0),
      Offset(1, 1),
      Offset(0, 1),
    ],
  }) : corners = List.unmodifiable(corners);
  final String id, label, mediaPath, displayKey;
  final Size outputSize;
  final BezierMask mask;
  final VideoFit fit;
  final bool loop, autoplay, flip;
  final double volume, scaleX, scaleY, rotation;
  final MappingMode mode;
  final Offset center;
  final List<Offset> corners;
  factory ProjectionPreset.initial() => ProjectionPreset(
    id: 'postazione-01',
    label: 'Postazione 01',
    mediaPath: 'media/demo.mp4',
    outputSize: const Size(1920, 1080),
    displayKey: '',
    mask: BezierMask.rectangle(),
  );
  ProjectionPreset copyWith({
    String? id,
    String? label,
    String? mediaPath,
    Size? outputSize,
    String? displayKey,
    BezierMask? mask,
    VideoFit? fit,
    bool? loop,
    bool? autoplay,
    double? volume,
    bool? flip,
    MappingMode? mode,
    Offset? center,
    double? scaleX,
    double? scaleY,
    double? rotation,
    List<Offset>? corners,
  }) => ProjectionPreset(
    id: id ?? this.id,
    label: label ?? this.label,
    mediaPath: mediaPath ?? this.mediaPath,
    outputSize: outputSize ?? this.outputSize,
    displayKey: displayKey ?? this.displayKey,
    mask: mask ?? this.mask,
    fit: fit ?? this.fit,
    loop: loop ?? this.loop,
    autoplay: autoplay ?? this.autoplay,
    volume: volume ?? this.volume,
    flip: flip ?? this.flip,
    mode: mode ?? this.mode,
    center: center ?? this.center,
    scaleX: scaleX ?? this.scaleX,
    scaleY: scaleY ?? this.scaleY,
    rotation: rotation ?? this.rotation,
    corners: corners ?? this.corners,
  );
  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
        label.trim().isEmpty ||
        label.length > 120) {
      throw const FormatException('Nome preset non valido');
    }
    if (!RegExp(r'^media/[a-zA-Z0-9_-]+\.[a-zA-Z0-9]{1,8}$')
        .hasMatch(mediaPath)) {
      throw const FormatException('Percorso video non valido');
    }
    for (final v in [outputSize.width, outputSize.height]) {
      if (!v.isFinite || v < 32 || v > 8192 || v != v.roundToDouble()) {
        throw const FormatException('Risoluzione non valida');
      }
    }
    for (final (v, min, max) in [
      (center.dx, -1.0, 2.0),
      (center.dy, -1.0, 2.0),
      (scaleX, .02, 4.0),
      (scaleY, .02, 4.0),
      (rotation, -180.0, 180.0),
      (volume, 0.0, 1.0),
    ]) {
      if (!v.isFinite || v < min || v > max) {
        throw const FormatException('Parametro fuori intervallo');
      }
    }
    final error =
        validateMask(mask, outputSize) ?? validateQuad(corners, outputSize);
    if (error != null) throw FormatException(error);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'label': label,
    'media': {'relativePath': mediaPath, 'fit': fit.name},
    'playback': {'loop': loop, 'autoplay': autoplay, 'volume': volume},
    'output': {
      'width': outputSize.width.toInt(),
      'height': outputSize.height.toInt(),
      'displayKey': displayKey,
    },
    'mapping': {
      'mode': mode.name,
      'flipHorizontal': flip,
      'affine': {
        'centerX': center.dx,
        'centerY': center.dy,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'rotationDeg': rotation,
      },
      'corners': corners.map((p) => [p.dx, p.dy]).toList(),
      'mask': mask.toJson(),
    },
  };
  factory ProjectionPreset.fromJson(Map<String, dynamic> j) {
    try {
      if (j['schemaVersion'] != 1) {
        throw const FormatException('Versione preset non supportata');
      }
      final media = j['media'] as Map,
          play = j['playback'] as Map,
          out = j['output'] as Map,
          map = j['mapping'] as Map,
          a = map['affine'] as Map;
      double number(dynamic v) {
        if (v is! num || !v.isFinite) {
          throw const FormatException('Numero non valido');
        }
        return v.toDouble();
      }

      final p = ProjectionPreset(
        id: j['id'] as String,
        label: j['label'] as String,
        mediaPath: media['relativePath'] as String,
        fit: VideoFit.values.byName(media['fit'] as String),
        loop: play['loop'] as bool,
        autoplay: play['autoplay'] as bool,
        volume: number(play['volume']),
        outputSize: Size(number(out['width']), number(out['height'])),
        displayKey: out['displayKey'] as String,
        mode: MappingMode.values.byName(map['mode'] as String),
        flip: map['flipHorizontal'] as bool,
        center: Offset(number(a['centerX']), number(a['centerY'])),
        scaleX: number(a['scaleX']),
        scaleY: number(a['scaleY']),
        rotation: number(a['rotationDeg']),
        corners: (map['corners'] as List).map(readPoint).toList(),
        mask: map['mask'] == null
            ? BezierMask.rectangle()
            : BezierMask.fromJson(
                Map<String, dynamic>.from(map['mask'] as Map),
              ),
      );
      p.validate();
      return p;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Preset incompleto o non valido');
    }
  }
}
