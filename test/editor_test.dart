import 'package:flutter_test/flutter_test.dart';
import 'package:dchs_video_mapping/mapping/editor_controller.dart';
import 'package:dchs_video_mapping/mapping/mask.dart';
import 'package:dchs_video_mapping/presets/preset.dart';

void main() {
  test('whole drag is one undo; new branch clears redo', () {
    final e = MappingEditor(ProjectionPreset.initial());
    e.beginGesture();
    for (var i = 1; i <= 10; i++) {
      e.change(e.draft.copyWith(center: Offset(.5 + i * .01, .5)));
    }
    e.endGesture();
    e.undo();
    expect(e.draft.center, const Offset(.5, .5));
    e.redo();
    expect(e.draft.center.dx, closeTo(.6, 1e-12));
    e.undo();
    e.change(e.draft.copyWith(rotation: 20));
    expect(e.canRedo, false);
  });
  test('invalid mask keeps last valid output and blocks save', () {
    final e = MappingEditor(
      ProjectionPreset.initial().copyWith(mask: BezierMask.arch()),
    );
    final before = e.appliedMask.toJson();
    e.change(
      e.draft.copyWith(
        mask: BezierMask(
          enabled: true,
          nodes: e.draft.mask.nodes.take(2).toList(),
        ),
      ),
    );
    expect(e.maskError, isNotNull);
    expect(e.appliedMask.toJson(), before);
    expect(e.canSave, false);
    e.undo();
    expect(e.maskError, isNull);
  });
  test('nudge is in physical output pixels and mask stays still under video transform', () {
    final e = MappingEditor(
      ProjectionPreset.initial().copyWith(mask: BezierMask.arch()),
    );
    final before = e.appliedMask.toJson();
    e.nudgeVideo(const Offset(10, 1));
    expect(e.draft.center.dx, closeTo(.5 + 10 / 1920, 1e-12));
    expect(e.draft.center.dy, closeTo(.5 + 1 / 1080, 1e-12));
    expect(e.appliedMask.toJson(), before);
  });
  test('node count limits and cancelled gesture restore original', () {
    final e = MappingEditor(ProjectionPreset.initial());
    e.beginGesture();
    e.nudgeVideo(const Offset(40, 0));
    e.cancelGesture();
    expect(e.draft.center, const Offset(.5, .5));
    e.deleteNode(0);
    expect(e.draft.mask.nodes.length, 3);
    e.deleteNode(0);
    expect(e.draft.mask.nodes.length, 3);
    for (var i = 0; i < 40; i++) {
      e.splitSegment(0, .5);
    }
    expect(e.draft.mask.nodes.length, 32);
  });
  test('calibration undo preserves imported source and playback controls', () {
    final e = MappingEditor(ProjectionPreset.initial());
    e.change(e.draft.copyWith(rotation: 30));
    e.change(
      e.draft.copyWith(
        mediaPath: 'media/new.mp4',
        volume: .7,
        loop: false,
        label: 'New',
      ),
    );
    e.undo();
    expect(e.draft.rotation, 0);
    expect(e.draft.mediaPath, 'media/new.mp4');
    expect(e.draft.volume, .7);
    expect(e.draft.loop, false);
    expect(e.draft.label, 'New');
    e.redo();
    expect(e.draft.rotation, 30);
    expect(e.draft.mediaPath, 'media/new.mp4');
  });
  test(
    'returning to affine after invalid quad restores valid inactive corners',
    () {
      final e = MappingEditor(ProjectionPreset.initial());
      e.setMode(MappingMode.quad);
      e.change(
        e.draft.copyWith(
          corners: const [
            Offset(0, 0),
            Offset(1, 1),
            Offset(1, 0),
            Offset(0, 1),
          ],
        ),
      );
      expect(e.canSave, false);
      e.setMode(MappingMode.affine);
      expect(e.canSave, true);
      expect(() => e.draft.validate(), returnsNormally);
    },
  );
}
