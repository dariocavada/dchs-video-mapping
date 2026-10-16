import 'dart:math' as math;
import 'dart:ui';

enum NodeMode { corner, smooth }

class BezierNode {
  const BezierNode({
    required this.id,
    required this.position,
    required this.inHandle,
    required this.outHandle,
    this.mode = NodeMode.corner,
  });
  final String id;
  final Offset position, inHandle, outHandle;
  final NodeMode mode;
  BezierNode copyWith({
    Offset? position,
    Offset? inHandle,
    Offset? outHandle,
    NodeMode? mode,
  }) => BezierNode(
    id: id,
    position: position ?? this.position,
    inHandle: inHandle ?? this.inHandle,
    outHandle: outHandle ?? this.outHandle,
    mode: mode ?? this.mode,
  );
  BezierNode move(Offset delta) => copyWith(
    position: position + delta,
    inHandle: inHandle + delta,
    outHandle: outHandle + delta,
  );
  BezierNode moveHandle(bool outgoing, Offset target) {
    final vector = target - position;
    var opposite = outgoing ? inHandle : outHandle;
    if (mode == NodeMode.smooth && vector.distance > 1e-12) {
      opposite =
          position - vector / vector.distance * (opposite - position).distance;
    }
    return outgoing
        ? copyWith(outHandle: target, inHandle: opposite)
        : copyWith(inHandle: target, outHandle: opposite);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': [position.dx, position.dy],
    'inHandle': [inHandle.dx, inHandle.dy],
    'outHandle': [outHandle.dx, outHandle.dy],
    'mode': mode.name,
  };
  factory BezierNode.fromJson(Map<String, dynamic> j) => BezierNode(
    id: j['id'] as String,
    position: readPoint(j['position']),
    inHandle: readPoint(j['inHandle']),
    outHandle: readPoint(j['outHandle']),
    mode: NodeMode.values.byName(j['mode'] as String),
  );
}

Offset readPoint(dynamic raw) {
  if (raw is! List ||
      raw.length != 2 ||
      raw.any((v) => v is! num || !v.isFinite)) {
    throw const FormatException('Invalid coordinates');
  }
  return Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
}

Offset _mix(Offset a, Offset b, double t) => a + (b - a) * t;

class BezierMask {
  BezierMask({required this.enabled, required List<BezierNode> nodes})
    : nodes = List.unmodifiable(nodes);
  final bool enabled;
  final List<BezierNode> nodes;
  factory BezierMask.rectangle() => BezierMask(
    enabled: false,
    nodes: [
      for (final (i, p) in const [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ].indexed)
        BezierNode(id: 'n$i', position: p, inHandle: p, outHandle: p),
    ],
  );
  factory BezierMask.arch() => BezierMask(
    enabled: true,
    nodes: const [
      BezierNode(
        id: 'n0',
        position: Offset(.2, .35),
        inHandle: Offset(.2, .55),
        outHandle: Offset(.2, 0),
      ),
      BezierNode(
        id: 'n1',
        position: Offset(.8, .35),
        inHandle: Offset(.8, 0),
        outHandle: Offset(.8, .55),
      ),
      BezierNode(
        id: 'n2',
        position: Offset(.8, .9),
        inHandle: Offset(.8, .9),
        outHandle: Offset(.8, .9),
      ),
      BezierNode(
        id: 'n3',
        position: Offset(.2, .9),
        inHandle: Offset(.2, .9),
        outHandle: Offset(.2, .9),
      ),
    ],
  );
  BezierMask copyWith({bool? enabled, List<BezierNode>? nodes}) =>
      BezierMask(enabled: enabled ?? this.enabled, nodes: nodes ?? this.nodes);
  BezierMask replace(int i, BezierNode n) =>
      copyWith(nodes: [...nodes.take(i), n, ...nodes.skip(i + 1)]);
  Offset at(int i, double t) {
    final a = nodes[i], b = nodes[(i + 1) % nodes.length], s = 1 - t;
    return a.position * (s * s * s) +
        a.outHandle * (3 * s * s * t) +
        b.inHandle * (3 * s * t * t) +
        b.position * (t * t * t);
  }

  BezierMask split(int i, double t) {
    if (nodes.length >= 32 || t <= 0 || t >= 1) return this;
    final a = nodes[i], j = (i + 1) % nodes.length, b = nodes[j];
    final q0 = _mix(a.position, a.outHandle, t),
        q1 = _mix(a.outHandle, b.inHandle, t),
        q2 = _mix(b.inHandle, b.position, t);
    final r0 = _mix(q0, q1, t), r1 = _mix(q1, q2, t), p = _mix(r0, r1, t);
    final result = nodes.toList();
    result[i] = a.copyWith(outHandle: q0);
    result[j] = b.copyWith(inHandle: q2);
    var id = 'split';
    while (result.any((n) => n.id == id)) {
      id += 'x';
    }
    result.insert(
      i + 1,
      BezierNode(
        id: id,
        position: p,
        inHandle: r0,
        outHandle: r1,
        mode: NodeMode.smooth,
      ),
    );
    return copyWith(nodes: result);
  }

  Path path(Size size) {
    Offset px(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final p = Path()..fillType = PathFillType.nonZero;
    if (nodes.isEmpty) return p;
    final first = px(nodes.first.position);
    p.moveTo(first.dx, first.dy);
    for (var i = 0; i < nodes.length; i++) {
      final a = px(nodes[i].outHandle),
          b = px(nodes[(i + 1) % nodes.length].inHandle),
          c = px(nodes[(i + 1) % nodes.length].position);
      p.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
    return p..close();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'space': 'outputNormalized',
    'fillRule': 'nonZero',
    'closed': true,
    'nodes': nodes.map((n) => n.toJson()).toList(),
  };
  factory BezierMask.fromJson(Map<String, dynamic> j) {
    if (j['space'] != 'outputNormalized' ||
        j['closed'] != true ||
        j['fillRule'] != 'nonZero' ||
        j['enabled'] is! bool) {
      throw const FormatException('Unsupported mask');
    }
    return BezierMask(
      enabled: j['enabled'] as bool,
      nodes: (j['nodes'] as List)
          .map((n) => BezierNode.fromJson(Map<String, dynamic>.from(n as Map)))
          .toList(),
    );
  }
}

// Adaptive de Casteljau subdivision in output pixels; also catches loops whose
// endpoints coincide. The polygon is used for validation, never for rendering.
List<Offset> flattenMask(BezierMask mask, Size size) {
  Offset px(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
  final points = <Offset>[px(mask.nodes.first.position)];
  void flatten(Offset a, Offset b, Offset c, Offset d, int depth) {
    final chord = (d - a).distance;
    double distance(Offset p) => chord < 1e-10
        ? (p - a).distance
        : ((d.dx - a.dx) * (a.dy - p.dy) - (a.dx - p.dx) * (d.dy - a.dy))
                  .abs() /
              chord;
    final excess =
        (b - a).distance + (c - b).distance + (d - c).distance - chord;
    if (depth >= 16 ||
        (math.max(distance(b), distance(c)) <= .5 && excess <= .5)) {
      points.add(d);
      return;
    }
    final ab = (a + b) / 2,
        bc = (b + c) / 2,
        cd = (c + d) / 2,
        abc = (ab + bc) / 2,
        bcd = (bc + cd) / 2,
        m = (abc + bcd) / 2;
    flatten(a, ab, abc, m, depth + 1);
    flatten(m, bcd, cd, d, depth + 1);
  }

  for (var i = 0; i < mask.nodes.length; i++) {
    final a = mask.nodes[i], b = mask.nodes[(i + 1) % mask.nodes.length];
    flatten(px(a.position), px(a.outHandle), px(b.inHandle), px(b.position), 0);
  }
  return points;
}

double _cross(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
bool _intersects(Offset a, Offset b, Offset c, Offset d) {
  const eps = 1e-7;
  if (math.max(a.dx, b.dx) + eps < math.min(c.dx, d.dx) ||
      math.max(c.dx, d.dx) + eps < math.min(a.dx, b.dx) ||
      math.max(a.dy, b.dy) + eps < math.min(c.dy, d.dy) ||
      math.max(c.dy, d.dy) + eps < math.min(a.dy, b.dy)) {
    return false;
  }
  final x = _cross(a, b, c),
      y = _cross(a, b, d),
      z = _cross(c, d, a),
      w = _cross(c, d, b);
  return ((x >= -eps && y <= eps) || (y >= -eps && x <= eps)) &&
      ((z >= -eps && w <= eps) || (w >= -eps && z <= eps));
}

String? validateMask(BezierMask mask, Size size) {
  if (mask.nodes.length < 3 || mask.nodes.length > 32) {
    return 'The mask requires 3 to 32 nodes.';
  }
  final ids = <String>{};
  for (final n in mask.nodes) {
    if (n.id.isEmpty || !ids.add(n.id)) {
      return 'Invalid node IDs.';
    }
    for (final (p, min, max) in [
      (n.position, 0.0, 1.0),
      (n.inHandle, -1.0, 2.0),
      (n.outHandle, -1.0, 2.0),
    ]) {
      if (!p.dx.isFinite ||
          !p.dy.isFinite ||
          p.dx < min ||
          p.dx > max ||
          p.dy < min ||
          p.dy > max) {
        return 'Coordinates outside mask limits.';
      }
    }
  }
  final points = flattenMask(mask, size);
  if (points.length > 8192) return 'The mask is too complex.';
  var area = 0.0;
  final count = points.length - 1;
  for (var i = 0; i < count; i++) {
    final a = points[i], b = points[i + 1];
    if ((b - a).distance < 1e-7) return 'Two nodes or segments overlap.';
    area += a.dx * b.dy - b.dx * a.dy;
    for (var j = i + 2; j < count; j++) {
      if (i == 0 && j == count - 1) continue;
      if (_intersects(a, b, points[j], points[j + 1])) {
        return 'The mask self-intersects: adjust nodes or handles.';
      }
    }
  }
  if (area.abs() / 2 < 16) return 'The mask area is too small.';
  return null;
}
