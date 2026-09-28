import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import 'media_byte_store.dart';
import 'media_loader.dart';

/// Size-bounded encoded bytes, deduplicated loads, and optional persistence.
final class CachedMediaLoader implements MediaLoader {
  CachedMediaLoader({
    this.store,
    this.maxMemoryBytes = 8 * 1024 * 1024,
    this.maxFileBytes = 2 * 1024 * 1024,
    this.ttl = const Duration(days: 1),
    this.timeout = const Duration(seconds: 12),
    this.retries = 1,
    http.Client Function()? clientFactory,
    Future<ByteData> Function(String)? assetLoader,
    DateTime Function()? clock,
  }) : assert(maxMemoryBytes >= 0),
       assert(maxFileBytes > 0),
       assert(retries >= 0 && retries <= 3),
       _clientFactory = clientFactory ?? http.Client.new,
       _assetLoader = assetLoader ?? rootBundle.load,
       _clock = clock ?? DateTime.now;

  final MediaByteStore? store;
  final int maxMemoryBytes;
  final int maxFileBytes;
  final Duration ttl;
  final Duration timeout;
  final int retries;
  final http.Client Function() _clientFactory;
  final Future<ByteData> Function(String) _assetLoader;
  final DateTime Function() _clock;
  final _memory = <String, ({Uint8List bytes, DateTime expiry})>{};
  final _pending = <String, Future<Uint8List>>{};
  int _bytes = 0;
  int _generation = 0;

  int get memoryBytes => _bytes;
  int get pendingLoads => _pending.length;

  @override
  Future<Uint8List> load(MediaItem item) {
    final key = item.cacheKey;
    final existing = _memory.remove(key);
    if (existing != null) {
      if (existing.expiry.isAfter(_clock())) {
        _memory[key] = existing;
        return Future.value(existing.bytes);
      }
      _bytes -= existing.bytes.length;
    }
    return _pending.putIfAbsent(key, () {
      final generation = _generation;
      late final Future<Uint8List> future;
      future = _load(item)
          .then((loaded) async {
            final bytes = loaded.bytes;
            if (bytes.isEmpty || bytes.length > maxFileBytes) {
              throw const FormatException('Invalid encoded media size');
            }
            final immutable = Uint8List.fromList(bytes).asUnmodifiableView();
            if (generation == _generation) {
              final expiry = loaded.expiry;
              // A cache failure must not prevent rendering already loaded content.
              if (!loaded.cached) {
                try {
                  await store?.write(key, immutable, expiry);
                } catch (_) {}
              }
              if (generation == _generation &&
                  immutable.length <= maxMemoryBytes) {
                _memory[key] = (bytes: immutable, expiry: expiry);
                _bytes += immutable.length;
                while (_bytes > maxMemoryBytes) {
                  _bytes -= _memory.remove(_memory.keys.first)!.bytes.length;
                }
              }
            }
            return immutable;
          })
          .whenComplete(() {
            if (identical(_pending[key], future)) _pending.remove(key);
          });
      return future;
    });
  }

  Future<({Uint8List bytes, DateTime expiry, bool cached})> _load(
    MediaItem item,
  ) async {
    try {
      final cached = await store?.read(item.cacheKey);
      if (cached != null &&
          cached.expiresAt.isAfter(_clock()) &&
          cached.bytes.isNotEmpty &&
          cached.bytes.length <= maxFileBytes) {
        return (bytes: cached.bytes, expiry: cached.expiresAt, cached: true);
      }
    } catch (_) {}
    final source = item.source;
    if (source.bytes != null) {
      return (bytes: source.bytes!, expiry: _clock().add(ttl), cached: false);
    }
    if (source.isAsset) {
      try {
        final data = await _assetLoader(source.identity);
        return (
          bytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          expiry: _clock().add(ttl),
          cached: false,
        );
      } catch (_) {
        if (source.fallbackUri == null) rethrow;
      }
    }
    final uri = source.uri ?? source.fallbackUri!;
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw ArgumentError('Only public HTTPS media URLs are supported');
    }
    for (var attempt = 0; ; attempt++) {
      try {
        return (
          bytes: await _download(uri),
          expiry: _clock().add(ttl),
          cached: false,
        );
      } on _RetryableDownload {
        if (attempt >= retries) rethrow;
      } on TimeoutException {
        if (attempt >= retries) rethrow;
      } on http.ClientException {
        if (attempt >= retries) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }
  }

  Future<Uint8List> _download(Uri uri) async {
    final client = _clientFactory();
    final abort = Completer<void>();
    try {
      return await (() async {
        final request = http.AbortableRequest(
          'GET',
          uri,
          abortTrigger: abort.future,
        )..followRedirects = false;
        final response = await client.send(request);
        if (response.statusCode == 429 || response.statusCode >= 500) {
          throw _RetryableDownload(response.statusCode);
        }
        if (response.statusCode != 200) {
          throw StateError('Media HTTP ${response.statusCode}');
        }
        if ((response.contentLength ?? 0) > maxFileBytes) {
          throw const FormatException('Encoded media exceeds size limit');
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (builder.length + chunk.length > maxFileBytes) {
            throw const FormatException('Encoded media exceeds size limit');
          }
          builder.add(chunk);
        }
        return builder.takeBytes();
      })().timeout(timeout);
    } finally {
      abort.complete();
      client.close();
    }
  }

  @override
  Future<void> evict(MediaItem item) async {
    _generation++;
    _pending.remove(item.cacheKey);
    final removed = _memory.remove(item.cacheKey);
    if (removed != null) _bytes -= removed.bytes.length;
    try {
      await store?.remove(item.cacheKey);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _generation++;
    _pending.clear();
    _memory.clear();
    _bytes = 0;
    await store?.clear();
  }
}

final class _RetryableDownload implements Exception {
  const _RetryableDownload(this.statusCode);
  final int statusCode;
}
