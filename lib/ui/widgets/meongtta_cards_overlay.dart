import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/card_data.dart';
import '../game/widgets/game_card_widget.dart';

/// 멍따 카드 공개 오버레이
///
/// 멍따 달성(열끗 7장 이상) 시 열끗 카드들을 화면 중앙에
/// 경고 애니메이션과 함께 표시합니다.
class MeongTtaCardsOverlay extends StatefulWidget {
  final List<CardData> cards; // 열끗 카드들 (7장 이상)
  final String? playerName; // 멍따 달성 플레이어 이름
  final VoidCallback onDismiss;

  const MeongTtaCardsOverlay({
    super.key,
    required this.cards,
    this.playerName,
    required this.onDismiss,
  });

  @override
  State<MeongTtaCardsOverlay> createState() => _MeongTtaCardsOverlayState();
}

class _MeongTtaCardsOverlayState extends State<MeongTtaCardsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 페이드 인/아웃 컨트롤러 (3초 동안 표시)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween:
            Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 75,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_fadeController);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_fadeController);

    // 경고 펄스 애니메이션
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });

    _fadeController.forward();
    _startPulseAnimation();
  }

  void _startPulseAnimation() async {
    // 2.5초 동안 반복 펄스
    for (int i = 0; i < 6; i++) {
      if (!mounted) return;
      await _pulseController.forward();
      if (!mounted) return;
      await _pulseController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeController, _pulseController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade800.withValues(alpha: 0.95),
                        Colors.orange.shade700.withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.6),
                        blurRadius: 40,
                        spreadRadius: 15,
                      ),
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.yellow.shade600,
                      width: 4,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 멍따 아이콘과 텍스트
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.yellow.shade300,
                            size: 36,
                          ),
                          const SizedBox(width: 8),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.yellow.shade200,
                                Colors.orange.shade100,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              '멍따!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.yellow.shade300,
                            size: 36,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 플레이어 이름
                      if (widget.playerName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.playerName!,
                            style: TextStyle(
                              color: Colors.yellow.shade100,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 열끗 개수 표시
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '열끗 ${widget.cards.length}장',
                          style: TextStyle(
                            color: Colors.yellow.shade100,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 카드 표시 (최대 7장, 그 이상은 스크롤)
                      SizedBox(
                        width: math.min(widget.cards.length * 54.0, 380),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children:
                                widget.cards.asMap().entries.map((entry) {
                              final index = entry.key;
                              final card = entry.value;
                              // 각 카드에 약간의 회전 추가
                              final rotation =
                                  (index - widget.cards.length / 2) * 0.05;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Transform.rotate(
                                  angle: rotation,
                                  child: GameCardWidget(
                                    cardData: card,
                                    width: 50,
                                    height: 75,
                                    isHighlighted: true,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 배수 표시
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade700,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          '점수 x2 적용!',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
