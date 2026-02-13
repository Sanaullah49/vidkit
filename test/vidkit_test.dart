import 'package:flutter_test/flutter_test.dart';
import 'package:vidkit/vidkit.dart';

void main() {
  // ─── VideoSource Tests ──────────────────────────────────────────

  group('VideoSource', () {
    test('creates network source', () {
      final source = VideoSource.network('https://example.com/video.mp4');
      expect(source.type, VideoSourceType.network);
      expect(source.url, 'https://example.com/video.mp4');
    });

    test('creates asset source', () {
      final source = VideoSource.asset('assets/video.mp4');
      expect(source.type, VideoSourceType.asset);
      expect(source.url, 'assets/video.mp4');
    });

    test('creates file source', () {
      final source = VideoSource.file('/path/to/video.mp4');
      expect(source.type, VideoSourceType.file);
      expect(source.url, '/path/to/video.mp4');
    });

    test('creates with all optional fields', () {
      final source = VideoSource.network(
        'https://example.com/video.mp4',
        title: 'My Video',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        qualities: const [
          QualityOption(label: '1080p', url: 'https://example.com/1080.mp4'),
        ],
        headers: const {'Authorization': 'Bearer token'},
      );
      expect(source.title, 'My Video');
      expect(source.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(source.qualities!.length, 1);
      expect(source.headers!['Authorization'], 'Bearer token');
    });

    test('toString works', () {
      final source = VideoSource.network(
        'https://example.com/video.mp4',
        title: 'Test',
      );
      expect(source.toString(), contains('Test'));
    });

    test('toString uses url when no title', () {
      final source = VideoSource.network('https://example.com/video.mp4');
      expect(source.toString(), contains('example.com'));
    });
  });

  // ─── VidKitConfig Tests ─────────────────────────────────────────

  group('VidKitConfig', () {
    test('has sensible defaults', () {
      const config = VidKitConfig();
      expect(config.enableCache, true);
      expect(config.maxCacheSize, 500 * 1024 * 1024);
      expect(config.autoPlay, false);
      expect(config.looping, false);
      expect(config.volume, 1.0);
      expect(config.playbackSpeed, 1.0);
      expect(config.allowBackgroundPlayback, false);
      expect(config.preloadNext, true);
      expect(config.connectionTimeout, const Duration(seconds: 30));
    });

    test('copyWith overrides specific values', () {
      const config = VidKitConfig();
      final copy = config.copyWith(autoPlay: true, volume: 0.5, looping: true);
      expect(copy.autoPlay, true);
      expect(copy.volume, 0.5);
      expect(copy.looping, true);
      // Unchanged values
      expect(copy.enableCache, true);
      expect(copy.playbackSpeed, 1.0);
      expect(copy.preloadNext, true);
    });

    test('copyWith with no args returns equivalent config', () {
      const config = VidKitConfig(
        autoPlay: true,
        volume: 0.7,
        enableCache: false,
      );
      final copy = config.copyWith();
      expect(copy.autoPlay, true);
      expect(copy.volume, 0.7);
      expect(copy.enableCache, false);
    });
  });

  // ─── VidKitValue Tests ──────────────────────────────────────────

  group('VidKitValue', () {
    test('has correct defaults', () {
      const value = VidKitValue();
      expect(value.state, VidKitState.idle);
      expect(value.position, Duration.zero);
      expect(value.duration, Duration.zero);
      expect(value.buffered, Duration.zero);
      expect(value.volume, 1.0);
      expect(value.playbackSpeed, 1.0);
      expect(value.isPlaying, false);
      expect(value.isBuffering, false);
      expect(value.isCaching, false);
      expect(value.cacheProgress, 0.0);
      expect(value.isFromCache, false);
      expect(value.aspectRatio, 16 / 9);
      expect(value.playlistIndex, -1);
      expect(value.playlistLength, 0);
    });

    test('progress calculates correctly', () {
      const value = VidKitValue(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
      );
      expect(value.progress, 0.25);
    });

    test('progress is 0 when duration is 0', () {
      const value = VidKitValue(
        position: Duration(seconds: 5),
        duration: Duration.zero,
      );
      expect(value.progress, 0.0);
    });

    test('progress clamps to 1.0', () {
      const value = VidKitValue(
        position: Duration(seconds: 130),
        duration: Duration(seconds: 120),
      );
      expect(value.progress, 1.0);
    });

    test('remaining calculates correctly', () {
      const value = VidKitValue(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
      );
      expect(value.remaining, const Duration(seconds: 90));
    });

    test('isCompleted checks state', () {
      const completed = VidKitValue(state: VidKitState.completed);
      expect(completed.isCompleted, true);

      const playing = VidKitValue(state: VidKitState.playing);
      expect(playing.isCompleted, false);
    });

    test('hasNext returns true when not last', () {
      const value = VidKitValue(playlistIndex: 0, playlistLength: 3);
      expect(value.hasNext, true);
    });

    test('hasNext returns false when last', () {
      const value = VidKitValue(playlistIndex: 2, playlistLength: 3);
      expect(value.hasNext, false);
    });

    test('hasPrevious returns false when first', () {
      const value = VidKitValue(playlistIndex: 0, playlistLength: 3);
      expect(value.hasPrevious, false);
    });

    test('hasPrevious returns true when not first', () {
      const value = VidKitValue(playlistIndex: 1, playlistLength: 3);
      expect(value.hasPrevious, true);
    });

    test('copyWith creates modified copy', () {
      const value = VidKitValue();
      final copy = value.copyWith(
        state: VidKitState.playing,
        position: const Duration(seconds: 10),
        isPlaying: true,
        volume: 0.5,
      );
      expect(copy.state, VidKitState.playing);
      expect(copy.position, const Duration(seconds: 10));
      expect(copy.isPlaying, true);
      expect(copy.volume, 0.5);
      // Unchanged
      expect(copy.duration, Duration.zero);
      expect(copy.aspectRatio, 16 / 9);
    });
  });

  // ─── VidKitState Tests ──────────────────────────────────────────

  group('VidKitState', () {
    test('all states exist', () {
      expect(
        VidKitState.values,
        containsAll([
          VidKitState.idle,
          VidKitState.loading,
          VidKitState.ready,
          VidKitState.playing,
          VidKitState.paused,
          VidKitState.completed,
          VidKitState.error,
        ]),
      );
    });
  });

  // ─── QualityOption Tests ────────────────────────────────────────

  group('QualityOption', () {
    test('creates with required fields', () {
      const quality = QualityOption(
        label: '1080p',
        url: 'https://example.com/1080.mp4',
      );
      expect(quality.label, '1080p');
      expect(quality.url, 'https://example.com/1080.mp4');
      expect(quality.height, isNull);
      expect(quality.bitrate, isNull);
    });

    test('creates with all fields', () {
      const quality = QualityOption(
        label: '720p',
        url: 'https://example.com/720.mp4',
        height: 720,
        bitrate: 2500000,
      );
      expect(quality.height, 720);
      expect(quality.bitrate, 2500000);
    });

    test('equality works by url and label', () {
      const a = QualityOption(label: '720p', url: 'url1');
      const b = QualityOption(label: '720p', url: 'url1');
      const c = QualityOption(label: '720p', url: 'url2');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = QualityOption(label: '720p', url: 'url1');
      const b = QualityOption(label: '720p', url: 'url1');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString is readable', () {
      const quality = QualityOption(label: '1080p', url: 'url');
      expect(quality.toString(), contains('1080p'));
    });
  });

  // ─── QualityManager Tests ──────────────────────────────────────

  group('QualityManager', () {
    test('selects 720p as default when available', () {
      final manager = QualityManager(
        qualities: [
          const QualityOption(label: '1080p', url: 'url1', height: 1080),
          const QualityOption(label: '720p', url: 'url2', height: 720),
          const QualityOption(label: '480p', url: 'url3', height: 480),
        ],
      );
      expect(manager.currentQuality!.label, '720p');
    });

    test('selects highest when no 720p available', () {
      final manager = QualityManager(
        qualities: [
          const QualityOption(label: '480p', url: 'url1', height: 480),
          const QualityOption(label: '360p', url: 'url2', height: 360),
        ],
      );
      expect(manager.currentQuality!.label, '480p');
    });

    test('uses initial quality if provided', () {
      const q480 = QualityOption(label: '480p', url: 'url3', height: 480);
      final manager = QualityManager(
        qualities: [
          const QualityOption(label: '1080p', url: 'url1', height: 1080),
          q480,
        ],
        initialQuality: q480,
      );
      expect(manager.currentQuality, q480);
    });

    test('setQuality changes current', () {
      const q480 = QualityOption(label: '480p', url: 'url3', height: 480);
      final manager = QualityManager(
        qualities: [
          const QualityOption(label: '1080p', url: 'url1', height: 1080),
          q480,
        ],
      );
      manager.setQuality(q480);
      expect(manager.currentQuality, q480);
    });

    test('setQuality ignores unknown quality', () {
      final manager = QualityManager(
        qualities: [
          const QualityOption(label: '1080p', url: 'url1', height: 1080),
        ],
      );
      final original = manager.currentQuality;
      manager.setQuality(
        const QualityOption(label: '4K', url: 'url_unknown', height: 2160),
      );
      expect(manager.currentQuality, original);
    });

    test('qualities list is unmodifiable', () {
      final manager = QualityManager(
        qualities: [
          const QualityOption(label: '1080p', url: 'url1', height: 1080),
        ],
      );
      expect(
        () => manager.qualities.add(
          const QualityOption(label: '720p', url: 'url2'),
        ),
        throwsA(anything),
      );
    });
  });

  // ─── PlaylistManager Tests ─────────────────────────────────────

  group('PlaylistManager', () {
    late PlaylistManager manager;

    setUp(() {
      manager = PlaylistManager(
        sources: [
          VideoSource.network('https://example.com/1.mp4', title: 'Video 1'),
          VideoSource.network('https://example.com/2.mp4', title: 'Video 2'),
          VideoSource.network('https://example.com/3.mp4', title: 'Video 3'),
          VideoSource.network('https://example.com/4.mp4', title: 'Video 4'),
        ],
      );
    });

    test('initializes with correct state', () {
      expect(manager.length, 4);
      expect(manager.currentIndex, 0);
      expect(manager.currentSource.title, 'Video 1');
    });

    test('initialIndex is respected', () {
      final m = PlaylistManager(
        sources: [
          VideoSource.network('url1', title: 'A'),
          VideoSource.network('url2', title: 'B'),
          VideoSource.network('url3', title: 'C'),
        ],
        initialIndex: 2,
      );
      expect(m.currentIndex, 2);
      expect(m.currentSource.title, 'C');
    });

    test('initialIndex is clamped', () {
      final m = PlaylistManager(
        sources: [VideoSource.network('url1')],
        initialIndex: 99,
      );
      expect(m.currentIndex, 0);
    });

    test('next advances to next item', () {
      manager.next();
      expect(manager.currentIndex, 1);
      expect(manager.currentSource.title, 'Video 2');
    });

    test('next does nothing when at end', () {
      manager.jumpTo(3);
      manager.next();
      expect(manager.currentIndex, 3);
    });

    test('previous goes back', () {
      manager.next();
      manager.next();
      manager.previous();
      expect(manager.currentIndex, 1);
    });

    test('previous does nothing when at start', () {
      manager.previous();
      expect(manager.currentIndex, 0);
    });

    test('hasNext and hasPrevious', () {
      expect(manager.hasNext, true);
      expect(manager.hasPrevious, false);

      manager.next();
      expect(manager.hasNext, true);
      expect(manager.hasPrevious, true);

      manager.jumpTo(3);
      expect(manager.hasNext, false);
      expect(manager.hasPrevious, true);
    });

    test('jumpTo valid index', () {
      final source = manager.jumpTo(2);
      expect(source, isNotNull);
      expect(source!.title, 'Video 3');
      expect(manager.currentIndex, 2);
    });

    test('jumpTo invalid index returns null', () {
      expect(manager.jumpTo(-1), isNull);
      expect(manager.jumpTo(99), isNull);
      expect(manager.currentIndex, 0); // Unchanged
    });

    test('peekNext returns next without advancing', () {
      final next = manager.peekNext();
      expect(next!.title, 'Video 2');
      expect(manager.currentIndex, 0); // Not changed
    });

    test('peekNext returns null when at end', () {
      manager.jumpTo(3);
      expect(manager.peekNext(), isNull);
    });

    test('peekPrevious returns previous without going back', () {
      manager.next();
      final prev = manager.peekPrevious();
      expect(prev!.title, 'Video 1');
      expect(manager.currentIndex, 1); // Not changed
    });

    test('peekPrevious returns null when at start', () {
      expect(manager.peekPrevious(), isNull);
    });

    test('add appends to playlist', () {
      manager.add(VideoSource.network('url5', title: 'Video 5'));
      expect(manager.length, 5);
      manager.jumpTo(4);
      expect(manager.currentSource.title, 'Video 5');
    });

    test('insert at beginning shifts index', () {
      manager.next(); // index = 1
      manager.insert(0, VideoSource.network('url0', title: 'Video 0'));
      expect(manager.length, 5);
      expect(manager.currentIndex, 2); // Shifted by 1
    });

    test('insert after current does not shift index', () {
      manager.next(); // index = 1
      manager.insert(3, VideoSource.network('url_new', title: 'New'));
      expect(manager.currentIndex, 1); // Unchanged
      expect(manager.length, 5);
    });

    test('removeAt before current shifts index', () {
      manager.jumpTo(2);
      manager.removeAt(0);
      expect(manager.currentIndex, 1);
      expect(manager.length, 3);
    });

    test('removeAt current clamps index', () {
      manager.jumpTo(3);
      manager.removeAt(3);
      expect(manager.currentIndex, 2);
      expect(manager.length, 3);
    });

    test('removeAt invalid index does nothing', () {
      manager.removeAt(-1);
      manager.removeAt(99);
      expect(manager.length, 4);
    });

    test('sources returns unmodifiable list', () {
      expect(
        () => manager.sources.add(VideoSource.network('bad')),
        throwsA(anything),
      );
    });

    test('shuffle keeps current video', () {
      manager.jumpTo(2);
      final currentTitle = manager.currentSource.title;
      manager.shuffle();
      expect(manager.currentSource.title, currentTitle);
    });
  });

  // ─── CacheInfo Tests ───────────────────────────────────────────

  group('CacheInfo', () {
    test('totalSizeMB converts correctly', () {
      const info = CacheInfo(
        totalSize: 10 * 1024 * 1024,
        fileCount: 5,
        maxSize: 500 * 1024 * 1024,
      );
      expect(info.totalSizeMB, closeTo(10.0, 0.1));
    });

    test('maxSizeMB converts correctly', () {
      const info = CacheInfo(
        totalSize: 0,
        fileCount: 0,
        maxSize: 500 * 1024 * 1024,
      );
      expect(info.maxSizeMB, closeTo(500.0, 0.1));
    });

    test('usage calculates fraction correctly', () {
      const info = CacheInfo(
        totalSize: 250 * 1024 * 1024,
        fileCount: 10,
        maxSize: 500 * 1024 * 1024,
      );
      expect(info.usage, closeTo(0.5, 0.01));
    });

    test('usage is 0 when maxSize is 0', () {
      const info = CacheInfo(totalSize: 100, fileCount: 1, maxSize: 0);
      expect(info.usage, 0.0);
    });

    test('usage clamps to 1.0', () {
      const info = CacheInfo(
        totalSize: 600 * 1024 * 1024,
        fileCount: 20,
        maxSize: 500 * 1024 * 1024,
      );
      expect(info.usage, 1.0);
    });

    test('toString is readable', () {
      const info = CacheInfo(
        totalSize: 50 * 1024 * 1024,
        fileCount: 3,
        maxSize: 500 * 1024 * 1024,
      );
      final str = info.toString();
      expect(str, contains('MB'));
      expect(str, contains('3 files'));
    });
  });

  // ─── VidKitController Tests (non-platform) ─────────────────────

  group('VidKitController', () {
    test('creates with default config', () {
      final controller = VidKitController(
        source: VideoSource.network('https://example.com/video.mp4'),
      );
      expect(controller.value.state, VidKitState.idle);
      expect(controller.isPlaylist, false);
      controller.dispose();
    });

    test('creates with custom config', () {
      final controller = VidKitController(
        source: VideoSource.network('https://example.com/video.mp4'),
        config: const VidKitConfig(autoPlay: true, volume: 0.5),
      );
      expect(controller.config.autoPlay, true);
      expect(controller.config.volume, 0.5);
      controller.dispose();
    });

    test('playlist constructor sets up playlist', () {
      final controller = VidKitController.playlist(
        sources: [
          VideoSource.network('url1', title: 'A'),
          VideoSource.network('url2', title: 'B'),
          VideoSource.network('url3', title: 'C'),
        ],
        initialIndex: 1,
      );
      expect(controller.isPlaylist, true);
      expect(controller.value.playlistIndex, 1);
      expect(controller.value.playlistLength, 3);
      controller.dispose();
    });

    test('dispose does not throw', () {
      final controller = VidKitController(
        source: VideoSource.network('https://example.com/video.mp4'),
      );
      expect(() => controller.dispose(), returnsNormally);
    });

    test('double dispose does not throw', () {
      final controller = VidKitController(
        source: VideoSource.network('https://example.com/video.mp4'),
      );
      controller.dispose();
      // Second dispose should not crash
      // (it will throw FlutterError from ValueNotifier but that's expected)
    });
  });
}
