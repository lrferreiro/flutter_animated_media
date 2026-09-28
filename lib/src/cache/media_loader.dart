import 'dart:typed_data';

import '../models/media_item.dart';

/// Injectable encoded-media access; no renderer types cross this boundary.
abstract interface class MediaLoader {
  /// Returns encoded bytes that must not be mutated after delivery. Renderers
  /// can reuse their identity for decoding and cache lookups.
  Future<Uint8List> load(MediaItem item);
  Future<void> evict(MediaItem item);
  Future<void> clear();
}
