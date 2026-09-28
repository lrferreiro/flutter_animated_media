import 'dart:async';

import 'package:flutter/material.dart';

import '../cache/media_loader.dart';
import '../catalog/media_catalog.dart';
import '../catalog/media_catalog_controller.dart';
import '../models/media_item.dart';
import 'media_picker_item.dart';

/// Embeddable paginated grid. Search controls and translations belong to the
/// caller. It never navigates, dismisses a sheet, or sends selected content.
class AnimatedMediaPicker extends StatefulWidget {
  const AnimatedMediaPicker({
    super.key,
    required this.catalog,
    required this.onSelected,
    required this.emptyBuilder,
    required this.errorBuilder,
    this.loadingBuilder,
    this.itemBuilder,
    this.loader,
    this.query = '',
    this.category,
    this.columns = 4,
    this.itemSize = 64,
    this.spacing = 8,
    this.padding = const EdgeInsets.all(12),
    this.debounce = const Duration(milliseconds: 250),
  });

  final MediaCatalog catalog;
  final ValueChanged<MediaItem> onSelected;
  final WidgetBuilder emptyBuilder;
  final Widget Function(BuildContext, Object, VoidCallback) errorBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext, MediaItem, VoidCallback)? itemBuilder;
  final MediaLoader? loader;
  final String query;
  final String? category;
  final int columns;
  final double itemSize;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final Duration debounce;

  @override
  State<AnimatedMediaPicker> createState() => _AnimatedMediaPickerState();
}

class _AnimatedMediaPickerState extends State<AnimatedMediaPicker> {
  late MediaCatalogController _controller;
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = MediaCatalogController(widget.catalog);
    _scroll.addListener(_onScroll);
    _search();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 200 && _controller.error == null) {
      unawaited(_controller.loadMore());
    }
  }

  void _search() {
    unawaited(
      _controller.search(query: widget.query, category: widget.category),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedMediaPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog ||
        oldWidget.query != widget.query ||
        oldWidget.category != widget.category) {
      _debounce?.cancel();
      // Dispose immediately so even responses during debounce cannot replace
      // the new search. Each generation has independent paging state.
      _controller.dispose();
      _controller = MediaCatalogController(widget.catalog);
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _debounce = Timer(widget.debounce, _search);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (!_controller.initialized && _controller.items.isEmpty) {
        return widget.loadingBuilder?.call(context) ??
            const Center(child: CircularProgressIndicator());
      }
      if (_controller.items.isEmpty && _controller.error != null) {
        return widget.errorBuilder(
          context,
          _controller.error!,
          () => _controller.retry(),
        );
      }
      if (_controller.items.isEmpty) return widget.emptyBuilder(context);
      final items = _controller.items;
      return Column(
        children: [
          if (_controller.loading) const LinearProgressIndicator(),
          Expanded(
            child: GridView.builder(
              controller: _scroll,
              padding: widget.padding,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.columns,
                mainAxisSpacing: widget.spacing,
                crossAxisSpacing: widget.spacing,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return widget.itemBuilder?.call(
                      context,
                      item,
                      () => widget.onSelected(item),
                    ) ??
                    MediaPickerItem(
                      key: ValueKey(item.identity),
                      item: item,
                      size: widget.itemSize,
                      loader: widget.loader,
                      onSelected: widget.onSelected,
                    );
              },
            ),
          ),
          if (_controller.error != null)
            widget.errorBuilder(
              context,
              _controller.error!,
              () => _controller.retry(),
            ),
        ],
      );
    },
  );
}
