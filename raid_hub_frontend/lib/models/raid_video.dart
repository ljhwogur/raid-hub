class RaidVideo {
  final int? id;
  final String title;
  final String youtubeUrl;
  final String uploaderName;
  final String raidName;
  final String difficulty;
  final String gate;

  RaidVideo({
    this.id,
    required this.title,
    required this.youtubeUrl,
    required this.uploaderName,
    required this.raidName,
    required this.difficulty,
    required this.gate,
  });

  factory RaidVideo.fromJson(Map<String, dynamic> json) {
    return RaidVideo(
      id: json['id'],
      title: json['title'],
      youtubeUrl: json['youtubeUrl'],
      uploaderName: json['uploaderName'],
      raidName: json['raidName'],
      difficulty: json['difficulty'],
      gate: json['gate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'youtubeUrl': youtubeUrl,
      'uploaderName': uploaderName,
      'raidName': raidName,
      'difficulty': difficulty,
      'gate': gate,
    };
  }
}
