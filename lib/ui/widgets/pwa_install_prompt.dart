import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../../config/constants.dart';

/// PWA 설치 안내 팝업 위젯
///
/// 모바일 웹 브라우저에서 실행 시 홈화면 바로가기 추가를 안내합니다.
/// - standalone 모드(PWA)로 실행 중이면 표시하지 않음
/// - 이전에 안내를 받았으면 표시하지 않음
/// - 브라우저별로 다른 안내 메시지 표시
class PwaInstallPrompt extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismiss;

  const PwaInstallPrompt({
    super.key,
    required this.child,
    this.onDismiss,
  });

  @override
  State<PwaInstallPrompt> createState() => _PwaInstallPromptState();
}

class _PwaInstallPromptState extends State<PwaInstallPrompt> {
  bool _showPrompt = false;
  _BrowserType _browserType = _BrowserType.other;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkShouldShowPrompt();
    }
  }

  void _checkShouldShowPrompt() {
    // 1. 이미 PWA로 실행 중인지 확인 (standalone 모드)
    if (_isRunningAsPwa()) {
      return;
    }

    // 2. 이전에 안내를 받았는지 확인 (localStorage)
    final wasPrompted = html.window.localStorage['pwa_install_prompted'];
    if (wasPrompted == 'true') {
      return;
    }

    // 3. 모바일 브라우저인지 확인
    if (!_isMobileBrowser()) {
      return;
    }

    // 4. 브라우저 종류 감지
    _browserType = _detectBrowser();

    // 약간의 딜레이 후 표시 (로그인 화면이 완전히 로드된 후)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showPrompt = true);
      }
    });
  }

  bool _isRunningAsPwa() {
    // display-mode: standalone 또는 fullscreen 체크
    final standaloneMatch = html.window.matchMedia('(display-mode: standalone)');
    final fullscreenMatch = html.window.matchMedia('(display-mode: fullscreen)');

    // iOS Safari의 navigator.standalone 체크
    final isIosStandalone = _getNavigatorStandalone();

    return standaloneMatch.matches || fullscreenMatch.matches || isIosStandalone;
  }

  bool _getNavigatorStandalone() {
    // iOS Safari에서 홈화면에서 실행 시 true
    try {
      final navigator = html.window.navigator;
      // JavaScript의 navigator.standalone 속성 확인
      final standalone = (navigator as dynamic).standalone;
      return standalone == true;
    } catch (e) {
      return false;
    }
  }

  bool _isMobileBrowser() {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobile') ||
        userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad');
  }

  _BrowserType _detectBrowser() {
    final userAgent = html.window.navigator.userAgent.toLowerCase();

    if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
      // iOS는 Safari만 PWA 설치 지원
      return _BrowserType.iosSafari;
    } else if (userAgent.contains('android')) {
      if (userAgent.contains('samsung')) {
        return _BrowserType.samsungBrowser;
      } else if (userAgent.contains('chrome')) {
        return _BrowserType.androidChrome;
      }
    }
    return _BrowserType.other;
  }

  void _dismissPrompt({bool remember = false}) {
    if (remember) {
      html.window.localStorage['pwa_install_prompted'] = 'true';
    }
    setState(() => _showPrompt = false);
    widget.onDismiss?.call();
  }

  String _getTitle() {
    return '전체화면으로 즐기기';
  }

  String _getInstructionText() {
    switch (_browserType) {
      case _BrowserType.iosSafari:
        return '하단의 공유 버튼(□↑)을 탭한 후\n\'홈 화면에 추가\'를 선택하세요';
      case _BrowserType.androidChrome:
        return '우측 상단 메뉴(⋮)를 탭한 후\n\'홈 화면에 추가\'를 선택하세요';
      case _BrowserType.samsungBrowser:
        return '하단 메뉴(≡)를 탭한 후\n\'홈 화면에 추가\'를 선택하세요';
      case _BrowserType.other:
        return '브라우저 메뉴에서\n\'홈 화면에 추가\'를 선택하세요';
    }
  }

  IconData _getBrowserIcon() {
    switch (_browserType) {
      case _BrowserType.iosSafari:
        return Icons.ios_share;
      case _BrowserType.androidChrome:
        return Icons.more_vert;
      case _BrowserType.samsungBrowser:
        return Icons.menu;
      case _BrowserType.other:
        return Icons.add_to_home_screen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showPrompt) _buildPromptOverlay(),
      ],
    );
  }

  Widget _buildPromptOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _dismissPrompt(remember: false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // 팝업 내부 탭은 무시
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1810),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 아이콘
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_to_home_screen,
                        color: AppColors.accent,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 제목
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 부제목
                    Text(
                      '앱처럼 빠르고 쾌적하게!',
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 브라우저별 안내
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getBrowserIcon(),
                              color: AppColors.text,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _getInstructionText(),
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _dismissPrompt(remember: false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              '다음에',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _dismissPrompt(remember: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '알겠어요!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

enum _BrowserType {
  iosSafari,
  androidChrome,
  samsungBrowser,
  other,
}
