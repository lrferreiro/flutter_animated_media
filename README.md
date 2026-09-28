# Flutter Animated Media

Unicode-aware animated emojis, configurable stickers, and an embeddable media
catalog. Rendering uses Flutter's Lottie player and image codecs; no account,
commercial GIF API, backend, or chat framework is required.

## Installation

```yaml
dependencies:
  flutter_animated_media: ^0.1.0
```

## Animated emojis

```dart
import 'package:flutter_animated_media/flutter_animated_media.dart';

const AnimatedEmoji('👍🏽', size: 48, maxCycles: 2)
```

The bundled Noto catalog includes base emojis and available skin-tone variants.
Lookup uses complete Unicode grapheme clusters. Unsupported sequences, multiple
emojis, and mixed text remain static. A bare red heart has an explicit emoji
presentation alias; explicit text presentation (VS15) remains static. There is
no blanket removal of variation selectors, joiners, or modifiers.

Noto artwork replaces the system emoji visually; it does not animate an Apple
or Android system glyph. Keep the original Unicode text as your application data.

Loading and failure retain the original emoji inside a fixed-size box. Views
cross-fade from the placeholder to loaded content over 180 ms; `fadeDuration`
customizes the transition, and `Duration.zero` disables it. Reduced motion or
`animate: false` also disables the fade. Parent rebuilds do not restart it. Views
pause outside the viewport, when their app is inactive, under disabled
`TickerMode`, or when reduced motion is requested. Visibility detection is
coalesced by `visibility_detector` (500 ms by default), not instantaneous.
Normal rebuilds retain the playhead. A Noto `rest` marker supplies a stable
paused frame when available.

By default, media inside a scrollable defers new loading/presentation while the
list is being dragged or flung. Already loaded animations hold their current
frame and resume when scrolling ends. Set `pauseWhileScrolling: false` to opt
out. Network responses arriving during a scroll do not force immediate decoding
or a new vector drawable into that scroll frame.

```dart
final playback = MediaPlaybackController();
// Pass controller: playback to AnimatedEmoji or AnimatedMedia.
playback.pause();
playback.play();
playback.replay();
// The owner disposes the controller when no longer needed.
```

## Catalogs and pickers

`NotoEmojiCatalog.instance` provides the initial public catalog. Its names and
keywords are English metadata, not automatic multilingual search.
`LocalMediaCatalog` accepts caller-owned `MediaItem` entries, with localized
names, keywords, category labels and license metadata supplied by the caller.
Implement `MediaCatalog` to connect another authorized, paginated source.

```dart
Expanded(
  child: AnimatedMediaPicker(
    catalog: NotoEmojiCatalog.instance,
    query: searchText,
    category: selectedCategory,
    onSelected: onMediaSelected,
    emptyBuilder: (context) => Text(emptyLabel),
    errorBuilder: (context, error, retry) =>
        TextButton(onPressed: retry, child: Text(retryLabel)),
  ),
)
```

The grid requires bounded height. Place search controls outside it, or embed it
inside a panel, page, or sheet. It never navigates, dismisses its parent, or sends
content. Selection supports keyboard focus. `itemBuilder`, state builders,
spacing, padding, column count and item size are configurable. Standard controls
inherit the surrounding Flutter theme.

`MediaCatalogController` handles stale searches, duplicate results, paging
errors, retries and disposal independently of the view. The example includes
search, categories, preview controls, a Noto catalog and original GIF/Lottie
fixtures without any chat-specific dependency.

## Custom content

Each `MediaItem` describes a provider-scoped identity, version, kind, format,
source, optional Unicode, dimensions, preview and attribution. Sources support
bundled assets, public HTTPS URLs and immutable encoded bytes. Only a declared
remote fallback is used for missing bundled assets; redirects are not followed.

The initial vector renderer accepts self-contained Lottie JSON without external
images or fonts. It is not a universal After Effects, dotLottie, or ZIP renderer.
GIF, animated WebP and PNG use Flutter's image codec. Raster playback retains
the current frame and bounds decode dimensions to 512 pixels; it does not cache
every decoded animation frame. The format enum describes supported file types,
not video playback.

No GIPHY/Tenor integration, credentials, uploading, or content hosting is included.
Consumers are responsible for permission to use their custom catalogs.

## Loading, offline use and limits

`CachedMediaLoader` deduplicates encoded-resource requests and limits memory
(8 MiB), file size (2 MiB), request duration (12 seconds) and transient retries
(one by default). Limits, clocks, HTTP clients, asset loaders and byte stores are
injectable. It retries transient transport/5xx/429 failures, not missing files.
Corrupt content is evicted; rendering falls back without an endless retry loop.

The default native persistent cache uses a dedicated application-cache directory,
checks payload hashes, expires files after one day and is bounded to 32 MiB.
Cache access does not extend the original expiry. Web has memory caching only.
Storage failures do not prevent rendering a successfully loaded resource.

Decoded vector compositions are separately limited to 24 entries and 4 MiB of
encoded input weight. Actual decoded memory depends on artwork complexity.
Native decoding runs in a background isolate, with one cold decode in flight
at a time and deduplication for repeated artwork. On web, Flutter's `compute`
uses the same event loop, so it does not provide parallel decoding there.
The renderer keeps its animation controller stable instead of rebuilding its
Lottie widget on every tick.
Per-view Lottie raster-frame caching is intentionally disabled. These are three
distinct caches, not one persistent cache implied by Lottie's rendering options.

Use `clearAnimatedMediaCache()` for shared defaults, or clear an injected loader
separately. `AnimatedMediaScope` supplies a loader to a widget subtree without a
global override.

All 881 supported Noto animations are bundled as local Lottie JSON. They work
offline on first use, without asset declarations in the consuming app, remote
fallbacks, startup downloads, or a dependency on another emoji package. The
catalog is generated from Google's Emoji 17.0 metadata, and its artwork snapshot
is identified by content hashes. Noto GIFs are not included; the generic raster
renderer remains available for caller-supplied GIFs and other supported formats.

Bundled artwork increases the application download size, but it is loaded and
decoded on demand rather than all at once. Network and persistent-cache limits
above also apply to custom remote media; Noto itself does not need connectivity.

## Attribution and licenses

Animated Noto Emoji by Google is licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
See the [Noto source](https://googlefonts.github.io/noto-emoji-files/),
`THIRD_PARTY_NOTICES`, and `licenses/CC-BY-4.0.txt`. Artwork is not relicensed as
MIT. Catalog metadata comes directly from
[Google Emoji Metadata](https://github.com/googlefonts/emoji-metadata) under
Apache-2.0; the derived catalog preserves the complete Unicode sequences and
available skin tones. See `licenses/Apache-2.0.txt`. Modified artwork must be
identified.

After initializing Flutter, call `registerAnimatedMediaLicenses()` and provide
users with an accessible license screen, for example Flutter's `showLicensePage`.
Registration is explicit and idempotent. It includes the Noto credit, source,
license link, full license text and catalog attribution. A file hidden in an
application bundle is not a substitute for accessible attribution.

New package code and original example fixtures use MIT. No code, catalog, or
assets are taken from third-party animated-emoji packages.

## Requirements and limitations

- Dart 3.11+ and Flutter 3.41+.
- Platform-independent public interfaces; persistent disk caching is native-only.
- Platform support depends on Flutter codecs and plugins. Device performance
  must be validated for the consuming application's workload.
- No promise of complete Unicode coverage or support for arbitrary Lottie files.
- No guaranteed zero-cost animation: visibility and cache limits reduce work,
  but animation has a higher rendering cost than a static glyph.
