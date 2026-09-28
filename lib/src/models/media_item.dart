import 'dart:convert';

import 'media_source.dart';

enum MediaKind { emoji, sticker }

/// The initial implementation supports vector-only Lottie JSON and raster
/// files decoded by Flutter. It does not load external Lottie fonts/images.
enum MediaFormat { lottie, gif, webp, png }

final class MediaAttribution {
  const MediaAttribution({
    required this.author,
    required this.source,
    required this.license,
    required this.licenseUrl,
    this.modifications = '',
  });

  final String author;
  final Uri source;
  final String license;
  final Uri licenseUrl;
  final String modifications;

  MediaAttribution copyWith({
    String? author,
    Uri? source,
    String? license,
    Uri? licenseUrl,
    String? modifications,
  }) => MediaAttribution(
    author: author ?? this.author,
    source: source ?? this.source,
    license: license ?? this.license,
    licenseUrl: licenseUrl ?? this.licenseUrl,
    modifications: modifications ?? this.modifications,
  );
}

/// Immutable catalog metadata, independent of Flutter and renderer types.
final class MediaItem {
  MediaItem({
    required this.id,
    required this.provider,
    required this.version,
    required this.name,
    required this.kind,
    required this.format,
    required this.source,
    required this.attribution,
    this.unicode,
    this.preview,
    this.width,
    this.height,
    Iterable<String> categories = const [],
    Iterable<String> keywords = const [],
  }) : categories = List.unmodifiable(categories),
       keywords = List.unmodifiable(keywords);

  final String id;
  final String provider;
  final String version;
  final String name;
  final MediaKind kind;
  final MediaFormat format;
  final MediaSource source;
  final MediaAttribution attribution;
  final String? unicode;

  /// An optional static preview source. Renderers still retain the first
  /// decoded frame when playback is disabled.
  final MediaSource? preview;
  final double? width;
  final double? height;
  final List<String> categories;
  final List<String> keywords;

  String get identity => jsonEncode([provider, id]);
  String get cacheKey => jsonEncode([
    provider,
    id,
    version,
    format.name,
    unicode,
    source.identity,
    source.fallbackUri?.toString(),
  ]);

  MediaItem copyWith({
    String? id,
    String? provider,
    String? version,
    String? name,
    MediaKind? kind,
    MediaFormat? format,
    MediaSource? source,
    MediaAttribution? attribution,
    String? unicode,
    MediaSource? preview,
    double? width,
    double? height,
    Iterable<String>? categories,
    Iterable<String>? keywords,
  }) => MediaItem(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    version: version ?? this.version,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    format: format ?? this.format,
    source: source ?? this.source,
    attribution: attribution ?? this.attribution,
    unicode: unicode ?? this.unicode,
    preview: preview ?? this.preview,
    width: width ?? this.width,
    height: height ?? this.height,
    categories: categories ?? this.categories,
    keywords: keywords ?? this.keywords,
  );
}
