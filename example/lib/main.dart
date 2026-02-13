import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidkit/vidkit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidKit Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}

// ─── Sample Videos ───────────────────────────────────────────────────

class _SampleVideos {
  static const bunny =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
  static const bee =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  static const sample1 =
      'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4';
  static const sample2 =
      'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_2mb.mp4';
  static const sample3 =
      'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_5mb.mp4';
}

// ─── Home Page ───────────────────────────────────────────────────────

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VidKit Examples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExampleCard(
            title: 'Simple Player',
            subtitle: 'Single video with caching and controls',
            icon: Icons.play_circle_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SimplePlayerExample()),
            ),
          ),
          const SizedBox(height: 12),
          _ExampleCard(
            title: 'Playlist',
            subtitle: 'Multiple videos with next/previous and preloading',
            icon: Icons.playlist_play,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlaylistExample()),
            ),
          ),
          const SizedBox(height: 12),
          _ExampleCard(
            title: 'Quality Switching',
            subtitle: 'Switch between video quality options',
            icon: Icons.hd,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const QualitySwitchingExample(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ExampleCard(
            title: 'Cache Manager',
            subtitle: 'View cache status, pre-cache, and clear cache',
            icon: Icons.storage,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CacheManagerExample()),
            ),
          ),
          const SizedBox(height: 12),
          _ExampleCard(
            title: 'Fullscreen',
            subtitle: 'Landscape fullscreen with rotation',
            icon: Icons.fullscreen,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FullscreenExample()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ExampleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─── Example 1: Simple Player ────────────────────────────────────────

class SimplePlayerExample extends StatefulWidget {
  const SimplePlayerExample({super.key});

  @override
  State<SimplePlayerExample> createState() => _SimplePlayerExampleState();
}

class _SimplePlayerExampleState extends State<SimplePlayerExample> {
  late final VidKitController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VidKitController(
      source: VideoSource.network(_SampleVideos.bunny, title: 'Big Buck Bunny'),
      config: const VidKitConfig(autoPlay: true, enableCache: true),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Player')),
      body: Column(
        children: [
          // Player
          VidKitPlayer(controller: _controller),

          // Status info
          Expanded(
            child: ValueListenableBuilder<VidKitValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _InfoRow('State', value.state.name),
                    _InfoRow('Position', _formatDuration(value.position)),
                    _InfoRow('Duration', _formatDuration(value.duration)),
                    _InfoRow('Buffered', _formatDuration(value.buffered)),
                    _InfoRow('Volume', '${(value.volume * 100).toInt()}%'),
                    _InfoRow('Speed', '${value.playbackSpeed}x'),
                    _InfoRow('From Cache', value.isFromCache.toString()),
                    _InfoRow(
                      'Caching',
                      value.isCaching
                          ? '${(value.cacheProgress * 100).toInt()}%'
                          : 'No',
                    ),
                    _InfoRow(
                      'Aspect Ratio',
                      value.aspectRatio.toStringAsFixed(2),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Example 2: Playlist ─────────────────────────────────────────────

class PlaylistExample extends StatefulWidget {
  const PlaylistExample({super.key});

  @override
  State<PlaylistExample> createState() => _PlaylistExampleState();
}

class _PlaylistExampleState extends State<PlaylistExample> {
  late final VidKitController _controller;

  final _videos = [
    VideoSource.network(_SampleVideos.bunny, title: 'Butterfly'),
    VideoSource.network(_SampleVideos.bee, title: 'Bee'),
    VideoSource.network(_SampleVideos.sample1, title: 'Big Buck Bunny 1MB'),
    VideoSource.network(_SampleVideos.sample2, title: 'Big Buck Bunny 2MB'),
    VideoSource.network(_SampleVideos.sample3, title: 'Big Buck Bunny 5MB'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = VidKitController.playlist(
      sources: _videos,
      config: const VidKitConfig(
        autoPlay: true,
        enableCache: true,
        preloadNext: true,
      ),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: Column(
        children: [
          // Player
          VidKitPlayer(controller: _controller),

          // Playlist
          Expanded(
            child: ValueListenableBuilder<VidKitValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final isPlaying = index == value.playlistIndex;
                    return Card(
                      color: isPlaying
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPlaying
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: isPlaying
                              ? const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                        title: Text(
                          _videos[index].title ?? 'Video ${index + 1}',
                          style: TextStyle(
                            fontWeight: isPlaying
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: isPlaying
                            ? Text(
                                '${_formatDuration(value.position)} / '
                                '${_formatDuration(value.duration)}',
                              )
                            : null,
                        onTap: () => _controller.jumpTo(index),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Example 3: Quality Switching ────────────────────────────────────

class QualitySwitchingExample extends StatefulWidget {
  const QualitySwitchingExample({super.key});

  @override
  State<QualitySwitchingExample> createState() =>
      _QualitySwitchingExampleState();
}

class _QualitySwitchingExampleState extends State<QualitySwitchingExample> {
  late final VidKitController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VidKitController(
      source: VideoSource.network(
        _SampleVideos.bunny,
        title: 'Big Buck Bunny',
        qualities: const [
          QualityOption(label: '1080p', url: _SampleVideos.bunny, height: 1080),
          QualityOption(label: '720p', url: _SampleVideos.bunny, height: 720),
          QualityOption(label: '480p', url: _SampleVideos.bunny, height: 480),
        ],
      ),
      config: const VidKitConfig(autoPlay: true),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quality Switching')),
      body: Column(
        children: [
          VidKitPlayer(controller: _controller),
          Expanded(
            child: ValueListenableBuilder<VidKitValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Quality: ${value.currentQuality ?? "Auto"}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      const Text('Tap a quality option to switch:'),
                      const SizedBox(height: 8),
                      ...(_controller.availableQualities).map((quality) {
                        final isSelected =
                            quality.label == value.currentQuality;
                        return Card(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(quality.label),
                            subtitle: quality.height != null
                                ? Text('${quality.height}p resolution')
                                : null,
                            onTap: () => _controller.setQuality(quality),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Example 4: Cache Manager ────────────────────────────────────────

class CacheManagerExample extends StatefulWidget {
  const CacheManagerExample({super.key});

  @override
  State<CacheManagerExample> createState() => _CacheManagerExampleState();
}

class _CacheManagerExampleState extends State<CacheManagerExample> {
  final _cacheManager = VideoCacheManager();
  CacheInfo? _cacheInfo;
  final Map<String, bool> _cachedStatus = {};
  final Map<String, double> _downloadProgress = {};

  final _videos = {
    'Butterfly': _SampleVideos.bunny,
    'Bee': _SampleVideos.bee,
    'Big Buck Bunny 1MB': _SampleVideos.sample1,
    'Big Buck Bunny 2MB': _SampleVideos.sample2,
  };

  @override
  void initState() {
    super.initState();
    _refreshCacheInfo();
  }

  Future<void> _refreshCacheInfo() async {
    final info = await _cacheManager.info;
    final status = <String, bool>{};
    for (final entry in _videos.entries) {
      status[entry.key] = await _cacheManager.isCached(entry.value);
    }
    if (mounted) {
      setState(() {
        _cacheInfo = info;
        _cachedStatus.addAll(status);
      });
    }
  }

  void _preCacheVideo(String name, String url) {
    setState(() => _downloadProgress[name] = 0.0);

    _cacheManager
        .cacheVideo(url)
        .listen(
          (progress) {
            if (mounted) {
              setState(() => _downloadProgress[name] = progress);
            }
          },
          onDone: () {
            if (mounted) {
              setState(() => _downloadProgress.remove(name));
              _refreshCacheInfo();
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(() => _downloadProgress.remove(name));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error caching $name: $error')),
              );
            }
          },
        );
  }

  Future<void> _clearCache() async {
    await _cacheManager.clearCache();
    await _refreshCacheInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearCache,
            tooltip: 'Clear all cache',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCacheInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cache info card
          if (_cacheInfo != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cache Info',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow('Files', '${_cacheInfo!.fileCount}'),
                    _InfoRow(
                      'Size',
                      '${_cacheInfo!.totalSizeMB.toStringAsFixed(1)} MB',
                    ),
                    _InfoRow(
                      'Max',
                      '${_cacheInfo!.maxSizeMB.toStringAsFixed(0)} MB',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _cacheInfo!.usage,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_cacheInfo!.usage * 100).toStringAsFixed(1)}% used',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          Text('Videos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          // Video list
          ..._videos.entries.map((entry) {
            final isCached = _cachedStatus[entry.key] ?? false;
            final progress = _downloadProgress[entry.key];
            final isDownloading = progress != null;

            return Card(
              child: ListTile(
                leading: Icon(
                  isCached
                      ? Icons.check_circle
                      : isDownloading
                      ? Icons.downloading
                      : Icons.cloud_download_outlined,
                  color: isCached ? Colors.green : null,
                ),
                title: Text(entry.key),
                subtitle: isDownloading
                    ? LinearProgressIndicator(value: progress)
                    : Text(isCached ? 'Cached' : 'Not cached'),
                trailing: isCached
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _cacheManager.removeFromCache(entry.value);
                          _refreshCacheInfo();
                        },
                      )
                    : isDownloading
                    ? Text('${(progress * 100).toInt()}%')
                    : IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _preCacheVideo(entry.key, entry.value),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Example 5: Fullscreen ───────────────────────────────────────────

class FullscreenExample extends StatefulWidget {
  const FullscreenExample({super.key});

  @override
  State<FullscreenExample> createState() => _FullscreenExampleState();
}

class _FullscreenExampleState extends State<FullscreenExample> {
  late final VidKitController _controller;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _controller = VidKitController(
      source: VideoSource.network(
        _SampleVideos.bunny,
        title: 'Big Buck Bunny - Fullscreen Demo',
      ),
      config: const VidKitConfig(autoPlay: true, enableCache: true),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _exitFullscreen();
    _controller.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _exitFullscreen();
    }
  }

  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: VidKitPlayer(
            controller: _controller,
            onFullscreenToggle: _toggleFullscreen,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fullscreen')),
      body: Column(
        children: [
          VidKitPlayer(
            controller: _controller,
            onFullscreenToggle: _toggleFullscreen,
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fullscreen, size: 48),
                  const SizedBox(height: 8),
                  const Text('Tap the fullscreen button on the player'),
                  const SizedBox(height: 4),
                  Text(
                    'or double-tap the right side to seek forward',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
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
