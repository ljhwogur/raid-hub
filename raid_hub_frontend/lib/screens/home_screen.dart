import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:async'; // Add Timer import
import 'dart:ui'; // For ImageFilter
import 'package:provider/provider.dart';
import '../models/raid_video.dart';
import '../models/playlist_item.dart';
import '../models/cheat_sheet.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'landing_screen.dart';
import '../widgets/skeleton_ui.dart';
import '../widgets/cheat_sheet_card.dart';
import '../widgets/video_cards.dart';
import '../widgets/upload_dialogs.dart';

class HomePage extends StatefulWidget {
  final int initialIndex;
  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();

  // Navigation & Filter State
  late int _currentIndex;

  String _selectedGuideKeyword = '전체';
  String _searchQuery = '';
  String _selectedCategory = '전체 레이드';
  String _selectedRaid = '전체';

  final _searchController = TextEditingController();

  // Data
  List<dynamic> _allContent = [];
  List<dynamic> _filteredContent = [];
  List<dynamic> _blockedContent = [];
  List<String> _blockedVideoIds = [];
  List<CheatSheet> _allCheatSheets = [];
  List<CheatSheet> _filteredCheatSheets = [];
  List<RaidVideo> _raidVideos = [];
  List<PlaylistItem> _playlistItems = [];

  bool _isLoading = true;
  bool _playlistLoaded = false;
  bool _isPlaylistLoading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
      // 검색 로그 기록 (의미 있는 검색어인 경우에만)
      if (_searchQuery.length >= 2) {
        _logSearch(_searchQuery);
      }
    });
  }

  Timer? _searchLogTimer;
  void _logSearch(String query) {
    _searchLogTimer?.cancel();
    _searchLogTimer = Timer(const Duration(seconds: 2), () {
      _apiService.logActivity(
        activityType: 'SEARCH',
        searchQuery: query,
      );
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
      final List<Future<dynamic>> futures = [
        _apiService.getVideos(),
        _apiService.getBlockedVideoIds(),
        _apiService.getCheatSheets()
      ];

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _raidVideos = results[0] as List<RaidVideo>;
          _blockedVideoIds = results[1] as List<String>;
          _allCheatSheets = results[2] as List<CheatSheet>;
          _playlistItems = [];
          _playlistLoaded = false;
          _blockedContent = [];
          _allContent = [..._raidVideos];
          _isLoading = false;
        });
      }

      if (_currentIndex == 0) {
        _loadPlaylistsIfNeeded();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlaylistsIfNeeded({bool force = false}) async {
    if (_isPlaylistLoading) return;
    if (_playlistLoaded && !force) return;

    if (mounted) {
      setState(() => _isPlaylistLoading = true);
    } else {
      _isPlaylistLoading = true;
    }
    try {
      final futures = RaidConstants.playlistIds
          .map((playlistId) => _apiService.getPlaylistItems(playlistId))
          .toList();
      final results = await Future.wait(futures);

      final List<PlaylistItem> playlistItems = [];
      for (int i = 0; i < RaidConstants.playlistIds.length; i++) {
        final items = results[i];
        final playlistId = RaidConstants.playlistIds[i];
        playlistItems.addAll(items.map((item) => item.copyWith(playlistId: playlistId)));
      }

      if (!mounted) return;
      setState(() {
        _playlistItems = playlistItems;
        _playlistLoaded = true;
        _blockedContent = _playlistItems.where((item) => _blockedVideoIds.contains(item.videoId)).toList();
        final filteredPlaylistItems = _playlistItems.where((item) => !_blockedVideoIds.contains(item.videoId)).toList();
        _allContent = [..._raidVideos, ...filteredPlaylistItems];
      });
    } catch (e) {
      // Keep existing content if playlist fetch fails.
      debugPrint('Playlist lazy-load failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isPlaylistLoading = false);
      } else {
        _isPlaylistLoading = false;
      }
    }
  }

  Future<void> _refreshVideos() async {
    await _loadData();
    if (_currentIndex == 0) {
      await _loadPlaylistsIfNeeded(force: true);
    }
  }

  bool _checkKeywordMatch(dynamic item, String keyword) {
    if (keyword == '전체') return true;

    String title = (item is RaidVideo) ? item.title : (item as PlaylistItem).title;
    String raidName = (item is RaidVideo) ? item.raidName : '';
    bool isEtcPlaylist = (item is PlaylistItem && item.playlistId == 'PLSC2n1C_PEtut5Q3C0NTDBkiclH2Xqctm');

    if (keyword == '로아 유용한 팁') {
      // 1. 기존 '유용한 팁' 전용 플레이리스트 영상 매칭
      if (isEtcPlaylist) return true;
      
      // 2. 미분류(Orphan) 영상 매칭: 다른 어떤 레이드 키워드에도 해당하지 않는 경우
      // RaidConstants.guideKeywords에서 '전체'와 '로아 유용한 팁'을 제외한 나머지 레이드명들
      final otherRaidKeywords = RaidConstants.guideKeywords.where((k) => k != '전체' && k != '로아 유용한 팁').toList();
      
      bool matchesAnyOtherRaid = otherRaidKeywords.any((k) {
        final term = RaidConstants.keywordMapping[k] ?? k;
        return title.contains(term) || raidName.contains(term) || title.contains(k) || raidName.contains(k);
      });
      
      return !matchesAnyOtherRaid;
    }

    if (isEtcPlaylist) return false;

    DateTime? videoDate;
    if (item is PlaylistItem) {
      videoDate = DateTime.tryParse(item.publishedAt);
    } else if (item is RaidVideo) {
      videoDate = item.createdAt;
    }

    final actKeywords = ['서막', '1막', '2막', '3막', '4막', '종막'];
    List<String> itemActs = [];
    for (String act in actKeywords) {
      String mappedRaid = RaidConstants.keywordMapping[act] ?? act;
      if (title.contains(act) || title.contains(mappedRaid) || raidName.contains(act) || raidName.contains(mappedRaid)) {
        itemActs.add(act);
      }
    }

    if (itemActs.contains('종막') && itemActs.length > 1) {
      if (!title.contains('종막') && !raidName.contains('종막')) itemActs.remove('종막');
    }

    bool isAfter2MakDate = videoDate != null && !videoDate.isBefore(DateTime(2024, 9, 25));
    if (title.contains('아브렐슈드') || raidName.contains('아브렐슈드') || title.contains('2막') || raidName.contains('2막')) {
      if (isAfter2MakDate) { if (!itemActs.contains('2막')) itemActs.add('2막'); } 
      else { itemActs.remove('2막'); }
    }

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
      if (itemActs.contains(act)) { primaryAct = act; break; }
    }

    if (RaidConstants.keywordMapping.containsKey(keyword)) {
      return (primaryAct == keyword);
    } else {
      bool matches = title.contains(keyword) || raidName.contains(keyword);
      if (keyword == '아브렐슈드' && isAfter2MakDate) return false;
      if (matches && primaryAct != null) return false;
      return matches;
    }
  }

  void _applyFilters() {
    List<dynamic> filteredVideos = _allContent.where((item) {
      String title = (item is RaidVideo) ? item.title : (item as PlaylistItem).title;
      String uploader = (item is RaidVideo) ? item.uploaderName : (item as PlaylistItem).channelTitle;
      String raidName = (item is RaidVideo) ? item.raidName : '';

      bool matchesCategory = true;
      if (_selectedCategory != '전체 레이드') {
        List<String> subRaids = RaidConstants.dropdownCategory[_selectedCategory] ?? [];
        List<String> actualRaids = subRaids.where((r) => r != '전체').toList();
        matchesCategory = actualRaids.any((raid) {
          if (raid.contains('(')) {
            RegExp regex = RegExp(r'\((.*?)\)');
            String act = regex.firstMatch(raid)?.group(1) ?? '';
            String realRaid = raid.split(')').last;
            return _checkKeywordMatch(item, act) || title.contains(realRaid) || raidName.contains(realRaid);
          }
          return _checkKeywordMatch(item, raid);
        });
      }

      bool matchesKeyword = _checkKeywordMatch(item, _selectedGuideKeyword);
      bool matchesSearch = _searchQuery.isEmpty || 
          title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          uploader.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          raidName.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesKeyword && matchesSearch;
    }).toList();

    // 1순위: 드롭다운 카테고리 순서 기반 정렬, 2순위: 최신순 (기본값)
    filteredVideos.sort((a, b) {
        List<String> currentRaids = RaidConstants.dropdownCategory[_selectedCategory] ?? [];
        if (currentRaids.isEmpty) currentRaids = RaidConstants.dropdownCategory['군단장 레이드']!;

        int getRaidIndex(dynamic item) {
          String title = (item is RaidVideo) ? item.title : (item as PlaylistItem).title;
          String raidName = (item is RaidVideo) ? item.raidName : '';

          for (int i = 0; i < currentRaids.length; i++) {
            String raid = currentRaids[i];
            if (raid == '전체') continue;
            
            if (raid.contains('(')) {
              String act = RegExp(r'\((.*?)\)').firstMatch(raid)?.group(1) ?? '';
              String realRaid = raid.split(')').last;
              if (title.contains(act) || title.contains(realRaid) || raidName.contains(act) || raidName.contains(realRaid)) {
                return i;
              }
            } else if (title.contains(raid) || raidName.contains(raid)) {
              return i;
            }
          }
          return 999;
        }

        int indexA = getRaidIndex(a);
        int indexB = getRaidIndex(b);

        if (indexA != indexB) {
          return indexA.compareTo(indexB);
        }

        DateTime dateA = (a is RaidVideo) ? (a.createdAt ?? DateTime(2000)) : DateTime.tryParse((a as PlaylistItem).publishedAt) ?? DateTime(2000);
        DateTime dateB = (b is RaidVideo) ? (b.createdAt ?? DateTime(2000)) : DateTime.tryParse((b as PlaylistItem).publishedAt) ?? DateTime(2000);
        return dateB.compareTo(dateA);
    });
    _filteredContent = filteredVideos;

    List<CheatSheet> filteredCS = _allCheatSheets.where((cs) {
      bool matchesCategory = true;
      if (_selectedCategory != '전체 레이드') {
        List<String> subRaids = RaidConstants.dropdownCategory[_selectedCategory] ?? [];
        List<String> actualRaids = subRaids.where((r) => r != '전체').toList();
        matchesCategory = actualRaids.any((raid) {
           String term = raid.contains('(') ? RegExp(r'\((.*?)\)').firstMatch(raid)?.group(1) ?? raid : raid;
           String realRaid = raid.contains(')') ? raid.split(')').last : raid;
           return cs.raidName.contains(term) || cs.title.contains(term) || cs.raidName.contains(realRaid) || cs.title.contains(realRaid);
        });
      }

      bool matchesKeyword = false;
      if (_selectedGuideKeyword == '전체') {
        matchesKeyword = true;
      } else if (_selectedGuideKeyword == '로아 유용한 팁') {
        final keywords = RaidConstants.guideKeywords.where((k) => k != '전체' && k != '로아 유용한 팁').toList();
        matchesKeyword = !keywords.any((k) => cs.raidName.contains(k) || cs.title.contains(k));
      } else {
        final term = RaidConstants.keywordMapping[_selectedGuideKeyword] ?? _selectedGuideKeyword;
        matchesKeyword = cs.raidName.contains(term) || cs.title.contains(term);
      }

      bool matchesSearch = _searchQuery.isEmpty || 
          cs.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          cs.raidName.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesKeyword && matchesSearch;
    }).toList();

    // 컨닝페이퍼 정렬 (1순위: 드롭다운 레이드 순서, 2순위: 최신순)
    filteredCS.sort((a, b) {
        List<String> currentRaids = RaidConstants.dropdownCategory[_selectedCategory] ?? [];
        if (currentRaids.isEmpty) currentRaids = RaidConstants.dropdownCategory['군단장 레이드']!;

        int getRaidIndex(CheatSheet cs) {
          for (int i = 0; i < currentRaids.length; i++) {
            String raid = currentRaids[i];
            if (raid == '전체') continue;
            
            if (raid.contains('(')) {
              String term = RegExp(r'\((.*?)\)').firstMatch(raid)?.group(1) ?? raid;
              String realRaid = raid.split(')').last;
              if (cs.raidName.contains(term) || cs.title.contains(term) || 
                  cs.raidName.contains(realRaid) || cs.title.contains(realRaid)) {
                return i;
              }
            } else if (cs.raidName.contains(raid) || cs.title.contains(raid)) {
              return i;
            }
          }
          return 999;
        }

        int indexA = getRaidIndex(a);
        int indexB = getRaidIndex(b);

        if (indexA != indexB) {
          return indexA.compareTo(indexB);
        }

        return (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
    });
    _filteredCheatSheets = filteredCS;
  }

  Widget _buildCenteredContent(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400), // 최대 너비 제한 (너무 넓어지는 것 방지)
        child: child,
      ),
    );
  }

  // 컨닝페이퍼 탭 전용 넷플릭스 스타일 콘텐츠 빌더
  Widget _buildCheatSheetsContent() {
    bool isFiltering = _searchQuery.isNotEmpty || _selectedCategory != '전체 레이드' || _selectedRaid != '전체';
    
    if (isFiltering) {
      return _buildCheatSheetsGrid();
    }

    final validCategories = RaidConstants.dropdownCategory.keys
        .where((cat) => cat != '전체 레이드')
        .toList();

    List<Widget> sections = [];
    bool isFirstValidSection = true;

    for (var i = 0; i < validCategories.length; i++) {
      final category = validCategories[i];
      final sectionWidget = _buildCheatSheetSection(category, isFirst: isFirstValidSection);
      if (sectionWidget is! SizedBox) {
        sections.add(sectionWidget);
        isFirstValidSection = false;
      }
    }
    
    final tipsSectionWidget = _buildCheatSheetSection('로아 유용한 팁', isFirst: isFirstValidSection);
    if (tipsSectionWidget is! SizedBox) {
      sections.add(tipsSectionWidget);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 5, bottom: 10),
      children: sections,
    );
  }

  // 컨닝페이퍼 전용 가로 스크롤 섹션 빌더
  Widget _buildCheatSheetSection(String categoryName, {bool isFirst = false}) {
    final List<String> actualRaids;
    if (RaidConstants.dropdownCategory.containsKey(categoryName)) {
      final List<String> subRaids = RaidConstants.dropdownCategory[categoryName] ?? [];
      actualRaids = subRaids.where((r) => r != '전체').toList();
    } else {
      actualRaids = [categoryName];
    }
    
    final sectionItems = _allCheatSheets.where((cs) {
      return actualRaids.any((raid) {
        if (raid.contains('(')) {
          String term = RegExp(r'\((.*?)\)').firstMatch(raid)?.group(1) ?? raid;
          String realRaid = raid.split(')').last;
          return cs.raidName.contains(term) || cs.title.contains(term) || 
                 cs.raidName.contains(realRaid) || cs.title.contains(realRaid);
        }
        // 로아 유용한 팁(기타) 처리
        if (categoryName == '로아 유용한 팁') {
          final otherKeywords = RaidConstants.guideKeywords.where((k) => k != '전체' && k != '로아 유용한 팁').toList();
          return !otherKeywords.any((k) => cs.raidName.contains(k) || cs.title.contains(k));
        }
        return cs.raidName.contains(raid) || cs.title.contains(raid);
      });
    }).toList();

    if (sectionItems.isEmpty) return const SizedBox.shrink();

    // 정렬 로직: 1순위 - 드롭다운 레이드 순서, 2순위 - 최신순
    sectionItems.sort((a, b) {
      int getRaidIndex(CheatSheet cs) {
        for (int i = 0; i < actualRaids.length; i++) {
          String raid = actualRaids[i];
          if (raid == '전체') continue;
          
          if (raid.contains('(')) {
            String term = RegExp(r'\((.*?)\)').firstMatch(raid)?.group(1) ?? raid;
            String realRaid = raid.split(')').last;
            if (cs.raidName.contains(term) || cs.title.contains(term) || 
                cs.raidName.contains(realRaid) || cs.title.contains(realRaid)) {
              return i;
            }
          } else if (cs.raidName.contains(raid) || cs.title.contains(raid)) {
            return i;
          }
        }
        return 999;
      }

      int indexA = getRaidIndex(a);
      int indexB = getRaidIndex(b);

      if (indexA != indexB) {
        return indexA.compareTo(indexB);
      }

      return (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
    });

    final ScrollController scrollController = ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, isFirst ? 0 : 35, 20, 15),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: categoryName == '로아 유용한 팁' ? Colors.orangeAccent : Colors.purpleAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                categoryName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.8),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 380, // 컨닝페이퍼 카드는 세로가 더 김
          child: Stack(
            children: [
              ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                scrollDirection: Axis.horizontal,
                itemCount: sectionItems.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 320, // 가로 카드 너비
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: CheatSheetCard(
                      cheatSheet: sectionItems[index],
                      onDelete: () => _confirmDeleteCheatSheet(sectionItems[index]),
                    ),
                  );
                },
              ),
              if (kIsWeb) ...[
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Center(
                    child: _buildScrollButton(scrollController, isForward: false),
                  ),
                ),
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  child: Center(
                    child: _buildScrollButton(scrollController, isForward: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 화살표 버튼 공통 위젯
  Widget _buildScrollButton(ScrollController controller, {required bool isForward}) {
    return Padding(
      padding: EdgeInsets.only(left: isForward ? 0 : 8.0, right: isForward ? 8.0 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            controller.animateTo(
              controller.offset + (isForward ? 350 : -350),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
            ),
            child: Icon(
              isForward ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 24
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && (_allContent.isNotEmpty || _allCheatSheets.isNotEmpty)) _applyFilters();
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isVideoTabLoading = _currentIndex == 0 && (_isLoading || _isPlaylistLoading);
    final isCheatSheetTabLoading = _currentIndex == 1 && _isLoading;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeProvider.isDarkMode 
            ? Colors.black.withOpacity(0.2) 
            : const Color(0xFFF8F9FA).withOpacity(0.8), // 라이트 모드 앱바 톤 다운
        title: Text(
          _currentIndex == 0 ? 'Lost Ark Raid Hub' : 'Raid Cheat Sheets',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            letterSpacing: -0.5,
            color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF2D3436), // 진한 차콜 텍스트
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.home_rounded),
          color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF2D3436),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LandingScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF2D3436),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          if (authService.isAdmin)
            IconButton(
              icon: const Icon(Icons.visibility_off_rounded),
              color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF2D3436),
              onPressed: _showBlockedVideosDialog,
            ),
          IconButton(
            icon: Icon(authService.isAuthenticated ? Icons.logout_rounded : Icons.admin_panel_settings_rounded),
            color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF2D3436),
            onPressed: () {
                if (authService.isAuthenticated) {
                    authService.logout();
                } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeProvider.isDarkMode 
              ? [const Color(0xFF1A1C20), const Color(0xFF0F1012)] // 깊은 다크 톤
              : [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)], // 눈이 편안한 오프화이트 톤
          ),
        ),
        child: _buildCenteredContent(
          Column(
            children: [
              _buildSearchAndSortBar(),
              _buildDropdownFilters(),
              Expanded(
                child: (isVideoTabLoading || isCheatSheetTabLoading)
                  ? _buildSkeletonGrid() 
                  : ((_currentIndex == 0 ? _allContent.isEmpty : _allCheatSheets.isEmpty))
                    ? _buildErrorView()
                    : (_currentIndex == 0 ? _buildVideosContent() : _buildCheatSheetsContent()),
                    ),
                    ],
                    ),
                    ),      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            _loadPlaylistsIfNeeded();
          }
        },
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

  // 넷플릭스 스타일과 기존 그리드 스타일을 전환하는 핵심 메서드
  Widget _buildVideosContent() {
    // 검색 중이거나 특정 필터가 선택된 경우 -> 기존 그리드 뷰
    bool isFiltering = _searchQuery.isNotEmpty || _selectedCategory != '전체 레이드' || _selectedRaid != '전체';
    
    if (isFiltering) {
      return _buildVideosGrid();
    }

    // 초기 상태 -> 넷플릭스 스타일 가로 섹션 뷰
    final validCategories = RaidConstants.dropdownCategory.keys
        .where((cat) => cat != '전체 레이드')
        .toList();

    List<Widget> sections = [];
    bool isFirstValidSection = true;

    for (var i = 0; i < validCategories.length; i++) {
      final category = validCategories[i];
      final sectionWidget = _buildNetflixSection(category, isFirst: isFirstValidSection);
      if (sectionWidget is! SizedBox) {
        sections.add(sectionWidget);
        isFirstValidSection = false; // 첫 번째 유효한 섹션이 렌더링된 이후로는 false로 설정
      }
    }
    
    // '로아 유용한 팁' 섹션을 맨 아래에 명시적으로 추가
    final tipsSectionWidget = _buildNetflixSection('로아 유용한 팁', isFirst: isFirstValidSection);
    if (tipsSectionWidget is! SizedBox) {
      sections.add(tipsSectionWidget);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 5, bottom: 10),
      children: sections,
    );
  }

  // 가로 스크롤 섹션 빌더
  Widget _buildNetflixSection(String categoryName, {bool isFirst = false}) {
    // 해당 카테고리에 속하는 아이템들 필터링
    final List<String> actualRaids;
    
    // categoryName이 대분류 키(Key)인 경우와 개별 키워드인 경우를 모두 처리
    if (RaidConstants.dropdownCategory.containsKey(categoryName)) {
      final List<String> subRaids = RaidConstants.dropdownCategory[categoryName] ?? [];
      actualRaids = subRaids.where((r) => r != '전체').toList();
    } else {
      // '로아 유용한 팁'처럼 직접 전달된 키워드인 경우
      actualRaids = [categoryName];
    }
    
    final sectionItems = _allContent.where((item) {
      return actualRaids.any((raid) {
        if (raid.contains('(')) {
          String act = RegExp(r'\((.*?)\)').firstMatch(raid)?.group(1) ?? '';
          String realRaid = raid.split(')').last;
          return _checkKeywordMatch(item, act) || 
                 (item is RaidVideo && item.title.contains(realRaid)) || 
                 (item is PlaylistItem && item.title.contains(realRaid));
        }
        return _checkKeywordMatch(item, raid);
      });
    }).toList();

    if (sectionItems.isEmpty) return const SizedBox.shrink();

    // 정렬 로직: 1순위 - 드롭다운 레이드 순서, 2순위 - 최신순
    sectionItems.sort((a, b) {
      // 1순위: 레이드 순서 비교
      int getRaidIndex(dynamic item) {
        for (int i = 0; i < actualRaids.length; i++) {
          String raid = actualRaids[i];
          if (raid.contains('(')) {
            String act = RegExp(r'\((.*?)\)').firstMatch(raid)?.group(1) ?? '';
            String realRaid = raid.split(')').last;
            if (_checkKeywordMatch(item, act) || 
                (item is RaidVideo && item.title.contains(realRaid)) || 
                (item is PlaylistItem && item.title.contains(realRaid))) {
              return i;
            }
          } else if (_checkKeywordMatch(item, raid)) {
            return i;
          }
        }
        return 999; // 매칭되는 레이드가 없으면 맨 뒤로
      }

      int indexA = getRaidIndex(a);
      int indexB = getRaidIndex(b);

      if (indexA != indexB) {
        return indexA.compareTo(indexB); // 레이드 순서대로 오름차순 정렬
      }

      // 2순위: 레이드 순서가 같으면 날짜 최신순 비교
      DateTime dateA = (a is RaidVideo) ? (a.createdAt ?? DateTime(2000)) : DateTime.tryParse((a as PlaylistItem).publishedAt) ?? DateTime(2000);
      DateTime dateB = (b is RaidVideo) ? (b.createdAt ?? DateTime(2000)) : DateTime.tryParse((b as PlaylistItem).publishedAt) ?? DateTime(2000);
      return dateB.compareTo(dateA); // 날짜 내림차순 정렬
    });

    final ScrollController scrollController = ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, isFirst ? 0 : 35, 20, 15),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: categoryName == '로아 유용한 팁' ? Colors.orangeAccent : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 270,
          child: Stack(
            children: [
              ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), // 위아래 여백 추가
                scrollDirection: Axis.horizontal,
                itemCount: sectionItems.length,
                itemBuilder: (context, index) {
                  final item = sectionItems[index];
                  return Container(
                    width: 280, 
                    margin: const EdgeInsets.symmetric(horizontal: 8), // 좌우 간격 확대
                    child: item is RaidVideo
                        ? VideoCard(
                            video: item,
                            thumbnailUrl: _getYouTubeThumbnail(item.youtubeUrl),
                            onDelete: () => _showDeleteVideoConfirm(item),
                          )
                        : PlaylistCard(
                            item: item as PlaylistItem,
                            onBlock: () => _showBlockVideoConfirm(item),
                          ),
                  );
                },
              ),
              if (kIsWeb) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildScrollButton(scrollController, isForward: false),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildScrollButton(scrollController, isForward: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideosGrid() {
    return _filteredContent.isEmpty
        ? const Center(child: Text("해당 키워드의 공략 영상이 없습니다."))
        : GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350, 
              childAspectRatio: 0.85, 
              crossAxisSpacing: 20, 
              mainAxisSpacing: 20,
            ),
            itemCount: _filteredContent.length,
            itemBuilder: (context, index) {
              final item = _filteredContent[index];
              if (item is RaidVideo) {
                return VideoCard(
                  video: item, 
                  thumbnailUrl: _getYouTubeThumbnail(item.youtubeUrl),
                  onDelete: () => _showDeleteVideoConfirm(item),
                );
              } else {
                return PlaylistCard(
                  item: item as PlaylistItem,
                  onBlock: () => _showBlockVideoConfirm(item),
                );
              }
            },
          );
  }

  // (이하 나머지 위젯 및 메서드는 기존과 동일)
  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _currentIndex == 0 ? 300 : 400,
        childAspectRatio: _currentIndex == 0 ? 0.8 : 1.2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text("데이터를 불러오지 못했습니다.", style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text("다시 시도"),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, double? width, double borderRadius = 15}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -5,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                ? const Color(0xFF1E2228).withOpacity(0.7)
                : Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2),
                width: 1.0,
              ),
              gradient: isDark ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(0.05), Colors.transparent],
              ) : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndSortBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
      child: _buildGlassContainer(
        borderRadius: 12,
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '찾으시는 레이드나 공략 키워드를 입력하세요...',
            hintStyle: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded, 
              color: isDark ? Colors.blueAccent : Colors.blue,
              size: 22,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.all(15),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownBg = isDark ? const Color(0xFF16191D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildGlassContainer(
              borderRadius: 12,
              child: DropdownButtonHideUnderline(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    dropdownColor: dropdownBg,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.blueAccent : Colors.blue),
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                    borderRadius: BorderRadius.circular(15),
                    menuMaxHeight: 400,
                    items: RaidConstants.dropdownCategory.keys.map((String category) {
                      final isSelected = _selectedCategory == category;
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16, // 높이를 살짝 줄임
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: isSelected ? Colors.blueAccent : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCategory = newValue;
                          _selectedRaid = '전체';
                          _updateGuideKeywordFromDropdown();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 3,
            child: _buildGlassContainer(
              borderRadius: 12,
              child: DropdownButtonHideUnderline(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedRaid,
                    dropdownColor: dropdownBg,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.blueAccent : Colors.blue),
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                    borderRadius: BorderRadius.circular(15),
                    menuMaxHeight: 400,
                    items: RaidConstants.dropdownCategory[_selectedCategory]!.map((String raid) {
                      final isSelected = _selectedRaid == raid;
                      return DropdownMenuItem<String>(
                        value: raid,
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16, // 높이를 첫 번째 드롭다운과 동일하게 맞춤
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                raid,
                                style: TextStyle(
                                  color: isSelected ? Colors.blueAccent : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRaid = newValue;
                          _updateGuideKeywordFromDropdown();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateGuideKeywordFromDropdown() {
    if (_selectedRaid == '전체') {
       _selectedGuideKeyword = '전체'; 
    } else if (_selectedRaid.contains('(')) {
       RegExp regex = RegExp(r'\((.*?)\)');
       Match? match = regex.firstMatch(_selectedRaid);
       if (match != null) {
          _selectedGuideKeyword = match.group(1)!;
       }
    } else {
       _selectedGuideKeyword = _selectedRaid;
    }
  }

  Widget _buildCheatSheetsGrid() {
    return _filteredCheatSheets.isEmpty && !_isLoading
        ? const Center(child: Text("해당 키워드의 컨닝 페이퍼가 없습니다."))
        : GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450, 
              childAspectRatio: 1.1, 
              crossAxisSpacing: 20, 
              mainAxisSpacing: 20,
            ),
            itemCount: _filteredCheatSheets.length,
            itemBuilder: (context, index) => CheatSheetCard(
              cheatSheet: _filteredCheatSheets[index],
              onDelete: () => _confirmDeleteCheatSheet(_filteredCheatSheets[index]),
            ),
          );
  }

  void _showDeleteVideoConfirm(RaidVideo video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("영상 삭제"),
        content: const Text("정말로 이 영상을 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiService.deleteVideo(video.id!);
                _refreshVideos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("삭제 실패: $e")));
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockVideoConfirm(PlaylistItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("영상 숨기기"),
        content: const Text("이 영상을 목록에서 숨기시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          TextButton(
            onPressed: () async {
              try {
                await _apiService.blockVideo(item.videoId, "관리자 숨김 처리");
                Navigator.pop(ctx);
                _refreshVideos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("숨김 실패: $e")));
              }
            },
            child: const Text("숨기기", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showAddCheatSheetDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => CheatSheetUploadDialog(
        raidByCategory: RaidConstants.raidByCategory,
        onUpload: (title, raid, gate, uploaderName, bytes, name) async {
          try {
            await _apiService.uploadCheatSheet(
              title: title, 
              raidName: raid, 
              gate: gate, 
              uploaderName: uploaderName.isNotEmpty ? uploaderName : (authService.username ?? 'admin'),
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

  void _showAddVideoDialog() {
    showDialog(
      context: context,
      builder: (context) => VideoUploadDialog(
        raidByCategory: RaidConstants.raidByCategory,
        onUpload: (video) async {
          try {
            await _apiService.createVideo(video);
            Navigator.pop(context);
            _refreshVideos();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('영상이 성공적으로 등록되었습니다!')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
          }
        },
      ),
    );
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
                      leading: Image.network(item.thumbnailUrl, width: 100, fit: BoxFit.cover, errorBuilder: (ctx, _, __) => const Icon(Icons.broken_image)),
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.channelTitle),
                      trailing: IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green),
                        onPressed: () async {
                          try {
                            await _apiService.unblockVideo(item.videoId);
                            Navigator.pop(context);
                            _refreshVideos();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("복구 실패: $e")));
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
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

  String? _getYouTubeThumbnail(String url) {
    final videoId = _getYouTubeVideoId(url);
    return videoId != null ? "https://img.youtube.com/vi/$videoId/mqdefault.jpg" : null;
  }
}
