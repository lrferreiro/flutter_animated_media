import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/media_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deduplicates concurrent requests and keeps immutable bytes', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final loader = CachedMediaLoader(
      clientFactory: () => MockClient((_) {
        calls++;
        return response.future;
      }),
    );
    final item = fixture(
      source: MediaSource.network(Uri.parse('https://example.org/a')),
    );
    final a = loader.load(item);
    final b = loader.load(item);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    response.complete(http.Response.bytes([1, 2, 3], 200));
    expect(await a, [1, 2, 3]);
    expect(await b, [1, 2, 3]);
    final cached = await loader.load(item);
    expect(calls, 1);
    expect(() => cached[0] = 9, throwsUnsupportedError);
  });

  test('memory eviction is bounded and expiration reloads', () async {
    var now = DateTime(2026);
    var calls = 0;
    final loader = CachedMediaLoader(
      maxMemoryBytes: 4,
      ttl: const Duration(seconds: 1),
      clock: () => now,
      assetLoader: (_) async {
        calls++;
        return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
      },
    );
    final a = fixture(source: const MediaSource.asset('a'));
    final b = fixture(id: 'b', source: const MediaSource.asset('b'));
    await loader.load(a);
    await loader.load(b);
    expect(loader.memoryBytes, 3);
    await loader.load(a);
    expect(calls, 3);
    now = now.add(const Duration(seconds: 2));
    await loader.load(a);
    expect(calls, 4);
  });

  test(
    'clearing during an in-flight download cannot repopulate memory',
    () async {
      final result = Completer<http.Response>();
      final loader = CachedMediaLoader(
        clientFactory: () => MockClient((_) => result.future),
      );
      final pending = loader.load(
        fixture(
          source: MediaSource.network(Uri.parse('https://example.org/a')),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await loader.clear();
      result.complete(http.Response.bytes([1], 200));
      expect(await pending, [1]);
      expect(loader.memoryBytes, 0);
      expect(loader.pendingLoads, 0);
    },
  );

  test(
    'bounded retries distinguish transient errors from missing media',
    () async {
      var calls = 0;
      final item = fixture(
        source: MediaSource.network(Uri.parse('https://example.org/a')),
      );
      final transient = CachedMediaLoader(
        clientFactory: () => MockClient((_) async {
          calls++;
          return http.Response.bytes([1], calls == 1 ? 503 : 200);
        }),
      );
      expect(await transient.load(item), [1]);
      expect(calls, 2);
      calls = 0;
      final missing = CachedMediaLoader(
        clientFactory: () => MockClient((_) async {
          calls++;
          return http.Response('', 404);
        }),
      );
      await expectLater(missing.load(item), throwsStateError);
      expect(calls, 1);
    },
  );

  test('enforces file limits and timeouts', () async {
    final item = fixture(
      source: MediaSource.network(Uri.parse('https://example.org/a')),
    );
    final large = CachedMediaLoader(
      maxFileBytes: 2,
      clientFactory: () =>
          MockClient((_) async => http.Response.bytes([1, 2, 3], 200)),
    );
    await expectLater(large.load(item), throwsFormatException);
    final slow = CachedMediaLoader(
      retries: 0,
      timeout: const Duration(milliseconds: 10),
      clientFactory: () => MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(slow.load(item), throwsA(isA<TimeoutException>()));
    expect(slow.pendingLoads, 0);
  });

  test(
    'prefers declared local assets and uses configured remote fallback',
    () async {
      var remote = 0;
      final loader = CachedMediaLoader(
        assetLoader: (path) async {
          if (path == 'local') {
            return ByteData.sublistView(Uint8List.fromList([7]));
          }
          throw StateError('not bundled');
        },
        clientFactory: () => MockClient((_) async {
          remote++;
          return http.Response.bytes([9], 200);
        }),
      );
      expect(
        await loader.load(fixture(source: const MediaSource.asset('local'))),
        [7],
      );
      expect(remote, 0);
      expect(
        await loader.load(
          fixture(
            source: MediaSource.asset(
              'missing',
              fallbackUri: Uri.parse('https://example.org/a'),
            ),
          ),
        ),
        [9],
      );
      expect(remote, 1);
    },
  );

  group('persistent store', () {
    late Directory root;
    late MediaByteStore store;
    var now = DateTime(2026);
    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'animated-media-cache-test-',
      );
      now = DateTime(2026);
      store = createPersistentMediaStore(
        maxBytes: 100,
        cacheRoot: () async => root.path,
        clock: () => now,
      )!;
    });
    tearDown(() async {
      await root.delete(recursive: true);
    });

    test('expiry is not extended on cache hits', () async {
      final item = fixture();
      final expiry = now.add(const Duration(seconds: 2));
      await store.write(item.cacheKey, Uint8List.fromList([1]), expiry);
      final loader = CachedMediaLoader(store: store, clock: () => now);
      expect(await loader.load(item), [1]);
      expect((await store.read(item.cacheKey))!.expiresAt, expiry);
      now = now.add(const Duration(seconds: 3));
      expect(await store.read(item.cacheKey), isNull);
    });

    test(
      'storage eviction is bounded, corruption discarded, clear scoped',
      () async {
        await store.write(
          'a',
          Uint8List.fromList([1, 2, 3]),
          now.add(const Duration(days: 1)),
        );
        now = now.add(const Duration(seconds: 1));
        await store.write(
          'b',
          Uint8List.fromList([1, 2, 3]),
          now.add(const Duration(days: 1)),
        );
        now = now.add(const Duration(seconds: 1));
        await store.write(
          'c',
          Uint8List.fromList([1, 2, 3]),
          now.add(const Duration(days: 1)),
        );
        expect(await store.read('a'), isNull);
        final directory = Directory('${root.path}/flutter_animated_media_v1');
        final files = await directory
            .list()
            .where((e) => e is File)
            .cast<File>()
            .toList();
        expect(files.length, 2);
        for (final file in files) {
          await file.writeAsBytes([1, 2]);
        }
        expect(await store.read('b'), isNull);
        expect(await store.read('c'), isNull);
        final unrelated = File('${root.path}/keep.txt');
        await unrelated.writeAsString('keep');
        await store.clear();
        expect(await unrelated.readAsString(), 'keep');
      },
    );
  });
}
