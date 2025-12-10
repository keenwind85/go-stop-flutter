import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../widgets/retro_background.dart';
import '../widgets/retro_button.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RetroBackground(
        baseColor: const Color(0xFF1D4E19),
        child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고/타이틀
              const Text(
                '光끼의 맞고',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'with 순시미와 고냉이',
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFFDA2F36),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              
              // 메인 이미지
              Image.asset(
                'assets/etc/login_img.png',
                height: 200,
                fit: BoxFit.contain,
              ),
              
              const SizedBox(height: 40),

              // Google 로그인 버튼
              RetroButton(
                onPressed: () => _signInWithGoogle(context, ref),
                color: Colors.white,
                width: 280,
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/google_logo.png', // 구글 로고 에셋 필요 (없으면 텍스트만)
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.login,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Google로 시작하기',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
