import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_animated_media/src/playback/lottie_composition_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'support/media_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List variant(int index) => Uint8List.fromList([
    ...pulseBytes,
    ...List.filled(index, 32),
  ]).asUnmodifiableView();

  test('the native background decoder rejects corrupt content', () async {
    final cache = LottieCompositionCache();
    await expectLater(
      cache.decode(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<Exception>()),
    );
    final valid = await cache.decode(pulseBytes);
    expect(valid.duration, greaterThan(Duration.zero));
  });

  test(
    'cold decoding is serialized and identical content is deduplicated',
    () async {
      final results = <Completer<LottieComposition>>[];
      var active = 0;
      var maximumActive = 0;
      final cache = LottieCompositionCache(
        decoder: (_) async {
          active++;
          if (active > maximumActive) maximumActive = active;
          final result = Completer<LottieComposition>();
          results.add(result);
          try {
            return await result.future;
          } finally {
            active--;
          }
        },
      );
      final first = cache.decode(variant(1));
      final duplicate = cache.decode(variant(1));
      final second = cache.decode(variant(2));
      await Future<void>.delayed(Duration.zero);
      expect(results.length, 1);
      final composition = LottieComposition.parseJsonBytes(pulseBytes);
      results.first.complete(composition);
      expect(await first, same(composition));
      expect(await duplicate, same(composition));
      await Future<void>.delayed(Duration.zero);
      expect(results.length, 2);
      results.last.complete(composition);
      await second;
      expect(maximumActive, 1);
      await cache.decode(variant(2));
      expect(results.length, 2);
    },
  );

  test('a decode failure releases the queue and can be retried', () async {
    var calls = 0;
    final cache = LottieCompositionCache(
      decoder: (_) async {
        if (++calls == 1) throw const FormatException('Invalid fixture');
        return LottieComposition.parseJsonBytes(pulseBytes);
      },
    );
    final first = cache.decode(variant(1));
    final next = cache.decode(variant(2));
    await expectLater(first, throwsFormatException);
    await next;
    await cache.decode(variant(1));
    expect(calls, 3);
  });

  test(
    'decoded compositions retain the existing bounded LRU behavior',
    () async {
      var calls = 0;
      final composition = LottieComposition.parseJsonBytes(pulseBytes);
      final cache = LottieCompositionCache(
        decoder: (_) async {
          calls++;
          return composition;
        },
      );
      for (var i = 0; i < 25; i++) {
        await cache.decode(variant(i));
      }
      await cache.decode(variant(24));
      expect(calls, 25);
      await cache.decode(variant(0));
      expect(calls, 26);
      cache.clear();
      await cache.decode(variant(0));
      expect(calls, 27);
    },
  );

  test('clear during decoding does not repopulate the cache', () async {
    var calls = 0;
    final pending = Completer<LottieComposition>();
    final composition = LottieComposition.parseJsonBytes(pulseBytes);
    final cache = LottieCompositionCache(
      decoder: (_) async => ++calls == 1 ? pending.future : composition,
    );
    final first = cache.decode(pulseBytes);
    await Future<void>.delayed(Duration.zero);
    cache.clear();
    pending.complete(composition);
    await first;
    await cache.decode(pulseBytes);
    expect(calls, 2);
  });
}
