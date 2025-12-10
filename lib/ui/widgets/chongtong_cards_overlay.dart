import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/card_data.dart';
import '../game/widgets/game_card_widget.dart';

/// 총통 카드 공개 오버레이
///
/// 총통 선언 시 해당 월의 4장 카드를 화면 중앙에
/// 애니메이션과 함께 표시합니다.
class ChongtongCardsOverlay extends StatefulWidget {
  final List<CardData> cards;  // 총통 4장의 카드
  final String? winnerName;    // 승리자 이름 (null이면 나가리)
  final VoidCallback onDismiss;

  const ChongtongCardsOverlay({
    super.key,
    required this.cards,
    this.winnerName,
    required this.onDismiss,
  });

  @override
  State<ChongtongCardsOverlay> createState() => _ChongtongCardsOverlayState();
}

class _ChongtongCardsOverlayState extends State<ChongtongCardsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 페이드 인/아웃 컨트롤러 (3초 표시)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_fadeController);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_fadeController);

    // 회전 애니메이션 컨트롤러
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });

    _fadeController.forward();
    _startRotateAnimation();
  }

  void _startRotateAnimation() async {
    // 1초 동안 좌우 흔들기
    for (int i = 0; i < 8; i++) {
      if (!mounted) return;
      await _rotateController.forward();
      if (!mounted) return;
      await _rotateController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    final bool isNagari = widget.winnerName == null;

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeController, _rotateController]),
      builder: (context, child) {
        // 좌우 흔들기 오프셋 계산
        final rotateAngle = math.sin(_rotateController.value * math.pi) * 0.05;

        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Transform.rotate(
                angle: rotateAngle,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isNagari
                          ? [Colors.grey.shade700, Colors.grey.shade900]
                          : [Colors.red.shade700, Colors.red.shade900],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isNagari
                            ? Colors.grey.withValues(alpha: 0.6)
                            : Colors.red.withValues(alpha: 0.6),
                        blurRadius: 40,
                        spreadRadius: 15,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.amber.shade400,
                      width: 4,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 총통 아이콘과 텍스트
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stars,
                            color: Colors.amber.shade300,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '총통!',
                            style: TextStyle(
                              color: Colors.amber.shade300,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.stars,
                            color: Colors.amber.shade300,
                            size: 36,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 월 표시
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.cards.first.month}월 4장',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 4장의 카드 표시
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.cards.asMap().entries.map((entry) {
                          final index = entry.key;
                          final card = entry.value;
                          // 각 카드에 약간의 회전 추가 (4장이라 범위 조정)
                          final rotation = (index - 1.5) * 0.06;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Transform.rotate(
                              angle: rotation,
                              child: GameCardWidget(
                                cardData: card,
                                width: 60,
                                height: 90,
                                isHighlighted: true,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // 결과 표시
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isNagari
                              ? Colors.grey.shade600
                              : Colors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          isNagari
                              ? '쌍총통! 나가리!'
                              : '${widget.winnerName} 승리!',
                          style: TextStyle(
                            color: isNagari ? Colors.white : Colors.red.shade900,
                            fontSize: 20,
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
