import '../models/media_item.dart';
import 'media_catalog.dart';

/// Searchable caller-supplied content. Names and keywords are caller-localized.
class LocalMediaCatalog implements MediaCatalog {
  LocalMediaCatalog(Iterable<MediaItem> items)
    : items = List.unmodifiable(
        {for (final item in items) item.identity: item}.values,
      ) {
    _searchText = {
      for (final item in this.items)
        item.identity:
            '${item.name} ${item.unicode ?? ''} ${item.keywords.join(' ')}'
                .toLowerCase(),
    };
    categories = List.unmodifiable(
      this.items.expand((item) => item.categories).toSet().toList()..sort(),
    );
  }

  final List<MediaItem> items;
  late final Map<String, String> _searchText;
  @override
  late final List<String> categories;

  @override
  Future<MediaPage> search({
    String query = '',
    String? category,
    String? cursor,
    int limit = 40,
  }) async {
    if (limit <= 0 || limit > 200) throw ArgumentError.value(limit, 'limit');
    final offset = cursor == null ? 0 : int.tryParse(cursor);
    if (offset == null || offset < 0) {
      throw ArgumentError.value(cursor, 'cursor');
    }
    final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
    final matches = items
        .where(
          (item) =>
              (category == null || item.categories.contains(category)) &&
              terms.every((term) => _searchText[item.identity]!.contains(term)),
        )
        .toList();
    final page = matches.skip(offset).take(limit).toList();
    final next = offset + page.length;
    return MediaPage(page, nextCursor: next < matches.length ? '$next' : null);
  }
}
