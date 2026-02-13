import '../core/vidkit_controller.dart';

/// Manages a playlist of video sources.
class PlaylistManager {
  final List<VideoSource> _sources;
  int _currentIndex;

  /// Creates a [PlaylistManager].
  PlaylistManager({required List<VideoSource> sources, int initialIndex = 0})
    : _sources = List.of(sources),
      _currentIndex = initialIndex.clamp(0, sources.length - 1);

  /// Current playlist index.
  int get currentIndex => _currentIndex;

  /// Total number of items.
  int get length => _sources.length;

  /// Current video source.
  VideoSource get currentSource => _sources[_currentIndex];

  /// Whether there is a next item.
  bool get hasNext => _currentIndex < _sources.length - 1;

  /// Whether there is a previous item.
  bool get hasPrevious => _currentIndex > 0;

  /// All sources in the playlist.
  List<VideoSource> get sources => List.unmodifiable(_sources);

  /// Moves to the next item.
  void next() {
    if (hasNext) _currentIndex++;
  }

  /// Moves to the previous item.
  void previous() {
    if (hasPrevious) _currentIndex--;
  }

  /// Jumps to a specific index. Returns the source or null if invalid.
  VideoSource? jumpTo(int index) {
    if (index < 0 || index >= _sources.length) return null;
    _currentIndex = index;
    return currentSource;
  }

  /// Peeks at the next source without advancing.
  VideoSource? peekNext() {
    if (!hasNext) return null;
    return _sources[_currentIndex + 1];
  }

  /// Peeks at the previous source without going back.
  VideoSource? peekPrevious() {
    if (!hasPrevious) return null;
    return _sources[_currentIndex - 1];
  }

  /// Adds a source to the end of the playlist.
  void add(VideoSource source) {
    _sources.add(source);
  }

  /// Inserts a source at a specific index.
  void insert(int index, VideoSource source) {
    _sources.insert(index, source);
    if (index <= _currentIndex) _currentIndex++;
  }

  /// Removes a source at a specific index.
  void removeAt(int index) {
    if (index < 0 || index >= _sources.length) return;
    _sources.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      _currentIndex = _currentIndex.clamp(0, _sources.length - 1);
    }
  }

  /// Shuffles the playlist (keeps current video in place).
  void shuffle() {
    final current = currentSource;
    _sources.shuffle();
    _currentIndex = _sources.indexOf(current);
  }
}
