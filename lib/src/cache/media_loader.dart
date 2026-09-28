import 'dart:typed_data';

import '../models/media_item.dart';

/// Injectable encoded-media access; no renderer types cross this boundary.
abstract interface class MediaLoader {
  Future<Uint8List> load(MediaItem item);
  Future<void> evict(MediaItem item);
  Future<void> clear();
}
