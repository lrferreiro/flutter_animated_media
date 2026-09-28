import 'dart:typed_data';

/// A public HTTPS resource, bundled asset, or caller-owned encoded file.
///
/// Memory sources need a stable, unique [identity] and an item version.
final class MediaSource {
  const MediaSource.asset(this.identity, {this.fallbackUri})
    : uri = null,
      bytes = null;

  MediaSource.network(Uri uri)
    : assert(uri.scheme == 'https'),
      identity = uri.toString(),
      uri = uri,
      fallbackUri = null,
      bytes = null;

  MediaSource.memory(this.identity, Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      uri = null,
      fallbackUri = null;

  final String identity;
  final Uri? uri;
  final Uri? fallbackUri;
  final Uint8List? bytes;

  bool get isAsset => uri == null && bytes == null;
}
