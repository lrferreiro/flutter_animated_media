import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Uses Flutter's image codec, retaining one decoded frame rather than an
/// entire GIF/WebP sequence. No decoding timer runs while playback is paused.
final class RasterPlayback extends ChangeNotifier {
  ui.Codec? _codec;
  ui.Image? _image;
  ui.Image? get image => _image;
  Timer? _timer;
  Duration _delay = const Duration(milliseconds: 100);
  bool _playing = false;
  bool _disposed = false;
  bool _decoding = false;
  bool _loading = false;
  bool _restartRequested = false;
  int _frames = 0;
  int? _maxCycles;
  Uint8List? _bytes;
  int _targetSize = 512;
  int _revision = 0;
  bool get completed =>
      _maxCycles != null &&
      _codec != null &&
      _frames >= _codec!.frameCount * _maxCycles!;

  Future<void> load(Uint8List bytes, {int targetSize = 512}) async {
    _loading = true;
    final revision = ++_revision;
    _bytes = bytes;
    _targetSize = targetSize;
    _timer?.cancel();
    _timer = null;
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 16 * 1024 * 1024) {
        throw const FormatException('Raster dimensions exceed limit');
      }
      final scale = (targetSize / math.max(descriptor.width, descriptor.height))
          .clamp(0.0, 1.0);
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, targetSize),
        targetHeight: (descriptor.height * scale).round().clamp(1, targetSize),
      );
      if (_disposed || revision != _revision) {
        codec.dispose();
        return;
      }
      final previousCodec = _codec;
      _codec = codec;
      _frames = 0;
      previousCodec?.dispose();
      await _next();
    } finally {
      descriptor?.dispose();
      buffer.dispose();
      _loading = false;
      if (_restartRequested) {
        _restartRequested = false;
        replay();
      } else {
        _schedule();
      }
    }
  }

  void configure({required bool playing, int? maxCycles}) {
    _playing = playing;
    _maxCycles = maxCycles;
    if (!playing) {
      _timer?.cancel();
      _timer = null;
    }
    _schedule();
  }

  void replay() {
    final bytes = _bytes;
    if (bytes == null || _disposed) return;
    if (_decoding || _loading) {
      _restartRequested = true;
      return;
    }
    unawaited(
      load(bytes, targetSize: _targetSize).catchError((Object _) {
        _playing = false;
        _timer?.cancel();
        _timer = null;
      }),
    );
  }

  void _schedule() {
    final codec = _codec;
    if (_disposed ||
        !_playing ||
        _loading ||
        _decoding ||
        _timer != null ||
        codec == null ||
        codec.frameCount <= 1 ||
        (_maxCycles != null && _frames >= codec.frameCount * _maxCycles!)) {
      return;
    }
    _timer = Timer(_delay, () {
      _timer = null;
      unawaited(
        _next().catchError((Object _) {
          _playing = false;
        }),
      );
    });
  }

  Future<void> _next() async {
    if (_decoding || _disposed || _codec == null) return;
    _decoding = true;
    final revision = _revision;
    try {
      final frame = await _codec!.getNextFrame();
      if (_disposed || revision != _revision) {
        frame.image.dispose();
        return;
      }
      final previous = _image;
      _image = frame.image;
      _frames++;
      _delay = frame.duration < const Duration(milliseconds: 20)
          ? const Duration(milliseconds: 20)
          : frame.duration;
      notifyListeners();
      if (previous != null) {
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => previous.dispose(),
        );
      }
    } catch (_) {
      _playing = false;
      rethrow;
    } finally {
      _decoding = false;
      if (_restartRequested && !_loading) {
        _restartRequested = false;
        replay();
      } else {
        _schedule();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    _codec?.dispose();
    _image?.dispose();
    super.dispose();
  }
}
