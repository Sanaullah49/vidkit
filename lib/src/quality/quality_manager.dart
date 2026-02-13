/// Represents a video quality option.
class QualityOption {
  /// Display label (e.g., "1080p", "720p", "480p", "Auto").
  final String label;

  /// URL for this quality variant.
  final String url;

  /// Resolution height in pixels (e.g., 1080, 720, 480).
  final int? height;

  /// Bitrate in bits per second.
  final int? bitrate;

  /// Creates a [QualityOption].
  const QualityOption({
    required this.label,
    required this.url,
    this.height,
    this.bitrate,
  });

  @override
  String toString() => 'QualityOption($label)';

  @override
  bool operator ==(Object other) =>
      other is QualityOption && other.url == url && other.label == label;

  @override
  int get hashCode => Object.hash(url, label);
}

/// Manages quality selection for a video.
class QualityManager {
  final List<QualityOption> _qualities;
  QualityOption? _currentQuality;

  /// Creates a [QualityManager].
  QualityManager({
    required List<QualityOption> qualities,
    QualityOption? initialQuality,
  }) : _qualities = List.of(qualities) {
    _currentQuality = initialQuality ?? _selectDefaultQuality();
  }

  /// All available quality options.
  List<QualityOption> get qualities => List.unmodifiable(_qualities);

  /// Currently selected quality.
  QualityOption? get currentQuality => _currentQuality;

  /// Sets the current quality.
  void setQuality(QualityOption quality) {
    if (_qualities.contains(quality)) {
      _currentQuality = quality;
    }
  }

  /// Selects default quality (highest available).
  QualityOption _selectDefaultQuality() {
    if (_qualities.isEmpty) return _qualities.first;

    // Sort by height descending, pick first reasonable one
    final sorted = List.of(_qualities)
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));

    // Default to 720p if available, otherwise highest
    return sorted.firstWhere(
      (q) => q.height != null && q.height! <= 720,
      orElse: () => sorted.first,
    );
  }
}
