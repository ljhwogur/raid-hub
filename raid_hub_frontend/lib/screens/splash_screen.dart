import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import 'landing_screen.dart' deferred as landing_screen;

/// [SplashScreen]
/// 최초 진입 시 표시되는 로딩 화면입니다.
/// 모든 초기화가 완료될 때까지 표시되고, 완료 후 자동으로 LandingScreen으로 이동합니다.
class SplashScreen extends StatefulWidget {
  final AuthService authService;
  final ThemeProvider themeProvider;

  const SplashScreen({
    super.key,
    required this.authService,
    required this.themeProvider,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _loadingComplete = false;

  @override
  void initState() {
    super.initState();
    _performInitialization();
  }

  Future<void> _performInitialization() async {
    try {
      // LandingScreen 번들 로드
      await landing_screen.loadLibrary();
      
      // 최소 1초는 Splash 화면 표시 (UX)
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      setState(() => _loadingComplete = true);
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() => _loadingComplete = true); // 에러 발생해도 진행
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingComplete) {
      return landing_screen.LandingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined, color: Colors.blueAccent, size: 60),
            const SizedBox(height: 20),
            const Text(
              'LOST ARK',
              style: TextStyle(
                fontSize: 18,
                color: Colors.blueAccent,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'RAID HUB',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(Colors.blueAccent.withValues(alpha: 0.8)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '초기화 중...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

