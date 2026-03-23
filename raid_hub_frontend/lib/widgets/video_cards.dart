import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/raid_video.dart';
import '../models/playlist_item.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart'; // Add ApiService import
import '../screens/video_player_screen.dart' deferred as video_player_screen;

String _formatPublishedDate(String rawDate) {
  final parsed = DateTime.tryParse(rawDate);
  if (parsed == null) return rawDate;

  final localDate = parsed.toLocal();
  return '${localDate.year}년 ${localDate.month}월 ${localDate.day}일';
}

/// [VideoCard]
/// DB에 저장된 개별 공략 영상(RaidVideo) 정보를 표시하는 카드 위젯입니다.
/// 관리자가 수동으로 등록한 영상임을 나타내는 UI 스타일이 적용되어 있습니다.
class VideoCard extends StatelessWidget {
  final RaidVideo video;
  final String? thumbnailUrl;
  final VoidCallback onDelete;

  const VideoCard({
    super.key,
    required this.video,
    required this.thumbnailUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = ApiService(); // Add instance

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: () async {
              // 활동 로그 기록
              apiService.logActivity(
                activityType: 'VIDEO_CLICK',
                targetTitle: video.title,
              );

              final videoId = _getYouTubeVideoId(video.youtubeUrl);
              if (videoId != null) {
                await video_player_screen.loadLibrary();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => video_player_screen.VideoPlayerScreen(videoId: videoId),
                  ),
                );
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumbnailUrl != null
                      ? Image.network(
                          thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => Container(
                            color: Colors.grey,
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                      : Container(
                          color: Colors.black12,
                          child: const Icon(Icons.videocam, size: 50),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "[관리자 등록] ${video.raidName} - ${video.difficulty}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${video.gate} | ${video.uploaderName}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (authService.isAdmin)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _getYouTubeVideoId(String url) {
    try {
      Uri uri = Uri.parse(url);
      if (uri.host.contains("youtu.be")) return uri.pathSegments.first;
      if (uri.host.contains("youtube.com")) return uri.queryParameters['v'];
    } catch (e) {}
    return null;
  }
}

/// [PlaylistCard]
/// YouTube API에서 불러온 플레이리스트 아이템(PlaylistItem) 정보를 표시하는 카드 위젯입니다.
class PlaylistCard extends StatelessWidget {
  final PlaylistItem item;
  final VoidCallback onBlock;

  const PlaylistCard({super.key, required this.item, required this.onBlock});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = ApiService(); // Define apiService here

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: () async {
              // 활동 로그 기록
              apiService.logActivity(
                activityType: 'VIDEO_CLICK',
                targetTitle: item.title,
              );

              await video_player_screen.loadLibrary();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      video_player_screen.VideoPlayerScreen(videoId: item.videoId),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: item.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          item.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => Container(
                            color: Colors.grey,
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                      : Container(
                          color: Colors.black12,
                          child: const Icon(Icons.videocam, size: 50),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.channelTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatPublishedDate(item.publishedAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (authService.isAdmin)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.visibility_off,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                  tooltip: '이 영상 숨기기',
                  onPressed: onBlock,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
