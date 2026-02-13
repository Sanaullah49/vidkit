import 'package:flutter/material.dart';

import '../core/vidkit_controller.dart';
import '../quality/quality_manager.dart';

/// Default controls overlay for VidKitPlayer.
class VidKitControls extends StatelessWidget {
  /// The VidKit controller.
  final VidKitController controller;

  /// Whether to show cache indicator in controls.
  final bool showCacheIndicator;

  /// Called when fullscreen is toggled.
  final VoidCallback? onFullscreenToggle;

  /// Called on any user interaction (for auto-hide timer reset).
  final VoidCallback? onInteraction;

  /// Creates [VidKitControls].
  const VidKitControls({
    super.key,
    required this.controller,
    this.showCacheIndicator = true,
    this.onFullscreenToggle,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VidKitValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black45,
                Colors.transparent,
                Colors.transparent,
                Colors.black54,
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Column(
            children: [
              // Top bar
              _buildTopBar(context, value),

              const Spacer(),

              // Center play button
              _buildCenterControls(value),

              const Spacer(),

              // Bottom bar with seek bar and controls
              _buildBottomBar(context, value),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, VidKitValue value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Title
          if (value.source?.title != null)
            Expanded(
              child: Text(
                value.source!.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),

          // Playlist indicator
          if (value.playlistLength > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${value.playlistIndex + 1}/${value.playlistLength}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(VidKitValue value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous
        if (value.playlistLength > 0)
          IconButton(
            onPressed: value.hasPrevious
                ? () {
                    onInteraction?.call();
                    controller.previous();
                  }
                : null,
            icon: Icon(
              Icons.skip_previous_rounded,
              color: value.hasPrevious ? Colors.white : Colors.white38,
              size: 36,
            ),
          ),

        const SizedBox(width: 16),

        // Seek backward
        IconButton(
          onPressed: () {
            onInteraction?.call();
            controller.seekBackward();
          },
          icon: const Icon(
            Icons.replay_10_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),

        const SizedBox(width: 8),

        // Play/Pause
        GestureDetector(
          onTap: () {
            onInteraction?.call();
            controller.togglePlayPause();
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              value.isCompleted
                  ? Icons.replay_rounded
                  : value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Seek forward
        IconButton(
          onPressed: () {
            onInteraction?.call();
            controller.seekForward();
          },
          icon: const Icon(
            Icons.forward_10_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),

        const SizedBox(width: 16),

        // Next
        if (value.playlistLength > 0)
          IconButton(
            onPressed: value.hasNext
                ? () {
                    onInteraction?.call();
                    controller.next();
                  }
                : null,
            icon: Icon(
              Icons.skip_next_rounded,
              color: value.hasNext ? Colors.white : Colors.white38,
              size: 36,
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, VidKitValue value) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
          _VidKitSeekBar(
            controller: controller,
            value: value,
            onInteraction: onInteraction,
          ),

          // Bottom controls row
          Row(
            children: [
              // Position / Duration
              Text(
                '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),

              const Spacer(),

              // Speed
              _SpeedButton(
                currentSpeed: value.playbackSpeed,
                onSpeedChanged: (speed) {
                  onInteraction?.call();
                  controller.setPlaybackSpeed(speed);
                },
              ),

              // Quality
              if (controller.availableQualities.isNotEmpty)
                _QualityButton(
                  qualities: controller.availableQualities,
                  currentQuality: value.currentQuality,
                  onQualityChanged: (quality) {
                    onInteraction?.call();
                    controller.setQuality(quality);
                  },
                ),

              // Volume
              IconButton(
                onPressed: () {
                  onInteraction?.call();
                  controller.toggleMute();
                },
                icon: Icon(
                  value.volume == 0
                      ? Icons.volume_off
                      : value.volume < 0.5
                      ? Icons.volume_down
                      : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),

              // Fullscreen
              if (onFullscreenToggle != null)
                IconButton(
                  onPressed: () {
                    onInteraction?.call();
                    onFullscreenToggle!();
                  },
                  icon: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 24,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

/// Seek bar with buffered progress.
class _VidKitSeekBar extends StatelessWidget {
  final VidKitController controller;
  final VidKitValue value;
  final VoidCallback? onInteraction;

  const _VidKitSeekBar({
    required this.controller,
    required this.value,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final duration = value.duration.inMilliseconds.toDouble();
    if (duration <= 0) return const SizedBox(height: 20);

    final position = value.position.inMilliseconds.toDouble().clamp(
      0.0,
      duration,
    );
    final buffered = value.buffered.inMilliseconds.toDouble().clamp(
      0.0,
      duration,
    );

    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Background
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),

          // Buffered progress
          FractionallySizedBox(
            widthFactor: buffered / duration,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),

          // Seek slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: position,
              min: 0,
              max: duration,
              onChanged: (val) {
                onInteraction?.call();
                controller.seekTo(Duration(milliseconds: val.round()));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Speed selection button.
class _SpeedButton extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const _SpeedButton({
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      onSelected: onSpeedChanged,
      itemBuilder: (context) => _speeds.map((speed) {
        return PopupMenuItem(
          value: speed,
          child: Row(
            children: [
              if (speed == currentSpeed)
                const Icon(Icons.check, size: 18)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text('${speed}x'),
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${currentSpeed}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Quality selection button.
class _QualityButton extends StatelessWidget {
  final List<QualityOption> qualities;
  final String? currentQuality;
  final ValueChanged<QualityOption> onQualityChanged;

  const _QualityButton({
    required this.qualities,
    required this.currentQuality,
    required this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<QualityOption>(
      onSelected: onQualityChanged,
      itemBuilder: (context) => qualities.map((quality) {
        return PopupMenuItem(
          value: quality,
          child: Row(
            children: [
              if (quality.label == currentQuality)
                const Icon(Icons.check, size: 18)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(quality.label),
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hd, color: Colors.white, size: 18),
            const SizedBox(width: 2),
            Text(
              currentQuality ?? 'Auto',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
