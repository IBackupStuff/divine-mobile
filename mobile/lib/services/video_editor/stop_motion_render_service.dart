// ABOUTME: Assembles captured stop-motion frames into a single silent video
// ABOUTME: Thin wrapper over pro_video_editor's renderStopMotionToFile

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Encodes a sequence of captured stop-motion stills into one silent video.
class StopMotionRenderService {
  StopMotionRenderService._();

  static const _logName = 'StopMotionRenderService';

  /// Default number of frames shown per second in the assembled video.
  ///
  /// Each captured still becomes one frame held for 1/[defaultFrameRate]s, so a
  /// sequence of N stills plays as an N/[defaultFrameRate]s stop-motion clip.
  static const double defaultFrameRate = 12;

  /// Test-only override for [assemble].
  ///
  /// When set, [assemble] delegates to this callback instead of running the
  /// real native render. Reset to `null` in `tearDown`.
  @visibleForTesting
  static Future<String?> Function({
    required List<String> framePaths,
    required model.AspectRatio aspectRatio,
    int framesPerShot,
    double frameRate,
  })?
  assembleOverride;

  /// Assembles [framePaths] (captured JPEG stills, in order) into a single
  /// silent mp4 using pro_video_editor's stop-motion encoder.
  ///
  /// [aspectRatio] sets the output resolution and a centered crop
  /// ([StopMotionFit.cover]). [framesPerShot] holds each still for that many
  /// output frames (the 1–10 "frames per shot" control).
  ///
  /// Returns the output file path, or null if rendering failed or was
  /// cancelled. The native render path needs a device build to exercise.
  static Future<String?> assemble({
    required List<String> framePaths,
    required model.AspectRatio aspectRatio,
    int framesPerShot = 1,
    double frameRate = defaultFrameRate,
  }) async {
    final override = assembleOverride;
    if (override != null) {
      return override(
        framePaths: framePaths,
        aspectRatio: aspectRatio,
        framesPerShot: framesPerShot,
        frameRate: frameRate,
      );
    }

    if (framePaths.isEmpty) return null;

    return _renderToFile(
      framePaths: framePaths,
      aspectRatio: aspectRatio,
      framesPerShot: framesPerShot,
      frameRate: frameRate,
    );
  }

  /// Renders [clip]'s stop-motion frames into an mp4 and returns a video-backed
  /// copy of the clip. Returns [clip] unchanged when it is already a normal
  /// video clip.
  ///
  /// Returns `null` only when the render fails, so callers (publish, gallery
  /// save) can surface a failure instead of proceeding with a clip that has no
  /// playable video.
  static Future<DivineVideoClip?> materialize(DivineVideoClip clip) async {
    // Already has a rendered video (stop-motion clips are rendered at capture);
    // nothing to do. Frames-only clips (no video) are rendered on demand.
    if (clip.video != null) return clip;

    final frames = clip.stopMotionFrames;
    if (frames == null) return clip;

    final outputPath = await assemble(
      framePaths: [for (final frame in frames) frame.path],
      aspectRatio: clip.targetAspectRatio,
    );
    if (outputPath == null) return null;
    return clip.copyWith(video: EditorVideo.file(outputPath));
  }

  /// Repeats [framePaths] an integer number of times until the sequence's total
  /// duration (each frame held for [perFrame]) reaches
  /// [VideoEditorConstants.stopMotionMinOutputDuration].
  ///
  /// Ultra-short clips (a single still ≈ 83ms) make looping players
  /// stutter/oscillate; repeating preserves the per-frame timing and keeps the
  /// loop seam clean (last frame → first frame). A sequence already at or above
  /// the minimum is returned unchanged.
  static List<String> framesForMinOutputDuration(
    List<String> framePaths,
    Duration perFrame,
  ) {
    if (framePaths.isEmpty) return framePaths;
    final singlePass = perFrame * framePaths.length;
    const minDuration = VideoEditorConstants.stopMotionMinOutputDuration;
    final loops = singlePass >= minDuration || singlePass == Duration.zero
        ? 1
        : (minDuration.inMicroseconds / singlePass.inMicroseconds).ceil();
    return [for (var i = 0; i < loops; i++) ...framePaths];
  }

  static Future<String?> _renderToFile({
    required List<String> framePaths,
    required model.AspectRatio aspectRatio,
    required int framesPerShot,
    required double frameRate,
  }) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = path.join(
      outputDir.path,
      'stop_motion_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    final perFrame = Duration(
      microseconds: (framesPerShot * Duration.microsecondsPerSecond / frameRate)
          .round(),
    );

    final renderedPaths = framesForMinOutputDuration(framePaths, perFrame);

    final data = StopMotionRenderData(
      frames: [
        for (final framePath in renderedPaths)
          StopMotionFrame(
            image: EditorLayerImage.file(framePath),
            duration: perFrame,
          ),
      ],
      frameRate: frameRate,
      resolution: VideoEditorConstants.quality.resolutionForAspectRatio(
        aspectRatio,
      ),
      fit: StopMotionFit.cover,
    );

    try {
      Log.debug(
        '🎞️ Assembling ${framePaths.length} stop-motion frame(s) '
        '(framesPerShot: $framesPerShot, fps: $frameRate)',
        name: _logName,
        category: LogCategory.video,
      );
      final result = await ProVideoEditor.instance.renderStopMotionToFile(
        outputPath,
        data,
        nativeLogLevel: NativeLogLevel.warning,
      );
      Log.info(
        '✅ Stop-motion video assembled to: $result',
        name: _logName,
        category: LogCategory.video,
      );
      return result;
    } on RenderCanceledException {
      Log.info(
        '🚫 Stop-motion assembly cancelled',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    } catch (e) {
      Log.error(
        '❌ Stop-motion assembly failed: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }
}
