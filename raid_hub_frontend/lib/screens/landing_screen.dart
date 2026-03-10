import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Add Timer
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../main.dart';

/// [LandingScreen]
/// 앱에 처음 접속했을 때 보여지는 대문(Hero) 화면입니다.
/// 시간에 따라 부드럽게 배경 이미지가 교체(CrossFade)되는 애니메이션 효과가 있습니다.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late Timer _timer;
  int _currentImageIndex = 0;

  // 사용할 배경 이미지 목록
  final List<String> _backgroundImages = [
    'assets/images/landing_bg.jpg',
    'assets/images/landing_bg2.jpg',
    'assets/images/landing_bg3.jpg',
    'assets/images/landing_bg4.jpg',
  ];

  @override
  void initState() {
    super.initState();
    // 5초마다 배경 이미지를 다음 인덱스로 변경
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer t) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _backgroundImages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // 화면을 벗어날 때 타이머 종료
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 크로스 페이드(CrossFade) 배경 이미지 애니메이션
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(seconds: 2), // 2초 동안 부드럽게 전환
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<int>(_currentImageIndex), // key가 바뀌면 애니메이션이 발동됨
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_backgroundImages[_currentImageIndex]),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(isDark ? 0.6 : 0.4),
                      BlendMode.darken,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. 상단 우측 버튼들 (다크모드 & 로그인)
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    authService.isAuthenticated ? Icons.logout : Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 30,
                  ),
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
          ),

          // 3. 중앙 콘텐츠 (타이틀 & 버튼)
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 타이틀
                  const Text(
                    'Lost Ark\nRaid Hub',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 서브 타이틀
                  const Text(
                    '모든 레이드 공략과 컨닝페이퍼를 한곳에서',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // 퀵 메뉴 버튼 1: 영상 보러가기
                  _buildMenuButton(
                    context, 
                    title: '공략 영상 찾기', 
                    icon: Icons.play_circle_fill,
                    color: const Color(0xFF4A90E2),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 0)),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 퀵 메뉴 버튼 2: 컨닝페이퍼 보러가기
                  _buildMenuButton(
                    context, 
                    title: '컨닝페이퍼 보기', 
                    icon: Icons.image_search,
                    color: const Color(0xFF5032B6),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 1)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 예쁜 그라데이션 퀵 메뉴 버튼 빌더
  Widget _buildMenuButton(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      width: 280,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0, // Container의 BoxShadow를 사용하기 위해 기본 elevation 제거
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}
