import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'package:shared_preferences/shared_preferences.dart'; // Add SharedPreferences
import 'package:flutter_markdown/flutter_markdown.dart'; // Add flutter_markdown
import 'package:url_launcher/url_launcher.dart'; // Add url_launcher
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart'; // Add ApiService import
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin_post_screen.dart'; // Add AdminPostScreen import
import 'admin_dashboard_screen.dart'; // Add AdminDashboardScreen import

/// [LandingScreen]
/// 앱의 첫인상을 결정하는 세련된 랜딩 페이지입니다.
/// 게이밍 감성의 글래스모피즘(Glassmorphism) UI와 부드러운 배경 전환 효과가 적용되어 있습니다.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _currentImageIndex = 0;
  late AnimationController _fadeController;

  final List<String> _backgroundImages = [
    'assets/images/landing_bg.jpg',
    'assets/images/landing_bg2.jpg',
    'assets/images/landing_bg3.jpg',
    'assets/images/landing_bg4.jpg',
  ];

  final ApiService _apiService = ApiService();
  String _noticeContent = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 6), (Timer t) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % _backgroundImages.length;
        });
      }
    });

    // 앱 진입 시 공지사항 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowNotice();
    });
  }

  Future<void> _checkAndShowNotice() async {
    // DB에서 최신 공지사항 가져오기
    _noticeContent = await _apiService.getNotice();
    if (_noticeContent.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastDismissed = prefs.getInt('notice_last_dismissed') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 24시간(86400000ms)이 지났는지 확인
    if (now - lastDismissed > 86400000) {
      if (mounted) _showNoticeDialog();
    }
  }

  void _showNoticeDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final authService = Provider.of<AuthService>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false, // 배경 클릭으로 닫기 방지
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.85),
            insetPadding: EdgeInsets.symmetric(
              horizontal: screenWidth > 800 ? screenWidth * 0.2 : 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.5), width: 1),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('공지사항', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (authService.isAdmin)
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
                    tooltip: '공지 수정',
                    onPressed: () {
                      Navigator.pop(context);
                      _editNoticeDialog();
                    },
                  ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectionArea(
                      child: MarkdownBody(
                        data: _noticeContent,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
                          h1: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          strong: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                          listBullet: const TextStyle(color: Colors.blueAccent),
                          horizontalRuleDecoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                          ),
                        ),
                        onTapLink: (text, href, title) async {
                          if (href != null && (href.startsWith('http://') || href.startsWith('https://'))) {
                            final url = Uri.parse(href);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('notice_last_dismissed', DateTime.now().millisecondsSinceEpoch);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('24시간 동안 보지 않기', style: TextStyle(color: Colors.white38, fontSize: 14)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _editNoticeDialog() {
    final controller = TextEditingController(text: _noticeContent);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C20),
        title: const Text('공지사항 수정', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 10,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '공지사항 내용을 입력하세요...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.updateNotice(controller.text);
                if (mounted) {
                  setState(() => _noticeContent = controller.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공지사항이 수정되었습니다.')));
                  _showNoticeDialog(); // 수정 후 다시 띄움
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final isDark = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800; // 넓은 화면 기준

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 다이나믹 배경 이미지 (크로스 페이드)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 2000),
              child: Container(
                key: ValueKey<int>(_currentImageIndex),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_backgroundImages[_currentImageIndex]),
                    fit: BoxFit.cover,
                  ),
                ),
                // 어두운 오버레이 레이어
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. 상단 액션 바 (다크모드 & 관리자)
          Positioned(
            top: 50,
            right: 20,
            child: FadeTransition(
              opacity: _fadeController,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.white.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        _buildHeaderIcon(
                          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          onPressed: () => themeProvider.toggleTheme(),
                        ),
                        if (authService.isAdmin) ...[
                          Container(width: 1, height: 20, color: Colors.white24),
                          _buildHeaderIcon(
                            icon: Icons.bar_chart_rounded,
                            tooltip: '통계 대시보드',
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                          ),
                        ],
                        Container(width: 1, height: 20, color: Colors.white24),
                        _buildHeaderIcon(
                          icon: authService.isAuthenticated ? Icons.logout_rounded : Icons.admin_panel_settings_rounded,
                          tooltip: authService.isAuthenticated ? '로그아웃' : '관리자',
                          onPressed: () {
                            if (authService.isAuthenticated) {
                              authService.logout();
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. 중앙 메인 콘텐츠
          Center(
            child: FadeTransition(
              opacity: _fadeController,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고 및 타이틀 섹션
                    Column(
                      children: [
                        Icon(Icons.hub_outlined, color: Colors.blueAccent, size: isWide ? 80 : 60),
                        const SizedBox(height: 10),
                        Text(
                          'LOST ARK',
                          style: TextStyle(
                            fontSize: isWide ? 20 : 16,
                            color: Colors.blueAccent.withValues(alpha: 0.8),
                            letterSpacing: isWide ? 12 : 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'RAID HUB',
                          style: TextStyle(
                            fontSize: isWide ? 80 : 56,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 15),
                          width: isWide ? 60 : 40,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isWide ? 40 : 24),
                    Text(
                      '당신의 완벽한 레이드를 위한\n올인원 공략 저장소',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isWide ? 24 : 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.w300,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: isWide ? 80 : 60),

                    // 메뉴 버튼들 (글래스모피즘 스타일)
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildGlassButton(
                          context,
                          title: '공략 영상 탐색',
                          subtitle: '가장 빠르고 정확한 가이드',
                          icon: Icons.play_arrow_rounded,
                          primaryColor: Colors.blueAccent,
                          width: isWide ? 380 : 320,
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomePage(initialIndex: 0)),
                          ),
                        ),
                        _buildGlassButton(
                          context,
                          title: '컨닝 페이퍼',
                          subtitle: '핵심 기믹 한눈에 보기',
                          icon: Icons.auto_awesome_motion_rounded,
                          primaryColor: Colors.purpleAccent,
                          width: isWide ? 380 : 320,
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomePage(initialIndex: 1)),
                          ),
                        ),
                        _buildGlassButton(
                          context,
                          title: '관리자 소식',
                          subtitle: '패치노트 및 공지사항',
                          icon: Icons.notifications_active_rounded,
                          primaryColor: Colors.orangeAccent,
                          width: isWide ? 380 : 320,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminPostScreen()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. 하단 푸터
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeController,
              child: Column(
                children: [
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    '문의: vmfhdirn2@kakao.com',
                    style: TextStyle(
                      fontSize: isWide ? 13 : 11,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© 2026 RAID HUB TEAM. ALL RIGHTS RESERVED.',
                    style: TextStyle(
                      fontSize: isWide ? 12 : 10,
                      color: Colors.white.withValues(alpha: 0.3),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({required IconData icon, String? tooltip, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 24),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 20,
    );
  }

  Widget _buildGlassButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required double width,
    required VoidCallback onTap,
  }) {
    return Container(
      width: width,
      height: width * 0.25, // 가로 너비에 비례한 높이
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 100),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withValues(alpha: 0.05),
            child: InkWell(
              onTap: onTap,
              hoverColor: Colors.white.withValues(alpha: 0.05),
              splashColor: primaryColor.withValues(alpha: 0.2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: primaryColor, size: width * 0.08 > 32 ? 32 : width * 0.08),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: width * 0.06 > 20 ? 20 : width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: width * 0.04 > 14 ? 14 : width * 0.04,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
