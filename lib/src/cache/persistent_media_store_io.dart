import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'media_byte_store.dart';

MediaByteStore createStore({
  required int maxBytes,
  Future<String> Function()? cacheRoot,
  DateTime Function()? clock,
}) => _FileMediaStore(
  maxBytes,
  cacheRoot ?? () async => (await getApplicationCacheDirectory()).path,
  clock ?? DateTime.now,
);

/// Serialized operations keep eviction, atomic writes and clearing coherent.
final class _FileMediaStore implements MediaByteStore {
  _FileMediaStore(this.maxBytes, this.root, this.clock) : assert(maxBytes > 40);

  final int maxBytes;
  final Future<String> Function() root;
  final DateTime Function() clock;
  Future<void> _tail = Future.value();
  Directory? _directory;
  static final _name = RegExp(r'^[a-f0-9]{64}\.media$');

  Future<T> _serial<T>(Future<T> Function() action) {
    final future = _tail.then((_) => action());
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  Future<Directory> _dir() async {
    final existing = _directory;
    if (existing != null) return existing;
    final directory = Directory('${await root()}/flutter_animated_media_v1');
    await directory.create(recursive: true);
    _directory = directory;
    return directory;
  }

  Future<File> _file(String key) async =>
      File('${(await _dir()).path}/${sha256.convert(utf8.encode(key))}.media');

  @override
  Future<StoredMediaBytes?> read(String key) => _serial(() async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) {
      await file.delete();
      return null;
    }
    final data = await file.readAsBytes();
    if (data.length <= 40) {
      await file.delete();
      return null;
    }
    final expires = DateTime.fromMillisecondsSinceEpoch(
      ByteData.sublistView(data, 0, 8).getInt64(0),
    );
    final payload = Uint8List.sublistView(data, 40);
    final digest = sha256.convert(payload).bytes;
    if (!expires.isAfter(clock()) ||
        List.generate(32, (i) => digest[i] == data[i + 8]).contains(false)) {
      await file.delete();
      return null;
    }
    await file.setLastModified(clock());
    return StoredMediaBytes(payload.asUnmodifiableView(), expires);
  });

  @override
  Future<void> write(
    String key,
    Uint8List bytes,
    DateTime expiresAt,
  ) => _serial(() async {
    if (bytes.length + 40 > maxBytes || !expiresAt.isAfter(clock())) return;
    final file = await _file(key);
    final content = Uint8List(bytes.length + 40);
    ByteData.sublistView(content).setInt64(0, expiresAt.millisecondsSinceEpoch);
    content.setRange(8, 40, sha256.convert(bytes).bytes);
    content.setRange(40, content.length, bytes);
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(content, flush: true);
      await temporary.rename(file.path);
      await file.setLastModified(clock());
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    final entries = <({File file, FileStat stat})>[];
    var total = 0;
    await for (final entity in (await _dir()).list(followLinks: false)) {
      if (entity is! File || !_name.hasMatch(entity.uri.pathSegments.last)) {
        continue;
      }
      final stat = await entity.stat();
      entries.add((file: entity, stat: stat));
      total += stat.size;
    }
    entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in entries) {
      if (total <= maxBytes) break;
      await entry.file.delete();
      total -= entry.stat.size;
    }
  });

  @override
  Future<void> remove(String key) => _serial(() async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  });

  @override
  Future<void> clear() => _serial(() async {
    await for (final entity in (await _dir()).list(followLinks: false)) {
      if (entity is File && _name.hasMatch(entity.uri.pathSegments.last)) {
        await entity.delete();
      }
    }
  });
}
