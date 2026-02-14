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
    ChangeNotifierProvider( // Provide AuthService to the widget tree
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
          brightness: Brightness.dark, // 다크 모드 느낌
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
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();

  // Data
  List<RaidVideo> _allVideos = [];
  List<PlaylistItem> _allPlaylistItems = [];

  // Filtered Data
  List<RaidVideo> _filteredVideos = [];
  List<PlaylistItem> _filteredPlaylistItems = [];

  // Loading State
  bool _isLoading = true;

  // 필터용 상태 변수들
  String _selectedLegionRaid = '전체';
  String _selectedDifficultyFilter = '전체';
  String _selectedGuideKeyword = '전체';

  final List<String> _legionRaids = ['전체', '발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘'];

  final List<String> _guideKeywords = ['전체', '발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘', '카양겔', '상아탑', '베히모스', '서막', '1막', '2막', '3막', '4막', '종막', '기타'];

  // 키워드 표시명 => 실제 검색어 매핑
  final Map<String, String> _keywordMapping = {
    '서막': '에키드나',
    '1막': '에기르',
    '2막': '아브렐슈드',
    '3막': '모르둠',
    '4막': '아르모체',
    '종막': '카제로스',
  };

  // 카테고리 정의
  final List<String> _categories = [
    '전체',
    '군단장 레이드',
    '에픽 레이드', // 에픽 레이드 다시 추가
    '카제로스 레이드',
    '그림자 레이드',
    '공략',
    '관리자 로그인'
  ];

  // 레이드 이름 -> 카테고리 매핑 (단순 필터링용 데이터)
  final Map<String, List<String>> _raidByCategory = {
    '군단장 레이드': ['발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘'],
    '에픽 레이드': ['베히모스'], // 베히모스를 에픽 레이드에 추가
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
      const String playlistId = 'PLfeapZwXytc5hLWufxWTGOZsF9Hx_IsVa';
      final results = await Future.wait([
        _apiService.getVideos(),
        _apiService.getPlaylistItems(playlistId),
      ]);

      if (mounted) {
        setState(() {
          _allVideos = results[0] as List<RaidVideo>;
          _allPlaylistItems = results[1] as List<PlaylistItem>;
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

  void _onCategorySelected(int index) {
    if (_categories[index] == '관리자 로그인') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }
    
    setState(() {
      _selectedIndex = index;
      _selectedLegionRaid = '전체';
      _selectedDifficultyFilter = '전체';
      _selectedGuideKeyword = '전체';
    });
  }

  void _applyFilters() {
    // --- Video Filtering ---
    final selectedCategory = _categories[_selectedIndex];
    List<RaidVideo> categoryFilteredVideos;
    if (_selectedIndex == 0) {
      categoryFilteredVideos = _allVideos;
    } else {
      List<String>? targetRaids = _raidByCategory[selectedCategory];
      categoryFilteredVideos = _allVideos.where((video) => targetRaids?.contains(video.raidName) ?? false).toList();
    }

    List<RaidVideo> legionRaidFilteredVideos;
    if (selectedCategory == '군단장 레이드' && _selectedLegionRaid != '전체') {
      legionRaidFilteredVideos = categoryFilteredVideos.where((video) => video.raidName == _selectedLegionRaid).toList();
    } else {
      legionRaidFilteredVideos = categoryFilteredVideos;
    }

    final availableDifficulties = ['전체', ...legionRaidFilteredVideos.map((v) => v.difficulty).toSet().toList()];
    if (!availableDifficulties.contains(_selectedDifficultyFilter)) {
      // This is now safe because it happens during the build, not in a callback that triggers a rebuild.
      _selectedDifficultyFilter = '전체';
    }

    if (_selectedDifficultyFilter != '전체') {
      _filteredVideos = legionRaidFilteredVideos.where((video) => video.difficulty == _selectedDifficultyFilter).toList();
    } else {
      _filteredVideos = legionRaidFilteredVideos;
    }

    // --- Playlist Filtering ---
    List<PlaylistItem> filteredItems;
    if (_selectedGuideKeyword == '전체') {
      filteredItems = _allPlaylistItems;
    } else if (_selectedGuideKeyword == '기타') {
      final keywords = _guideKeywords.where((k) => k != '전체' && k != '기타').toList();
      filteredItems = _allPlaylistItems.where((item) {
        return !keywords.any((keyword) {
          if (item.title.contains(keyword)) return true;
          final mappedTerm = _keywordMapping[keyword];
          return mappedTerm != null && item.title.contains(mappedTerm);
        });
      }).toList();
    } else {
      filteredItems = _allPlaylistItems.where((item) {
        if (item.title.contains(_selectedGuideKeyword)) return true;
        final mappedTerm = _keywordMapping[_selectedGuideKeyword];
        return mappedTerm != null && item.title.contains(mappedTerm);
      }).toList();
    }
    _filteredPlaylistItems = filteredItems;
  }

  @override
  Widget build(BuildContext context) {
    // Apply filters on every build to ensure UI is consistent with the state.
    if (!_isLoading) {
      _applyFilters();
    }
    
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost Ark Raid Hub'),
        actions: [
          if (authService.isAuthenticated)
            TextButton.icon(
              onPressed: () => authService.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onCategorySelected,
            labelType: NavigationRailLabelType.all,
            destinations: _categories.map((category) {
              IconData icon;
              switch (category) {
                case '전체': icon = Icons.dashboard; break;
                case '군단장 레이드': icon = Icons.shield; break;
                case '에픽 레이드': icon = Icons.star; break;
                case '카제로스 레이드': icon = Icons.whatshot; break;
                case '그림자 레이드': icon = Icons.visibility_off; break;
                case '공략': icon = Icons.school; break;
                default: icon = Icons.category;
              }
              return NavigationRailDestination(
                icon: Icon(icon),
                label: Text(category),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
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

  Widget _buildContent() {
    final selectedCategory = _categories[_selectedIndex];
    if (selectedCategory == '공략') {
      return _buildPlaylistContent();
    }
    return _buildVideoContent();
  }

  Widget _buildPlaylistContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGuideKeywordFilters(),
        Expanded(
          child: _filteredPlaylistItems.isEmpty
              ? const Center(child: Text("해당 키워드의 공략 영상이 없습니다."))
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: _filteredPlaylistItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredPlaylistItems[index];
                    return _buildPlaylistCard(item);
                  },
                ),
        ),
      ],
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

  Widget _buildSubCategoryFilters() {
    if (_categories[_selectedIndex] != '군단장 레이드') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: _legionRaids.map((raidName) {
          return ChoiceChip(
            label: Text(raidName),
            selected: _selectedLegionRaid == raidName,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedLegionRaid = raidName;
                  _selectedDifficultyFilter = '전체';
                });
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVideoContent() {
    // Note: availableDifficulties logic moved inside _applyFilters, but we still need it for building the widget.
    final availableDifficulties = ['전체', ..._allVideos.where((v) {
        final selectedCategory = _categories[_selectedIndex];
        if (selectedCategory == '군단장 레이드' && _selectedLegionRaid != '전체') {
            return v.raidName == _selectedLegionRaid;
        }
        List<String>? targetRaids = _raidByCategory[selectedCategory];
        return targetRaids?.contains(v.raidName) ?? (_selectedIndex == 0);
    }).map((v) => v.difficulty).toSet().toList()];


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubCategoryFilters(),
        _buildDifficultyFilters(availableDifficulties),
        Expanded(
          child: _filteredVideos.isEmpty
              ? const Center(child: Text("이 카테고리에 해당하는 영상이 없습니다."))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: _filteredVideos.length,
                  itemBuilder: (context, index) {
                    final video = _filteredVideos[index];
                    return _buildVideoCard(video);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDifficultyFilters(List<String> difficulties) {
    if (difficulties.length <= 2) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: difficulties.map((difficulty) {
          return ChoiceChip(
            label: Text(difficulty),
            selected: _selectedDifficultyFilter == difficulty,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedDifficultyFilter = difficulty);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  // 영상 카드 위젯
  Widget _buildVideoCard(RaidVideo video) {
    String? thumbnailUrl = _getYouTubeThumbnail(video.youtubeUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          print('Video card tapped: ${video.title}');
          final videoId = _getYouTubeVideoId(video.youtubeUrl);
          if (videoId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(videoId: videoId),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('유튜브 비디오 ID를 찾을 수 없습니다.')),
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
                      "${video.raidName} [${video.difficulty}]",
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary),
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

  // 플레이리스트 카드 위젯 (공략용)
  Widget _buildPlaylistCard(PlaylistItem item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          print('Playlist item card tapped: ${item.title}');
          final videoId = _getYouTubeVideoId(item.youtubeUrl);
          if (videoId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(videoId: videoId),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('유튜브 비디오 ID를 찾을 수 없습니다.')),
            );
          }
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
                          color: Theme.of(context).colorScheme.primary),
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
      // Handle parsing error if needed
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
        categories: _categories.sublist(1),
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

// 영상 등록 다이얼로그 위젯 분리
class VideoUploadDialog extends StatefulWidget {
  final List<String> categories;
  final Map<String, List<String>> raidByCategory;
  final Function(RaidVideo) onUpload;

  const VideoUploadDialog({
    super.key,
    required this.categories,
    required this.raidByCategory,
    required this.onUpload,
  });

  @override
  State<VideoUploadDialog> createState() => _VideoUploadDialogState();
}

class _VideoUploadDialogState extends State<VideoUploadDialog> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = '';
  String? _selectedRaidName;
  String? _selectedDifficulty;

  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _uploaderController = TextEditingController();
  final _gateController = TextEditingController();

  static const Map<String, List<String>> _comprehensiveRaidDifficulties = {
    '발탄': ['싱글', '노말', '하드'],
    '비아키스': ['싱글', '노말', '하드'],
    '아브렐슈드': ['싱글', '노말', '하드'],
    '일리아칸': ['싱글', '노말', '하드'],
    '카멘': ['싱글', '노말', '하드'],
    '쿠크세이튼': ['싱글', '노말'],
    '베히모스': ['노말'],
    '(서막)에키드나': ['싱글', '노말', '하드'],
    '(1막)에기르': ['싱글', '노말', '하드'],
    '(2막)아브렐슈드': ['싱글', '노말', '하드'],
    '(3막)모르둠': ['싱글', '노말', '하드'],
    '(4막)아르모체': ['노말', '하드'],
    '(종막)카제로스': ['노말', '하드'],
    '세르카': ['노말', '하드', '나이트메어'],
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.first;
    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
    _updateAvailableDifficulties();
  }

  void _updateAvailableDifficulties() {
    final availableDifficulties = _comprehensiveRaidDifficulties[_selectedRaidName] ?? ['노말', '하드'];
    
    if (_selectedDifficulty == null || !availableDifficulties.contains(_selectedDifficulty)) {
      _selectedDifficulty = availableDifficulties.first;
    }
  }

  String? _difficultyValidator(String? value) {
    if (value == null || value.isEmpty) {
      return '난이도를 선택하세요';
    }
    final allowedDifficulties = _comprehensiveRaidDifficulties[_selectedRaidName] ?? [];
    if (!allowedDifficulties.contains(value)) {
      return '선택된 레이드에 유효하지 않은 난이도입니다.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentRaidDifficulties = _comprehensiveRaidDifficulties[_selectedRaidName] ?? ['노말', '하드'];

    return AlertDialog(
      title: const Text('공략 영상 등록'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val!;
                    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
                    _updateAvailableDifficulties();
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
                    _updateAvailableDifficulties();
                  });
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(labelText: '난이도'),
                items: currentRaidDifficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _selectedDifficulty = val!),
                validator: _difficultyValidator,
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
              TextFormField(
                controller: _gateController,
                decoration: const InputDecoration(labelText: '관문 (예: 1관문, 전체)'),
                validator: (val) => val!.isEmpty ? '관문을 입력하세요' : null,
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
                difficulty: _selectedDifficulty!,
                gate: _gateController.text,
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