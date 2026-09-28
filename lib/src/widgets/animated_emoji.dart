import 'package:flutter/widgets.dart';

import '../cache/media_loader.dart';
import '../catalog/noto_emoji_catalog.dart';
import '../playback/media_playback_controller.dart';
import 'animated_media.dart';

/// Resolves a single Unicode emoji, leaving unsupported text unchanged.
class AnimatedEmoji extends StatelessWidget {
  const AnimatedEmoji(
    this.emoji, {
    super.key,
    this.size = 48,
    this.animate = true,
    this.pauseWhileScrolling = true,
    this.fadeDuration = const Duration(milliseconds: 180),
    this.maxCycles,
    this.controller,
    this.loader,
    this.catalog,
    this.semanticLabel,
    this.fallbackStyle,
  });

  final String emoji;
  final double size;
  final bool animate;

  /// Defers animation loading and pauses playback during scrolling.
  final bool pauseWhileScrolling;

  /// Duration of the fade from the original glyph to its loaded animation.
  final Duration fadeDuration;
  final int? maxCycles;
  final MediaPlaybackController? controller;
  final MediaLoader? loader;
  final NotoEmojiCatalog? catalog;
  final String? semanticLabel;
  final TextStyle? fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      emoji,
      style: fallbackStyle ?? TextStyle(fontSize: size, height: 1),
      semanticsLabel: semanticLabel,
    );
    final item = (catalog ?? NotoEmojiCatalog.instance).resolve(emoji);
    if (item == null ||
        !animate ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      return fallback;
    }
    return AnimatedMedia(
      item: item,
      width: size,
      height: size,
      animate: animate,
      pauseWhileScrolling: pauseWhileScrolling,
      fadeDuration: fadeDuration,
      maxCycles: maxCycles,
      controller: controller,
      loader: loader,
      semanticLabel: semanticLabel ?? emoji,
      placeholder: Center(child: fallback),
    );
  }
}
