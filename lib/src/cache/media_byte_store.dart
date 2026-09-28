import 'dart:typed_data';

final class StoredMediaBytes {
  const StoredMediaBytes(this.bytes, this.expiresAt);
  final Uint8List bytes;
  final DateTime expiresAt;
}

/// Optional persistent byte cache. Implementations must bound storage.
abstract interface class MediaByteStore {
  Future<StoredMediaBytes?> read(String key);
  Future<void> write(String key, Uint8List bytes, DateTime expiresAt);
  Future<void> remove(String key);
  Future<void> clear();
}
