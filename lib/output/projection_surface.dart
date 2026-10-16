import 'package:flutter/material.dart';

import '../mapping/geometry.dart';
import '../mapping/mask.dart';
import '../presets/preset.dart';
import '../playback/playback_controller.dart';

class ProjectionSurface extends StatelessWidget {
  const ProjectionSurface({
    super.key,
    required this.preset,
    required this.playback,
    this.pattern = false,
    this.outputAllowed = true,
  });
  final ProjectionPreset preset;
  final PlaybackController playback;
  final bool pattern, outputAllowed;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: preset.outputSize.width,
            height: preset.outputSize.height,
            child: AnimatedBuilder(
              animation: playback,
              builder: (context, _) => _raster(),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _raster() {
    final size = preset.outputSize;
    if (!outputAllowed || (!pattern && !playback.visible)) {
      return const ColoredBox(color: Colors.black);
    }
    Widget source;
    if (pattern) {
      source = CustomPaint(painter: CalibrationPattern());
    } else {
      final s = playback.snapshot;
      source = FittedBox(
        fit: switch (preset.fit) {
          VideoFit.contain => BoxFit.contain,
          VideoFit.cover => BoxFit.cover,
          VideoFit.stretch => BoxFit.fill,
        },
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: s.width,
          height: s.height,
          child: playback.backend!.surface,
        ),
      );
    }
    if (preset.flip) source = Transform.flip(flipX: true, child: source);
    final transformed = Transform(
      transform: mappingMatrix(preset, size),
      alignment: Alignment.topLeft,
      child: SizedBox(width: size.width, height: size.height, child: source),
    );
    return ClipPath(
      clipper: preset.mask.enabled ? MaskClipper(preset.mask) : null,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [Positioned.fill(child: transformed)],
      ),
    );
  }
}

class MaskClipper extends CustomClipper<Path> {
  MaskClipper(this.mask);
  final BezierMask mask;
  Path? _path;
  Size? _size;
  @override
  Path getClip(Size size) {
    if (_size != size) {
      _size = size;
      _path = mask.path(size);
    }
    return _path!;
  }

  @override
  bool shouldReclip(MaskClipper old) => old.mask != mask;
}

class CalibrationPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff101010),
    );
    final p = Paint()
      ..color = const Color(0xffb0b0b0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i <= 12; i++) {
      final x = size.width * i / 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var i = 0; i <= 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    canvas.drawRect(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      p
        ..strokeWidth = 6
        ..color = Colors.white,
    );
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * .15,
      p..strokeWidth = 3,
    );
    void label(String text, Offset point, {double font = 48}) {
      final t = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: Colors.white, fontSize: font),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, point);
    }

    label('1', const Offset(24, 24));
    label('2', Offset(size.width - 70, 24));
    label('3', Offset(size.width - 70, size.height - 90));
    label('4', Offset(24, size.height - 90));
    label(
      'DCHS · CALIBRATION',
      Offset(size.width * .34, size.height * .46),
      font: 38,
    );
  }

  @override
  bool shouldRepaint(CalibrationPattern old) => false;
}
