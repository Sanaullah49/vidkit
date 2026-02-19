import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// HLS-specific tuning for pre-caching behavior.
class HlsCacheOptions {
  /// Number of additional fetch cycles for live/event media playlists.
  ///
  /// A value of `0` performs a single snapshot fetch.
  final int livePlaylistUpdates;

  /// Fixed delay between live playlist refreshes.
  ///
  /// If `null`, a delay based on target duration is used.
  final Duration? livePlaylistUpdateInterval;

  /// Number of retries for transient network failures.
  final int requestRetries;

  /// Base backoff between retries.
  final Duration retryBackoff;

  /// Whether to continue when live segments disappear during refresh.
  final bool skipMissingLiveSegments;

  /// Whether to append `#EXT-X-ENDLIST` to live snapshots for offline playback.
  final bool finalizeLiveAsVod;

  /// Creates [HlsCacheOptions].
  const HlsCacheOptions({
    this.livePlaylistUpdates = 2,
    this.livePlaylistUpdateInterval,
    this.requestRetries = 2,
    this.retryBackoff = const Duration(milliseconds: 300),
    this.skipMissingLiveSegments = true,
    this.finalizeLiveAsVod = true,
  });
}

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

  /// HLS cache behavior controls.
  final HlsCacheOptions hlsOptions;

  final http.Client Function() _clientFactory;

  Directory? _cacheDir;
  final Map<String, Completer<File?>> _activeDownloads = {};

  static final RegExp _uriAttributePattern = RegExp(
    'URI=(?:\\"([^\\"]+)\\"|\'([^\']+)\'|([^,]+))',
  );

  /// Creates a [VideoCacheManager].
  VideoCacheManager({
    this.maxCacheSize = 500 * 1024 * 1024, // 500 MB default
    this.directoryName,
    this.hlsOptions = const HlsCacheOptions(),
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

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

  /// Generates a stable cache hash from a URL.
  String _cacheHash(String url) => md5.convert(utf8.encode(url)).toString();

  /// Generates a cache key (filename) from a URL.
  String _cacheKey(String url) {
    final extension = _extractVideoExtension(url);
    return '${_cacheHash(url)}$extension';
  }

  /// Extracts recognized video extension from URL.
  String _extractVideoExtension(String url) {
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

  /// Extracts any extension from URL path.
  String _extractPathExtension(String url, {String fallback = '.bin'}) {
    try {
      final uri = Uri.parse(url);
      final pathSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '';
      final ext = p.extension(pathSegment).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 10) {
        return ext;
      }
    } catch (_) {}
    return fallback;
  }

  bool _isHlsUrl(String url) {
    return _looksLikePlaylistUri(url);
  }

  bool _looksLikePlaylistUri(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('.m3u8')) return true;

    try {
      final uri = Uri.parse(value);
      return p.extension(uri.path).toLowerCase() == '.m3u8';
    } catch (_) {
      return false;
    }
  }

  bool _isHlsBundlePath(String path) => p.basename(path).endsWith('.hls');

  bool _isTempCachePath(String path) {
    final normalized = p.normalize(path);
    final segments = p.split(normalized);
    return segments.any((segment) => segment.endsWith('.tmp'));
  }

  Directory _hlsBundleDirectory(Directory cacheDir, String url) {
    return Directory(p.join(cacheDir.path, '${_cacheHash(url)}.hls'));
  }

  File _hlsManifestFile(Directory cacheDir, String url) {
    return File(p.join(_hlsBundleDirectory(cacheDir, url).path, 'index.m3u8'));
  }

  bool _isDownloadableUri(Uri uri) {
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  bool _isRetryableStatusCode(int code) {
    return code == 408 ||
        code == 429 ||
        code == 500 ||
        code == 502 ||
        code == 503 ||
        code == 504;
  }

  bool _isMissingSegmentStatusCode(int code) {
    return code == 404 || code == 410;
  }

  Duration _retryDelayForAttempt(int attempt) {
    final millis = hlsOptions.retryBackoff.inMilliseconds * (attempt + 1);
    return Duration(milliseconds: millis.clamp(50, 5000));
  }

  Duration _resolveLiveRefreshDelay({int? targetDurationSeconds}) {
    if (hlsOptions.livePlaylistUpdateInterval != null) {
      return hlsOptions.livePlaylistUpdateInterval!;
    }

    final target = (targetDurationSeconds ?? 4).clamp(1, 15);
    final millis = ((target * 1000) / 2).round().clamp(250, 2000);
    return Duration(milliseconds: millis);
  }

  bool _isLiveOnlyControlTag(String upper) {
    return upper.startsWith('#EXT-X-SERVER-CONTROL:') ||
        upper.startsWith('#EXT-X-PRELOAD-HINT:') ||
        upper.startsWith('#EXT-X-RENDITION-REPORT:') ||
        upper.startsWith('#EXT-X-SKIP:') ||
        upper.startsWith('#EXT-X-PART-INF:');
  }

  Future<http.StreamedResponse> _sendGetRequest(
    http.Client client,
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final retries = hlsOptions.requestRetries.clamp(0, 10);
    Object? lastError;

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final request = http.Request('GET', uri);
        if (headers != null) {
          request.headers.addAll(headers);
        }

        final response = await client.send(request);
        if (response.statusCode == 200) {
          return response;
        }

        final shouldRetry =
            attempt < retries && _isRetryableStatusCode(response.statusCode);
        if (!shouldRetry) {
          return response;
        }

        await response.stream.drain();
        await Future<void>.delayed(_retryDelayForAttempt(attempt));
      } catch (error) {
        lastError = error;
        if (attempt >= retries) break;
        await Future<void>.delayed(_retryDelayForAttempt(attempt));
      }
    }

    throw HttpException(
      'Failed to download resource: $uri (${lastError ?? 'unknown error'})',
    );
  }

  /// Returns the cached file for a URL if it exists.
  ///
  /// Returns `null` if the video is not cached.
  Future<File?> getCachedFile(String url) async {
    if (kIsWeb) return null;

    try {
      final dir = await cacheDirectory;

      // HLS is cached as a bundle directory with a rewritten local manifest.
      if (_isHlsUrl(url)) {
        final manifest = _hlsManifestFile(dir, url);
        if (manifest.existsSync() && manifest.lengthSync() > 0) {
          return manifest;
        }
      }

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

      // HLS needs full bundle caching (manifest + child playlists + segments/keys).
      if (_isHlsUrl(url)) {
        yield 0.0;
        final manifest = await _cacheHlsBundle(url, headers: headers);
        completer.complete(manifest);
        yield 1.0;
        return;
      }

      final dir = await cacheDirectory;
      final targetFile = File(p.join(dir.path, _cacheKey(url)));
      final tempFile = File('${targetFile.path}.tmp');

      // Start download
      final client = _clientFactory();

      try {
        final response = await _sendGetRequest(
          client,
          Uri.parse(url),
          headers: headers,
        );

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
        if (targetFile.existsSync()) {
          await targetFile.delete();
        }
        if (tempFile.existsSync()) {
          await tempFile.rename(targetFile.path);
        }

        completer.complete(targetFile);
        yield 1.0;
      } finally {
        client.close();
      }
    } catch (e) {
      await _cleanupTempArtifacts(url);
      completer.completeError(e);
      rethrow;
    } finally {
      _activeDownloads.remove(url);
    }
  }

  Future<File> _cacheHlsBundle(
    String url, {
    Map<String, String>? headers,
  }) async {
    final dir = await cacheDirectory;
    final bundleDir = _hlsBundleDirectory(dir, url);
    final cachedManifest = File(p.join(bundleDir.path, 'index.m3u8'));

    if (cachedManifest.existsSync() && cachedManifest.lengthSync() > 0) {
      return cachedManifest;
    }

    final tempBundleDir = Directory('${bundleDir.path}.tmp');
    if (tempBundleDir.existsSync()) {
      await tempBundleDir.delete(recursive: true);
    }
    await tempBundleDir.create(recursive: true);

    final rootUri = Uri.parse(url);
    final assignedPaths = <String, String>{rootUri.toString(): 'index.m3u8'};
    final completedPlaylists = <String>{};
    final activePlaylists = <String>{};
    final completedAssets = <String>{};

    final client = _clientFactory();

    String localPathFor(Uri remoteUri, {required bool isPlaylist}) {
      final remoteKey = remoteUri.toString();
      final existing = assignedPaths[remoteKey];
      if (existing != null) return existing;

      final hash = _cacheHash(remoteKey);
      final path = isPlaylist
          ? p.join('playlists', '$hash.m3u8')
          : p.join('assets', '$hash${_extractPathExtension(remoteKey)}');

      assignedPaths[remoteKey] = path;
      return path;
    }

    String relativePathForPlaylist({
      required String playlistLocalPath,
      required String targetLocalPath,
    }) {
      final fromDir = p.dirname(p.join(tempBundleDir.path, playlistLocalPath));
      final toPath = p.join(tempBundleDir.path, targetLocalPath);
      return p.relative(toPath, from: fromDir).replaceAll('\\', '/');
    }

    Future<void> cacheAsset(Uri assetUri) async {
      final assetKey = assetUri.toString();
      if (completedAssets.contains(assetKey)) return;

      if (!_isDownloadableUri(assetUri)) {
        throw HttpException(
          'Unsupported HLS asset URI scheme for offline cache: $assetUri',
        );
      }

      final localPath = localPathFor(assetUri, isPlaylist: false);
      final targetFile = File(p.join(tempBundleDir.path, localPath));
      final tempFile = File('${targetFile.path}.tmp');

      if (!targetFile.parent.existsSync()) {
        await targetFile.parent.create(recursive: true);
      }

      final response = await _sendGetRequest(
        client,
        assetUri,
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download HLS asset: HTTP ${response.statusCode} ($assetUri)',
        );
      }

      final sink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      if (targetFile.existsSync()) {
        await targetFile.delete();
      }
      if (tempFile.existsSync()) {
        await tempFile.rename(targetFile.path);
      }

      completedAssets.add(assetKey);
    }

    late Future<void> Function(Uri playlistUri) cachePlaylist;

    Future<String?> rewriteAttributeUri({
      required String line,
      required Uri playlistUri,
      required String playlistLocalPath,
      required bool? forcePlaylist,
      required bool allowMissingAsset,
    }) async {
      final match = _uriAttributePattern.firstMatch(line);
      if (match == null) return line;

      final rawUri = (match.group(1) ?? match.group(2) ?? match.group(3) ?? '')
          .trim();
      if (rawUri.isEmpty) return line;

      final remoteUri = playlistUri.resolve(rawUri);
      if (!_isDownloadableUri(remoteUri)) {
        // Keep non-network URI schemes (e.g. skd://, data:) untouched.
        return line;
      }

      final isPlaylist = forcePlaylist ?? _looksLikePlaylistUri(rawUri);
      final localPath = localPathFor(remoteUri, isPlaylist: isPlaylist);

      try {
        if (isPlaylist) {
          await cachePlaylist(remoteUri);
        } else {
          await cacheAsset(remoteUri);
        }
      } catch (_) {
        if (allowMissingAsset && !isPlaylist) {
          return null;
        }
        rethrow;
      }

      final relativePath = relativePathForPlaylist(
        playlistLocalPath: playlistLocalPath,
        targetLocalPath: localPath,
      );

      final quote = match.group(1) != null
          ? '"'
          : match.group(2) != null
          ? "'"
          : '';
      final replacement = quote.isEmpty
          ? 'URI=$relativePath'
          : 'URI=$quote$relativePath$quote';

      return line.replaceRange(match.start, match.end, replacement);
    }

    Future<_HlsPlaylistRewriteResult> fetchAndRewritePlaylist(
      Uri playlistUri, {
      required String playlistLocalPath,
      required bool allowMissingLiveSegments,
    }) async {
      final response = await _sendGetRequest(
        client,
        playlistUri,
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download HLS playlist: HTTP '
          '${response.statusCode} ($playlistUri)',
        );
      }

      final content = await response.stream.bytesToString();
      final lines = const LineSplitter().convert(content);

      final hasEndList = lines.any(
        (line) => line.trim().toUpperCase() == '#EXT-X-ENDLIST',
      );
      final isLikelyMediaPlaylist = lines.any(
        (line) => line.trim().toUpperCase().startsWith('#EXTINF:'),
      );
      final canSkipMissingLiveSegments =
          hlsOptions.skipMissingLiveSegments &&
          allowMissingLiveSegments &&
          isLikelyMediaPlaylist &&
          !hasEndList;

      final rewrittenLines = <String>[];
      var nextLineIsPlaylist = false;
      var rewrittenHasEndList = hasEndList;
      int? targetDurationSeconds;
      var isMediaPlaylist = isLikelyMediaPlaylist;
      int? segmentBlockStartIndex;

      for (final line in lines) {
        final trimmed = line.trim();

        if (trimmed.isEmpty) {
          rewrittenLines.add(line);
          nextLineIsPlaylist = false;
          segmentBlockStartIndex = null;
          continue;
        }

        if (trimmed.startsWith('#')) {
          final upper = trimmed.toUpperCase();

          if (upper.startsWith('#EXTINF:')) {
            isMediaPlaylist = true;
          }

          if (upper.startsWith('#EXT-X-TARGETDURATION:')) {
            targetDurationSeconds = _parseTargetDurationSeconds(trimmed);
          }

          if (upper == '#EXT-X-ENDLIST') {
            rewrittenHasEndList = true;
          }

          final isSegmentLinkedTag =
              upper.startsWith('#EXTINF:') ||
              upper.startsWith('#EXT-X-BYTERANGE:') ||
              upper.startsWith('#EXT-X-DISCONTINUITY') ||
              upper.startsWith('#EXT-X-PROGRAM-DATE-TIME:') ||
              upper.startsWith('#EXT-X-GAP');
          if (isSegmentLinkedTag && segmentBlockStartIndex == null) {
            segmentBlockStartIndex = rewrittenLines.length;
          }

          bool? forcePlaylist;
          if (upper.startsWith('#EXT-X-MEDIA:') ||
              upper.startsWith('#EXT-X-I-FRAME-STREAM-INF:') ||
              upper.startsWith('#EXT-X-RENDITION-REPORT:')) {
            forcePlaylist = true;
          } else if (upper.startsWith('#EXT-X-KEY:') ||
              upper.startsWith('#EXT-X-SESSION-KEY:') ||
              upper.startsWith('#EXT-X-MAP:') ||
              upper.startsWith('#EXT-X-PART:') ||
              upper.startsWith('#EXT-X-PRELOAD-HINT:')) {
            forcePlaylist = false;
          }

          final allowMissingAttributeAsset =
              canSkipMissingLiveSegments &&
              (upper.startsWith('#EXT-X-PART:') ||
                  upper.startsWith('#EXT-X-PRELOAD-HINT:'));

          final rewrittenComment = await rewriteAttributeUri(
            line: line,
            playlistUri: playlistUri,
            playlistLocalPath: playlistLocalPath,
            forcePlaylist: forcePlaylist,
            allowMissingAsset: allowMissingAttributeAsset,
          );

          if (rewrittenComment != null) {
            rewrittenLines.add(rewrittenComment);
          }

          nextLineIsPlaylist = upper.startsWith('#EXT-X-STREAM-INF:');
          if (!isSegmentLinkedTag && !nextLineIsPlaylist) {
            segmentBlockStartIndex = null;
          }
          continue;
        }

        final remoteUri = playlistUri.resolve(trimmed);
        final isPlaylist = nextLineIsPlaylist || _looksLikePlaylistUri(trimmed);

        if (!_isDownloadableUri(remoteUri)) {
          throw HttpException(
            'Unsupported HLS URI scheme for offline cache: $remoteUri',
          );
        }

        final targetLocalPath = localPathFor(remoteUri, isPlaylist: isPlaylist);

        try {
          if (isPlaylist) {
            await cachePlaylist(remoteUri);
          } else {
            await cacheAsset(remoteUri);
          }
        } catch (e) {
          final shouldSkipMissingSegment =
              canSkipMissingLiveSegments &&
              !isPlaylist &&
              e is HttpException &&
              _isMissingSegmentStatusCode(
                int.tryParse(
                      RegExp(r'HTTP (\d{3})').firstMatch(e.message)?.group(1) ??
                          '',
                    ) ??
                    -1,
              );

          if (shouldSkipMissingSegment) {
            if (segmentBlockStartIndex != null &&
                segmentBlockStartIndex <= rewrittenLines.length) {
              rewrittenLines.removeRange(
                segmentBlockStartIndex,
                rewrittenLines.length,
              );
            }
            nextLineIsPlaylist = false;
            segmentBlockStartIndex = null;
            continue;
          }
          rethrow;
        }

        rewrittenLines.add(
          relativePathForPlaylist(
            playlistLocalPath: playlistLocalPath,
            targetLocalPath: targetLocalPath,
          ),
        );
        nextLineIsPlaylist = false;
        segmentBlockStartIndex = null;
      }

      final rewrittenContent = _joinPlaylistLines(content, rewrittenLines);
      return _HlsPlaylistRewriteResult(
        content: rewrittenContent,
        isMediaPlaylist: isMediaPlaylist,
        hasEndList: rewrittenHasEndList,
        targetDurationSeconds: targetDurationSeconds,
      );
    }

    cachePlaylist = (Uri playlistUri) async {
      final playlistKey = playlistUri.toString();
      if (completedPlaylists.contains(playlistKey) ||
          activePlaylists.contains(playlistKey)) {
        return;
      }

      activePlaylists.add(playlistKey);
      try {
        final localPath = localPathFor(playlistUri, isPlaylist: true);
        var rewriteResult = await fetchAndRewritePlaylist(
          playlistUri,
          playlistLocalPath: localPath,
          allowMissingLiveSegments: false,
        );

        if (rewriteResult.isLiveMedia && hlsOptions.livePlaylistUpdates > 0) {
          for (var i = 0; i < hlsOptions.livePlaylistUpdates; i++) {
            await Future<void>.delayed(
              _resolveLiveRefreshDelay(
                targetDurationSeconds: rewriteResult.targetDurationSeconds,
              ),
            );

            rewriteResult = await fetchAndRewritePlaylist(
              playlistUri,
              playlistLocalPath: localPath,
              allowMissingLiveSegments: true,
            );

            if (!rewriteResult.isLiveMedia) {
              break;
            }
          }
        }

        if (rewriteResult.isLiveMedia && hlsOptions.finalizeLiveAsVod) {
          rewriteResult = rewriteResult.copyWith(
            content: _finalizeLiveSnapshotContent(rewriteResult.content),
            hasEndList: true,
          );
        }

        final localFile = File(p.join(tempBundleDir.path, localPath));

        if (!localFile.parent.existsSync()) {
          await localFile.parent.create(recursive: true);
        }

        await localFile.writeAsString(rewriteResult.content, flush: true);
        completedPlaylists.add(playlistKey);
      } finally {
        activePlaylists.remove(playlistKey);
      }
    };

    try {
      await cachePlaylist(rootUri);

      final manifestInTemp = File(p.join(tempBundleDir.path, 'index.m3u8'));
      if (!manifestInTemp.existsSync() || manifestInTemp.lengthSync() == 0) {
        throw const FileSystemException(
          'Failed to generate local HLS manifest',
        );
      }

      if (bundleDir.existsSync()) {
        await bundleDir.delete(recursive: true);
      }

      await tempBundleDir.rename(bundleDir.path);
      return File(p.join(bundleDir.path, 'index.m3u8'));
    } catch (e) {
      if (tempBundleDir.existsSync()) {
        await tempBundleDir.delete(recursive: true);
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  int? _parseTargetDurationSeconds(String line) {
    final value = line.split(':').skip(1).join(':').trim();
    if (value.isEmpty) return null;

    final whole = value.split('.').first.trim();
    return int.tryParse(whole);
  }

  String _finalizeLiveSnapshotContent(String content) {
    final lines = const LineSplitter().convert(content);
    final filtered = <String>[];

    for (final line in lines) {
      final upper = line.trim().toUpperCase();
      if (_isLiveOnlyControlTag(upper)) {
        continue;
      }
      filtered.add(line);
    }

    final hasEndList = filtered.any(
      (line) => line.trim().toUpperCase() == '#EXT-X-ENDLIST',
    );
    if (!hasEndList) {
      filtered.add('#EXT-X-ENDLIST');
    }

    return _joinPlaylistLines(content, filtered);
  }

  String _joinPlaylistLines(String original, List<String> lines) {
    final separator = original.contains('\r\n') ? '\r\n' : '\n';
    var joined = lines.join(separator);

    if (original.endsWith('\n')) {
      joined = '$joined$separator';
    }

    return joined;
  }

  Future<void> _cleanupTempArtifacts(String url) async {
    try {
      final dir = await cacheDirectory;

      final tempFile = File(p.join(dir.path, '${_cacheKey(url)}.tmp'));
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }

      final tempBundleDir = Directory(
        '${_hlsBundleDirectory(dir, url).path}.tmp',
      );
      if (tempBundleDir.existsSync()) {
        await tempBundleDir.delete(recursive: true);
      }
    } catch (_) {}
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
    var removed = false;

    try {
      final dir = await cacheDirectory;

      if (_isHlsUrl(url)) {
        final bundleDir = _hlsBundleDirectory(dir, url);
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
          removed = true;
        }

        final tempBundleDir = Directory('${bundleDir.path}.tmp');
        if (tempBundleDir.existsSync()) {
          await tempBundleDir.delete(recursive: true);
        }
      }

      final file = File(p.join(dir.path, _cacheKey(url)));
      if (file.existsSync()) {
        await file.delete();
        removed = true;
      }
    } catch (e) {
      debugPrint('VidKit cache remove error: $e');
    }

    return removed;
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

      var total = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && !_isTempCachePath(entity.path)) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Returns the number of cached videos.
  ///
  /// Regular videos are counted per file. HLS is counted per bundle.
  Future<int> get cachedFileCount async {
    try {
      final dir = await cacheDirectory;
      if (!dir.existsSync()) return 0;

      var count = 0;
      await for (final entity in dir.list()) {
        if (entity is File && !_isTempCachePath(entity.path)) {
          count++;
          continue;
        }

        if (entity is Directory && _isHlsBundlePath(entity.path)) {
          final manifest = File(p.join(entity.path, 'index.m3u8'));
          if (manifest.existsSync() && manifest.lengthSync() > 0) {
            count++;
          }
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

  Future<int> _directorySize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && !_isTempCachePath(entity.path)) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Enforces the maximum cache size by removing oldest entries.
  Future<void> _enforceMaxCacheSize() async {
    try {
      final dir = await cacheDirectory;
      if (!dir.existsSync()) return;

      final entries = <_CacheEntry>[];
      var totalSize = 0;

      await for (final entity in dir.list()) {
        if (entity is File && !_isTempCachePath(entity.path)) {
          final size = await entity.length();
          final modified = await entity.lastModified();
          entries.add(
            _CacheEntry(entity: entity, size: size, lastModified: modified),
          );
          totalSize += size;
          continue;
        }

        if (entity is Directory && _isHlsBundlePath(entity.path)) {
          final manifest = File(p.join(entity.path, 'index.m3u8'));
          if (!manifest.existsSync()) continue;

          final size = await _directorySize(entity);
          final modified = await manifest.lastModified();
          entries.add(
            _CacheEntry(entity: entity, size: size, lastModified: modified),
          );
          totalSize += size;
        }
      }

      if (totalSize <= maxCacheSize) return;

      // Sort by last modified (oldest first)
      entries.sort((a, b) => a.lastModified.compareTo(b.lastModified));

      // Remove oldest entries until under limit
      for (final entry in entries) {
        if (totalSize <= maxCacheSize * 0.8) break; // Keep 20% buffer

        if (entry.entity is Directory) {
          await (entry.entity as Directory).delete(recursive: true);
        } else if (entry.entity is File) {
          await (entry.entity as File).delete();
        }

        totalSize -= entry.size;
      }
    } catch (e) {
      debugPrint('VidKit cache cleanup error: $e');
    }
  }
}

class _HlsPlaylistRewriteResult {
  final String content;
  final bool isMediaPlaylist;
  final bool hasEndList;
  final int? targetDurationSeconds;

  const _HlsPlaylistRewriteResult({
    required this.content,
    required this.isMediaPlaylist,
    required this.hasEndList,
    required this.targetDurationSeconds,
  });

  bool get isLiveMedia => isMediaPlaylist && !hasEndList;

  _HlsPlaylistRewriteResult copyWith({
    String? content,
    bool? isMediaPlaylist,
    bool? hasEndList,
    int? targetDurationSeconds,
  }) {
    return _HlsPlaylistRewriteResult(
      content: content ?? this.content,
      isMediaPlaylist: isMediaPlaylist ?? this.isMediaPlaylist,
      hasEndList: hasEndList ?? this.hasEndList,
      targetDurationSeconds:
          targetDurationSeconds ?? this.targetDurationSeconds,
    );
  }
}

class _CacheEntry {
  final FileSystemEntity entity;
  final int size;
  final DateTime lastModified;

  const _CacheEntry({
    required this.entity,
    required this.size,
    required this.lastModified,
  });
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
