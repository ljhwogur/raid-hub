import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../main.dart'; // To access HomePage

/// [LandingScreen]
/// 앱에 처음 접속했을 때 보여지는 대문(Hero) 화면입니다.
/// 고화질 배경 이미지와 함께 주요 기능으로 이동할 수 있는 퀵 메뉴 버튼을 제공합니다.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 배경 이미지 (로컬 에셋)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                // assets/images/ 폴더 안에 있는 이미지를 불러옵니다.
                // 이미지 이름이 다르다면 이 부분을 수정해 주세요!
                image: const AssetImage('assets/images/landing_bg.jpg'), 
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(isDark ? 0.6 : 0.4),
                  BlendMode.darken,
                ),
              ),
            ),
          ),

          // 2. 상단 우측 다크/라이트 모드 토글 버튼
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () => themeProvider.toggleTheme(),
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
