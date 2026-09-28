import 'media_byte_store.dart';
import 'persistent_media_store_stub.dart'
    if (dart.library.io) 'persistent_media_store_io.dart'
    as platform;

/// Creates a native, size-bounded cache in a dedicated subdirectory.
/// Returns null on the web, where the loader retains its bounded memory cache.
MediaByteStore? createPersistentMediaStore({
  int maxBytes = 32 * 1024 * 1024,
  Future<String> Function()? cacheRoot,
  DateTime Function()? clock,
}) => platform.createStore(
  maxBytes: maxBytes,
  cacheRoot: cacheRoot,
  clock: clock,
);
