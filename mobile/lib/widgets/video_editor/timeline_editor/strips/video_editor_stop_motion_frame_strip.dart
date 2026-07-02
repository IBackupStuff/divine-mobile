import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';

/// Timeline strip for a frames-only stop-motion clip: one tile per captured
/// still, laid out by each still's hold duration so the strip stays aligned
/// with the timeline playhead.
///
/// Tapping a tile selects it (via [onFrameTapped]); long-pressing and dragging
/// reorders the stills (via [onReorder]). This widget is presentational — it
/// owns only the drag gesture state; the actual selection and reorder commit
/// live in the caller.
class VideoEditorStopMotionFrameStrip extends StatefulWidget {
  const VideoEditorStopMotionFrameStrip({
    required this.frames,
    required this.pixelsPerSecond,
    required this.onFrameTapped,
    required this.onReorder,
    this.selectedFrameIndex,
    this.scrollController,
    this.onReorderChanged,
    super.key,
  });

  /// The clip's captured stills, in playback order.
  final List<StopMotionClipFrame> frames;

  /// Horizontal pixels per second — the strip's tiles are sized by their hold
  /// duration times this, matching the rest of the timeline geometry.
  final double pixelsPerSecond;

  /// Index of the currently selected still, highlighted with a border.
  final int? selectedFrameIndex;

  /// Called with the tapped still's index.
  final ValueChanged<int> onFrameTapped;

  /// Called when a drag reorder settles, with the still's original and final
  /// indices. A single-item move — [StopMotionFrameOps.reorderFrame] reproduces
  /// it on the source list.
  final void Function(int from, int to) onReorder;

  /// Timeline scroll controller, used to auto-scroll while dragging near an
  /// edge.
  final ScrollController? scrollController;

  /// Reports the start (`true`) and end (`false`) of a reorder drag so the
  /// timeline can fade sibling rows out, matching the clip strip.
  final ValueChanged<bool>? onReorderChanged;

  @override
  State<VideoEditorStopMotionFrameStrip> createState() =>
      _VideoEditorStopMotionFrameStripState();
}

class _VideoEditorStopMotionFrameStripState
    extends State<VideoEditorStopMotionFrameStrip> {
  static const _animDuration = Duration(milliseconds: 200);
  static const _autoScrollEdgeZone = 40.0;
  static const _maxAutoScrollPxPerFrame = 8.0;

  /// Local, live-reordered copy of the stills while a drag is in progress.
  late List<StopMotionClipFrame> _orderedFrames;

  bool _isReordering = false;

  /// Current visual slot of the dragged tile within [_orderedFrames].
  int? _dragIndex;

  /// The dragged still's index in [widget.frames] when the drag began.
  int _dragStartIndex = 0;

  // Finger tracking (global X is the source of truth so auto-scroll and the
  // gesture callbacks never fight over the position).
  double _dragGlobalX = 0;
  double _dragStartGlobalX = 0;
  double _dragStartLocalX = 0;
  double _dragStartScrollOffset = 0;
  double _dragTileWidth = 0;
  double _dragFingerRatio = 0.5;

  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0;

  double get _effectiveLocalX {
    final scrollDelta =
        (widget.scrollController?.offset ?? 0) - _dragStartScrollOffset;
    return _dragGlobalX - _dragStartGlobalX + _dragStartLocalX + scrollDelta;
  }

  @override
  void initState() {
    super.initState();
    _orderedFrames = List.of(widget.frames);
  }

  @override
  void didUpdateWidget(VideoEditorStopMotionFrameStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReordering) _orderedFrames = List.of(widget.frames);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  double _tileWidth(StopMotionClipFrame frame) =>
      frame.duration.inMicroseconds /
      Duration.microsecondsPerSecond *
      widget.pixelsPerSecond;

  ({List<double> widths, List<double> offsets, double total}) _computeLayout() {
    final widths = <double>[];
    final offsets = <double>[];
    var x = 0.0;
    for (final frame in _orderedFrames) {
      final w = _tileWidth(frame);
      widths.add(w);
      offsets.add(x);
      x += w;
    }
    return (widths: widths, offsets: offsets, total: x);
  }

  int _indexAtX(double x, List<double> widths) {
    var acc = 0.0;
    for (var i = 0; i < widths.length; i++) {
      if (x < acc + widths[i] / 2) return i;
      acc += widths[i];
    }
    return widths.length - 1;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.frames.length <= 1) return;

    final layout = _computeLayout();
    final fingerX = details.localPosition.dx;
    final pressedIndex = _indexAtX(fingerX, layout.widths);
    final tileWidth = layout.widths[pressedIndex];
    final tileLeft = layout.offsets[pressedIndex];
    final fingerRatio = tileWidth > 0
        ? ((fingerX - tileLeft) / tileWidth).clamp(0.0, 1.0)
        : 0.5;

    HapticFeedback.mediumImpact();
    widget.onReorderChanged?.call(true);
    setState(() {
      _isReordering = true;
      _dragIndex = pressedIndex;
      _dragStartIndex = pressedIndex;
      _dragGlobalX = details.globalPosition.dx;
      _dragStartGlobalX = details.globalPosition.dx;
      _dragStartLocalX = fingerX;
      _dragStartScrollOffset = widget.scrollController?.offset ?? 0;
      _dragTileWidth = tileWidth;
      _dragFingerRatio = fingerRatio;
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isReordering || _dragIndex == null) return;
    setState(() {
      _dragGlobalX = details.globalPosition.dx;
      _applyDragTarget();
    });
    _updateAutoScroll(details.globalPosition.dx);
  }

  void _applyDragTarget() {
    final widths = _computeLayout().widths;
    final target = _indexAtX(_effectiveLocalX, widths);
    if (target != _dragIndex) {
      HapticFeedback.selectionClick();
      final frame = _orderedFrames.removeAt(_dragIndex!);
      _orderedFrames.insert(target, frame);
      _dragIndex = target;
    }
  }

  void _updateAutoScroll(double globalX) {
    if (widget.scrollController == null) return;
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (globalX < _autoScrollEdgeZone) {
      _autoScrollSpeed =
          -(1 - globalX / _autoScrollEdgeZone) * _maxAutoScrollPxPerFrame;
    } else if (globalX > screenWidth - _autoScrollEdgeZone) {
      _autoScrollSpeed =
          (1 - (screenWidth - globalX) / _autoScrollEdgeZone) *
          _maxAutoScrollPxPerFrame;
    } else {
      _autoScrollSpeed = 0;
    }

    if (_autoScrollSpeed != 0 && _autoScrollTimer == null) {
      _autoScrollTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _tickAutoScroll(),
      );
    } else if (_autoScrollSpeed == 0) {
      _stopAutoScroll();
    }
  }

  void _tickAutoScroll() {
    final sc = widget.scrollController;
    if (sc == null || !_isReordering) {
      _stopAutoScroll();
      return;
    }
    final pos = sc.position;
    final newOffset = (pos.pixels + _autoScrollSpeed).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (newOffset == pos.pixels) return;
    sc.jumpTo(newOffset);
    setState(_applyDragTarget);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollSpeed = 0;
  }

  void _endReorder() {
    if (!_isReordering) return;
    _stopAutoScroll();
    final from = _dragStartIndex;
    final to = _dragIndex ?? from;

    widget.onReorderChanged?.call(false);
    setState(() {
      _isReordering = false;
      _dragIndex = null;
    });

    if (from != to) widget.onReorder(from, to);
  }

  /// Unique per-tile keys. Duplicated stills share a file path, so keying by
  /// path alone collides (Flutter requires unique sibling keys). Disambiguate
  /// by occurrence — duplicates are identical images, so the exact key→tile
  /// mapping among them is visually indistinguishable during reorder.
  List<Key> _tileKeys() {
    final seen = <String, int>{};
    return [
      for (final frame in _orderedFrames)
        ValueKey(
          '${frame.path}#${seen[frame.path] = (seen[frame.path] ?? 0) + 1}',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final layout = _computeLayout();
    final tileKeys = _tileKeys();

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _isReordering ? _onLongPressMoveUpdate : null,
      onLongPressEnd: _isReordering ? (_) => _endReorder() : null,
      onLongPressCancel: _isReordering ? _endReorder : null,
      child: SizedBox(
        width: layout.total,
        height: TimelineConstants.thumbnailStripHeight,
        child: Stack(
          clipBehavior: .none,
          children: [
            for (var i = 0; i < _orderedFrames.length; i++)
              if (i != _dragIndex)
                AnimatedPositioned(
                  key: tileKeys[i],
                  duration: _isReordering ? _animDuration : Duration.zero,
                  curve: Curves.easeInOut,
                  left: layout.offsets[i],
                  top: 0,
                  width: layout.widths[i],
                  height: TimelineConstants.thumbnailStripHeight,
                  child: _FrameTile(
                    frame: _orderedFrames[i],
                    index: i,
                    total: _orderedFrames.length,
                    isSelected:
                        !_isReordering && i == widget.selectedFrameIndex,
                    onTap: _isReordering ? null : () => widget.onFrameTapped(i),
                  ),
                ),
            if (_dragIndex != null)
              Positioned(
                left: _effectiveLocalX - _dragTileWidth * _dragFingerRatio,
                top: 0,
                width: _dragTileWidth,
                height: TimelineConstants.thumbnailStripHeight,
                child: _FrameTile(
                  frame: _orderedFrames[_dragIndex!],
                  index: _dragIndex!,
                  total: _orderedFrames.length,
                  isSelected: true,
                  isDragging: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.frame,
    required this.index,
    required this.total,
    required this.isSelected,
    this.onTap,
    this.isDragging = false,
  });

  final StopMotionClipFrame frame;
  final int index;
  final int total;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TimelineConstants.thumbnailRadius);
    // Decode the still at strip height, not full camera resolution — a 4000px
    // portrait decoded into a 64px tile otherwise wastes ~45 MB per tile.
    final cacheHeight =
        (TimelineConstants.thumbnailStripHeight *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return Semantics(
      button: true,
      selected: isSelected,
      label: context.l10n.videoEditorStopMotionFrameSemanticLabel(
        index + 1,
        total,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isDragging ? 0.85 : 1,
          child: DecoratedBox(
            // Foreground: the image fills the same box, so a background
            // decoration would be painted underneath it and never show.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              // Selected stills use the same accent-yellow highlight as the
              // trim handles on a video clip — just the highlight, no handles.
              border: Border.all(
                color: isSelected
                    ? VineTheme.accentYellow
                    : VineTheme.surfaceBackground,
                width: isSelected ? 2 : 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Image.file(
                File(frame.path),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheHeight: cacheHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
