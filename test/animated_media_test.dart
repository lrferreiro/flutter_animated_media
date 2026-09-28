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

  Future<void> settleLoad(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> disposeView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

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

  testWidgets('single emoji keeps a fixed box from fallback through playback', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    await tester.pumpWidget(
      host(AnimatedEmoji('👍🏽', loader: loader, size: 48)),
    );
    expect(find.text('👍🏽'), findsOneWidget);
    final initialSize = tester.getSize(find.byType(AnimatedMedia));
    await settleLoad(tester);
    expect(find.byType(Lottie), findsOneWidget);
    expect(tester.getSize(find.byType(AnimatedMedia)), initialSize);
    expect(initialSize, const Size(48, 48));
    expect(loader.calls, 1);
    await disposeView(tester);
  });

  testWidgets('unsupported and text-presentation emojis never load', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    for (final value in ['👨‍👩‍👧‍👦', '❤\uFE0E', '😀😀', 'hello 😀']) {
      await tester.pumpWidget(host(AnimatedEmoji(value, loader: loader)));
      await settleLoad(tester);
      expect(find.text(value), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
    }
    expect(loader.calls, 0);
    await disposeView(tester);
  });

  testWidgets('load errors evict content and retain the original glyph', (
    tester,
  ) async {
    final loader = FakeMediaLoader(
      error: const FormatException('Invalid media'),
    );
    await tester.pumpWidget(host(AnimatedEmoji('😀', loader: loader)));
    await settleLoad(tester);
    expect(find.text('😀'), findsOneWidget);
    expect(tester.getSize(find.byType(AnimatedMedia)), const Size(48, 48));
    expect(loader.evictions, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(loader.calls, 1);
    await disposeView(tester);
  });

  testWidgets('ordinary parent rebuilds do not reload or restart', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    Widget view() => host(AnimatedMedia(item: fixture(), loader: loader));
    await tester.pumpWidget(view());
    await settleLoad(tester);
    await tester.pump(const Duration(milliseconds: 80));
    final before = tester.widget<Lottie>(find.byType(Lottie)).controller!.value;
    await tester.pumpWidget(view());
    final after = tester.widget<Lottie>(find.byType(Lottie)).controller!.value;
    expect(after, closeTo(before, 0.05));
    expect(loader.calls, 1);
    await disposeView(tester);
  });

  testWidgets('pause, accessibility, TickerMode and lifecycle stop ticking', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    final controller = MediaPlaybackController();
    Widget view({bool reduced = false, bool ticker = true}) => host(
      AnimatedMedia(item: fixture(), loader: loader, controller: controller),
      reduced: reduced,
      ticker: ticker,
    );
    await tester.pumpWidget(view());
    await settleLoad(tester);
    controller.pause();
    await tester.pump();
    final paused = tester.widget<Lottie>(find.byType(Lottie)).controller!.value;
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<Lottie>(find.byType(Lottie)).controller!.value,
      paused,
    );
    expect(
      paused,
      closeTo(0.5, 0.01),
      reason: 'Noto-style rest marker is used',
    );
    controller.play();
    await tester.pumpWidget(view(reduced: true));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(view(ticker: false));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(view());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await disposeView(tester);
    controller.dispose();
  });

  testWidgets(
    'offscreen items neither load nor animate; scroll restores visibility',
    (tester) async {
      final loader = FakeMediaLoader();
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 1000),
              AnimatedMedia(item: fixture(), loader: loader),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await settleLoad(tester);
      expect(loader.calls, 0);
      scroll.jumpTo(1000);
      await settleLoad(tester);
      expect(loader.calls, 1);
      expect(tester.hasRunningAnimations, isTrue);
      scroll.jumpTo(0);
      await settleLoad(tester);
      expect(tester.hasRunningAnimations, isFalse);
      await disposeView(tester);
      scroll.dispose();
    },
  );

  testWidgets('finite cycles end, replay works, no timers survive disposal', (
    tester,
  ) async {
    final playback = MediaPlaybackController();
    await tester.pumpWidget(
      host(
        AnimatedMedia(
          item: fixture(),
          loader: FakeMediaLoader(),
          maxCycles: 1,
          controller: playback,
        ),
      ),
    );
    await settleLoad(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    playback.replay();
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await disposeView(tester);
    playback.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('GIF fixture uses Flutter codec and freezes while paused', (
    tester,
  ) async {
    final playback = MediaPlaybackController();
    final item = fixture().copyWith(format: MediaFormat.gif);
    await tester.pumpWidget(
      host(
        AnimatedMedia(
          item: item,
          loader: FakeMediaLoader(bytes: colorGif),
          controller: playback,
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await settleLoad(tester);
    expect(find.byType(RawImage), findsOneWidget);
    final frame = tester.widget<RawImage>(find.byType(RawImage)).image;
    expect(frame, isNotNull);
    playback.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(frame));
    await disposeView(tester);
    playback.dispose();
  });

  testWidgets(
    'picker selection does not navigate and supports keyboard activation',
    (tester) async {
      MediaItem? selected;
      final catalog = LocalMediaCatalog([fixture(id: 'One')]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMediaPicker(
              catalog: catalog,
              loader: FakeMediaLoader(),
              onSelected: (item) => selected = item,
              emptyBuilder: (_) => const Text('Empty'),
              errorBuilder: (_, error, retry) =>
                  TextButton(onPressed: retry, child: const Text('Retry')),
            ),
          ),
        ),
      );
      await settleLoad(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selected?.id, 'One');
      expect(find.byType(AnimatedMediaPicker), findsOneWidget);
      await disposeView(tester);
    },
  );
}
