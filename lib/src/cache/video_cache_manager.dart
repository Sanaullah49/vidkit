import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages video file caching on the device.
///
/// Downloads videos to local storage and serves them from cache
/// on subsequent plays, eliminating re-downloads.
///
/// ```dart
/// final cache = VideoCacheManager(maxCacheSize: 500 * 1024 * 1024);
///
/// // Check if cached
/// final file = await cache.getCachedFile(url);
///
/// // Cache a video with progress
/// cache.cacheVideo(url).listen((progress) {
///   print('${(progress * 100).toInt()}%');
/// });
/// ```
class VideoCacheManager {
  /// Maximum total cache size in bytes.
  final int maxCacheSize;

  /// Custom directory name for cache storage.
  final String? directoryName;

  Directory? _cacheDir;
  final Map<String, Completer<File?>> _activeDownloads = {};

  /// Creates a [VideoCacheManager].
  VideoCacheManager({
    this.maxCacheSize = 500 * 1024 * 1024, // 500 MB default
    this.directoryName,
  });

  /// Gets the cache directory, creating it if necessary.
  Future<Directory> get cacheDirectory async {
    if (_cacheDir != null) return _cacheDir!;

    final appDir = await getTemporaryDirectory();
    _cacheDir = Directory(p.join(appDir.path, directoryName ?? 'vidkit_cache'));

    if (!_cacheDir!.existsSync()) {
      await _cacheDir!.create(recursive: true);
    }

    return _cacheDir!;
  }

  /// Generates a cache key (filename) from a URL.
  String _cacheKey(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    final extension = _extractExtension(url);
    return '$hash$extension';
  }

  /// Extracts file extension from URL.
  String _extractExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '';
      final ext = p.extension(pathSegment).toLowerCase();
      if ([
        '.mp4',
        '.m4v',
        '.mov',
        '.avi',
        '.mkv',
        '.webm',
        '.m3u8',
      ].contains(ext)) {
        return ext;
      }
    } catch (_) {}
    return '.mp4';
  }

  /// Returns the cached file for a URL if it exists.
  ///
  /// Returns `null` if the video is not cached.
  Future<File?> getCachedFile(String url) async {
    if (kIsWeb) return null;

    try {
      final dir = await cacheDirectory;
      final file = File(p.join(dir.path, _cacheKey(url)));

      if (file.existsSync() && file.lengthSync() > 0) {
        return file;
      }
    } catch (e) {
      debugPrint('VidKit cache read error: $e');
    }

    return null;
  }

  /// Checks if a video URL is cached.
  Future<bool> isCached(String url) async {
    final file = await getCachedFile(url);
    return file != null;
  }

  /// Caches a video from URL, emitting download progress (0.0 to 1.0).
  ///
  /// If the video is already cached, immediately emits 1.0.
  /// If a download is already in progress for this URL, joins that download.
  Stream<double> cacheVideo(String url, {Map<String, String>? headers}) async* {
    if (kIsWeb) return;

    // Check if already cached
    final existing = await getCachedFile(url);
    if (existing != null) {
      yield 1.0;
      return;
    }

    // Check if download already in progress
    if (_activeDownloads.containsKey(url)) {
      // Wait for existing download
      await _activeDownloads[url]!.future;
      yield 1.0;
      return;
    }

    final completer = Completer<File?>();
    _activeDownloads[url] = completer;

    try {
      // Ensure we have space
      await _enforceMaxCacheSize();

      final dir = await cacheDirectory;
      final targetFile = File(p.join(dir.path, _cacheKey(url)));
      final tempFile = File('${targetFile.path}.tmp');

      // Start download
      final client = http.Client();

      try {
        final request = http.Request('GET', Uri.parse(url));
        if (headers != null) {
          request.headers.addAll(headers);
        }

        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw HttpException(
            'Failed to download video: HTTP ${response.statusCode}',
          );
        }

        final contentLength = response.contentLength ?? 0;
        int receivedBytes = 0;

        final sink = tempFile.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;

          if (contentLength > 0) {
            yield (receivedBytes / contentLength).clamp(0.0, 1.0);
          } else {
            // Unknown content length, show indeterminate
            yield 0.5;
          }
        }

        await sink.flush();
        await sink.close();

        // Move temp file to final location
        if (tempFile.existsSync()) {
          await tempFile.rename(targetFile.path);
        }

        completer.complete(targetFile);
        yield 1.0;
      } finally {
        client.close();
      }
    } catch (e) {
      // Clean up temp file
      try {
        final dir = await cacheDirectory;
        final tempFile = File(p.join(dir.path, '${_cacheKey(url)}.tmp'));
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
      } catch (_) {}

      completer.completeError(e);
      rethrow;
    } finally {
      _activeDownloads.remove(url);
    }
  }

  /// Pre-caches a video without progress tracking.
  ///
  /// Useful for preloading the next video in a playlist.
  Future<File?> preCache(String url, {Map<String, String>? headers}) async {
    if (kIsWeb) return null;

    try {
      await cacheVideo(url, headers: headers).last;
      return getCachedFile(url);
    } catch (e) {
      debugPrint('VidKit precache error: $e');
      return null;
    }
  }

  /// Removes a specific video from cache.
  Future<bool> removeFromCache(String url) async {
    try {
      final dir = await cacheDirectory;
      final file = File(p.join(dir.path, _cacheKey(url)));

      if (file.existsSync()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('VidKit cache remove error: $e');
    }
    return false;
  }

  /// Clears the entire video cache.
  Future<void> clearCache() async {
    try {
      final dir = await cacheDirectory;
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('VidKit cache clear error: $e');
    }
  }

  /// Returns the total size of cached files in bytes.
  Future<int> get cacheSize async {
    try {
      final dir = await cacheDirectory;
      if (!dir.existsSync()) return 0;

      int total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Returns the number of cached video files.
  Future<int> get cachedFileCount async {
    try {
      final dir = await cacheDirectory;
      if (!dir.existsSync()) return 0;

      int count = 0;
      await for (final entity in dir.list()) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Returns cache info summary.
  Future<CacheInfo> get info async {
    final size = await cacheSize;
    final count = await cachedFileCount;
    return CacheInfo(totalSize: size, fileCount: count, maxSize: maxCacheSize);
  }

  /// Enforces the maximum cache size by removing oldest files.
  Future<void> _enforceMaxCacheSize() async {
    try {
      final dir = await cacheDirectory;
      if (!dir.existsSync()) return;

      final files = <File>[];
      int totalSize = 0;

      await for (final entity in dir.list()) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          files.add(entity);
          totalSize += await entity.length();
        }
      }

      if (totalSize <= maxCacheSize) return;

      // Sort by last modified (oldest first)
      files.sort((a, b) {
        return a.lastModifiedSync().compareTo(b.lastModifiedSync());
      });

      // Remove oldest files until under limit
      for (final file in files) {
        if (totalSize <= maxCacheSize * 0.8) break; // Keep 20% buffer
        final fileSize = await file.length();
        await file.delete();
        totalSize -= fileSize;
      }
    } catch (e) {
      debugPrint('VidKit cache cleanup error: $e');
    }
  }
}

/// Information about the current cache state.
class CacheInfo {
  /// Total size of cached files in bytes.
  final int totalSize;

  /// Number of cached files.
  final int fileCount;

  /// Maximum allowed cache size in bytes.
  final int maxSize;

  /// Creates a [CacheInfo].
  const CacheInfo({
    required this.totalSize,
    required this.fileCount,
    required this.maxSize,
  });

  /// Total size in megabytes.
  double get totalSizeMB => totalSize / (1024 * 1024);

  /// Maximum size in megabytes.
  double get maxSizeMB => maxSize / (1024 * 1024);

  /// Cache usage as a fraction (0.0 to 1.0).
  double get usage => maxSize > 0 ? (totalSize / maxSize).clamp(0.0, 1.0) : 0.0;

  @override
  String toString() =>
      'CacheInfo(${totalSizeMB.toStringAsFixed(1)} MB / '
      '${maxSizeMB.toStringAsFixed(0)} MB, $fileCount files)';
}
