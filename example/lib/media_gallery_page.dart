import 'package:flutter/material.dart';
import 'package:flutter_animated_media/flutter_animated_media.dart';

import 'demo_catalog.dart';
import 'media_preview_card.dart';

class MediaGalleryPage extends StatefulWidget {
  const MediaGalleryPage({super.key});

  @override
  State<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<MediaGalleryPage> {
  bool _custom = false;
  String _query = '';
  String? _category;
  MediaItem? _selected;

  @override
  Widget build(BuildContext context) {
    final catalog = _custom ? demoCatalog : NotoEmojiCatalog.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animated media'),
        actions: [
          IconButton(
            tooltip: 'Licenses',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showLicensePage(context: context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Custom catalog'),
              subtitle: const Text('Original vector and GIF fixtures'),
              value: _custom,
              onChanged: (value) => setState(() {
                _custom = value;
                _category = null;
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  labelText: 'Search names or keywords',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final category in catalog.categories)
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedMediaPicker(
                catalog: catalog,
                query: _query,
                category: _category,
                onSelected: (item) => setState(() => _selected = item),
                emptyBuilder: (_) =>
                    const Center(child: Text('No matching media')),
                errorBuilder: (_, error, retry) => Center(
                  child: TextButton(
                    onPressed: retry,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            ),
            if (_selected case final item?) MediaPreviewCard(item: item),
          ],
        ),
      ),
    );
  }
}
