## 0.1.1

* HLS pre-cache support for VOD `.m3u8` streams
* HLS bundle caching now downloads child playlists, segments, init files, and key files
* Live/event HLS snapshot support with bounded playlist refresh cycles
* Live snapshots are finalized with offline-friendly manifests (`#EXT-X-ENDLIST`)
* Encrypted HLS edge-case support for non-HTTP key URI schemes (e.g. `skd://`)
* Retry/backoff for transient HLS request failures
* Cache lookup/removal/count/size now support HLS bundle entries
* Added tests for VOD HLS, live snapshot refresh, and encrypted-key edge cases

## 0.1.0

* 🎉 Initial release
* Smart video caching — play once, instant replay forever
* Background preloading — next video in playlist cached automatically
* Playlist support — next, previous, jump to, shuffle, add, remove
* Quality switching — switch resolutions without losing position
* Built-in controls — play/pause, seek bar, speed, volume, fullscreen
* Cache management — view size, pre-cache, clear, per-video removal
* Double-tap to seek — forward/backward with double tap gesture
* Buffered progress indicator on seek bar
* Cache status badge — shows when playing from cache
* Custom controls builder — bring your own controls UI
* Custom loading, error, and placeholder widgets
* Asset and file video sources
* HTTP headers support for authenticated streams
* Configurable cache size limit (default 500 MB)
* LRU cache eviction — oldest files removed when limit reached
* Works on all platforms (Android, iOS, Web, macOS, Windows, Linux)
