# 🎬 VidKit

[![pub package](https://img.shields.io/pub/v/vidkit.svg)](https://pub.dev/packages/vidkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Smart video player for Flutter with built-in caching. No more buffering. No more re-downloading.**

VidKit solves the 6+ year old pain point of Flutter's video_player — no caching, no controls, no playlist support. Drop in one widget and get a production-ready video player with smart caching, playlist management, quality switching, and preloading.

## 📸 Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/Sanaullah49/vidkit/main/screenshots/simple_player.png" width="240" alt="Simple Player"/>
  &nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/Sanaullah49/vidkit/main/screenshots/playlist.png" width="240" alt="Playlist"/>
  &nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/Sanaullah49/vidkit/main/screenshots/cache_manager.png" width="240" alt="Cache Manager"/>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Sanaullah49/vidkit/main/screenshots/quality_switching.png" width="240" alt="Quality Switching"/>
  &nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/Sanaullah49/vidkit/main/screenshots/fullscreen.png" width="240" alt="Fullscreen"/>
</p>

## ✨ Features

- 📦 **Smart Caching** — Videos are cached automatically. Play once, instant replay forever
- 🔄 **Preloading** — Next video in playlist is pre-cached in the background
- 🎵 **Playlist Support** — Next, previous, jump to, shuffle, add, remove
- 🎚️ **Quality Switching** — Switch between 1080p, 720p, 480p seamlessly
- 🎮 **Built-in Controls** — Play/pause, seek bar, speed, volume, fullscreen
- ⚡ **Zero Config** — Works out of the box with sensible defaults
- 💾 **Cache Management** — View cache size, pre-cache videos, clear cache
- 🔁 **Double Tap to Seek** — Seek forward/backward with double tap
- 📊 **Buffered Progress** — See how much is buffered on the seek bar
- 🏷️ **Cache Indicator** — Shows "Cached" badge when playing from cache
- 🌐 **All Platforms** — Android, iOS, Web, macOS, Windows, Linux
- 🎨 **Fully Customizable** — Custom controls, themes, error/loading widgets

## 🚀 Quick Start

### Installation

```yaml
dependencies:
  vidkit: ^0.1.0
```

### Simplest Possible Usage

```dart
import 'package:vidkit/vidkit.dart';

// Create controller
final controller = VidKitController(
  source: VideoSource.network('https://example.com/video.mp4'),
  config: VidKitConfig(autoPlay: true, enableCache: true),
);
await controller.initialize();

// Drop in the widget
VidKitPlayer(controller: controller)

// That's it! Cached. Controls. Done. 🎉
```

## 📖 Usage

### Single Video with Caching

```dart
class MyVideoScreen extends StatefulWidget {
  @override
  State<MyVideoScreen> createState() => _MyVideoScreenState();
}

class _MyVideoScreenState extends State<MyVideoScreen> {
  late final VidKitController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VidKitController(
      source: VideoSource.network(
        'https://example.com/video.mp4',
        title: 'My Video',
      ),
      config: const VidKitConfig(
        autoPlay: true,
        enableCache: true, // Videos cached automatically
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
      body: VidKitPlayer(controller: _controller),
    );
  }
}
```

### Playlist with Preloading

```dart
final controller = VidKitController.playlist(
  sources: [
    VideoSource.network('https://example.com/video1.mp4', title: 'Episode 1'),
    VideoSource.network('https://example.com/video2.mp4', title: 'Episode 2'),
    VideoSource.network('https://example.com/video3.mp4', title: 'Episode 3'),
  ],
  config: VidKitConfig(
    autoPlay: true,
    enableCache: true,
    preloadNext: true, // Next video is cached in background
  ),
);
await controller.initialize();

// Playback controls
await controller.next();
await controller.previous();
await controller.jumpTo(2);
```

### Quality Switching

```dart
final controller = VidKitController(
  source: VideoSource.network(
    'https://example.com/video_1080p.mp4',
    title: 'My Video',
    qualities: [
      QualityOption(label: '1080p', url: 'https://example.com/video_1080p.mp4', height: 1080),
      QualityOption(label: '720p', url: 'https://example.com/video_720p.mp4', height: 720),
      QualityOption(label: '480p', url: 'https://example.com/video_480p.mp4', height: 480),
    ],
  ),
);

// Switch quality (maintains position and play state)
await controller.setQuality(
  QualityOption(label: '480p', url: 'https://example.com/video_480p.mp4', height: 480),
);
```

### Cache Management

```dart
final cache = VideoCacheManager();

// Check cache status
final info = await cache.info;
print('${info.totalSizeMB} MB used, ${info.fileCount} files');

// Check if specific video is cached
final isCached = await cache.isCached('https://example.com/video.mp4');

// Pre-cache a video
await cache.preCache('https://example.com/video.mp4');

// Cache with progress tracking
cache.cacheVideo('https://example.com/video.mp4').listen((progress) {
  print('${(progress * 100).toInt()}% downloaded');
});

// Remove specific video from cache
await cache.removeFromCache('https://example.com/video.mp4');

// Clear entire cache
await cache.clearCache();
```

### Playback Controls

```dart
// Play / Pause
await controller.play();
await controller.pause();
await controller.togglePlayPause();

// Seeking
await controller.seekTo(Duration(seconds: 30));
await controller.seekForward();  // +10 seconds
await controller.seekBackward(); // -10 seconds
await controller.seekToFraction(0.5); // Seek to 50%

// Volume
await controller.setVolume(0.5);
await controller.toggleMute();

// Speed
await controller.setPlaybackSpeed(1.5);

// Looping
await controller.setLooping(true);
```

### Listen to State Changes

```dart
ValueListenableBuilder<VidKitValue>(
  valueListenable: controller,
  builder: (context, value, child) {
    return Column(
      children: [
        Text('State: ${value.state.name}'),
        Text('Position: ${value.position}'),
        Text('Duration: ${value.duration}'),
        Text('Buffered: ${value.buffered}'),
        Text('From Cache: ${value.isFromCache}'),
        Text('Cache Progress: ${(value.cacheProgress * 100).toInt()}%'),
        Text('Progress: ${(value.progress * 100).toInt()}%'),
      ],
    );
  },
)
```

### Custom Controls

```dart
VidKitPlayer(
  controller: controller,
  showControls: false, // Hide default controls
  controlsBuilder: (context, controller) {
    return YourCustomControlsWidget(controller: controller);
  },
)
```

### Custom Loading & Error Widgets

```dart
VidKitPlayer(
  controller: controller,
  loadingWidget: Center(child: MyCustomSpinner()),
  errorBuilder: (context, error) {
    return Center(child: Text('Oops: $error'));
  },
  placeholder: Center(child: Image.asset('assets/thumbnail.png')),
)
```

### Asset & File Videos

```dart
// From assets
final controller = VidKitController(
  source: VideoSource.asset('assets/videos/intro.mp4'),
);

// From local file
final controller = VidKitController(
  source: VideoSource.file('/path/to/video.mp4'),
);
```

### Configuration

```dart
const config = VidKitConfig(
  enableCache: true,           // Enable video caching
  maxCacheSize: 500 * 1024 * 1024, // 500 MB cache limit
  autoPlay: false,             // Auto-play when ready
  looping: false,              // Loop video
  volume: 1.0,                 // Initial volume (0.0 - 1.0)
  playbackSpeed: 1.0,          // Initial speed
  preloadNext: true,           // Pre-cache next playlist video
  connectionTimeout: Duration(seconds: 30),
  httpHeaders: {'Authorization': 'Bearer token'},
);
```

## 🆚 Why VidKit?

| Feature | video_player | chewie | better_player | VidKit |
|---------|:---:|:---:|:---:|:---:|
| Built-in caching | ❌ | ❌ | ⚠️ Buggy | ✅ |
| Playlist support | ❌ | ❌ | ✅ | ✅ |
| Quality switching | ❌ | ❌ | ✅ | ✅ |
| Preloading | ❌ | ❌ | ❌ | ✅ |
| Cache management | ❌ | ❌ | ❌ | ✅ |
| Built-in controls | ❌ | ✅ | ✅ | ✅ |
| Actively maintained | ✅ | ✅ | ❌ (2+ yrs) | ✅ |
| Double-tap seek | ❌ | ❌ | ✅ | ✅ |
| Speed control | ❌ | ✅ | ✅ | ✅ |

## 📊 Cache Strategy

```
First Play:
  Network → Stream video → Cache in background → Play
  
Second Play:
  Cache hit → Play instantly from disk → Zero bandwidth

Playlist:
  Playing Video 2 → Pre-cache Video 3 in background
  User taps Next → Video 3 plays instantly from cache
```

## ☕ Support

If this package saves you time, consider buying me a coffee!

<a href="https://buymeacoffee.com/sanaullah49" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50">
</a>

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ for the Flutter community
</p>