import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/card_data.dart';
import '../game/widgets/game_card_widget.dart';

/// 흔들기 카드 공개 오버레이
///
/// 흔들기 선언 시 해당 월의 3장 카드를 화면 중앙에
/// 흔들리는 애니메이션과 함께 표시합니다.
class ShakeCardsOverlay extends StatefulWidget {
  final List<CardData> cards;  // 흔든 3장의 카드
  final VoidCallback onDismiss;

  const ShakeCardsOverlay({
    super.key,
    required this.cards,
    required this.onDismiss,
  });

  @override
  State<ShakeCardsOverlay> createState() => _ShakeCardsOverlayState();
}

class _ShakeCardsOverlayState extends State<ShakeCardsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 페이드 인/아웃 컨트롤러
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_fadeController);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.1).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_fadeController);

    // 흔들기 애니메이션 컨트롤러
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });

    _fadeController.forward();
    _startShakeAnimation();
  }

  void _startShakeAnimation() async {
    // 1.5초 동안 반복 흔들기
    for (int i = 0; i < 15; i++) {
      if (!mounted) return;
      await _shakeController.forward();
      if (!mounted) return;
      await _shakeController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeController, _shakeController]),
      builder: (context, child) {
        // 흔들기 오프셋 계산
        final shakeOffset = math.sin(_shakeController.value * math.pi) * 8;

        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.amber.shade700,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 흔들기 아이콘과 텍스트
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.vibration,
                            color: Colors.amber.shade900,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '흔들기!',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.vibration,
                            color: Colors.amber.shade900,
                            size: 32,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 월 표시
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.cards.first.month}월',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 3장의 카드 표시
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.cards.asMap().entries.map((entry) {
                          final index = entry.key;
                          final card = entry.value;
                          // 각 카드에 약간의 회전 추가
                          final rotation = (index - 1) * 0.08;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Transform.rotate(
                              angle: rotation,
                              child: GameCardWidget(
                                cardData: card,
                                width: 70,
                                height: 105,
                                isHighlighted: true,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // 배수 표시
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '배수 ×2 적용!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
