import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/mapping/mask.dart';
import 'package:dchs_video_mapping/mapping/geometry.dart';
import 'package:dchs_video_mapping/presets/preset.dart';

void main() {
  const size = Size(1920, 1080);
  test('subdivision preserves a curved segment and moves adjacent handles', () {
    final mask = BezierMask.arch();
    final divided = mask.split(0, .37);
    expect(divided.nodes.length, 5);
    for (var i = 0; i <= 100; i++) {
      final t = i / 100;
      final point = t <= .37
          ? divided.at(0, t / .37)
          : divided.at(1, (t - .37) / .63);
      expect((point - mask.at(0, t)).distance, lessThan(1e-10));
    }
    expect(validateMask(divided, size), isNull);
  });
  test(
    'invalid bow tie, straight area, non finite and excessive handles rejected',
    () {
      final rect = BezierMask.rectangle();
      expect(validateMask(rect, size), isNull);
      final nodes = rect.nodes;
      final crossed = BezierMask(
        enabled: true,
        nodes: [nodes[0], nodes[2], nodes[1], nodes[3]],
      );
      expect(validateMask(crossed, size), isNotNull);
      expect(
        validateMask(
          rect.replace(
            0,
            nodes[0].copyWith(position: const Offset(double.nan, 0)),
          ),
          size,
        ),
        isNotNull,
      );
      expect(
        validateMask(
          rect.replace(0, nodes[0].copyWith(outHandle: const Offset(3, 0))),
          size,
        ),
        isNotNull,
      );
      expect(
        validateMask(
          BezierMask(enabled: false, nodes: nodes.take(2).toList()),
          size,
        ),
        isNotNull,
      );
    },
  );
  test('node move translates both handles; smooth handle preserves opposite length', () {
    final n = BezierNode(
      id: 'x',
      position: const Offset(.5, .5),
      inHandle: const Offset(.3, .5),
      outHandle: const Offset(.7, .5),
      mode: NodeMode.smooth,
    );
    final moved = n.move(const Offset(.1, .2));
    expect(moved.inHandle, const Offset(.4, .7));
    expect(moved.outHandle.dx, closeTo(.8, 1e-12));
    final h = n.moveHandle(true, const Offset(.5, .8));
    expect(h.inHandle.dx, closeTo(.5, 1e-12));
    expect(h.inHandle.dy, closeTo(.3, 1e-12));
  });
  test('quad maps all four corners without applying affine twice', () {
    final p = ProjectionPreset.initial().copyWith(
      mode: MappingMode.quad,
      corners: const [
        Offset(.1, .2),
        Offset(.8, .1),
        Offset(.9, .9),
        Offset(.2, .8),
      ],
    );
    final m = mappingMatrix(p, size);
    const sources = [
      Offset(0, 0),
      Offset(1920, 0),
      Offset(1920, 1080),
      Offset(0, 1080),
    ];
    const expected = [
      Offset(192, 216),
      Offset(1536, 108),
      Offset(1728, 972),
      Offset(384, 864),
    ];
    for (var i = 0; i < 4; i++) {
      expect(
        (projectPoint(m, sources[i]) - expected[i]).distance,
        lessThan(.5),
      );
    }
    expect(
      validateQuad(const [
        Offset(0, 0),
        Offset(1, 1),
        Offset(1, 0),
        Offset(0, 1),
      ], size),
      isNotNull,
    );
    expect(validateQuad(List.filled(4, Offset.zero), size), isNotNull);
  });
  test('affine centers, scales then rotates clockwise', () {
    final p = ProjectionPreset.initial().copyWith(
      center: const Offset(.25, .5),
      scaleX: .5,
      scaleY: .5,
      rotation: 90,
    );
    expect(
      (projectPoint(mappingMatrix(p, size), const Offset(960, 540)) -
              const Offset(480, 540))
          .distance,
      lessThan(1e-9),
    );
    expect(
      (projectPoint(mappingMatrix(p, size), const Offset(1920, 540)) -
              const Offset(480, 1020))
          .distance,
      lessThan(1e-9),
    );
  });
  test(
    'preset round trip retains curves and rejects traversal and unknown schema',
    () {
      final p = ProjectionPreset.initial().copyWith(mask: BezierMask.arch());
      expect(
        ProjectionPreset.fromJson(jsonDecode(jsonEncode(p.toJson()))).toJson(),
        p.toJson(),
      );
      final raw = p.toJson();
      raw['schemaVersion'] = 99;
      expect(() => ProjectionPreset.fromJson(raw), throwsFormatException);
      expect(
        () => p.copyWith(mediaPath: '../private.mp4').validate(),
        throwsFormatException,
      );
    },
  );
}
