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

  Widget host(Widget child, {bool reduced = false, bool ticker = true}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: ticker,
            child: Center(child: child),
          ),
        ),
      );

  Future<void> flushLoad(WidgetTester tester) async {
    for (var i = 0; i < 20 && find.byType(Lottie).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(find.byType(Lottie), findsOneWidget);
    // Establish the first transition tick without advancing its playhead.
    await tester.pump();
  }

  double opacityOf(WidgetTester tester, Finder child) => tester
      .widget<FadeTransition>(
        find.ancestor(of: child, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  testWidgets('loaded emoji cross-fades without resizing or restarting', (
    tester,
  ) async {
    final pending = Completer<ByteData>();
    final loader = CachedMediaLoader(assetLoader: (_) => pending.future);
    Widget view() => host(AnimatedEmoji('😀', loader: loader, size: 64));
    await tester.pumpWidget(view());
    await tester.pump(const Duration(milliseconds: 1));
    final size = tester.getSize(find.byType(AnimatedMedia));
    expect(find.text('😀'), findsOneWidget);
    expect(find.byType(Lottie), findsNothing);

    pending.complete(ByteData.sublistView(pulseBytes));
    await flushLoad(tester);
    expect(opacityOf(tester, find.byType(Lottie)), 0);
    expect(opacityOf(tester, find.text('😀')), 1);
    await tester.pump(const Duration(milliseconds: 90));
    final halfway = opacityOf(tester, find.byType(Lottie));
    expect(halfway, closeTo(0.5, 0.02));
    expect(opacityOf(tester, find.text('😀')), closeTo(0.5, 0.02));
    expect(tester.getSize(find.byType(AnimatedMedia)), size);
    expect(size, const Size(64, 64));

    await tester.pumpWidget(view());
    expect(opacityOf(tester, find.byType(Lottie)), halfway);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(opacityOf(tester, find.byType(Lottie)), 1);
    expect(find.text('😀'), findsNothing);
    expect(tester.getSize(find.byType(AnimatedMedia)), size);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a remounted emoji also fades when its bytes are cached', (
    tester,
  ) async {
    var loads = 0;
    final loader = CachedMediaLoader(
      assetLoader: (_) async {
        loads++;
        return ByteData.sublistView(pulseBytes);
      },
    );
    for (var visit = 0; visit < 2; visit++) {
      await tester.pumpWidget(host(AnimatedEmoji('😀', loader: loader)));
      await flushLoad(tester);
      expect(opacityOf(tester, find.byType(Lottie)), 0);
      await tester.pump(const Duration(milliseconds: 90));
      expect(opacityOf(tester, find.byType(Lottie)), closeTo(0.5, 0.02));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    expect(loads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fade honors disabled animations and a zero duration', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    for (final mode in ['reduced', 'disabled', 'zero']) {
      await tester.pumpWidget(
        host(
          AnimatedMedia(
            item: fixture(),
            loader: loader,
            animate: mode != 'disabled',
            fadeDuration: mode == 'zero'
                ? Duration.zero
                : const Duration(milliseconds: 180),
            placeholder: const Text('Placeholder'),
          ),
          reduced: mode == 'reduced',
        ),
      );
      await flushLoad(tester);
      expect(opacityOf(tester, find.byType(Lottie)), 1);
      expect(find.text('Placeholder'), findsNothing);
      if (mode != 'zero') expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets('enabling reduced motion completes an in-progress fade', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    Widget view({bool reduced = false}) => host(
      AnimatedMedia(
        item: fixture(),
        loader: loader,
        placeholder: const Text('Placeholder'),
      ),
      reduced: reduced,
    );
    await tester.pumpWidget(view());
    await flushLoad(tester);
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacityOf(tester, find.byType(Lottie)), closeTo(0.5, 0.02));
    await tester.pumpWidget(view(reduced: true));
    expect(opacityOf(tester, find.byType(Lottie)), 1);
    expect(find.text('Placeholder'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    expect(loader.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fade tickers stop in background and under disabled TickerMode', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    Widget view({bool ticker = true}) => host(
      AnimatedMedia(item: fixture(), loader: loader),
      ticker: ticker,
    );
    await tester.pumpWidget(view());
    await flushLoad(tester);
    await tester.pump(const Duration(milliseconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(view(ticker: false));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
