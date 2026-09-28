import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';

/// Internal cache bounded by entry count and encoded input weight. Decoded
/// vector memory varies with artwork complexity; no raster-frame cache is used.
final class LottieCompositionCache {
  LottieCompositionCache({
    Future<LottieComposition> Function(Uint8List)? decoder,
  }) : _decoder = decoder ?? _decodeInBackground;

  static final instance = LottieCompositionCache();
  final Future<LottieComposition> Function(Uint8List) _decoder;
  final _entries = <String, ({int weight, LottieComposition value})>{};
  final _pending = <String, Future<LottieComposition>>{};
  final _fingerprints = Expando<String>();
  Future<void> _decodeTail = Future.value();
  int _weight = 0;
  int _generation = 0;

  Future<LottieComposition> decode(Uint8List bytes) {
    // Loaders return immutable bytes. Reusing those bytes on list remounts
    // must not hash the entire file again on the UI isolate.
    final key = _fingerprints[bytes] ??= sha256.convert(bytes).toString();
    final found = _entries.remove(key);
    if (found != null) {
      _entries[key] = found;
      return Future.value(found.value);
    }
    return _pending.putIfAbsent(key, () {
      final generation = _generation;
      late final Future<LottieComposition> future;
      // A group of newly visible items shares one decode queue, rather than
      // starting an isolate for every item at once. Failures release the queue.
      future = _decodeTail
          .then((_) => _decoder(bytes))
          .then((composition) {
            if (generation == _generation && bytes.length <= 4 * 1024 * 1024) {
              _entries[key] = (weight: bytes.length, value: composition);
              _weight += bytes.length;
              while (_entries.length > 24 || _weight > 4 * 1024 * 1024) {
                _weight -= _entries.remove(_entries.keys.first)!.weight;
              }
            }
            return composition;
          })
          .whenComplete(() {
            if (identical(_pending[key], future)) _pending.remove(key);
          });
      _decodeTail = future.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      return future;
    });
  }

  void clear() {
    _generation++;
    _entries.clear();
    _pending.clear();
    _weight = 0;
  }
}

Future<LottieComposition> _decodeInBackground(Uint8List bytes) => compute(
  _parseVectorComposition,
  bytes,
  debugLabel: 'animated_media_lottie_decode',
);

LottieComposition _parseVectorComposition(Uint8List bytes) {
  // JSON only: do not expand archives or fetch external assets. This is the
  // same isolate mechanism Lottie's backgroundLoading providers use.
  final composition = LottieComposition.parseJsonBytes(bytes);
  if (composition.duration <= Duration.zero ||
      composition.duration > const Duration(minutes: 1) ||
      composition.images.isNotEmpty ||
      composition.fonts.isNotEmpty) {
    throw const FormatException(
      'Only self-contained vector Lottie JSON is supported',
    );
  }
  return composition;
}
