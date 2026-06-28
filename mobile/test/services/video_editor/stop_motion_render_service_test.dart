import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(StopMotionRenderService, () {
    tearDown(() => StopMotionRenderService.assembleOverride = null);

    test('returns null for an empty frame list', () async {
      final result = await StopMotionRenderService.assemble(
        framePaths: const [],
        aspectRatio: model.AspectRatio.vertical,
      );

      expect(result, isNull);
    });

    test('delegates to assembleOverride with the given arguments', () async {
      List<String>? capturedPaths;
      model.AspectRatio? capturedRatio;
      int? capturedFramesPerShot;
      double? capturedFrameRate;

      StopMotionRenderService.assembleOverride =
          ({
            required framePaths,
            required aspectRatio,
            framesPerShot = 1,
            frameRate = StopMotionRenderService.defaultFrameRate,
          }) async {
            capturedPaths = framePaths;
            capturedRatio = aspectRatio;
            capturedFramesPerShot = framesPerShot;
            capturedFrameRate = frameRate;
            return '/tmp/out.mp4';
          };

      final result = await StopMotionRenderService.assemble(
        framePaths: const ['/a.jpg', '/b.jpg'],
        aspectRatio: model.AspectRatio.square,
        framesPerShot: 3,
      );

      expect(result, '/tmp/out.mp4');
      expect(capturedPaths, ['/a.jpg', '/b.jpg']);
      expect(capturedRatio, model.AspectRatio.square);
      expect(capturedFramesPerShot, 3);
      expect(capturedFrameRate, StopMotionRenderService.defaultFrameRate);
    });

    group('framesForMinOutputDuration', () {
      const min = VideoEditorConstants.stopMotionMinOutputDuration;

      test('returns an empty list unchanged', () {
        expect(
          StopMotionRenderService.framesForMinOutputDuration(
            const [],
            const Duration(milliseconds: 83),
          ),
          isEmpty,
        );
      });

      test('repeats a single still until it reaches the minimum', () {
        const perFrame = Duration(milliseconds: 83);
        final result = StopMotionRenderService.framesForMinOutputDuration(
          const ['/a.jpg'],
          perFrame,
        );

        expect(result.toSet(), {'/a.jpg'});
        expect(perFrame * result.length, greaterThanOrEqualTo(min));
        // Minimal: one fewer copy would fall short of the floor.
        expect(perFrame * (result.length - 1), lessThan(min));
      });

      test('loops a short sequence a whole number of times', () {
        const perFrame = Duration(milliseconds: 100);
        const frames = ['/a.jpg', '/b.jpg', '/c.jpg']; // 300ms < 1s
        final result = StopMotionRenderService.framesForMinOutputDuration(
          frames,
          perFrame,
        );

        expect(result.length % frames.length, 0);
        expect(perFrame * result.length, greaterThanOrEqualTo(min));
        expect(perFrame * (result.length - frames.length), lessThan(min));
        // Order preserved across the repeats (seamless loop).
        expect(result.sublist(0, frames.length), frames);
      });

      test('leaves a sequence already at the minimum unchanged', () {
        const perFrame = Duration(milliseconds: 250);
        const frames = ['/a.jpg', '/b.jpg', '/c.jpg', '/d.jpg']; // 1s
        final result = StopMotionRenderService.framesForMinOutputDuration(
          frames,
          perFrame,
        );

        expect(result, frames);
      });
    });

    group('materialize', () {
      DivineVideoClip stopMotionClip() => DivineVideoClip(
        id: 'sm1',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/a.jpg',
            duration: Duration(milliseconds: 83),
          ),
          StopMotionClipFrame(
            path: '/b.jpg',
            duration: Duration(milliseconds: 83),
          ),
        ],
        duration: const Duration(milliseconds: 166),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      test('returns a non-stop-motion clip unchanged', () async {
        final clip = DivineVideoClip(
          id: 'v1',
          video: EditorVideo.file('/v.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

        final result = await StopMotionRenderService.materialize(clip);

        expect(identical(result, clip), isTrue);
      });

      test('renders a stop-motion clip to a video-backed copy', () async {
        List<String>? capturedPaths;
        StopMotionRenderService.assembleOverride =
            ({
              required framePaths,
              required aspectRatio,
              framesPerShot = 1,
              frameRate = StopMotionRenderService.defaultFrameRate,
            }) async {
              capturedPaths = framePaths;
              return '/rendered.mp4';
            };

        final clip = stopMotionClip();
        final result = await StopMotionRenderService.materialize(clip);

        expect(capturedPaths, ['/a.jpg', '/b.jpg']);
        expect(result?.video?.file?.path, '/rendered.mp4');
        // Frames are kept as the source of truth.
        expect(result?.stopMotionFrames, clip.stopMotionFrames);
      });

      test('returns null when the render fails', () async {
        StopMotionRenderService.assembleOverride =
            ({
              required framePaths,
              required aspectRatio,
              framesPerShot = 1,
              frameRate = StopMotionRenderService.defaultFrameRate,
            }) async => null;

        final result = await StopMotionRenderService.materialize(
          stopMotionClip(),
        );

        expect(result, isNull);
      });
    });
  });
}
