import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:url_launcher/url_launcher.dart'; // 유튜브 링크 열기용 (추가 필요, 없으면 에러날 수 있으니 일단 로직만 구현하거나 패키지 추가)
import 'models/raid_video.dart';
import 'models/playlist_item.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart'; // Import AuthService
import 'screens/login_screen.dart'; // Import LoginScreen

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
  late Future<List<RaidVideo>> _videosFuture;
  late Future<List<PlaylistItem>> _playlistItemsFuture;

  // 필터용 상태 변수들
  String _selectedLegionRaid = '전체';
  String _selectedDifficultyFilter = '전체';
  String _selectedGuideKeyword = '전체';

  final List<String> _legionRaids = ['전체', '발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘'];

  final List<String> _guideKeywords = ['전체', '발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘', '카양겔', '상아탑', '베히모스', '서막', '1막',  '2막', '3막', '4막', '종막', '기타'];

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
    _refreshVideos();
    _loadPlaylistItems();
  }

  void _refreshVideos() {
    setState(() {
      _videosFuture = _apiService.getVideos();
    });
  }

  void _loadPlaylistItems() {
    const String playlistId = 'PLfeapZwXytc5hLWufxWTGOZsF9Hx_IsVa';
    _playlistItemsFuture = _apiService.getPlaylistItems(playlistId);
  }

  void _onCategorySelected(int index) {
    // '관리자 로그인' 카테고리인 경우 LoginScreen으로 이동
    if (_categories[index] == '관리자 로그인') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }
    
    setState(() {
      _selectedIndex = index;
      // 다른 카테고리를 선택하면 하위 필터들을 '전체'로 리셋
      _selectedLegionRaid = '전체';
      _selectedDifficultyFilter = '전체';
      _selectedGuideKeyword = '전체';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context); // Access AuthService

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost Ark Raid Hub'),
        actions: [
          if (authService.isAuthenticated) // Show logout button if authenticated
            TextButton.icon(
              onPressed: () {
                authService.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
        ],
      ),
      body: Row(
        children: [
          // 왼쪽 사이드바 (NavigationRail)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onCategorySelected, // 변경된 콜백 사용
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
          // 메인 컨텐츠 영역
          Expanded(
            child: _buildVideoContent(),
          ),
        ],
      ),
      floatingActionButton: authService.isAdmin // Show FAB only if admin
          ? FloatingActionButton(
              onPressed: _showAddVideoDialog,
              child: const Icon(Icons.add),
            )
          : null, // Don't show FAB if not admin
    );
  }

  // 플레이리스트 컨텐츠 빌드 (공략 카테고리용)
  Widget _buildPlaylistContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 공략 키워드 필터
        _buildGuideKeywordFilters(),
        
        Expanded(
          child: FutureBuilder<List<PlaylistItem>>(
            future: _playlistItemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("에러 발생: ${snapshot.error}"));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("등록된 공략 영상이 없습니다."));
              }

              final allItems = snapshot.data!;
              
              // 키워드 필터링
              List<PlaylistItem> filteredItems;
              if (_selectedGuideKeyword == '전체') {
                filteredItems = allItems;
              } else if (_selectedGuideKeyword == '기타') {
                // 기타는 다른 모든 키워드에 해당하지 않는 것
                final keywords = _guideKeywords.where((k) => k != '전체' && k != '기타').toList();
                filteredItems = allItems.where((item) {
                  return !keywords.any((keyword) => item.title.contains(keyword));
                }).toList();
              } else {
                filteredItems = allItems.where((item) => 
                  item.title.contains(_selectedGuideKeyword)
                ).toList();
              }
              
              if (filteredItems.isEmpty) {
                return const Center(child: Text("해당 키워드의 공략 영상이 없습니다."));
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _buildPlaylistCard(item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 공략 키워드 필터 위젯
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
              setState(() {
                if (selected) {
                  _selectedGuideKeyword = keyword;
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  // 하위 카테고리 필터 위젯 (군단장 레이드용)
  Widget _buildSubCategoryFilters() {
    // '군단장 레이드' 카테고리가 아니면 아무것도 보여주지 않음
    if (_categories[_selectedIndex] != '군단장 레이드') {
      return const SizedBox.shrink(); // 빈 공간
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
              setState(() {
                if (selected) {
                  _selectedLegionRaid = raidName;
                  // 군단장 필터 변경 시 난이도 필터도 리셋
                  _selectedDifficultyFilter = '전체';
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  // 영상 컨텐츠 영역 빌드 (필터링 로직 포함)
  Widget _buildVideoContent() {
    String selectedCategory = _categories[_selectedIndex];
    
    // "공략" 카테고리일 때 플레이리스트 표시
    if (selectedCategory == '공략') {
      return _buildPlaylistContent();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 하위 카테고리 필터
        _buildSubCategoryFilters(),

        // 영상 리스트
        Expanded(
          child: FutureBuilder<List<RaidVideo>>(
            future: _videosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("에러 발생: ${snapshot.error}"));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("등록된 영상이 없습니다."));
              }

              // --- 필터링 로직 시작 ---
              final allVideos = snapshot.data!;
              
              // 1단계: 메인 카테고리 필터링
              List<RaidVideo> categoryFilteredVideos;
              if (_selectedIndex == 0) {
                categoryFilteredVideos = allVideos; // 전체보기
              } else {
                List<String>? targetRaids = _raidByCategory[selectedCategory];
                if (targetRaids == null) {
                  categoryFilteredVideos = [];
                } else {
                  categoryFilteredVideos = allVideos.where((video) => targetRaids.contains(video.raidName)).toList();
                }
              }

              // 2단계: 군단장 레이드 하위 카테고리 필터링
              List<RaidVideo> legionRaidFilteredVideos;
              if (selectedCategory == '군단장 레이드' && _selectedLegionRaid != '전체') {
                legionRaidFilteredVideos = categoryFilteredVideos.where((video) => video.raidName == _selectedLegionRaid).toList();
              } else {
                legionRaidFilteredVideos = categoryFilteredVideos;
              }

              // 3단계: 현재 필터링된 영상들에서 동적으로 난이도 목록 추출
              final availableDifficulties = ['전체', ...legionRaidFilteredVideos.map((v) => v.difficulty).toSet().toList()];

              // 4단계: 최종 난이도 필터링
              List<RaidVideo> finalFilteredVideos;
              if (_selectedDifficultyFilter != '전체') {
                finalFilteredVideos = legionRaidFilteredVideos.where((video) => video.difficulty == _selectedDifficultyFilter).toList();
              } else {
                finalFilteredVideos = legionRaidFilteredVideos;
              }
              // --- 필터링 로직 끝 ---

              if (finalFilteredVideos.isEmpty) {
                return Column(
                  children: [
                    _buildDifficultyFilters(availableDifficulties), // 필터는 계속 보여줌
                    const Expanded(
                      child: Center(child: Text("이 카테고리에 해당하는 영상이 없습니다."))
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _buildDifficultyFilters(availableDifficulties),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: finalFilteredVideos.length,
                      itemBuilder: (context, index) {
                        final video = finalFilteredVideos[index];
                        return _buildVideoCard(video);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // 난이도 필터 위젯
  Widget _buildDifficultyFilters(List<String> difficulties) {
    // '전체' 와 유니크한 난이도 1개만 있으면 굳이 필터 안보여줌
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
              setState(() {
                if (selected) {
                  _selectedDifficultyFilter = difficulty;
                }
              });
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
        onTap: () async {
          if (await canLaunchUrl(Uri.parse(video.youtubeUrl))) {
            await launchUrl(Uri.parse(video.youtubeUrl));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('유튜브 링크를 열 수 없습니다: ${video.youtubeUrl}')),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 영역
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
        onTap: () async {
          if (await canLaunchUrl(Uri.parse(item.youtubeUrl))) {
            await launchUrl(Uri.parse(item.youtubeUrl));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('유튜브 링크를 열 수 없습니다: ${item.youtubeUrl}')),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 영역
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

  // 유튜브 URL에서 썸네일 추출
  String? _getYouTubeThumbnail(String url) {
    try {
      Uri uri = Uri.parse(url);
      String? videoId;
      if (uri.host.contains("youtu.be")) {
        videoId = uri.pathSegments.first;
      } else if (uri.host.contains("youtube.com")) {
        videoId = uri.queryParameters['v'];
      }
      if (videoId != null) {
        return "https://img.youtube.com/vi/$videoId/mqdefault.jpg";
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // 영상 등록 다이얼로그
  void _showAddVideoDialog() {
    showDialog(
      context: context,
      builder: (context) => VideoUploadDialog(
        categories: _categories.sublist(1), // '전체' 제외
        raidByCategory: _raidByCategory,
        onUpload: (video) async {
          try {
            await _apiService.createVideo(video);
            Navigator.pop(context);
            _refreshVideos(); // 목록 새로고침
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

  // 입력 값 저장 변수
  String _selectedCategory = ''; // 초기값 설정
  String? _selectedRaidName;
  String? _selectedDifficulty;

  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _uploaderController = TextEditingController();
  final _gateController = TextEditingController();

  // 모든 레이드에 대한 포괄적인 난이도 정의
  static const Map<String, List<String>> _comprehensiveRaidDifficulties = {
    // 군단장 레이드
    '발탄': ['싱글', '노말', '하드'],
    '비아키스': ['싱글', '노말', '하드'],
    '아브렐슈드': ['싱글', '노말', '하드'],
    '일리아칸': ['싱글', '노말', '하드'],
    '카멘': ['싱글', '노말', '하드'],
    '쿠크세이튼': ['싱글', '노말'],

    // 에픽 레이드
    '베히모스': ['노말'],
    '(서막)에키드나': ['싱글', '노말', '하드'],
    '(1막)에기르': ['싱글', '노말', '하드'],
    '(2막)아브렐슈드': ['싱글', '노말', '하드'],
    '(3막)모르둠': ['싱글', '노말', '하드'],
    '(4막)아르모체': ['노말', '하드'],
    '(종막)카제로스': ['노말', '하드'],

    // 그림자 레이드
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
    // 현재 선택된 레이드 이름이 종합 맵에 있는지 확인하고 해당하는 난이도 목록을 가져옴
    final availableDifficulties = _comprehensiveRaidDifficulties[_selectedRaidName] ?? ['노말', '하드']; // 기본값 설정 (명확하게 알 수 없는 경우)
    
    // 현재 선택된 난이도가 유효한지 확인하고, 유효하지 않으면 첫 번째 난이도로 설정
    if (_selectedDifficulty == null || !availableDifficulties.contains(_selectedDifficulty)) {
      _selectedDifficulty = availableDifficulties.first;
    }
  }

  // 난이도 드롭다운의 유효성 검사기
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
    // 현재 선택된 레이드에 맞는 난이도 목록
    final currentRaidDifficulties = _comprehensiveRaidDifficulties[_selectedRaidName] ?? ['노말', '하드']; // 알 수 없는 레이드의 기본 난이도

    return AlertDialog(
      title: const Text('공략 영상 등록'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 카테고리 선택
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val!;
                    // 새 카테고리에 해당하는 첫 번째 레이드 이름으로 설정
                    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
                    _updateAvailableDifficulties(); // 난이도 목록 갱신
                  });
                },
              ),
              // 레이드 이름 선택
              DropdownButtonFormField<String>(
                value: _selectedRaidName,
                decoration: const InputDecoration(labelText: '레이드 이름'),
                items: widget.raidByCategory[_selectedCategory]?.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedRaidName = val;
                    _updateAvailableDifficulties(); // 난이도 목록 갱신
                  });
                },
              ),
              // 난이도
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(labelText: '난이도'),
                items: currentRaidDifficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _selectedDifficulty = val!),
                validator: _difficultyValidator, // 난이도 유효성 검사기 추가
              ),
              // 제목
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '영상 제목'),
                validator: (val) => val!.isEmpty ? '제목을 입력하세요' : null,
              ),
              // 유튜브 URL
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: '유튜브 URL'),
                validator: (val) => val!.isEmpty ? 'URL을 입력하세요' : null,
              ),
              // 스트리머
              TextFormField(
                controller: _uploaderController,
                decoration: const InputDecoration(labelText: '스트리머/유튜버 이름'),
                validator: (val) => val!.isEmpty ? '이름을 입력하세요' : null,
              ),
              // 관문
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