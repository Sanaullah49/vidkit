import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../cache/video_cache_manager.dart';
import '../playlist/playlist_manager.dart';
import '../quality/quality_manager.dart';

/// Configuration for VidKit player.
class VidKitConfig {
  /// Whether to enable video caching.
  final bool enableCache;

  /// Maximum cache size in bytes (default: 500 MB).
  final int maxCacheSize;

  /// Whether to auto-play when ready.
  final bool autoPlay;

  /// Whether to loop the video.
  final bool looping;

  /// Initial volume (0.0 to 1.0).
  final double volume;

  /// Playback speed (0.5 to 2.0).
  final double playbackSpeed;

  /// Whether to allow background audio.
  final bool allowBackgroundPlayback;

  /// Connection timeout for network videos.
  final Duration connectionTimeout;

  /// Headers for network requests.
  final Map<String, String>? httpHeaders;

  /// Whether to preload the next video in playlist.
  final bool preloadNext;

  /// Custom cache directory name.
  final String? cacheDirectoryName;

  /// Creates a [VidKitConfig].
  const VidKitConfig({
    this.enableCache = true,
    this.maxCacheSize = 500 * 1024 * 1024,
    this.autoPlay = false,
    this.looping = false,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.allowBackgroundPlayback = false,
    this.connectionTimeout = const Duration(seconds: 30),
    this.httpHeaders,
    this.preloadNext = true,
    this.cacheDirectoryName,
  });

  /// Creates a copy with optional overrides.
  VidKitConfig copyWith({
    bool? enableCache,
    int? maxCacheSize,
    bool? autoPlay,
    bool? looping,
    double? volume,
    double? playbackSpeed,
    bool? preloadNext,
    Map<String, String>? httpHeaders,
  }) {
    return VidKitConfig(
      enableCache: enableCache ?? this.enableCache,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      autoPlay: autoPlay ?? this.autoPlay,
      looping: looping ?? this.looping,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      allowBackgroundPlayback: allowBackgroundPlayback,
      connectionTimeout: connectionTimeout,
      httpHeaders: httpHeaders ?? this.httpHeaders,
      preloadNext: preloadNext ?? this.preloadNext,
      cacheDirectoryName: cacheDirectoryName,
    );
  }
}

/// Represents a video source.
class VideoSource {
  /// The URL or file path.
  final String url;

  /// The type of video source.
  final VideoSourceType type;

  /// Display title for the video.
  final String? title;

  /// Thumbnail URL.
  final String? thumbnailUrl;

  /// Duration if known ahead of time.
  final Duration? duration;

  /// Available quality variants.
  final List<QualityOption>? qualities;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Custom HTTP headers for this specific video.
  final Map<String, String>? headers;

  /// Creates a [VideoSource].
  const VideoSource({
    required this.url,
    this.type = VideoSourceType.network,
    this.title,
    this.thumbnailUrl,
    this.duration,
    this.qualities,
    this.metadata,
    this.headers,
  });

  /// Creates a network video source.
  factory VideoSource.network(
    String url, {
    String? title,
    String? thumbnailUrl,
    List<QualityOption>? qualities,
    Map<String, String>? headers,
  }) {
    return VideoSource(
      url: url,
      type: VideoSourceType.network,
      title: title,
      thumbnailUrl: thumbnailUrl,
      qualities: qualities,
      headers: headers,
    );
  }

  /// Creates an asset video source.
  factory VideoSource.asset(String assetPath, {String? title}) {
    return VideoSource(
      url: assetPath,
      type: VideoSourceType.asset,
      title: title,
    );
  }

  /// Creates a file video source.
  factory VideoSource.file(String filePath, {String? title}) {
    return VideoSource(url: filePath, type: VideoSourceType.file, title: title);
  }

  @override
  String toString() => 'VideoSource(${title ?? url})';
}

/// Types of video sources.
enum VideoSourceType {
  /// Network/URL video.
  network,

  /// Asset video bundled with the app.
  asset,

  /// Local file video.
  file,
}

/// Represents the current state of the video player.
enum VidKitState {
  /// Player is not initialized.
  idle,

  /// Player is initializing/buffering.
  loading,

  /// Player is ready to play.
  ready,

  /// Video is playing.
  playing,

  /// Video is paused.
  paused,

  /// Video playback completed.
  completed,

  /// An error occurred.
  error,
}

/// Information about the current video state.
class VidKitValue {
  /// Current player state.
  final VidKitState state;

  /// Current playback position.
  final Duration position;

  /// Total video duration.
  final Duration duration;

  /// Buffered position.
  final Duration buffered;

  /// Current volume (0.0 to 1.0).
  final double volume;

  /// Current playback speed.
  final double playbackSpeed;

  /// Whether the video is playing.
  final bool isPlaying;

  /// Whether the video is buffering.
  final bool isBuffering;

  /// Whether caching is active.
  final bool isCaching;

  /// Cache progress (0.0 to 1.0).
  final double cacheProgress;

  /// Whether the video is served from cache.
  final bool isFromCache;

  /// Video aspect ratio.
  final double aspectRatio;

  /// Video size.
  final Size? videoSize;

  /// Current quality label.
  final String? currentQuality;

  /// Error message if state is error.
  final String? errorMessage;

  /// Current video source.
  final VideoSource? source;

  /// Current playlist index (-1 if no playlist).
  final int playlistIndex;

  /// Total items in playlist.
  final int playlistLength;

  /// Creates a [VidKitValue].
  const VidKitValue({
    this.state = VidKitState.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCaching = false,
    this.cacheProgress = 0.0,
    this.isFromCache = false,
    this.aspectRatio = 16 / 9,
    this.videoSize,
    this.currentQuality,
    this.errorMessage,
    this.source,
    this.playlistIndex = -1,
    this.playlistLength = 0,
  });

  /// Creates a copy with overrides.
  VidKitValue copyWith({
    VidKitState? state,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? volume,
    double? playbackSpeed,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCaching,
    double? cacheProgress,
    bool? isFromCache,
    double? aspectRatio,
    Size? videoSize,
    String? currentQuality,
    String? errorMessage,
    VideoSource? source,
    int? playlistIndex,
    int? playlistLength,
  }) {
    return VidKitValue(
      state: state ?? this.state,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCaching: isCaching ?? this.isCaching,
      cacheProgress: cacheProgress ?? this.cacheProgress,
      isFromCache: isFromCache ?? this.isFromCache,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      videoSize: videoSize ?? this.videoSize,
      currentQuality: currentQuality ?? this.currentQuality,
      errorMessage: errorMessage ?? this.errorMessage,
      source: source ?? this.source,
      playlistIndex: playlistIndex ?? this.playlistIndex,
      playlistLength: playlistLength ?? this.playlistLength,
    );
  }

  /// Progress as a value between 0.0 and 1.0.
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Remaining time.
  Duration get remaining => duration - position;

  /// Whether the video has completed playback.
  bool get isCompleted => state == VidKitState.completed;

  /// Whether there is a next video in the playlist.
  bool get hasNext => playlistIndex < playlistLength - 1;

  /// Whether there is a previous video in the playlist.
  bool get hasPrevious => playlistIndex > 0;
}

/// Main controller for VidKit video player.
///
/// Manages video playback, caching, playlists, and quality switching.
///
/// ```dart
/// final controller = VidKitController(
///   source: VideoSource.network('https://example.com/video.mp4'),
/// );
/// await controller.initialize();
///
/// // In your widget tree:
/// VidKitPlayer(controller: controller)
/// ```
class VidKitController extends ValueNotifier<VidKitValue> {
  /// The video source.
  VideoSource? _currentSource;

  /// Player configuration.
  final VidKitConfig config;

  /// The underlying video player controller.
  VideoPlayerController? _videoController;

  /// Cache manager instance.
  VideoCacheManager? _cacheManager;

  /// Playlist manager.
  PlaylistManager? _playlistManager;

  /// Quality manager.
  QualityManager? _qualityManager;

  /// Timer for position updates.
  Timer? _positionTimer;

  /// Whether the controller has been disposed.
  bool _isDisposed = false;

  /// Listener for video player events.
  VoidCallback? _videoListener;

  /// Creates a [VidKitController] with a single video source.
  VidKitController({VideoSource? source, this.config = const VidKitConfig()})
    : super(const VidKitValue()) {
    _currentSource = source;
    if (config.enableCache && !kIsWeb) {
      _cacheManager = VideoCacheManager(
        maxCacheSize: config.maxCacheSize,
        directoryName: config.cacheDirectoryName,
      );
    }
  }

  /// Creates a [VidKitController] with a playlist.
  factory VidKitController.playlist({
    required List<VideoSource> sources,
    int initialIndex = 0,
    VidKitConfig config = const VidKitConfig(),
  }) {
    final controller = VidKitController(config: config);
    controller._playlistManager = PlaylistManager(
      sources: sources,
      initialIndex: initialIndex,
    );
    controller._currentSource = sources[initialIndex];
    controller._updatePlaylistState();
    return controller;
  }

  /// The underlying VideoPlayerController (for advanced use).
  VideoPlayerController? get videoController => _videoController;

  /// The cache manager (for cache operations).
  VideoCacheManager? get cacheManager => _cacheManager;

  /// Whether this controller manages a playlist.
  bool get isPlaylist => _playlistManager != null;

  // ─── Initialization ─────────────────────────────────────────────

  /// Initializes the video player.
  ///
  /// Must be called before the player can be used.
  /// Returns `true` if initialization was successful.
  Future<bool> initialize() async {
    if (_isDisposed) return false;
    if (_currentSource == null) return false;

    _updateState(VidKitState.loading);

    try {
      // Check cache for network videos
      String? cachedPath;
      if (_cacheManager != null &&
          _currentSource!.type == VideoSourceType.network) {
        final cachedFile = await _cacheManager!.getCachedFile(
          _currentSource!.url,
        );
        if (cachedFile != null) {
          cachedPath = cachedFile.path;
          value = value.copyWith(isFromCache: true, cacheProgress: 1.0);
        }
      }

      // Create the video player controller
      _videoController = _createVideoController(
        _currentSource!,
        cachedPath: cachedPath,
      );

      // Initialize
      await _videoController!.initialize();

      if (_isDisposed) return false;

      // Apply config
      await _videoController!.setVolume(config.volume);
      await _videoController!.setLooping(config.looping);
      await _videoController!.setPlaybackSpeed(config.playbackSpeed);

      // Set up quality manager if qualities available
      // Don't recreate if we already have one (preserves quality selection)
      if (_currentSource!.qualities != null &&
          _currentSource!.qualities!.isNotEmpty &&
          _qualityManager == null) {
        _qualityManager = QualityManager(qualities: _currentSource!.qualities!);
      }

      // Start listening to video player
      _setupVideoListener();

      // Start position tracking
      _startPositionTracking();

      // Update state
      final videoValue = _videoController!.value;
      value = value.copyWith(
        state: VidKitState.ready,
        duration: videoValue.duration,
        aspectRatio: videoValue.aspectRatio > 0
            ? videoValue.aspectRatio
            : 16 / 9,
        videoSize: videoValue.size,
        source: _currentSource,
        currentQuality: _qualityManager?.currentQuality?.label,
      );

      // Start caching in background (if not already cached)
      if (config.enableCache &&
          _currentSource!.type == VideoSourceType.network &&
          !value.isFromCache &&
          !kIsWeb) {
        _startBackgroundCache(_currentSource!);
      }

      // Auto play
      if (config.autoPlay) {
        await play();
      }

      // Preload next video in playlist
      if (config.preloadNext && _playlistManager != null) {
        _preloadNextVideo();
      }

      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _updateState(VidKitState.error, errorMessage: e.toString());
      return false;
    }
  }

  /// Creates the appropriate VideoPlayerController.
  VideoPlayerController _createVideoController(
    VideoSource source, {
    String? cachedPath,
  }) {
    final headers = <String, String>{
      ...?config.httpHeaders,
      ...?source.headers,
    };

    // If we have a cached path, use file controller
    if (cachedPath != null && !kIsWeb) {
      return VideoPlayerController.file(
        File(cachedPath),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: config.allowBackgroundPlayback,
        ),
      );
    }

    switch (source.type) {
      case VideoSourceType.network:
        return VideoPlayerController.networkUrl(
          Uri.parse(source.url),
          httpHeaders: headers.isNotEmpty ? headers : const {},
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: config.allowBackgroundPlayback,
          ),
        );

      case VideoSourceType.asset:
        return VideoPlayerController.asset(
          source.url,
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: config.allowBackgroundPlayback,
          ),
        );

      case VideoSourceType.file:
        return VideoPlayerController.file(
          File(source.url),
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: config.allowBackgroundPlayback,
          ),
        );
    }
  }

  void _setupVideoListener() {
    _videoListener = () {
      if (_isDisposed || _videoController == null) return;

      final v = _videoController!.value;

      if (v.hasError) {
        _updateState(
          VidKitState.error,
          errorMessage: v.errorDescription ?? 'Unknown playback error',
        );
        return;
      }

      value = value.copyWith(
        isBuffering: v.isBuffering,
        isPlaying: v.isPlaying,
      );

      // Detect completion
      if (v.isInitialized &&
          v.position >= v.duration &&
          v.duration > Duration.zero &&
          !v.isPlaying) {
        _onVideoCompleted();
      }
    };

    _videoController!.addListener(_videoListener!);
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_isDisposed || _videoController == null) return;

      final v = _videoController!.value;
      if (!v.isInitialized) return;

      final buffered = v.buffered.isNotEmpty
          ? v.buffered.last.end
          : Duration.zero;

      value = value.copyWith(position: v.position, buffered: buffered);
    });
  }

  void _onVideoCompleted() {
    if (config.looping) return;

    if (_playlistManager != null && _playlistManager!.hasNext) {
      next();
    } else {
      _updateState(VidKitState.completed);
    }
  }

  // ─── Playback Controls ─────────────────────────────────────────

  /// Starts or resumes playback.
  Future<void> play() async {
    if (_videoController == null || _isDisposed) return;

    if (value.state == VidKitState.completed) {
      await seekTo(Duration.zero);
    }

    await _videoController!.play();
    _updateState(VidKitState.playing);
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (_videoController == null || _isDisposed) return;
    await _videoController!.pause();
    _updateState(VidKitState.paused);
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() async {
    if (value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seeks to a specific position.
  Future<void> seekTo(Duration position) async {
    if (_videoController == null || _isDisposed) return;
    await _videoController!.seekTo(position);
    value = value.copyWith(position: position);
  }

  /// Seeks forward by the given duration.
  Future<void> seekForward([
    Duration duration = const Duration(seconds: 10),
  ]) async {
    final newPosition = value.position + duration;
    final clamped = newPosition > value.duration ? value.duration : newPosition;
    await seekTo(clamped);
  }

  /// Seeks backward by the given duration.
  Future<void> seekBackward([
    Duration duration = const Duration(seconds: 10),
  ]) async {
    final newPosition = value.position - duration;
    final clamped = newPosition < Duration.zero ? Duration.zero : newPosition;
    await seekTo(clamped);
  }

  /// Seeks to a position as a fraction (0.0 to 1.0).
  Future<void> seekToFraction(double fraction) async {
    final position = Duration(
      milliseconds: (value.duration.inMilliseconds * fraction.clamp(0.0, 1.0))
          .round(),
    );
    await seekTo(position);
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double vol) async {
    if (_videoController == null || _isDisposed) return;
    final clamped = vol.clamp(0.0, 1.0);
    await _videoController!.setVolume(clamped);
    value = value.copyWith(volume: clamped);
  }

  /// Toggles mute.
  Future<void> toggleMute() async {
    if (value.volume > 0) {
      await setVolume(0.0);
    } else {
      await setVolume(1.0);
    }
  }

  /// Sets the playback speed.
  Future<void> setPlaybackSpeed(double speed) async {
    if (_videoController == null || _isDisposed) return;
    final clamped = speed.clamp(0.25, 3.0);
    await _videoController!.setPlaybackSpeed(clamped);
    value = value.copyWith(playbackSpeed: clamped);
  }

  /// Sets looping mode.
  Future<void> setLooping(bool looping) async {
    if (_videoController == null || _isDisposed) return;
    await _videoController!.setLooping(looping);
  }

  // ─── Source Switching ───────────────────────────────────────────

  /// Changes the video source.
  Future<bool> changeSource(VideoSource source) async {
    if (_isDisposed) return false;

    final wasPlaying = value.isPlaying;
    await _disposeCurrentPlayer();

    _currentSource = source;
    value = value.copyWith(
      state: VidKitState.loading,
      position: Duration.zero,
      duration: Duration.zero,
      buffered: Duration.zero,
      isPlaying: false,
      isBuffering: false,
      isFromCache: false,
      cacheProgress: 0.0,
      isCaching: false,
      errorMessage: null,
    );
    _updatePlaylistState();

    final success = await initialize();

    if (success && wasPlaying) {
      await play();
    }

    return success;
  }

  // ─── Playlist Controls ─────────────────────────────────────────

  /// Plays the next video in the playlist.
  Future<bool> next() async {
    if (_playlistManager == null || !_playlistManager!.hasNext) {
      return false;
    }

    _playlistManager!.next();
    _currentSource = _playlistManager!.currentSource;
    _updatePlaylistState();

    return changeSource(_currentSource!);
  }

  /// Plays the previous video in the playlist.
  Future<bool> previous() async {
    if (_playlistManager == null) return false;

    // If more than 3 seconds in, restart current video
    if (value.position.inSeconds > 3) {
      await seekTo(Duration.zero);
      await play();
      return true;
    }

    if (!_playlistManager!.hasPrevious) return false;

    _playlistManager!.previous();
    _currentSource = _playlistManager!.currentSource;
    _updatePlaylistState();

    return changeSource(_currentSource!);
  }

  /// Jumps to a specific index in the playlist.
  Future<bool> jumpTo(int index) async {
    if (_playlistManager == null) return false;

    final source = _playlistManager!.jumpTo(index);
    if (source == null) return false;

    _currentSource = source;
    _updatePlaylistState();

    return changeSource(_currentSource!);
  }

  void _updatePlaylistState() {
    if (_playlistManager == null) return;
    value = value.copyWith(
      playlistIndex: _playlistManager!.currentIndex,
      playlistLength: _playlistManager!.length,
    );
  }

  // ─── Quality Switching ──────────────────────────────────────────

  /// Available quality options for the current video.
  List<QualityOption> get availableQualities =>
      _qualityManager?.qualities ?? [];

  /// Switches to a different quality.
  Future<bool> setQuality(QualityOption quality) async {
    if (_qualityManager == null || _isDisposed) return false;

    final currentPosition = value.position;
    final wasPlaying = value.isPlaying;

    _qualityManager!.setQuality(quality);

    // Create new source with the quality URL but keep original qualities list
    final newSource = VideoSource(
      url: quality.url,
      type: _currentSource!.type,
      title: _currentSource!.title,
      thumbnailUrl: _currentSource!.thumbnailUrl,
      qualities: _currentSource!.qualities,
      headers: _currentSource!.headers,
    );

    await _disposeCurrentPlayer();
    _currentSource = newSource;

    value = value.copyWith(
      state: VidKitState.loading,
      currentQuality: quality.label,
      position: Duration.zero,
      isPlaying: false,
    );

    final success = await initialize();
    if (success) {
      await seekTo(currentPosition);
      if (wasPlaying) await play();
    }

    return success;
  }

  // ─── Caching ────────────────────────────────────────────────────

  void _startBackgroundCache(VideoSource source) {
    if (_cacheManager == null) return;

    _cacheManager!
        .cacheVideo(
          source.url,
          headers: <String, String>{...?config.httpHeaders, ...?source.headers},
        )
        .listen(
          (progress) {
            if (_isDisposed) return;
            value = value.copyWith(
              isCaching: progress < 1.0,
              cacheProgress: progress,
            );
          },
          onError: (Object error) {
            debugPrint('VidKit cache error: $error');
          },
          onDone: () {
            if (_isDisposed) return;
            value = value.copyWith(isCaching: false, cacheProgress: 1.0);
          },
        );
  }

  void _preloadNextVideo() {
    if (_playlistManager == null || !_playlistManager!.hasNext) return;
    if (_cacheManager == null) return;

    final nextSource = _playlistManager!.peekNext();
    if (nextSource != null && nextSource.type == VideoSourceType.network) {
      _cacheManager!
          .cacheVideo(
            nextSource.url,
            headers: <String, String>{
              ...?config.httpHeaders,
              ...?nextSource.headers,
            },
          )
          .listen((_) {}, onError: (_) {});
    }
  }

  // ─── Internal Helpers ───────────────────────────────────────────

  void _updateState(VidKitState state, {String? errorMessage}) {
    if (_isDisposed) return;
    value = value.copyWith(
      state: state,
      errorMessage: errorMessage,
      isPlaying: state == VidKitState.playing,
    );
  }

  Future<void> _disposeCurrentPlayer() async {
    _positionTimer?.cancel();

    if (_videoController != null) {
      if (_videoListener != null) {
        _videoController!.removeListener(_videoListener!);
        _videoListener = null;
      }
      final oldController = _videoController!;
      _videoController = null; // Null out BEFORE disposing
      await oldController.dispose();
    }
  }

  // ─── Lifecycle ──────────────────────────────────────────────────

  @override
  void dispose() {
    _isDisposed = true;
    _positionTimer?.cancel();

    if (_videoController != null) {
      if (_videoListener != null) {
        _videoController!.removeListener(_videoListener!);
      }
      _videoController!.dispose();
    }

    super.dispose();
  }
}
