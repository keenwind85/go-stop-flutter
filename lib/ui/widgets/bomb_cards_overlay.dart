import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../models/card_data.dart';
import '../game/widgets/game_card_widget.dart';

/// 폭탄 카드 공개 오버레이
///
/// 폭탄 선언 시 해당 월의 3장 카드를 화면 중앙에
/// 폭탄 애니메이션과 함께 표시합니다.
class BombCardsOverlay extends StatefulWidget {
  final List<CardData> cards;  // 폭탄으로 던질 3장의 카드
  final String playerName;     // 폭탄 사용 플레이어 이름
  final VoidCallback onDismiss;

  const BombCardsOverlay({
    super.key,
    required this.cards,
    required this.playerName,
    required this.onDismiss,
  });

  @override
  State<BombCardsOverlay> createState() => _BombCardsOverlayState();
}

class _BombCardsOverlayState extends State<BombCardsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 페이드 인/아웃 컨트롤러 (3초)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 3000),
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
        tween: Tween(begin: 0.5, end: 1.1).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_fadeController);

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepOrange.withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.deepOrange.shade900,
                    width: 3,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 폭탄 아이콘과 텍스트
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 폭탄 로티 애니메이션
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Lottie.asset(
                            'assets/etc/Bomb.json',
                            fit: BoxFit.contain,
                            repeat: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.whatshot,
                                color: Colors.yellow.shade300,
                                size: 32,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '폭탄!',
                          style: TextStyle(
                            color: Colors.yellow.shade300,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 폭탄 로티 애니메이션
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Lottie.asset(
                            'assets/etc/Bomb.json',
                            fit: BoxFit.contain,
                            repeat: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.whatshot,
                                color: Colors.yellow.shade300,
                                size: 32,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 플레이어 이름
                    Text(
                      '${widget.playerName}님이 폭탄을 던집니다!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
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
                          color: Colors.deepOrange.shade800,
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
                    // 설명 표시
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '3장을 바닥에 던지고 나머지 1장을 획득!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 폭탄 투척 애니메이션 위젯 (획득한 카드 위치에 표시)
class BombExplosionAnimation extends StatefulWidget {
  final Offset position;  // 폭발 위치
  final VoidCallback onComplete;

  const BombExplosionAnimation({
    super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<BombExplosionAnimation> createState() => _BombExplosionAnimationState();
}

class _BombExplosionAnimationState extends State<BombExplosionAnimation> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 50,  // 중앙 정렬 (100/2)
      top: widget.position.dy - 50,   // 중앙 정렬 (100/2)
      child: SizedBox(
        width: 100,
        height: 100,
        child: Lottie.asset(
          'assets/etc/Bomb.json',
          fit: BoxFit.contain,
          repeat: false,  // 한 번만 재생
          onLoaded: (composition) {
            // 애니메이션 완료 후 콜백 호출 (약 3초 후)
            Future.delayed(composition.duration, widget.onComplete);
          },
          errorBuilder: (context, error, stackTrace) {
            // 애니메이션 로드 실패 시 바로 완료 처리
            Future.delayed(const Duration(milliseconds: 100), widget.onComplete);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
