import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'models/raid_video.dart';
import 'models/playlist_item.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart'; // Import AuthService
import 'screens/login_screen.dart'; // Import LoginScreen
import 'screens/video_player_screen.dart'; // Import VideoPlayerScreen

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const RaidHubApp(),
    ),
  );
}

class RaidHubApp extends StatelessWidget {
  const RaidHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lost Ark Raid Hub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();

  // Data
  List<dynamic> _allContent = []; // RaidVideo + PlaylistItem
  List<dynamic> _filteredContent = [];

  // Loading State
  bool _isLoading = true;

  // 필터용 상태 변수들
  String _selectedGuideKeyword = '전체';

  final List<String> _guideKeywords = [
    '전체', '발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘', 
    '카양겔', '상아탑', '베히모스', '서막', '1막', '2막', '3막', '4막', '종막', '세르카', '기타'
  ];

  // 키워드 표시명 => 실제 검색어 매핑
  final Map<String, String> _keywordMapping = {
    '서막': '에키드나',
    '1막': '에기르',
    '2막': '아브렐슈드',
    '3막': '모르둠',
    '4막': '아르모체',
    '종막': '카제로스',
  };

  // 영상 등록 시 사용될 내부 분류 (화면에는 표시되지 않지만 등록 시 필요)
  final Map<String, List<String>> _raidByCategory = {
    '군단장 레이드': ['발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘'],
    '에픽 레이드': ['베히모스'],
    '카제로스 레이드': ['(서막)에키드나', '(1막)에기르', '(2막)아브렐슈드', '(3막)모르둠', '(4막)아르모체', '(종막)카제로스'],
    '그림자 레이드': ['세르카'],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      const List<String> playlistIds = [
        'PLfeapZwXytc5hLWufxWTGOZsF9Hx_IsVa', // 꿀맹이는 여왕님
//         'PLMAYHL7_2pknYPEMC7wcP1WFINEfCS9xX', // 바보온돌 (이슈 발생 시 주석 처리)
        'PLMAYHL7_2pknWRmpGLK6kbsit75Vu4YC0', // 바보온돌
        'PLMAYHL7_2pknNJ_VXH3jd-YtSZq13CBxc', // 바보온돌
        'PLMAYHL7_2pknM3ZUjR68XASaXnOPKy2gB', // 바보온돌
        'PLMAYHL7_2pkkhJVv05QgpN8ZIb5AjzGZf', // 바보온돌
        'PLQMXZuhZUJEBkcXgn9XPb_3xmMXpbXsy1'  // 김상드
      ];

      List<Future> futures = [_apiService.getVideos()];
      for (final playlistId in playlistIds) {
        futures.add(_apiService.getPlaylistItems(playlistId));
      }

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          final raidVideos = results[0] as List<RaidVideo>;
          final playlistItems = results
              .sublist(1)
              .expand((items) => items as List<PlaylistItem>)
              .toList();

          // 두 리스트를 합칩니다.
          _allContent = [...raidVideos, ...playlistItems];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("데이터 로딩 중 에러 발생: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refreshVideos() {
    _loadData();
  }

  void _applyFilters() {
    List<dynamic> filtered;

    if (_selectedGuideKeyword == '전체') {
      filtered = _allContent;
    } else if (_selectedGuideKeyword == '기타') {
      final keywords = _guideKeywords.where((k) => k != '전체' && k != '기타').toList();
      filtered = _allContent.where((item) {
        String title = '';
        String raidName = '';

        if (item is RaidVideo) {
            title = item.title;
            raidName = item.raidName;
        } else if (item is PlaylistItem) {
            title = item.title;
        }

        // 키워드 목록에 있는 단어가 하나라도 포함되면 제외
        bool isKnownRaid = keywords.any((keyword) {
          if (title.contains(keyword) || raidName == keyword) return true;
          final mappedTerm = _keywordMapping[keyword];
          return mappedTerm != null && title.contains(mappedTerm);
        });
        
        return !isKnownRaid;
      }).toList();
    } else {
      // 특정 키워드 선택 시
      filtered = _allContent.where((item) {
        String title = '';
        String raidName = '';
        
        if (item is RaidVideo) {
            title = item.title;
            raidName = item.raidName;
            
            // RaidVideo는 raidName으로도 매칭 가능
            if (raidName.contains(_selectedGuideKeyword)) return true;
            final mappedTerm = _keywordMapping[_selectedGuideKeyword];
            if (mappedTerm != null && raidName.contains(mappedTerm)) return true;
        } else if (item is PlaylistItem) {
            title = item.title;
        }
        
        // 제목 매칭
        if (title.contains(_selectedGuideKeyword)) return _isValidGuideItem(item);
        final mappedTerm = _keywordMapping[_selectedGuideKeyword];
        return mappedTerm != null && title.contains(mappedTerm) && _isValidGuideItem(item);
      }).toList();
    }
    _filteredContent = filtered;
  }

  bool _isValidGuideItem(dynamic item) {
    if (_selectedGuideKeyword != '2막') {
      return true;
    }
    
    // 2막 필터링 시 2024년 이후 영상만 (구 아브렐슈드 제외 로직)
    String? publishedAtStr;
    if (item is PlaylistItem) {
        publishedAtStr = item.publishedAt;
    } else {
        // RaidVideo는 날짜 정보가 없으면 통과시킴 (혹은 수동 관리되므로 맞다고 가정)
        return true; 
    }

    final publishedAt = DateTime.tryParse(publishedAtStr);
    if (publishedAt == null) {
      return true;
    }

    return publishedAt.year >= 2024;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading) {
      _applyFilters();
    }
    
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost Ark Raid Hub'),
        actions: [
          // 관리자 로그인 버튼
          IconButton(
            icon: Icon(authService.isAuthenticated ? Icons.logout : Icons.admin_panel_settings),
            tooltip: authService.isAuthenticated ? '로그아웃' : '관리자 로그인',
            onPressed: () {
                if (authService.isAuthenticated) {
                    authService.logout();
                } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideKeywordFilters(),
                Expanded(
                  child: _filteredContent.isEmpty
                      ? const Center(child: Text("해당 키워드의 공략 영상이 없습니다."))
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: _filteredContent.length,
                          itemBuilder: (context, index) {
                            final item = _filteredContent[index];
                            if (item is RaidVideo) {
                                return _buildVideoCard(item);
                            } else {
                                return _buildPlaylistCard(item as PlaylistItem);
                            }
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: authService.isAdmin
          ? FloatingActionButton(
              onPressed: _showAddVideoDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildGuideKeywordFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: _guideKeywords.map((keyword) {
          return ChoiceChip(
            label: Text(keyword),
            selected: _selectedGuideKeyword == keyword,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedGuideKeyword = keyword);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  // 영상 카드 위젯 (DB 데이터)
  Widget _buildVideoCard(RaidVideo video) {
    String? thumbnailUrl = _getYouTubeThumbnail(video.youtubeUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4, // 수동 추가 영상 강조
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          final videoId = _getYouTubeVideoId(video.youtubeUrl);
          if (videoId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(videoId: videoId),
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
                  ? Image.network(thumbnailUrl, fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => Container(
                          color: Colors.grey,
                          child: const Icon(Icons.broken_image)))
                  : Container(
                      color: Colors.black12,
                      child: const Icon(Icons.videocam, size: 50)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "[관리자 등록] ${video.raidName} - ${video.difficulty}",
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${video.gate} | ${video.uploaderName}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 플레이리스트 카드 위젯 (유튜브 API 데이터)
  Widget _buildPlaylistCard(PlaylistItem item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(videoId: item.videoId),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: item.thumbnailUrl.isNotEmpty
                  ? Image.network(item.thumbnailUrl, fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => Container(
                          color: Colors.grey,
                          child: const Icon(Icons.broken_image)))
                  : Container(
                      color: Colors.black12,
                      child: const Icon(Icons.videocam, size: 50)),
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
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.channelTitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.publishedAt,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getYouTubeVideoId(String url) {
    try {
      Uri uri = Uri.parse(url);
      if (uri.host.contains("youtu.be")) {
        return uri.pathSegments.first;
      } else if (uri.host.contains("youtube.com")) {
        return uri.queryParameters['v'];
      }
    } catch (e) {
      // Handle parsing error
    }
    return null;
  }

  String? _getYouTubeThumbnail(String url) {
    final videoId = _getYouTubeVideoId(url);
    if (videoId != null) {
      return "https://img.youtube.com/vi/$videoId/mqdefault.jpg";
    }
    return null;
  }

  void _showAddVideoDialog() {
    showDialog(
      context: context,
      builder: (context) => VideoUploadDialog(
        raidByCategory: _raidByCategory,
        onUpload: (video) async {
          try {
            await _apiService.createVideo(video);
            Navigator.pop(context);
            _refreshVideos();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('영상이 성공적으로 등록되었습니다!')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('등록 실패: $e')),
            );
          }
        },
      ),
    );
  }
}

class VideoUploadDialog extends StatefulWidget {
  final Map<String, List<String>> raidByCategory;
  final Function(RaidVideo) onUpload;

  const VideoUploadDialog({
    super.key,
    required this.raidByCategory,
    required this.onUpload,
  });

  @override
  State<VideoUploadDialog> createState() => _VideoUploadDialogState();
}

class _VideoUploadDialogState extends State<VideoUploadDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedCategory;
  String? _selectedRaidName;

  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _uploaderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.raidByCategory.keys.first;
    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('공략 영상 등록'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 카테고리 선택 - 내부 분류용
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: '레이드 분류'),
                items: widget.raidByCategory.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val!;
                    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
                  });
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedRaidName,
                decoration: const InputDecoration(labelText: '레이드 이름'),
                items: widget.raidByCategory[_selectedCategory]?.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedRaidName = val;
                  });
                },
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '영상 제목'),
                validator: (val) => val!.isEmpty ? '제목을 입력하세요' : null,
              ),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: '유튜브 URL'),
                validator: (val) => val!.isEmpty ? 'URL을 입력하세요' : null,
              ),
              TextFormField(
                controller: _uploaderController,
                decoration: const InputDecoration(labelText: '스트리머/유튜버 이름'),
                validator: (val) => val!.isEmpty ? '이름을 입력하세요' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final video = RaidVideo(
                title: _titleController.text,
                youtubeUrl: _urlController.text,
                uploaderName: _uploaderController.text,
                raidName: _selectedRaidName!,
                difficulty: '공략', // 기본값 설정
                gate: '전체',       // 기본값 설정
              );
              widget.onUpload(video);
            }
          },
          child: const Text('등록'),
        ),
      ],
    );
  }
}
