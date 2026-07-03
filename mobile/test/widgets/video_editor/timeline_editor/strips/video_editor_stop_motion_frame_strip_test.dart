import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_stop_motion_frame_strip.dart';

void main() {
  // 1x1 transparent PNG.
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M8AAAMBAQDJ/IY1AAAAAElFTkSuQmCC',
  );

  late Directory tempDir;
  late List<StopMotionClipFrame> frames;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('frame_strip_test');
    frames = [
      for (final name in ['a', 'b', 'c'])
        StopMotionClipFrame(
          path: (File(
            '${tempDir.path}/$name.png',
          )..writeAsBytesSync(pngBytes)).path,
          // 0.5s each → wide, easily tappable tiles at the test pps.
          duration: const Duration(milliseconds: 500),
        ),
    ];
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<int> onFrameTapped,
    int? selectedFrameIndex,
    bool isMultiSelectMode = false,
    Set<int> selectedFrameIndexes = const {},
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: VideoEditorStopMotionFrameStrip(
              frames: frames,
              pixelsPerSecond: 100,
              selectedFrameIndex: selectedFrameIndex,
              isMultiSelectMode: isMultiSelectMode,
              selectedFrameIndexes: selectedFrameIndexes,
              onFrameTapped: onFrameTapped,
              onReorder: (_, _) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders one tile per captured still', (tester) async {
    await pump(tester, onFrameTapped: (_) {});
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('renders duplicated stills without a key collision', (
    tester,
  ) async {
    // Duplicating a still reuses its file path; sibling tile keys must stay
    // unique or the Stack throws "duplicate keys found".
    frames = [...frames, frames[1]];
    await pump(tester, onFrameTapped: (_) {});

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNWidgets(4));
  });

  testWidgets('tapping a tile reports its index', (tester) async {
    int? tapped;
    await pump(tester, onFrameTapped: (index) => tapped = index);

    await tester.tap(find.byType(Image).at(1));
    expect(tapped, 1);
  });

  testWidgets('marks the selected tile via semantics', (tester) async {
    await pump(tester, onFrameTapped: (_) {}, selectedFrameIndex: 2);

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          l10n.videoEditorStopMotionFrameSemanticLabel(3, 3),
        ),
      ),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('selected tile paints a visible accent-yellow border', (
    tester,
  ) async {
    await pump(tester, onFrameTapped: (_) {}, selectedFrameIndex: 1);

    final selectedBoxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.border is Border &&
              (decoration.border! as Border).top.color ==
                  VineTheme.accentYellow;
        })
        .toList();

    expect(selectedBoxes, hasLength(1));
    // Foreground position — a background border would be painted underneath
    // the image that fills the same box and never be visible.
    expect(selectedBoxes.single.position, DecorationPosition.foreground);
    expect(
      ((selectedBoxes.single.decoration as BoxDecoration).border! as Border)
          .top
          .width,
      2,
    );
  });

  testWidgets('multi-select highlights every selected tile', (tester) async {
    await pump(
      tester,
      onFrameTapped: (_) {},
      isMultiSelectMode: true,
      selectedFrameIndexes: {0, 2},
    );

    final selectedBoxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.border is Border &&
              (decoration.border! as Border).top.color ==
                  VineTheme.accentYellow;
        });

    expect(selectedBoxes, hasLength(2));
  });

  testWidgets('multi-select taps still report the tile index', (tester) async {
    int? tapped;
    await pump(
      tester,
      onFrameTapped: (index) => tapped = index,
      isMultiSelectMode: true,
    );

    await tester.tap(find.byType(Image).at(2));
    expect(tapped, 2);
  });
}
