import 'package:characters/characters.dart';

import '../models/media_item.dart';
import '../models/media_source.dart';
import 'local_media_catalog.dart';
import 'noto_emoji_data.g.dart';

/// A bundled snapshot of Google's animated Noto Emoji catalog.
///
/// Every supported emoji has its own local Lottie JSON, including skin tones.
/// Lookup and playback never require another emoji package or a remote CDN.
final class NotoEmojiCatalog extends LocalMediaCatalog {
  NotoEmojiCatalog() : super(_entries) {
    _byUnicode = {for (final item in items) item.unicode!: item};
    // Explicit presentation alias; never strip selectors or skin tones globally.
    final heart = _byUnicode['❤️'];
    if (heart != null) _byUnicode['❤'] = heart;
  }

  static final NotoEmojiCatalog instance = NotoEmojiCatalog();
  static const catalogVersion = notoCatalogVersion;
  static final _attribution = MediaAttribution(
    author: 'Google',
    source: Uri.parse('https://googlefonts.github.io/noto-emoji-files/'),
    license: 'CC BY 4.0',
    licenseUrl: Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
  );
  static final List<MediaItem> _entries = [
    for (final entry in notoEmojiEntries)
      MediaItem(
        id: entry.id,
        provider: 'google-noto',
        version: catalogVersion,
        name: entry.name,
        kind: MediaKind.emoji,
        format: MediaFormat.lottie,
        unicode: entry.unicode,
        width: 512,
        height: 512,
        categories: entry.categories,
        keywords: entry.keywords,
        source: MediaSource.asset(
          'packages/flutter_animated_media/assets/noto/lottie/${entry.id}.json',
        ),
        attribution: _attribution,
      ),
  ];
  late final Map<String, MediaItem> _byUnicode;

  /// Resolves one complete supported emoji without altering the caller's text.
  /// Explicit text presentation (VS15) remains static.
  MediaItem? resolve(String text) {
    final value = text.trim();
    if (value.isEmpty ||
        value.contains('\uFE0E') ||
        value.characters.length != 1) {
      return null;
    }
    return _byUnicode[value];
  }
}
