// ABOUTME: Lightweight looping player for a stop-motion clip's captured stills
// ABOUTME: Renders frames directly, avoiding the short-mp4 loop oscillation

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';

/// Plays a stop-motion clip by looping through its captured stills, holding
/// each for its own [StopMotionClipFrame.duration].
///
/// Used wherever a frames-based clip would otherwise be handed to the video
/// player. Rendering the frames directly avoids the stutter/oscillation a
/// looping video player exhibits on ultra-short (≈83ms) clips.
///
/// Honors the platform reduce-motion setting: when animations are disabled it
/// holds the first frame statically.
class StopMotionPlayer extends StatefulWidget {
  const StopMotionPlayer({
    required this.frames,
    this.fit = BoxFit.cover,
    super.key,
  });

  /// The captured stills, in playback order.
  final List<StopMotionClipFrame> frames;

  /// How each frame is inscribed into the player's box.
  final BoxFit fit;

  @override
  State<StopMotionPlayer> createState() => _StopMotionPlayerState();
}

class _StopMotionPlayerState extends State<StopMotionPlayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<int> _frameIndex = ValueNotifier<int>(0);

  /// Cumulative end offset (microseconds) per frame, so the active frame for a
  /// given elapsed time is found with a single forward scan.
  late List<int> _cumulativeEndUs;
  late int _totalUs;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _computeTimeline();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheFrames();
    _syncTicker();
  }

  @override
  void didUpdateWidget(StopMotionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      _computeTimeline();
      _frameIndex.value = 0;
      _precached = false;
      _precacheFrames();
      _syncTicker();
    }
  }

  void _computeTimeline() {
    var acc = 0;
    _cumulativeEndUs = [
      for (final frame in widget.frames) acc += frame.duration.inMicroseconds,
    ];
    _totalUs = acc;
  }

  void _precacheFrames() {
    if (_precached) return;
    _precached = true;
    for (final frame in widget.frames) {
      precacheImage(FileImage(File(frame.path)), context);
    }
  }

  void _syncTicker() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate =
        !reduceMotion && widget.frames.length > 1 && _totalUs > 0;

    if (shouldAnimate && _ticker == null) {
      _ticker = createTicker(_onTick)..start();
    } else if (!shouldAnimate && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
      _frameIndex.value = 0;
    }
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds % _totalUs;
    var index = 0;
    while (index < _cumulativeEndUs.length - 1 &&
        t >= _cumulativeEndUs[index]) {
      index++;
    }
    if (index != _frameIndex.value) _frameIndex.value = index;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frameIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: _frameIndex,
      builder: (context, index, _) => Image.file(
        File(widget.frames[index].path),
        fit: widget.fit,
        gaplessPlayback: true,
      ),
    );
  }
}
