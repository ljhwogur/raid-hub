import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:file_picker/file_picker.dart'; // Import FilePicker
import 'models/raid_video.dart';
import 'models/playlist_item.dart';
import 'models/cheat_sheet.dart'; // Import CheatSheet model
import 'services/api_service.dart';
import 'services/auth_service.dart'; // Import AuthService
import 'screens/login_screen.dart'; // Import LoginScreen
import 'screens/video_player_screen.dart'; // Import VideoPlayerScreen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: authService,
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

  // Navigation & Filter State
  int _currentIndex = 0; 
  String _selectedGuideKeyword = '전체';
  String _searchQuery = '';
  String _sortOption = '최신순'; // '최신순', '제목순'
  final _searchController = TextEditingController();

  // Data - Videos
  List<dynamic> _allContent = []; 
  List<dynamic> _filteredContent = [];
  List<dynamic> _blockedContent = [];
  List<String> _blockedVideoIds = [];

  // Data - Cheat Sheets
  List<CheatSheet> _allCheatSheets = [];
  List<CheatSheet> _filteredCheatSheets = [];

  // Loading State
  bool _isLoading = true;

  final List<String> _guideKeywords = [
    '전체', '발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘', 
    '카양겔', '상아탑', '베히모스', '서막', '1막', '2막', '3막', '4막', '종막', '세르카', '기타'
  ];

  final Map<String, String> _keywordMapping = {
    '서막': '에키드나',
    '1막': '에기르',
    '2막': '아브렐슈드',
    '3막': '모르둠',
    '4막': '아르모체',
    '종막': '카제로스',
  };

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
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      const List<String> playlistIds = [
        'PLfeapZwXytc5hLWufxWTGOZsF9Hx_IsVa', // 꿀맹이는 여왕님 로스트아크 공략
        'PLMAYHL7_2pknWRmpGLK6kbsit75Vu4YC0', // 바보온돌 싱글모드 공략
        'PLMAYHL7_2pknNJ_VXH3jd-YtSZq13CBxc', // 바보온돌 헬/시련 공략
        'PLMAYHL7_2pknM3ZUjR68XASaXnOPKy2gB', // 바보온돌 어비스 레이드
        'PLMAYHL7_2pkkhJVv05QgpN8ZIb5AjzGZf', // 바보온돌 군단장 레이드
        'PLQMXZuhZUJEBkcXgn9XPb_3xmMXpbXsy1', // 김상드 로스트아크 공략
        'PLMAYHL7_2pknYPEMC7wcP1WFINEfCS9xX' // 바보온돌 완전공략
      ];

      List<Future> futures = [
        _apiService.getVideos(), 
        _apiService.getBlockedVideoIds(),
        _apiService.getCheatSheets()
      ];
      for (final playlistId in playlistIds) {
        futures.add(_apiService.getPlaylistItems(playlistId));
      }

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          final raidVideos = results[0] as List<RaidVideo>;
          _blockedVideoIds = results[1] as List<String>;
          _allCheatSheets = results[2] as List<CheatSheet>;

          final playlistItems = results
              .sublist(3)
              .expand((items) => items as List<PlaylistItem>)
              .toList();
          
          _blockedContent = playlistItems.where((item) => _blockedVideoIds.contains(item.videoId)).toList();
          final filteredPlaylistItems = playlistItems.where((item) => !_blockedVideoIds.contains(item.videoId)).toList();

          _allContent = [...raidVideos, ...filteredPlaylistItems];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("데이터 로딩 중 에러 발생: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshVideos() async {
    await _loadData();
  }

  void _applyFilters() {
    // 1. 영상 필터링 & 검색
    List<dynamic> filteredVideos = _allContent.where((item) {
      String title = (item is RaidVideo) ? item.title : (item as PlaylistItem).title;
      String uploader = (item is RaidVideo) ? item.uploaderName : (item as PlaylistItem).channelTitle;
      String raidName = (item is RaidVideo) ? item.raidName : '';

      // 키워드 필터 적용
      bool matchesKeyword = false;
      if (_selectedGuideKeyword == '전체') {
        matchesKeyword = true;
      } else if (_selectedGuideKeyword == '기타') {
        final keywords = _guideKeywords.where((k) => k != '전체' && k != '기타').toList();
        bool isKnown = keywords.any((k) => 
            title.contains(k) || 
            raidName == k || 
            (_keywordMapping[k] != null && title.contains(_keywordMapping[k]!)));
        matchesKeyword = !isKnown;
      } else {
        DateTime? videoDate;
        if (item is PlaylistItem) {
          videoDate = DateTime.tryParse(item.publishedAt);
        } else if (item is RaidVideo) {
          videoDate = item.createdAt;
        }

        final actKeywords = ['서막', '1막', '2막', '3막', '4막', '종막'];
        
        List<String> itemActs = [];
        for (String act in actKeywords) {
          String mappedRaid = _keywordMapping[act]!;
          if (title.contains(act) || title.contains(mappedRaid) || raidName.contains(act) || raidName.contains(mappedRaid)) {
             itemActs.add(act);
          }
        }

        // '종막' 오분류 방지 ('카제로스'가 그룹명으로 쓰인 경우 필터링)
        // 다른 막이 같이 잡혔는데 명시적인 '종막' 단어가 없다면, 종막에서 제외 (남은 다른 막으로 정상 분류됨)
        if (itemActs.contains('종막') && itemActs.length > 1) {
          if (!title.contains('종막') && !raidName.contains('종막')) {
            itemActs.remove('종막');
          }
        }

        // 아브렐슈드 2막 날짜 판별 (2024년 9월 25일)
        bool isAfter2MakDate = videoDate != null && !videoDate.isBefore(DateTime(2024, 9, 25));
        if (title.contains('아브렐슈드') || raidName.contains('아브렐슈드') || title.contains('2막') || raidName.contains('2막')) {
          if (isAfter2MakDate) {
            if (!itemActs.contains('2막')) itemActs.add('2막');
          } else {
            itemActs.remove('2막');
          }
        }

        // 서막/4막 날짜 판별 (2025년 8월 20일)
        bool isAfter4MakDate = videoDate != null && !videoDate.isBefore(DateTime(2025, 8, 20));
        if (title.contains('서막') || title.contains('에키드나') || raidName.contains('서막') || raidName.contains('에키드나') ||
            title.contains('4막') || title.contains('아르모체') || raidName.contains('4막') || raidName.contains('아르모체')) {
          if (isAfter4MakDate) {
            itemActs.remove('서막');
            if (!itemActs.contains('4막')) itemActs.add('4막');
          } else {
            itemActs.remove('4막');
            if (!itemActs.contains('서막')) itemActs.add('서막');
          }
        }

        String? primaryAct;
        for (String act in actKeywords.reversed) {
          if (itemActs.contains(act)) {
            primaryAct = act;
            break;
          }
        }

        if (_keywordMapping.containsKey(_selectedGuideKeyword)) {
          matchesKeyword = (primaryAct == _selectedGuideKeyword);
        } else {
          matchesKeyword = title.contains(_selectedGuideKeyword) || raidName.contains(_selectedGuideKeyword);
          
          if (_selectedGuideKeyword == '아브렐슈드' && isAfter2MakDate) {
             matchesKeyword = false;
          } else if (matchesKeyword && primaryAct != null) {
             matchesKeyword = false;
          }
        }
      }

      // 검색어 필터 적용
      bool matchesSearch = _searchQuery.isEmpty || 
          title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          uploader.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          raidName.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesKeyword && matchesSearch;
    }).toList();

    // 영상 정렬
    if (_sortOption == '최신순') {
        filteredVideos.sort((a, b) {
            DateTime dateA = (a is RaidVideo) ? (a.createdAt ?? DateTime(2000)) : DateTime.tryParse((a as PlaylistItem).publishedAt) ?? DateTime(2000);
            DateTime dateB = (b is RaidVideo) ? (b.createdAt ?? DateTime(2000)) : DateTime.tryParse((b as PlaylistItem).publishedAt) ?? DateTime(2000);
            return dateB.compareTo(dateA);
        });
    } else {
        filteredVideos.sort((a, b) {
            String titleA = (a is RaidVideo) ? a.title : (a as PlaylistItem).title;
            String titleB = (b is RaidVideo) ? b.title : (b as PlaylistItem).title;
            return titleA.compareTo(titleB);
        });
    }
    _filteredContent = filteredVideos;

    // 2. 컨닝 페이퍼 필터링 & 검색
    List<CheatSheet> filteredCS = _allCheatSheets.where((cs) {
      bool matchesKeyword = false;
      if (_selectedGuideKeyword == '전체') {
        matchesKeyword = true;
      } else if (_selectedGuideKeyword == '기타') {
        final keywords = _guideKeywords.where((k) => k != '전체' && k != '기타').toList();
        matchesKeyword = !keywords.any((k) => cs.raidName.contains(k) || cs.title.contains(k));
      } else {
        final term = _keywordMapping[_selectedGuideKeyword] ?? _selectedGuideKeyword;
        matchesKeyword = cs.raidName.contains(term) || cs.title.contains(term);
      }

      bool matchesSearch = _searchQuery.isEmpty || 
          cs.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          cs.raidName.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesKeyword && matchesSearch;
    }).toList();

    // 컨닝 페이퍼 정렬
    if (_sortOption == '최신순') {
        filteredCS.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    } else {
        filteredCS.sort((a, b) => a.title.compareTo(b.title));
    }
    _filteredCheatSheets = filteredCS;
  }

  bool _isValidGuideItem(dynamic item) {
    if (_selectedGuideKeyword != '2막') return true;
    if (item is RaidVideo) return true; 
    final publishedAt = DateTime.tryParse((item as PlaylistItem).publishedAt);
    return publishedAt != null && publishedAt.year >= 2024;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading) _applyFilters();
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Lost Ark Raid Hub' : 'Raid Cheat Sheets'),
        actions: [
          if (authService.isAdmin)
            IconButton(
              icon: const Icon(Icons.visibility_off),
              tooltip: '숨긴 영상 관리',
              onPressed: _showBlockedVideosDialog,
            ),
          IconButton(
            icon: Icon(authService.isAuthenticated ? Icons.logout : Icons.admin_panel_settings),
            tooltip: authService.isAuthenticated ? '로그아웃' : '관리자 로그인',
            onPressed: () {
                if (authService.isAuthenticated) {
                    authService.logout();
                } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndSortBar(), // 검색 및 정렬 바
                _buildGuideKeywordFilters(),
                Expanded(
                  child: _currentIndex == 0 ? _buildVideosGrid() : _buildCheatSheetsGrid(),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: '공략 영상'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: '컨닝 페이퍼'),
        ],
      ),
      floatingActionButton: authService.isAdmin
          ? FloatingActionButton(
              onPressed: _currentIndex == 0 ? _showAddVideoDialog : _showAddCheatSheetDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSearchAndSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '제목, 작성자, 레이드 검색...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _sortOption,
            underline: const SizedBox(),
            icon: const Icon(Icons.sort),
            items: ['최신순', '제목순'].map((String val) {
              return DropdownMenuItem<String>(value: val, child: Text(val));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _sortOption = val);
            },
          ),
        ],
      ),
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
              if (selected) setState(() => _selectedGuideKeyword = keyword);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVideosGrid() {
    return _filteredContent.isEmpty
        ? const Center(child: Text("해당 키워드의 공략 영상이 없습니다."))
        : GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300, childAspectRatio: 0.8, crossAxisSpacing: 20, mainAxisSpacing: 20,
            ),
            itemCount: _filteredContent.length,
            itemBuilder: (context, index) {
              final item = _filteredContent[index];
              return (item is RaidVideo) ? _buildVideoCard(item) : _buildPlaylistCard(item as PlaylistItem);
            },
          );
  }

  Widget _buildCheatSheetsGrid() {
    return _filteredCheatSheets.isEmpty
        ? const Center(child: Text("해당 키워드의 컨닝 페이퍼가 없습니다."))
        : GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400, childAspectRatio: 1.2, crossAxisSpacing: 20, mainAxisSpacing: 20,
            ),
            itemCount: _filteredCheatSheets.length,
            itemBuilder: (context, index) => _buildCheatSheetCard(_filteredCheatSheets[index]),
          );
  }

  Widget _buildCheatSheetCard(CheatSheet cs) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: () => _showFullImage(cs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.network(cs.fullImageUrl, fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => const Center(child: Icon(Icons.broken_image, size: 50))),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cs.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text("${cs.raidName} | ${cs.gate}", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (authService.isAdmin)
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _confirmDeleteCheatSheet(cs),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullImage(CheatSheet cs) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(cs.fullImageUrl))),
            Positioned(
              top: 20, left: 20,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCheatSheetDialog() {
    final authService = Provider.of<AuthService>(context, listen: false); // Get authService
    showDialog(
      context: context,
      builder: (context) => CheatSheetUploadDialog(
        raidByCategory: _raidByCategory,
        onUpload: (title, raid, gate, bytes, name) async {
          try {
            await _apiService.uploadCheatSheet(
              title: title, 
              raidName: raid, 
              gate: gate, 
              uploaderName: authService.username ?? 'admin', // Use username or fallback
              fileBytes: bytes, 
              fileName: name
            );
            Navigator.pop(context);
            _refreshVideos();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('컨닝 페이퍼가 등록되었습니다!')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
          }
        },
      ),
    );
  }

  void _confirmDeleteCheatSheet(CheatSheet cs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("삭제 확인"),
        content: const Text("이 컨닝 페이퍼를 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            try {
              await _apiService.deleteCheatSheet(cs.id!);
              _refreshVideos();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("삭제 실패: $e")));
            }
          }, child: const Text("삭제", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // 영상 카드 위젯 (DB 데이터)
  Widget _buildVideoCard(RaidVideo video) {
    String? thumbnailUrl = _getYouTubeThumbnail(video.youtubeUrl);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4, // 수동 추가 영상 강조
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          InkWell(
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
          if (authService.isAdmin)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("영상 삭제"),
                        content: const Text("정말로 이 영상을 삭제하시겠습니까?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("취소"),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx); // 다이얼로그 닫기
                              try {
                                await _apiService.deleteVideo(video.id!);
                                _refreshVideos(); // 목록 새로고침
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("영상이 삭제되었습니다.")),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("삭제 실패: $e")),
                                  );
                                }
                              }
                            },
                            child: const Text("삭제", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 플레이리스트 카드 위젯 (유튜브 API 데이터)
  Widget _buildPlaylistCard(PlaylistItem item) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
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
                  icon: const Icon(Icons.visibility_off, color: Colors.orangeAccent, size: 20),
                  tooltip: '이 영상 숨기기',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("영상 숨기기"),
                        content: const Text("이 영상을 목록에서 숨기시겠습니까?\n(새로고침 후 적용됩니다)"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("취소"),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await _apiService.blockVideo(item.videoId, "관리자 숨김 처리");
                                if (mounted) {
                                  Navigator.pop(ctx); // 성공 후에 팝업 닫기
                                  _refreshVideos(); // 목록 새로고침
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("영상이 숨김 처리되었습니다.")),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("숨김 실패: $e")),
                                  );
                                }
                              }
                            },
                            child: const Text("숨기기", style: TextStyle(color: Colors.orange)),
                          ),
                        ],
                      ),
                    );
                  },
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

  void _showBlockedVideosDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('숨겨진 영상 목록'),
        content: SizedBox(
          width: double.maxFinite,
          child: _blockedContent.isEmpty
              ? const Center(child: Text("숨겨진 영상이 없습니다."))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _blockedContent.length,
                  itemBuilder: (context, index) {
                    final item = _blockedContent[index] as PlaylistItem;
                    return ListTile(
                      leading: Image.network(
                        item.thumbnailUrl,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, __) => const Icon(Icons.broken_image),
                      ),
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.channelTitle),
                      trailing: IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green),
                        tooltip: '영상 복구',
                          onPressed: () async {
                            try {
                              await _apiService.unblockVideo(item.videoId);
                              if (mounted) {
                                Navigator.pop(context); // API 성공 후에 팝업 닫기
                                _refreshVideos(); // 전체 목록 새로고침
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("영상이 복구되었습니다.")),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("복구 실패: $e")),
                                );
                              }
                            }
                          },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
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

class CheatSheetUploadDialog extends StatefulWidget {
  final Map<String, List<String>> raidByCategory;
  final Function(String, String, String, List<int>, String) onUpload;

  const CheatSheetUploadDialog({
    super.key,
    required this.raidByCategory,
    required this.onUpload,
  });

  @override
  State<CheatSheetUploadDialog> createState() => _CheatSheetUploadDialogState();
}

class _CheatSheetUploadDialogState extends State<CheatSheetUploadDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedCategory;
  String? _selectedRaidName;
  final _titleController = TextEditingController();
  final _gateController = TextEditingController(text: '전체');

  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.raidByCategory.keys.first;
    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // 바이트 데이터 가져오기 (웹 필수)
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('컨닝 페이퍼 등록'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pickedFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Image.memory(_pickedFile!.bytes!, height: 150, fit: BoxFit.cover),
                ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: Text(_pickedFile == null ? '이미지 선택' : '이미지 변경'),
              ),
              const SizedBox(height: 10),
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
                onChanged: (val) => setState(() => _selectedRaidName = val),
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '공략 제목 (예: 1관문 핵심 요약)'),
                validator: (val) => val!.isEmpty ? '제목을 입력하세요' : null,
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
            if (_formKey.currentState!.validate() && _pickedFile != null) {
              widget.onUpload(
                _titleController.text,
                _selectedRaidName!,
                _gateController.text,
                _pickedFile!.bytes!,
                _pickedFile!.name,
              );
            } else if (_pickedFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지를 선택해주세요.')));
            }
          },
          child: const Text('업로드'),
        ),
      ],
    );
  }
}
