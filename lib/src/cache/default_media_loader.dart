import '../playback/lottie_composition_cache.dart';
import 'cached_media_loader.dart';
import 'persistent_media_store.dart';

final defaultMediaLoader = CachedMediaLoader(
  store: createPersistentMediaStore(),
);

/// Clears the shared default byte store and decoded composition cache.
/// Caller-supplied loaders own their storage and must be cleared separately.
Future<void> clearAnimatedMediaCache() async {
  LottieCompositionCache.instance.clear();
  await defaultMediaLoader.clear();
}
