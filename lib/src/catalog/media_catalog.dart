import '../models/media_item.dart';

final class MediaPage {
  MediaPage(Iterable<MediaItem> items, {this.nextCursor})
    : items = List.unmodifiable(items);

  final List<MediaItem> items;
  final String? nextCursor;
}

abstract interface class MediaCatalog {
  List<String> get categories;

  Future<MediaPage> search({
    String query = '',
    String? category,
    String? cursor,
    int limit = 40,
  });
}
