import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_animated_media/flutter_animated_media.dart';
import 'package:flutter_animated_media/src/playback/lottie_composition_cache.dart';

// Reuse the original sample fixture; the package does not depend on the example.
// ignore: avoid_relative_lib_imports
import '../../example/lib/demo_catalog.dart' show pulseJson;
export '../../example/lib/demo_catalog.dart' show pulseJson, colorGif;

MediaItem fixture({
  String id = 'pulse',
  MediaSource? source,
  String version = '1',
}) => MediaItem(
  id: id,
  provider: 'test',
  version: version,
  name: id,
  kind: MediaKind.sticker,
  format: MediaFormat.lottie,
  source: source ?? MediaSource.memory(id, pulseBytes),
  attribution: MediaAttribution(
    author: 'Test',
    source: Uri.parse('https://example.org/art'),
    license: 'MIT',
    licenseUrl: Uri.parse('https://opensource.org/license/mit'),
  ),
);

Uint8List get pulseBytes => Uint8List.fromList(utf8.encode(pulseJson));

// Decode the original fixture with the production isolate before fake-clock
// widget tests. Cold/background decoding is covered separately by cache tests.
Future<void> warmFixtureComposition() async {
  await LottieCompositionCache.instance.decode(pulseBytes);
}

class FakeMediaLoader implements MediaLoader {
  FakeMediaLoader({this.bytes, this.error});
  final Uint8List? bytes;
  final Object? error;
  int calls = 0;
  int evictions = 0;

  @override
  Future<Uint8List> load(MediaItem item) async {
    calls++;
    if (error != null) throw error!;
    return bytes ?? pulseBytes;
  }

  @override
  Future<void> evict(MediaItem item) async {
    evictions++;
  }

  @override
  Future<void> clear() async {}
}
