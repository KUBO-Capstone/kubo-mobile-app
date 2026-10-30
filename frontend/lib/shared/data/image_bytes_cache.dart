import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Downloaded photo bytes, shared by every size a photo is decoded at.
///
/// `Image.network` keys each download on the decode size, so one photo shown
/// as a grid thumbnail, a carousel slide and a full-screen view was fetched
/// three times. Photos load through here instead: one download per URL,
/// concurrent requests for the same URL share it, and the bytes stay in
/// memory (least recently used dropped first, up to [maxBytes]) so the next
/// size decodes without touching the network.
class ImageBytesCache {
  ImageBytesCache({this.maxBytes = 48 << 20});

  static final ImageBytesCache instance = ImageBytesCache();

  /// Upper bound on the compressed bytes kept in memory.
  final int maxBytes;

  // Iteration order is recency: [load] re-inserts on every hit.
  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> _inFlight = <String, Future<Uint8List>>{};
  int _bytes = 0;

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _bodyTimeout = Duration(seconds: 30);

  // `autoUncompress` stays off so Content-Length can be trusted for progress;
  // consolidateHttpClientResponseBytes inflates gzip bodies itself.
  static final HttpClient _sharedClient = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = _connectTimeout;

  /// Replaces the network in tests.
  @visibleForTesting
  static Future<Uint8List> Function(Uri uri)? debugFetch;

  /// Bytes held right now.
  int get sizeInBytes => _bytes;

  bool contains(String url) => _entries.containsKey(url);

  /// The bytes at [url], from memory when they are there. [onProgress] only
  /// hears about downloads this call started.
  Future<Uint8List> load(String url, {void Function(int received, int? total)? onProgress}) {
    final cached = _entries.remove(url);
    if (cached != null) {
      _entries[url] = cached;
      return SynchronousFuture<Uint8List>(cached);
    }
    final pending = _inFlight[url];
    if (pending != null) return pending;

    final future = () async {
      try {
        final bytes = await _fetch(url, onProgress);
        _store(url, bytes);
        return bytes;
      } finally {
        _inFlight.remove(url);
      }
    }();
    _inFlight[url] = future;
    return future;
  }

  /// Forgets [url], e.g. after its bytes failed to decode.
  void evict(String url) {
    final removed = _entries.remove(url);
    if (removed != null) _bytes -= removed.lengthInBytes;
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }

  void _store(String url, Uint8List bytes) {
    // A single photo bigger than the whole budget is decoded and dropped.
    if (bytes.lengthInBytes > maxBytes) return;
    evict(url);
    _entries[url] = bytes;
    _bytes += bytes.lengthInBytes;
    while (_bytes > maxBytes && _entries.isNotEmpty) {
      evict(_entries.keys.first);
    }
  }

  static HttpClient get _client {
    HttpClient? client;
    assert(() {
      if (debugNetworkImageHttpClientProvider != null) {
        client = debugNetworkImageHttpClientProvider!();
      }
      return true;
    }());
    return client ?? _sharedClient;
  }

  Future<Uint8List> _fetch(String url, void Function(int received, int? total)? onProgress) async {
    final uri = Uri.base.resolve(url);
    final fetch = debugFetch;
    if (fetch != null) return fetch(uri);

    final request = await _client.getUrl(uri);
    final response = await request.close().timeout(_connectTimeout);
    if (response.statusCode != HttpStatus.ok) {
      // Drain so the connection can be reused; the next build tries again.
      await response.drain<List<int>>(<int>[]);
      throw NetworkImageLoadException(statusCode: response.statusCode, uri: uri);
    }
    final bytes = await consolidateHttpClientResponseBytes(
      response,
      onBytesReceived: onProgress,
    ).timeout(_bodyTimeout);
    if (bytes.lengthInBytes == 0) {
      throw Exception('The photo at $uri is an empty file.');
    }
    return bytes;
  }
}
