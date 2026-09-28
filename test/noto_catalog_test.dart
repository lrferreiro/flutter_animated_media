import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_animated_media/src/playback/lottie_composition_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = NotoEmojiCatalog.instance;

  test(
    'every bundled Noto JSON matches its snapshot and decodes offline',
    () async {
      final manifest =
          jsonDecode(await File('assets/noto/manifest.json').readAsString())
              as Map<String, dynamic>;
      final entries = {
        for (final entry
            in (manifest['entries'] as List).cast<Map<String, dynamic>>())
          entry['id'] as String: entry,
      };
      expect(manifest['version'], NotoEmojiCatalog.catalogVersion);
      expect(entries.length, 881);
      expect(catalog.items.length, entries.length);
      var networkCalls = 0;
      final loader = CachedMediaLoader(
        clientFactory: () {
          networkCalls++;
          throw StateError('Network is unavailable');
        },
      );
      final compositions = LottieCompositionCache();
      for (final item in catalog.items) {
        final entry = entries[item.id]!;
        final file = entry['lottie'] as Map<String, dynamic>;
        expect(item.source.isAsset, isTrue);
        expect(item.source.fallbackUri, isNull);
        expect(item.source.uri, isNull);
        expect(
          item.source.identity,
          'packages/flutter_animated_media/${file['path']}',
        );
        expect(catalog.resolve(entry['unicode'] as String)?.id, item.id);
        final bytes = await loader.load(item);
        expect(bytes.length, file['bytes'], reason: item.id);
        expect(
          sha256.convert(bytes).toString(),
          file['sha256'],
          reason: item.id,
        );
        final composition = await compositions.decode(bytes);
        expect(
          composition.duration,
          greaterThan(Duration.zero),
          reason: item.id,
        );
      }
      expect(networkCalls, 0);
      await loader.clear();
      compositions.clear();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('missing Noto assets never fall back to a remote provider', () async {
    var networkCalls = 0;
    final loader = CachedMediaLoader(
      assetLoader: (_) async => throw StateError('Missing bundled asset'),
      clientFactory: () {
        networkCalls++;
        throw StateError('Network is unavailable');
      },
    );
    await expectLater(loader.load(catalog.resolve('😀')!), throwsStateError);
    expect(networkCalls, 0);
  });

  test('the package asset manifest declares the entire Noto catalog', () async {
    final assets = await AssetManifest.loadFromAssetBundle(rootBundle);
    final declared = assets.listAssets().toSet();
    for (final item in catalog.items) {
      // Flutter lists an owning package's assets without its package prefix.
      // The consuming-app prefix is verified by the integration tests.
      expect(
        declared,
        contains(
          item.source.identity.replaceFirst(
            'packages/flutter_animated_media/',
            '',
          ),
        ),
      );
    }
  });

  test('indexes base and skin-tone variants without losing tone', () {
    expect(catalog.items.length, greaterThan(609));
    expect(catalog.resolve('👍')?.id, '1f44d');
    expect(catalog.resolve('👍🏽')?.id, '1f44d_1f3fd');
    expect(catalog.resolve('👍🏿')?.unicode, '👍🏿');
    expect(
      catalog.resolve('👍🏽')?.source.identity,
      endsWith('/1f44d_1f3fd.json'),
    );
  });

  test('explicit heart alias but no arbitrary selector stripping', () {
    expect(catalog.resolve('❤')?.id, catalog.resolve('❤️')?.id);
    expect(catalog.resolve('❤\uFE0E'), isNull);
    expect(catalog.resolve('  ❤️  ')?.unicode, '❤️');
  });

  test('preserves supported ZWJ clusters exactly', () {
    final joined = catalog.items.where(
      (item) => item.unicode!.contains('\u200D'),
    );
    expect(joined, isNotEmpty);
    for (final item in joined) {
      expect(catalog.resolve(item.unicode!)?.id, item.id);
    }
    expect(catalog.resolve('👨‍👩‍👧‍👦'), isNull);
  });

  test('flags and keycaps are supported exactly or remain static', () {
    for (final value in ['🇪🇸', '🏳️‍🌈', '1️⃣', '#️⃣']) {
      final resolved = catalog.resolve(value);
      if (resolved != null) expect(resolved.unicode, value);
      expect(catalog.resolve('$value$value'), isNull);
    }
  });

  test('rejects mixed text, multiple emojis and invalid input', () {
    for (final value in [
      '',
      ' ',
      'hello 😀',
      '😀😀',
      'a',
      '\u200D',
      '🏽',
      '1',
    ]) {
      expect(catalog.resolve(value), isNull, reason: value);
    }
  });

  test('cache identity includes variant, source, provider and revision', () {
    final base = fixture();
    expect(base.cacheKey, isNot(base.copyWith(version: '2').cacheKey));
    expect(base.cacheKey, isNot(base.copyWith(provider: 'other').cacheKey));
    expect(base.cacheKey, isNot(base.copyWith(unicode: '👍🏽').cacheKey));
  });

  test('local catalog deduplicates, searches and paginates', () async {
    final first = fixture(
      id: 'blue',
    ).copyWith(categories: ['Shapes'], keywords: ['cool']);
    final second = fixture(id: 'red');
    final local = LocalMediaCatalog([first, second, first]);
    expect(local.items.length, 2);
    expect((await local.search(query: 'COOL')).items.single.id, 'blue');
    expect((await local.search(category: 'Shapes')).items.length, 1);
    final page = await local.search(limit: 1);
    expect(page.nextCursor, '1');
    expect(
      (await local.search(limit: 1, cursor: page.nextCursor)).items.single.id,
      'red',
    );
    expect((await local.search(query: 'missing')).items, isEmpty);
    await expectLater(local.search(cursor: '-1'), throwsArgumentError);
  });
}
