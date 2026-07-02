import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip clip(String videoPath) => DivineVideoClip(
    id: 'c1',
    video: editor.EditorVideo.file(File(videoPath)),
    duration: const Duration(seconds: 5),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
  );

  DivineVideoClip stopMotionClip(List<String> framePaths) => DivineVideoClip(
    id: 'sm1',
    stopMotionFrames: [
      for (final path in framePaths)
        StopMotionClipFrame(
          path: path,
          duration: const Duration(milliseconds: 83),
        ),
    ],
    duration: Duration(milliseconds: 83 * framePaths.length),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );

  group('DivineVideoClip.hasResolvableVideoFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('divine_video_clip_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('is true when the source video file exists on disk', () async {
      final path = '${tempDir.path}/clip.mp4';
      await File(path).writeAsBytes(const [0]);

      expect(clip(path).hasResolvableVideoFile, isTrue);
    });

    test('is false when the source video file is missing', () {
      expect(
        clip('${tempDir.path}/deleted.mp4').hasResolvableVideoFile,
        isFalse,
      );
    });

    test('is true for a stop-motion clip whose stills all exist', () async {
      final a = '${tempDir.path}/f0.jpg';
      final b = '${tempDir.path}/f1.jpg';
      await File(a).writeAsBytes(const [0]);
      await File(b).writeAsBytes(const [0]);

      expect(stopMotionClip([a, b]).hasResolvableVideoFile, isTrue);
    });

    test('is false for a stop-motion clip with a missing still', () async {
      final a = '${tempDir.path}/f0.jpg';
      await File(a).writeAsBytes(const [0]);

      expect(
        stopMotionClip([a, '${tempDir.path}/gone.jpg']).hasResolvableVideoFile,
        isFalse,
      );
    });
  });
}
