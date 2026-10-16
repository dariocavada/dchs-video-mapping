import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../mapping/editor_controller.dart';
import '../presets/preset.dart';
import '../playback/playback_controller.dart';
import '../output/projection_surface.dart';
import 'player_theme.dart';

enum SelectedPart { node, inHandle, outHandle }

class MappingCanvas extends StatefulWidget {
  const MappingCanvas({
    super.key,
    required this.editor,
    required this.playback,
    required this.maskMode,
    required this.pattern,
    required this.showHelpers,
    required this.selected,
    required this.part,
    required this.onSelection,
    required this.addNode,
    required this.onAdded,
    this.viewScale = 1,
    this.viewOffset = Offset.zero,
    this.panView = false,
    this.onViewPan,
    this.onViewZoom,
  });
  final MappingEditor editor;
  final PlaybackController playback;
  final bool maskMode, pattern, showHelpers, addNode;
  final int selected;
  final SelectedPart part;
  final void Function(int, SelectedPart) onSelection;
  final VoidCallback onAdded;
  // Editor camera only; never serialized or applied to ProjectionSurface output.
  final double viewScale;
  final Offset viewOffset;
  final bool panView;
  final ValueChanged<Offset>? onViewPan;
  final void Function(double factor, Offset focalPoint)? onViewZoom;
  @override
  State<MappingCanvas> createState() => _MappingCanvasState();
}

class _MappingCanvasState extends State<MappingCanvas> {
  Offset? _last;
  bool _draggingView = false;
  Rect _frame(Size size) => Rect.fromCenter(
    center:
        size.center(Offset.zero) +
        Offset(
          widget.viewOffset.dx * size.width,
          widget.viewOffset.dy * size.height,
        ),
    width: size.width * widget.viewScale,
    height: size.height * widget.viewScale,
  );
  Offset _normal(Offset point, Size size) {
    final frame = _frame(size);
    return Offset(
      (point.dx - frame.left) / frame.width,
      (point.dy - frame.top) / frame.height,
    );
  }

  void _start(DragStartDetails d, Size size) {
    _draggingView = widget.panView;
    if (_draggingView) return;
    final e = widget.editor, p = e.draft, v = _normal(d.localPosition, size);
    if (widget.maskMode) {
      if (widget.addNode) {
        var best = double.infinity, segment = 0, t = .5;
        for (var i = 0; i < p.mask.nodes.length; i++) {
          for (var k = 1; k < 100; k++) {
            final at = p.mask.at(i, k / 100),
                delta = Offset(
                  (v.dx - at.dx) * size.width * widget.viewScale,
                  (v.dy - at.dy) * size.height * widget.viewScale,
                ).distance;
            if (delta < best) {
              best = delta;
              segment = i;
              t = k / 100;
            }
          }
        }
        if (best < 60) {
          e.splitSegment(segment, t);
          widget.onSelection(segment + 1, SelectedPart.node);
          widget.onAdded();
        }
        return;
      }
      var best = double.infinity, index = widget.selected, part = widget.part;
      final points = <(int, SelectedPart, Offset)>[
        for (final (i, n) in p.mask.nodes.indexed)
          (i, SelectedPart.node, n.position),
        if (widget.selected < p.mask.nodes.length) ...[
          (
            widget.selected,
            SelectedPart.inHandle,
            p.mask.nodes[widget.selected].inHandle,
          ),
          (
            widget.selected,
            SelectedPart.outHandle,
            p.mask.nodes[widget.selected].outHandle,
          ),
        ],
      ];
      // Selected component wins exact overlaps; explicit component buttons remain
      // available when a handle lies on its node.
      points.sort(
        (a, b) => (a.$1 == widget.selected && a.$2 == widget.part ? -1 : 0)
            .compareTo(b.$1 == widget.selected && b.$2 == widget.part ? -1 : 0),
      );
      for (final (i, type, at) in points) {
        final distance = Offset(
          (v.dx - at.dx) * size.width * widget.viewScale,
          (v.dy - at.dy) * size.height * widget.viewScale,
        ).distance;
        if (distance < best) {
          best = distance;
          index = i;
          part = type;
        }
      }
      final globalScale = math.min(
        MediaQuery.sizeOf(context).width / 1920,
        MediaQuery.sizeOf(context).height / 1080,
      );
      if (best > math.max(28, 28 / globalScale)) return;
      widget.onSelection(index, part);
    } else if (p.mode == MappingMode.quad) {
      var nearest = 0, best = double.infinity;
      for (var i = 0; i < 4; i++) {
        final delta = (p.corners[i] - v).distance;
        if (delta < best) {
          best = delta;
          nearest = i;
        }
      }
      widget.onSelection(nearest, SelectedPart.node);
    }
    _last = v;
    e.beginGesture();
  }

  void _update(DragUpdateDetails d, Size size) {
    if (_draggingView) {
      widget.onViewPan?.call(
        Offset(d.delta.dx / size.width, d.delta.dy / size.height),
      );
      return;
    }
    if (_last == null) return;
    final e = widget.editor,
        p = e.draft,
        v = _normal(d.localPosition, size),
        delta = v - _last!;
    _last = v;
    if (widget.maskMode) {
      if (widget.selected >= p.mask.nodes.length) return;
      final n = p.mask.nodes[widget.selected];
      Offset clamp(Offset v, double min, double max) =>
          Offset(v.dx.clamp(min, max), v.dy.clamp(min, max));
      final node = switch (widget.part) {
        SelectedPart.node => n.move(
          clamp(n.position + delta, 0, 1) - n.position,
        ),
        SelectedPart.inHandle => n.moveHandle(
          false,
          clamp(n.inHandle + delta, -1, 2),
        ),
        SelectedPart.outHandle => n.moveHandle(
          true,
          clamp(n.outHandle + delta, -1, 2),
        ),
      };
      e.change(p.copyWith(mask: p.mask.replace(widget.selected, node)));
    } else if (p.mode == MappingMode.quad) {
      final corners = p.corners.toList();
      corners[widget.selected] = Offset(
        (corners[widget.selected].dx + delta.dx).clamp(0, 1),
        (corners[widget.selected].dy + delta.dy).clamp(0, 1),
      );
      e.change(p.copyWith(corners: corners));
    } else {
      e.change(
        p.copyWith(
          center: Offset(
            (p.center.dx + delta.dx).clamp(-1, 2),
            (p.center.dy + delta.dy).clamp(-1, 2),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight),
          frame = _frame(size);
      return Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
            GestureBinding.instance.pointerSignalResolver.register(event, (_) {
              widget.onViewZoom?.call(
                event.scrollDelta.dy < 0 ? 1.25 : .8,
                Offset(
                  event.localPosition.dx / size.width,
                  event.localPosition.dy / size.height,
                ),
              );
            });
          }
        },
        child: MouseRegion(
          cursor: widget.panView
              ? SystemMouseCursors.grab
              : SystemMouseCursors.precise,
          child: GestureDetector(
            key: const ValueKey('mapping-canvas'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _start(d, size),
            onPanUpdate: (d) => _update(d, size),
            onPanEnd: (_) {
              if (!_draggingView) widget.editor.endGesture();
              _last = null;
              _draggingView = false;
            },
            onPanCancel: () {
              if (!_draggingView) widget.editor.cancelGesture();
              _last = null;
              _draggingView = false;
            },
            onTapUp: (d) {
              if (widget.panView) return;
              _start(DragStartDetails(localPosition: d.localPosition), size);
              _last = null;
              widget.editor.endGesture();
            },
            child: ColoredBox(
              color: PlayerTheme.surface,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fromRect(
                      rect: frame,
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(color: PlayerTheme.outlineVariant),
                        ),
                        child: ProjectionSurface(
                          key: const ValueKey('editor-output-raster'),
                          preset: widget.editor.applied,
                          playback: widget.playback,
                          pattern: widget.pattern,
                        ),
                      ),
                    ),
                    if (widget.showHelpers)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _Helpers(
                            widget.editor.draft,
                            widget.maskMode,
                            widget.selected,
                            widget.part,
                            widget.editor.maskError != null ||
                                widget.editor.geometryError != null,
                            frame,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Helpers extends CustomPainter {
  _Helpers(
    this.p,
    this.maskMode,
    this.selected,
    this.part,
    this.invalid,
    this.frame,
  );
  final Rect frame;
  final ProjectionPreset p;
  final bool maskMode, invalid;
  final int selected;
  final SelectedPart part;
  @override
  void paint(Canvas canvas, Size viewportSize) {
    canvas.save();
    canvas.translate(frame.left, frame.top);
    final size = frame.size;
    Offset px(Offset v) => Offset(v.dx * size.width, v.dy * size.height);
    final stroke = Paint()
      ..color = invalid ? Colors.redAccent : PlayerTheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    void marker(
      Offset point,
      bool active, {
      bool handle = false,
      String? label,
    }) {
      final v = px(point),
          paint = Paint()
            ..color = active ? PlayerTheme.primary : PlayerTheme.surface;
      if (handle) {
        canvas.drawRect(
          Rect.fromCenter(center: v, width: 18, height: 18),
          paint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: v, width: 18, height: 18),
          stroke,
        );
      } else {
        canvas.drawCircle(v, active ? 15 : 12, paint);
        canvas.drawCircle(v, active ? 15 : 12, stroke);
      }
      if (label != null) {
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, v + const Offset(18, -24));
      }
    }

    if (maskMode) {
      canvas.drawPath(p.mask.path(size), stroke);
      for (final (i, n) in p.mask.nodes.indexed) {
        marker(
          n.position,
          i == selected && part == SelectedPart.node,
          label: '${i + 1}',
        );
      }
      if (selected < p.mask.nodes.length) {
        final n = p.mask.nodes[selected], pos = px(n.position);
        canvas.drawLine(pos, px(n.inHandle), stroke);
        canvas.drawLine(pos, px(n.outHandle), stroke);
        marker(n.inHandle, part == SelectedPart.inHandle, handle: true);
        marker(n.outHandle, part == SelectedPart.outHandle, handle: true);
      }
    } else if (p.mode == MappingMode.quad) {
      final path = Path()
        ..moveTo(px(p.corners.first).dx, px(p.corners.first).dy);
      for (final c in p.corners.skip(1)) {
        path.lineTo(px(c).dx, px(c).dy);
      }
      canvas.drawPath(path..close(), stroke);
      for (var i = 0; i < 4; i++) {
        marker(p.corners[i], i == selected, label: '${i + 1}');
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Helpers old) =>
      p != old.p ||
      maskMode != old.maskMode ||
      selected != old.selected ||
      part != old.part ||
      invalid != old.invalid ||
      frame != old.frame;
}
