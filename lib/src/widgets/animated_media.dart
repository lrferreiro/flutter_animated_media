import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../cache/default_media_loader.dart';
import '../cache/media_loader.dart';
import '../models/media_item.dart';
import '../playback/lottie_composition_cache.dart';
import '../playback/media_playback_controller.dart';
import '../playback/raster_playback.dart';
import 'animated_media_scope.dart';
import 'raster_media_frame.dart';

/// A fixed-size, lifecycle-aware view. It does not intercept pointer gestures.
class AnimatedMedia extends StatefulWidget {
  const AnimatedMedia({
    super.key,
    required this.item,
    this.width = 96,
    this.height = 96,
    this.fit = BoxFit.contain,
    this.animate = true,
    this.maxCycles,
    this.controller,
    this.loader,
    this.placeholder,
    this.errorBuilder,
    this.semanticLabel,
    this.onPlaybackChanged,
  }) : assert(width > 0),
       assert(height > 0),
       assert(maxCycles == null || maxCycles > 0);

  final MediaItem item;
  final double width;
  final double height;
  final BoxFit fit;
  final bool animate;

  /// Null repeats indefinitely while visible and enabled.
  final int? maxCycles;
  final MediaPlaybackController? controller;
  final MediaLoader? loader;
  final Widget? placeholder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final String? semanticLabel;
  final ValueChanged<bool>? onPlaybackChanged;

  @override
  State<AnimatedMedia> createState() => _AnimatedMediaState();
}

class _AnimatedMediaState extends State<AnimatedMedia>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _visibilityKey = UniqueKey();
  late final AnimationController _animation;
  LottieComposition? _composition;
  RasterPlayback? _raster;
  RasterPlayback? _preview;
  Object? _error;
  bool _loading = false;
  bool _visible = false;
  bool _foreground = true;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;
  bool _active = false;
  int _loadRevision = 0;
  int _cycles = 0;
  int _replayRevision = 0;
  double _rest = 0;
  MediaLoader? _scopeLoader;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _animation = AnimationController(vsync: this)..addStatusListener(_status);
    _replayRevision = widget.controller?.replayRevision ?? 0;
    widget.controller?.addListener(_intentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scopeLoader = AnimatedMediaScope.loaderOf(context);
    if (_scopeLoader != scopeLoader) {
      _scopeLoader = scopeLoader;
      _reset();
    }
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(covariant AnimatedMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_intentChanged);
      widget.controller?.addListener(_intentChanged);
      _replayRevision = widget.controller?.replayRevision ?? 0;
    }
    if (oldWidget.item.cacheKey != widget.item.cacheKey ||
        oldWidget.item.preview?.identity != widget.item.preview?.identity ||
        oldWidget.loader != widget.loader) {
      _reset();
    }
    _sync();
  }

  void _reset() {
    _loadRevision++;
    _loading = false;
    _error = null;
    _composition = null;
    _raster?.dispose();
    _raster = null;
    _preview?.dispose();
    _preview = null;
    _cycles = 0;
    _animation.stop();
    _animation.value = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
    if (mounted) setState(() {});
  }

  void _intentChanged() {
    final revision = widget.controller?.replayRevision ?? 0;
    if (revision != _replayRevision) {
      _replayRevision = revision;
      _cycles = 0;
      _animation.value = 0;
      _raster?.replay();
    }
    _sync();
    if (mounted) setState(() {});
  }

  void _sync() {
    final eligible = _visible && _foreground && _tickerEnabled;
    final active =
        eligible &&
        !_reduceMotion &&
        widget.animate &&
        (widget.controller?.isPlaying ?? true) &&
        (widget.maxCycles == null || _cycles < widget.maxCycles!);
    if (_active != active) {
      _active = active;
      widget.onPlaybackChanged?.call(active);
    }
    if (eligible &&
        !_loading &&
        _composition == null &&
        _raster == null &&
        _error == null) {
      unawaited(_load());
    }
    if (_active && _composition != null) {
      if (!_animation.isAnimating) _animation.forward();
    } else {
      _animation.stop();
    }
    _raster?.configure(playing: _active, maxCycles: widget.maxCycles);
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _cycles++;
    if (_active && (widget.maxCycles == null || _cycles < widget.maxCycles!)) {
      _animation.forward(from: 0);
    } else {
      _sync();
    }
  }

  Future<void> _load() async {
    _loading = true;
    final revision = ++_loadRevision;
    final item = widget.item;
    final loader = widget.loader ?? _scopeLoader ?? defaultMediaLoader;
    if (item.preview != null) {
      unawaited(_loadPreview(item, loader, revision));
    }
    RasterPlayback? raster;
    try {
      final bytes = await loader.load(item);
      if (!mounted || revision != _loadRevision) return;
      if (item.format == MediaFormat.lottie) {
        final composition = await LottieCompositionCache.instance.decode(bytes);
        if (!mounted || revision != _loadRevision) return;
        _composition = composition;
        _animation.duration = composition.duration;
        _rest = 0;
        for (final marker in composition.markers) {
          if (marker.matchesName('rest')) {
            _rest = marker.start.clamp(0.0, 1.0);
            break;
          }
        }
        _animation.value = _rest;
      } else {
        raster = RasterPlayback();
        await raster.load(bytes);
        if (!mounted || revision != _loadRevision) {
          raster.dispose();
          return;
        }
        _raster = raster;
        raster.addListener(_rasterChanged);
      }
      if (mounted && revision == _loadRevision) {
        _loading = false;
        _sync();
        setState(() {});
      }
    } catch (error) {
      raster?.dispose();
      try {
        await loader.evict(item);
      } catch (_) {}
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _rasterChanged() {
    if (_raster?.completed ?? false) {
      _cycles = widget.maxCycles ?? 0;
      _sync();
    }
  }

  Future<void> _loadPreview(
    MediaItem item,
    MediaLoader loader,
    int revision,
  ) async {
    final previewItem = item.copyWith(
      id: '${item.id}:preview',
      source: item.preview!,
      format: MediaFormat.png,
    );
    final preview = RasterPlayback();
    try {
      final bytes = await loader.load(previewItem);
      if (!mounted || revision != _loadRevision) {
        preview.dispose();
        return;
      }
      await preview.load(bytes);
      if (!mounted || revision != _loadRevision) {
        preview.dispose();
        return;
      }
      setState(() => _preview = preview);
    } catch (_) {
      preview.dispose();
      try {
        await loader.evict(previewItem);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _loadRevision++;
    VisibilityDetectorController.instance.forget(_visibilityKey);
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_intentChanged);
    _animation.dispose();
    _raster?.dispose();
    _preview?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback =
        widget.placeholder ??
        (_preview != null
            ? RasterMediaFrame(
                playback: _preview!,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
              )
            : const SizedBox.expand());
    final Widget content;
    if (_error != null) {
      content = widget.errorBuilder?.call(context, _error!) ?? fallback;
    } else if (_composition case final composition?) {
      content = AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Lottie(
          composition: composition,
          animate: false,
          controller: AlwaysStoppedAnimation(
            _active ? _animation.value : _rest,
          ),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          // No unbounded per-view raster-frame cache.
        ),
      );
    } else if (_raster case final raster?) {
      content = RasterMediaFrame(
        playback: raster,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    } else {
      content = fallback;
    }
    return Semantics(
      label: widget.semanticLabel ?? widget.item.name,
      image: true,
      child: ExcludeSemantics(
        child: VisibilityDetector(
          key: _visibilityKey,
          onVisibilityChanged: (info) {
            final visible = info.visibleFraction > 0;
            if (!mounted || _visible == visible) return;
            _visible = visible;
            _sync();
            setState(() {});
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: content,
          ),
        ),
      ),
    );
  }
}
