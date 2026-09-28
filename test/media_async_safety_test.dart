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

  testWidgets('late response cannot replace another item', (tester) async {
    final responses = <String, Completer<ByteData>>{};
    final loader = CachedMediaLoader(
      assetLoader: (path) => (responses[path] ??= Completer<ByteData>()).future,
    );
    Widget host(String id) => MaterialApp(
      home: Center(
        child: AnimatedMedia(
          item: fixture(id: id, source: MediaSource.asset(id)),
          loader: loader,
          semanticLabel: id,
          maxCycles: 1,
        ),
      ),
    );
    await tester.pumpWidget(host('old'));
    await tester.pump();
    await tester.pumpWidget(host('new'));
    await tester.pump();
    responses['new']!.complete(ByteData.sublistView(pulseBytes));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(Lottie), findsOneWidget);
    final composition = tester.widget<Lottie>(find.byType(Lottie)).composition;
    responses['old']!.complete(ByteData.sublistView(Uint8List.fromList([0])));
    await tester.pump();
    expect(
      tester.widget<Lottie>(find.byType(Lottie)).composition,
      same(composition),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'custom preview appears while main file is pending and stays static',
    (tester) async {
      final pending = Completer<ByteData>();
      final loader = CachedMediaLoader(assetLoader: (_) => pending.future);
      final item = fixture(
        source: const MediaSource.asset('pending'),
      ).copyWith(preview: MediaSource.memory('preview', colorGif));
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AnimatedMedia(item: item, loader: loader),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(RawImage), findsOneWidget);
      final image = tester.widget<RawImage>(find.byType(RawImage)).image;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(image));
      pending.complete(ByteData.sublistView(pulseBytes));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(Lottie), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('disabled emoji animations do not download artwork', (
    tester,
  ) async {
    final loader = FakeMediaLoader();
    await tester.pumpWidget(
      MaterialApp(home: AnimatedEmoji('😀', animate: false, loader: loader)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(loader.calls, 0);
    expect(find.text('😀'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
