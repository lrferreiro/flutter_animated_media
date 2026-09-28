import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import 'media_catalog.dart';

/// Owns paginated search state, independently of navigation and UI strings.
final class MediaCatalogController extends ChangeNotifier {
  MediaCatalogController(this.catalog, {this.pageSize = 40});

  final MediaCatalog catalog;
  final int pageSize;
  final List<MediaItem> _items = [];
  List<MediaItem> get items => List.unmodifiable(_items);
  String _query = '';
  String? _category;
  String? _cursor;
  int _generation = 0;
  bool _disposed = false;
  bool loading = false;
  bool initialized = false;
  Object? error;
  bool get hasMore => _cursor != null;

  Future<void> search({String query = '', String? category}) async {
    final generation = ++_generation;
    _query = query;
    _category = category;
    _cursor = null;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await catalog.search(
        query: query,
        category: category,
        limit: pageSize,
      );
      if (_disposed || generation != _generation) return;
      _items
        ..clear()
        ..addAll({for (final item in page.items) item.identity: item}.values);
      _cursor = page.nextCursor;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
    } finally {
      if (!_disposed && generation == _generation) {
        initialized = true;
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || _cursor == null) return;
    final generation = _generation;
    final cursor = _cursor!;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await catalog.search(
        query: _query,
        category: _category,
        cursor: cursor,
        limit: pageSize,
      );
      if (_disposed || generation != _generation) return;
      final ids = _items.map((item) => item.identity).toSet();
      _items.addAll(page.items.where((item) => ids.add(item.identity)));
      _cursor = page.nextCursor == cursor ? null : page.nextCursor;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() =>
      _cursor == null ? search(query: _query, category: _category) : loadMore();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
