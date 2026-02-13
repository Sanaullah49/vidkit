import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/vidkit_controller.dart';
import 'vidkit_controls.dart';

/// A complete video player widget with built-in controls.
///
/// ```dart
/// VidKitPlayer(
///   controller: VidKitController(
///     source: VideoSource.network('https://example.com/video.mp4'),
///     config: VidKitConfig(autoPlay: true, enableCache: true),
///   ),
/// )
/// ```
class VidKitPlayer extends StatefulWidget {
  /// The VidKit controller.
  final VidKitController controller;

  /// Whether to show default controls overlay.
  final bool showControls;

  /// Whether to auto-hide controls after a delay.
  final bool autoHideControls;

  /// Delay before controls are hidden.
  final Duration controlsHideDelay;

  /// Custom controls overlay builder.
  final Widget Function(BuildContext, VidKitController)? controlsBuilder;

  /// Custom loading widget.
  final Widget? loadingWidget;

  /// Custom error widget builder.
  final Widget Function(BuildContext, String error)? errorBuilder;

  /// Placeholder widget shown before initialization.
  final Widget? placeholder;

  /// Background color.
  final Color backgroundColor;

  /// Whether to show cache indicator.
  final bool showCacheIndicator;

  /// Aspect ratio override (null = use video's aspect ratio).
  final double? aspectRatio;

  /// Whether tapping the video toggles play/pause.
  final bool tapToToggle;

  /// Whether double-tapping seeks forward/backward.
  final bool doubleTapToSeek;

  /// Duration to seek on double tap.
  final Duration doubleTapSeekDuration;

  /// Called when fullscreen is toggled.
  final VoidCallback? onFullscreenToggle;

  /// Creates a [VidKitPlayer].
  const VidKitPlayer({
    super.key,
    required this.controller,
    this.showControls = true,
    this.autoHideControls = true,
    this.controlsHideDelay = const Duration(seconds: 3),
    this.controlsBuilder,
    this.loadingWidget,
    this.errorBuilder,
    this.placeholder,
    this.backgroundColor = Colors.black,
    this.showCacheIndicator = true,
    this.aspectRatio,
    this.tapToToggle = true,
    this.doubleTapToSeek = true,
    this.doubleTapSeekDuration = const Duration(seconds: 10),
    this.onFullscreenToggle,
  });

  @override
  State<VidKitPlayer> createState() => _VidKitPlayerState();
}

class _VidKitPlayerState extends State<VidKitPlayer> {
  bool _showControls = true;
  Timer? _hideTimer;

  // Double tap tracking
  TapDownDetails? _lastTapDetails;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    if (!widget.autoHideControls) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.controlsHideDelay, () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTap() {
    if (widget.tapToToggle) {
      setState(() => _showControls = !_showControls);
      if (_showControls) {
        _startHideTimer();
      }
    }
  }

  void _onDoubleTap() {
    if (!widget.doubleTapToSeek) return;
    if (_lastTapDetails == null) return;

    final width = context.size?.width ?? 0;
    final tapX = _lastTapDetails!.localPosition.dx;

    if (tapX < width / 2) {
      widget.controller.seekBackward(widget.doubleTapSeekDuration);
    } else {
      widget.controller.seekForward(widget.doubleTapSeekDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VidKitValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final aspectRatio = widget.aspectRatio ?? value.aspectRatio;

        return Container(
          color: widget.backgroundColor,
          child: AspectRatio(
            aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video - only render when controller is valid and initialized
                if (value.state == VidKitState.error)
                  _buildError(value.errorMessage ?? 'Unknown error')
                else if (widget.controller.videoController != null &&
                    widget.controller.videoController!.value.isInitialized)
                  VideoPlayer(widget.controller.videoController!)
                else if (value.state == VidKitState.loading ||
                    value.state == VidKitState.idle)
                  _buildLoading()
                else
                  _buildPlaceholder(),

                // Tap area
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onTap,
                    onTapDown: (details) {
                      _lastTapDetails = details;
                    },
                    onDoubleTap: _onDoubleTap,
                    child: const SizedBox.expand(),
                  ),
                ),

                // Buffering indicator
                if (value.isBuffering && value.state != VidKitState.loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),

                // Controls overlay
                if (widget.showControls && _showControls)
                  Positioned.fill(
                    child:
                        widget.controlsBuilder?.call(
                          context,
                          widget.controller,
                        ) ??
                        VidKitControls(
                          controller: widget.controller,
                          showCacheIndicator: widget.showCacheIndicator,
                          onFullscreenToggle: widget.onFullscreenToggle,
                          onInteraction: _startHideTimer,
                        ),
                  ),

                // Cache indicator
                if (widget.showCacheIndicator &&
                    value.isCaching &&
                    !_showControls)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _CacheChip(progress: value.cacheProgress),
                  ),

                // "From cache" indicator
                if (value.isFromCache &&
                    _showControls &&
                    widget.showCacheIndicator)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.offline_bolt,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Cached',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return widget.loadingWidget ??
        const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
  }

  Widget _buildError(String error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 48),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => widget.controller.initialize(),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white38,
            size: 64,
          ),
        );
  }
}

class _CacheChip extends StatelessWidget {
  final double progress;

  const _CacheChip({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Caching ${(progress * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
