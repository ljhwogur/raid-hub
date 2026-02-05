import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 유튜브 링크 열기용 (추가 필요, 없으면 에러날 수 있으니 일단 로직만 구현하거나 패키지 추가)
import 'models/raid_video.dart';
import 'services/api_service.dart';

void main() {
  runApp(const RaidHubApp());
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

  // 카테고리 정의
  final List<String> _categories = [
    '전체',
    '군단장 레이드',
    '에픽 레이드',
    '카제로스 레이드',
    '그림자 레이드',
  ];

  // 레이드 이름 -> 카테고리 매핑 (단순 필터링용 데이터)
  final Map<String, List<String>> _raidByCategory = {
    '군단장 레이드': ['발탄', '비아키스', '쿠크세이튼', '아브렐슈드', '일리아칸', '카멘'],
    '에픽 레이드': ['베히모스'],
    '카제로스 레이드': ['에키드나', '카제로스 1막', '카제로스 2막'],
    '그림자 레이드': ['미정'], // 필요 시 추가
  };

  @override
  void initState() {
    super.initState();
    _refreshVideos();
  }

  void _refreshVideos() {
    setState(() {
      _videosFuture = _apiService.getVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 왼쪽 사이드바 (NavigationRail)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: _categories.map((category) {
              IconData icon;
              switch (category) {
                case '전체': icon = Icons.dashboard; break;
                case '군단장 레이드': icon = Icons.shield; break;
                case '에픽 레이드': icon = Icons.star; break;
                case '카제로스 레이드': icon = Icons.whatshot; break;
                case '그림자 레이드': icon = Icons.visibility_off; break;
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVideoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // 영상 리스트 빌드
  Widget _buildVideoContent() {
    return FutureBuilder<List<RaidVideo>>(
      future: _videosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("에러 발생: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("등록된 영상이 없습니다."));
        }

        final videos = snapshot.data!;
        final filteredVideos = _filterVideos(videos);

        if (filteredVideos.isEmpty) {
          return const Center(child: Text("이 카테고리에 해당하는 영상이 없습니다."));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.8, // 카드 비율
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: filteredVideos.length,
          itemBuilder: (context, index) {
            final video = filteredVideos[index];
            return _buildVideoCard(video);
          },
        );
      },
    );
  }

  // 카테고리에 따른 필터링 로직
  List<RaidVideo> _filterVideos(List<RaidVideo> videos) {
    if (_selectedIndex == 0) return videos; // 전체보기

    String selectedCategory = _categories[_selectedIndex];
    List<String>? targetRaids = _raidByCategory[selectedCategory];

    if (targetRaids == null) return [];

    return videos.where((video) {
      // 레이드 이름이 해당 카테고리 리스트에 포함되는지 확인
      return targetRaids.contains(video.raidName);
    }).toList();
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
  String _selectedCategory = '군단장 레이드';
  String? _selectedRaidName;
  String? _selectedDifficulty; // String? 으로 변경

  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _uploaderController = TextEditingController();
  final _gateController = TextEditingController();

  // 레이드별 난이도 정의
  final Map<String, List<String>> _raidDifficulties = {
    '쿠크세이튼': ['노말', '헬'],
    '일리아칸': ['노말', '하드'],
    '베히모스': ['노말'],
    // 그 외 레이드는 기본 난이도 (노말, 하드, 헬)
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.first; // 기본 카테고리 설정
    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first; // 기본 레이드 설정
    _updateAvailableDifficulties();
  }

  void _updateAvailableDifficulties() {
    final availableDifficulties = _raidDifficulties[_selectedRaidName] ?? ['노말', '하드', '헬'];
    if (_selectedDifficulty != null && !availableDifficulties.contains(_selectedDifficulty)) {
      _selectedDifficulty = availableDifficulties.first; // 현재 선택된 난이도가 없거나 유효하지 않으면 첫 번째 난이도로 설정
    } else if (_selectedDifficulty == null) {
      _selectedDifficulty = availableDifficulties.first; // 초기 선택
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 선택된 레이드에 맞는 난이도 목록
    final currentRaidDifficulties = _raidDifficulties[_selectedRaidName] ?? ['노말', '하드', '헬'];

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
                    _selectedRaidName = widget.raidByCategory[_selectedCategory]?.first;
                    _updateAvailableDifficulties(); // 레이드 이름 변경 시 난이도 목록 갱신
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
                    _updateAvailableDifficulties(); // 레이드 이름 변경 시 난이도 목록 갱신
                  });
                },
              ),
              // 난이도
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(labelText: '난이도'),
                items: currentRaidDifficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => _selectedDifficulty = val!),
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