class PlaylistItem {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final int position;
  final String publishedAt;

  PlaylistItem({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.position,
    required this.publishedAt,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      channelTitle: json['channelTitle'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      position: json['position'] ?? 0,
      publishedAt: json['publishedAt'] ?? '',
    );
  }

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';
}
