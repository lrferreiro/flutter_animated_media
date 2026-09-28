import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'support/media_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmFixtureComposition);
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('new visible emojis wait for scrolling to stop and then resume', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 800),
            for (final emoji in ['😀', '❤️', '👍🏽'])
              AnimatedEmoji(emoji, loader: loader),
            const SizedBox(height: 1000),
          ],
        ),
      ),
    );
    await flush(tester);
    expect(loader.calls, 0);
    final drag = await tester.startGesture(const Offset(400, 500));
    await drag.moveBy(const Offset(0, -600));
    await flush(tester);
    expect(scroll.position.isScrollingNotifier.value, isTrue);
    expect(find.byType(AnimatedEmoji), findsNWidgets(3));
    expect(loader.calls, 0);
    expect(find.byType(Lottie), findsNothing);

    await drag.up();
    scroll.jumpTo(scroll.offset);
    await flush(tester);
    expect(find.byType(Lottie), findsNWidgets(3));
    expect(loader.calls, 3);

    final secondDrag = await tester.startGesture(const Offset(400, 300));
    await secondDrag.moveBy(const Offset(0, -30));
    await tester.pump();
    final frames = tester
        .widgetList<Lottie>(find.byType(Lottie))
        .map((view) => view.controller!.value)
        .toList();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widgetList<Lottie>(find.byType(Lottie))
          .map((view) => view.controller!.value)
          .toList(),
      frames,
    );
    await secondDrag.up();
    scroll.jumpTo(scroll.offset);
    await flush(tester);
    expect(loader.calls, 3);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    scroll.dispose();
  });

  testWidgets('an in-flight response does not mount a drawable during a drag', (
    tester,
  ) async {
    final response = Completer<ByteData>();
    final loader = CachedMediaLoader(assetLoader: (_) => response.future);
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 100),
            AnimatedEmoji('😀', loader: loader),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    await flush(tester);
    final drag = await tester.startGesture(const Offset(400, 500));
    await drag.moveBy(const Offset(0, -40));
    await tester.pump();
    response.complete(ByteData.sublistView(pulseBytes));
    await flush(tester);
    expect(find.byType(Lottie), findsNothing);
    expect(find.text('😀'), findsOneWidget);
    await drag.up();
    scroll.jumpTo(scroll.offset);
    await flush(tester);
    expect(find.byType(Lottie), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    scroll.dispose();
  });

  testWidgets('animation ticks do not rebuild the Lottie widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: AnimatedEmoji('😀', loader: FakeMediaLoader())),
      ),
    );
    await flush(tester);
    final view = tester.widget<Lottie>(find.byType(Lottie));
    final progress = view.controller!.value;
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<Lottie>(find.byType(Lottie)), same(view));
    expect(view.controller!.value, greaterThan(progress));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('completed emojis keep their resting frame when a drag starts', (
    tester,
  ) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 100),
            AnimatedEmoji('😀', loader: FakeMediaLoader(), maxCycles: 1),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    await flush(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final resting = tester
        .widget<Lottie>(find.byType(Lottie))
        .controller!
        .value;
    expect(resting, closeTo(0.5, 0.01));
    final drag = await tester.startGesture(const Offset(400, 500));
    await drag.moveBy(const Offset(0, -40));
    await flush(tester);
    expect(
      tester.widget<Lottie>(find.byType(Lottie)).controller!.value,
      resting,
    );
    await drag.up();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    scroll.dispose();
  });

  testWidgets('disposing a response waiting for idle releases its listener', (
    tester,
  ) async {
    final response = Completer<ByteData>();
    final loader = CachedMediaLoader(assetLoader: (_) => response.future);
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 100),
            AnimatedEmoji('😀', loader: loader),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    await flush(tester);
    final drag = await tester.startGesture(const Offset(400, 500));
    await drag.moveBy(const Offset(0, -40));
    response.complete(ByteData.sublistView(pulseBytes));
    await flush(tester);
    await tester.pumpWidget(const SizedBox());
    await drag.up();
    await tester.pump();
    scroll.dispose();
    expect(tester.takeException(), isNull);
  });
}
