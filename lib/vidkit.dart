/// Smart Video Player for Flutter with built-in caching.
///
/// VidKit provides a reliable, cached video player with playlist support,
/// quality switching, and smart preloading.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:vidkit/vidkit.dart';
///
/// final controller = VidKitController(
///   source: VideoSource.network('https://example.com/video.mp4'),
///   config: VidKitConfig(autoPlay: true, enableCache: true),
/// );
/// await controller.initialize();
///
/// VidKitPlayer(controller: controller)
/// ```
library;

// ─── Cache ───────────────────────────────────────────────────────────
export 'src/cache/video_cache_manager.dart';
// ─── Core ────────────────────────────────────────────────────────────
export 'src/core/vidkit_controller.dart';
// ─── Playlist ────────────────────────────────────────────────────────
export 'src/playlist/playlist_manager.dart';
// ─── Quality ─────────────────────────────────────────────────────────
export 'src/quality/quality_manager.dart';
// ─── Widgets ─────────────────────────────────────────────────────────
export 'src/widgets/vidkit_controls.dart';
export 'src/widgets/vidkit_player.dart';
