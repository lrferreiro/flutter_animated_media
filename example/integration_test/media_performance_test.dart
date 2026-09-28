import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'widgets/performance_list.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('compare a static emoji list with a warmed animated list', (
    tester,
  ) async {
    final loader = CachedMediaLoader();
    for (final emoji in PerformanceList.emojis) {
      await loader.load(NotoEmojiCatalog.instance.resolve(emoji)!);
    }
    for (final animated in [false, true]) {
      final scroll = ScrollController();
      await tester.pumpWidget(
        PerformanceList(animated: animated, scroll: scroll, loader: loader),
      );
      await tester.pump(const Duration(seconds: 1));
      await binding.watchPerformance(() async {
        for (var i = 0; i < 100; i++) {
          scroll.jumpTo(i * 45.0);
          await tester.pump(const Duration(milliseconds: 32));
        }
      }, reportKey: animated ? 'animated_scroll' : 'static_scroll');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      scroll.dispose();
    }
    binding.reportData!['mode'] = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    debugPrint('MEDIA_PERFORMANCE ${jsonEncode(binding.reportData)}');
    await loader.clear();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
