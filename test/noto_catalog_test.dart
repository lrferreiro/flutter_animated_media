import 'dart:convert';
import 'dart:io';

import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_animated_media/src/playback/lottie_composition_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_fixtures.dart';

void main() {
  final catalog = NotoEmojiCatalog.instance;

  test('real pinned Noto assets decode with the selected renderer', () async {
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final dependency = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['name'] == 'animated_emoji');
    final root = configFile.absolute.uri.resolve(
      '${dependency['rootUri'].toString().replaceFirst(RegExp(r'/$'), '')}/',
    );
    final library = root.resolve(dependency['packageUri'] as String);
    for (final glyph in ['😀', '❤️', '👍🏽', '🚀', '🔥']) {
      final item = catalog.resolve(glyph)!;
      final uri = library.resolve(
        item.source.identity.replaceFirst('packages/animated_emoji/', ''),
      );
      final bytes = await File.fromUri(uri).readAsBytes();
      final composition = await LottieCompositionCache.instance.decode(bytes);
      expect(composition.duration, greaterThan(Duration.zero));
    }
  });

  test('indexes base and skin-tone variants without losing tone', () {
    expect(catalog.items.length, greaterThan(609));
    expect(catalog.resolve('👍')?.id, '1f44d');
    expect(catalog.resolve('👍🏽')?.id, '1f44d_1f3fd');
    expect(catalog.resolve('👍🏿')?.unicode, '👍🏿');
    expect(
      catalog.resolve('👍🏽')?.source.identity,
      contains('thumbsUpMedium'),
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
