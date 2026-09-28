import 'dart:async';

import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_fixtures.dart';

class _Catalog implements MediaCatalog {
  final requests =
      <({String query, String? cursor, Completer<MediaPage> result})>[];
  @override
  List<String> get categories => [];
  @override
  Future<MediaPage> search({
    String query = '',
    String? category,
    String? cursor,
    int limit = 40,
  }) {
    final result = Completer<MediaPage>();
    requests.add((query: query, cursor: cursor, result: result));
    return result.future;
  }
}

void main() {
  test('late searches and pages cannot overwrite newer results', () async {
    final catalog = _Catalog();
    final controller = MediaCatalogController(catalog);
    final old = controller.search(query: 'old');
    final next = controller.search(query: 'new');
    catalog.requests[1].result.complete(
      MediaPage([fixture(id: 'new')], nextCursor: '1'),
    );
    await next;
    catalog.requests[0].result.complete(MediaPage([fixture(id: 'old')]));
    await old;
    expect(controller.items.single.id, 'new');
    final page = controller.loadMore();
    final newest = controller.search(query: 'latest');
    catalog.requests[3].result.complete(MediaPage([fixture(id: 'latest')]));
    await newest;
    catalog.requests[2].result.completeError(StateError('late failure'));
    await page;
    expect(controller.items.single.id, 'latest');
    expect(controller.error, isNull);
    controller.dispose();
  });

  test(
    'deduplicates pages, suppresses concurrent pagination and keeps data on error',
    () async {
      final catalog = _Catalog();
      final controller = MediaCatalogController(catalog);
      final first = controller.search();
      catalog.requests[0].result.complete(
        MediaPage([fixture(id: 'a')], nextCursor: '1'),
      );
      await first;
      final page = controller.loadMore();
      await controller.loadMore();
      expect(catalog.requests.length, 2);
      catalog.requests[1].result.complete(
        MediaPage([fixture(id: 'a'), fixture(id: 'b')], nextCursor: '2'),
      );
      await page;
      expect(controller.items.map((e) => e.id), ['a', 'b']);
      final fail = controller.loadMore();
      catalog.requests[2].result.completeError(StateError('offline'));
      await fail;
      expect(controller.items.length, 2);
      expect(controller.error, isA<StateError>());
      final retry = controller.retry();
      catalog.requests[3].result.complete(MediaPage([fixture(id: 'c')]));
      await retry;
      expect(controller.items.length, 3);
      expect(controller.hasMore, isFalse);
      controller.dispose();
    },
  );

  test('disposed controller ignores outstanding results', () async {
    final catalog = _Catalog();
    final controller = MediaCatalogController(catalog);
    final pending = controller.search();
    controller.dispose();
    catalog.requests.single.result.complete(MediaPage([fixture()]));
    await pending;
    expect(controller.items, isEmpty);
  });
}
