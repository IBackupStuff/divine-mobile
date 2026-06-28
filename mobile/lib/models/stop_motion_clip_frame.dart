// ABOUTME: One captured still in a stop-motion clip (image path + hold time)
// ABOUTME: Source-of-truth frame for a frames-based DivineVideoClip

import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;

/// A single captured still in a stop-motion clip, together with how long it is
/// held during playback.
///
/// Deliberately distinct from `pro_video_editor`'s `StopMotionFrame` (which
/// wraps an editor layer image): this is the persisted, source-of-truth frame
/// for a frames-based [DivineVideoClip]. Per-frame [duration] is stored so a
/// future timing editor can vary individual frames; today all frames share the
/// same hold time.
class StopMotionClipFrame {
  const StopMotionClipFrame({required this.path, required this.duration});

  /// Absolute path to the captured JPEG still.
  final String path;

  /// How long this frame is held during playback.
  final Duration duration;

  StopMotionClipFrame copyWith({String? path, Duration? duration}) =>
      StopMotionClipFrame(
        path: path ?? this.path,
        duration: duration ?? this.duration,
      );

  /// Serializes to JSON, storing only the basename for iOS path stability
  /// (mirrors [DivineVideoClip.toJson]).
  Map<String, dynamic> toJson() => {
    'path': p.basename(path),
    'durationMs': duration.inMilliseconds,
  };

  /// Restores a frame, resolving [path] against [documentsPath] the same way
  /// [DivineVideoClip.fromJson] resolves clip file paths.
  factory StopMotionClipFrame.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    return StopMotionClipFrame(
      path: resolvePath(
        json['path'] as String,
        documentsPath,
        useOriginalPath: useOriginalPath,
      )!,
      duration: Duration(milliseconds: json['durationMs'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StopMotionClipFrame &&
      other.path == path &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(path, duration);

  @override
  String toString() => 'StopMotionClipFrame(path: $path, duration: $duration)';
}
