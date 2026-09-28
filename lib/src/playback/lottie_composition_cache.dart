import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:lottie/lottie.dart';

/// Internal cache bounded by entry count and encoded input weight. Decoded
/// vector memory varies with artwork complexity; no raster-frame cache is used.
final class LottieCompositionCache {
  static final instance = LottieCompositionCache();
  final _entries = <String, ({int weight, LottieComposition value})>{};
  final _pending = <String, Future<LottieComposition>>{};
  int _weight = 0;
  int _generation = 0;

  Future<LottieComposition> decode(Uint8List bytes) {
    final key = sha256.convert(bytes).toString();
    final found = _entries.remove(key);
    if (found != null) {
      _entries[key] = found;
      return Future.value(found.value);
    }
    return _pending.putIfAbsent(key, () {
      final generation = _generation;
      late final Future<LottieComposition> future;
      future =
          Future<LottieComposition>(() {
            // JSON only: do not expand untrusted archives or fetch external assets.
            final composition = LottieComposition.parseJsonBytes(bytes);
            if (composition.duration <= Duration.zero ||
                composition.duration > const Duration(minutes: 1) ||
                composition.images.isNotEmpty ||
                composition.fonts.isNotEmpty) {
              throw const FormatException(
                'Only self-contained vector Lottie JSON is supported',
              );
            }
            if (generation == _generation && bytes.length <= 4 * 1024 * 1024) {
              _entries[key] = (weight: bytes.length, value: composition);
              _weight += bytes.length;
              while (_entries.length > 24 || _weight > 4 * 1024 * 1024) {
                _weight -= _entries.remove(_entries.keys.first)!.weight;
              }
            }
            return composition;
          }).whenComplete(() {
            if (identical(_pending[key], future)) _pending.remove(key);
          });
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
