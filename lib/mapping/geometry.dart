import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import '../presets/preset.dart';

Offset projectPoint(Matrix4 m, Offset p) {
  final v = m * Vector4(p.dx, p.dy, 0, 1);
  if (v.w.abs() < 1e-12) {
    throw const FormatException('Trasformazione singolare');
  }
  return Offset(v.x / v.w, v.y / v.w);
}

String? validateQuad(List<Offset> p, Size size) {
  if (p.length != 4) return 'Occorrono quattro angoli.';
  for (final v in p) {
    if (!v.dx.isFinite ||
        !v.dy.isFinite ||
        v.dx < 0 ||
        v.dx > 1 ||
        v.dy < 0 ||
        v.dy > 1) {
      return 'Angoli fuori dal raster.';
    }
  }
  var sign = 0.0, area = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
    final cross = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    if (cross.abs() < 1e-8 || (sign != 0 && sign * cross < 0)) {
      return 'Il quadrilatero deve essere convesso e non incrociato.';
    }
    sign = cross;
    area += a.dx * b.dy - b.dx * a.dy;
  }
  if (area.abs() * size.width * size.height / 2 < 16) {
    return 'Area del quadrilatero insufficiente.';
  }
  return null;
}

Matrix4 mappingMatrix(ProjectionPreset p, Size size) {
  if (p.mode == MappingMode.affine) {
    return Matrix4.identity()
      ..translateByDouble(
        p.center.dx * size.width,
        p.center.dy * size.height,
        0,
        1,
      )
      ..rotateZ(p.rotation * math.pi / 180)
      ..scaleByDouble(p.scaleX, p.scaleY, 1, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }
  final error = validateQuad(p.corners, size);
  if (error != null) throw FormatException(error);
  final a = <List<double>>[];
  const src = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
  for (var i = 0; i < 4; i++) {
    final x = src[i].dx,
        y = src[i].dy,
        u = p.corners[i].dx,
        v = p.corners[i].dy;
    a.add([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
    a.add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
  }
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var r = col + 1; r < 8; r++) {
      if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
    }
    if (a[pivot][col].abs() < 1e-12) {
      throw const FormatException('Omografia singolare');
    }
    final tmp = a[col];
    a[col] = a[pivot];
    a[pivot] = tmp;
    final divisor = a[col][col];
    for (var k = col; k < 9; k++) {
      a[col][k] /= divisor;
    }
    for (var r = 0; r < 8; r++) {
      if (r == col) continue;
      final f = a[r][col];
      for (var k = col; k < 9; k++) {
        a[r][k] -= f * a[col][k];
      }
    }
  }
  final h = [for (var i = 0; i < 8; i++) a[i][8]],
      w = size.width,
      t = size.height;
  return Matrix4.zero()
    ..setEntry(0, 0, h[0])
    ..setEntry(0, 1, h[1] * w / t)
    ..setEntry(0, 3, h[2] * w)
    ..setEntry(1, 0, h[3] * t / w)
    ..setEntry(1, 1, h[4])
    ..setEntry(1, 3, h[5] * t)
    ..setEntry(2, 2, 1)
    ..setEntry(3, 0, h[6] / w)
    ..setEntry(3, 1, h[7] / t)
    ..setEntry(3, 3, 1);
}
