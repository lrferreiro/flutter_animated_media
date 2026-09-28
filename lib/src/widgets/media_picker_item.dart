import 'package:flutter/material.dart';

import '../cache/media_loader.dart';
import '../models/media_item.dart';
import 'animated_media.dart';

class MediaPickerItem extends StatelessWidget {
  const MediaPickerItem({
    super.key,
    required this.item,
    required this.onSelected,
    required this.size,
    this.loader,
    this.placeholder,
  });

  final MediaItem item;
  final ValueChanged<MediaItem> onSelected;
  final double size;
  final MediaLoader? loader;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: item.name,
    child: Tooltip(
      message: item.name,
      child: InkWell(
        onTap: () => onSelected(item),
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: AnimatedMedia(
            item: item,
            width: size,
            height: size,
            loader: loader,
            placeholder:
                placeholder ??
                Text(item.unicode ?? '', style: TextStyle(fontSize: size)),
          ),
        ),
      ),
    ),
  );
}
