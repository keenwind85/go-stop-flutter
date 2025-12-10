import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/card_data.dart';
import '../../../config/constants.dart';
import '../game_screen_new.dart';
import '../effects/ripple_effect.dart';
import 'card_animator.dart';
import 'card_journey.dart';

/// 애니메이션 중인 카드를 렌더링하는 오버레이
///
/// 모든 카드 이동 애니메이션을 화면 최상단에서 렌더링합니다.
/// Z-Index 관리를 위해 Stack의 맨 위에 배치해야 합니다.
class AnimatedCardOverlay extends StatelessWidget {
  final List<CardAnimationState> animatingCards;
  final double cardWidth;
  final double cardHeight;

  const AnimatedCardOverlay({
    super.key,
    required this.animatingCards,
    this.cardWidth = GameConstants.cardWidth,
    this.cardHeight = GameConstants.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (animatingCards.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Stack(
        children: animatingCards.map((state) {
          return _AnimatedCard(
            state: state,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
          );
        }).toList(),
      ),
    );
  }
}

/// 개별 애니메이션 카드 위젯
class _AnimatedCard extends StatelessWidget {
  final CardAnimationState state;
  final double cardWidth;
  final double cardHeight;

  const _AnimatedCard({
    required this.state,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    // 3D 플립 효과 적용
    Widget cardWidget;
    if (state.flipProgress < 1.0) {
      cardWidget = _build3DFlipCard();
    } else {
      cardWidget = _buildNormalCard();
    }

    return Positioned(
      left: state.position.dx - cardWidth / 2,
      top: state.position.dy - cardHeight / 2,
      child: Opacity(
        opacity: state.opacity,
        child: Transform.scale(
          scale: state.scale,
          child: Transform.rotate(
            angle: state.rotation,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                cardWidget,
                // 착지 충격 이펙트
                if (state.showImpactEffect) _buildImpactEffect(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 일반 카드 렌더링
  Widget _buildNormalCard() {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _getBorderColor(),
          width: 2,
        ),
        boxShadow: [
          // 비행 중 강한 그림자
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(3, 6),
          ),
          // 글로우 효과 (페이즈에 따라)
          if (state.phase == CardAnimationPhase.throwing ||
              state.phase == CardAnimationPhase.sweeping)
            BoxShadow(
              color: AppColors.cardHighlight.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.asset(
          state.showFront
              ? 'assets/${state.card.imagePath}'
              : 'assets/cards/back_of_card.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.primaryDark,
              child: Center(
                child: Text(
                  '${state.card.month}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 3D 플립 카드 렌더링
  Widget _build3DFlipCard() {
    // flipProgress: 0.0 = 뒷면, 0.5 = 옆면, 1.0 = 앞면
    final rotationY = state.flipProgress * math.pi;
    final showFront = state.flipProgress > 0.5;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // 원근감
        ..rotateY(rotationY),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.woodDark.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(4, 8),
            ),
            // 플립 중 하이라이트
            BoxShadow(
              color: AppColors.cardHighlight.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Transform(
            alignment: Alignment.center,
            // 뒤집힌 후 이미지가 거꾸로 보이지 않도록
            transform: showFront ? (Matrix4.identity()..rotateY(math.pi)) : Matrix4.identity(),
            child: Image.asset(
              showFront
                  ? 'assets/${state.card.imagePath}'
                  : 'assets/cards/back_of_card.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.primaryDark,
                  child: Center(
                    child: Text(
                      showFront ? '${state.card.month}' : '?',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 착지 충격 이펙트
  Widget _buildImpactEffect() {
    return Positioned(
      left: -10,
      top: -10,
      right: -10,
      bottom: -10,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.cardHighlight.withValues(alpha: 0.8),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardHighlight.withValues(alpha: 0.6),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor() {
    switch (state.phase) {
      case CardAnimationPhase.impact:
        return AppColors.cardHighlight;
      case CardAnimationPhase.sweeping:
        return AppColors.primaryLight;
      case CardAnimationPhase.gathering:
        return AppColors.woodDarkBlue;
      default:
        return AppColors.woodDark.withValues(alpha: 0.5);
    }
  }
}

/// 착지 시 '탁!' 이펙트 위젯 + 충격파
class CardImpactEffect extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;
  final String? message; // 추가 메시지 (예: "맞는 바닥패가 없어요 ㅠ")

  const CardImpactEffect({
    super.key,
    required this.position,
    required this.onComplete,
    this.message,
  });

  @override
  State<CardImpactEffect> createState() => _CardImpactEffectState();
}

class _CardImpactEffectState extends State<CardImpactEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    // 메시지가 있으면 더 오래 표시
    final duration = widget.message != null ? 800 : 400;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _rippleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMessage = widget.message != null;
    final containerWidth = hasMessage ? 160.0 : 80.0;
    final containerHeight = hasMessage ? 100.0 : 80.0;

    return Stack(
      children: [
        // 1. 충격파 (가장 뒤)
        AnimatedBuilder(
          animation: _rippleAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: ImpactRipplePainter(
                center: widget.position,
                progress: _rippleAnimation.value,
                color: AppColors.cardHighlight,
              ),
            );
          },
        ),

        // 2. 중앙 텍스트 + 그라디언트
        Positioned(
          left: widget.position.dx - containerWidth / 2,
          top: widget.position.dy - containerHeight / 2,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: containerWidth,
                    height: containerHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(hasMessage ? 16 : 40),
                      gradient: RadialGradient(
                        colors: [
                          AppColors.cardHighlight.withValues(alpha: 0.7),
                          AppColors.cardHighlight.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '탁!',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 6,
                                ),
                                Shadow(
                                  color: AppColors.cardHighlight,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          if (hasMessage) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.message!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 쓸어담기 '촤르륵' 이펙트 위젯
class CardSweepEffect extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final VoidCallback onComplete;

  const CardSweepEffect({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.onComplete,
  });

  @override
  State<CardSweepEffect> createState() => _CardSweepEffectState();
}

class _CardSweepEffectState extends State<CardSweepEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // 잔상 파티클들
        return Stack(
          children: List.generate(8, (i) {
            final particleT = (t - i * 0.08).clamp(0.0, 1.0);
            if (particleT <= 0) return const SizedBox.shrink();

            final position = Offset.lerp(
              widget.startPosition,
              widget.endPosition,
              Curves.easeInQuart.transform(particleT),
            )!;

            final opacity = (1.0 - particleT) * 0.6;
            final size = 20.0 * (1.0 - particleT * 0.5);

            return Positioned(
              left: position.dx - size / 2 + (i - 4) * 5,
              top: position.dy - size / 2,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryLight.withValues(alpha: 0.8),
                        AppColors.primaryLight.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 카드 카운트 팝업 이펙트 (획득 시 +2 등 표시)
class CardCountPopup extends StatefulWidget {
  final Offset position;
  final int count;
  final VoidCallback onComplete;

  const CardCountPopup({
    super.key,
    required this.position,
    required this.count,
    required this.onComplete,
  });

  @override
  State<CardCountPopup> createState() => _CardCountPopupState();
}

class _CardCountPopupState extends State<CardCountPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -50),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 30,
      ),
    ]).animate(_controller);

    // elasticOut은 1.0 초과 값을 생성할 수 있어 TweenSequence와 호환 안됨
    // 단순 Tween 사용으로 변경
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx - 25 + _slideAnimation.value.dx,
          top: widget.position.dy - 20 + _slideAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  '+${widget.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

/// 보너스 카드 사용 이펙트 (화면 중앙에 카드 + "보너스패 사용" 텍스트)
class BonusCardUseEffect extends StatefulWidget {
  final CardData card;
  final Size screenSize;
  final Offset startPosition;  // 손패에서 시작 위치
  final Offset endPosition;    // 점수패 영역 위치
  final VoidCallback onComplete;

  const BonusCardUseEffect({
    super.key,
    required this.card,
    required this.screenSize,
    required this.startPosition,
    required this.endPosition,
    required this.onComplete,
  });

  @override
  State<BonusCardUseEffect> createState() => _BonusCardUseEffectState();
}

class _BonusCardUseEffectState extends State<BonusCardUseEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Phase 1: 손패 → 화면 중앙으로 이동
  late Animation<Offset> _moveToCenter;
  late Animation<double> _scaleUp;

  // Phase 2: 중앙에서 잠시 정지 + 텍스트 표시
  late Animation<double> _textOpacity;
  late Animation<double> _textScale;

  // Phase 3: 중앙 → 점수패 영역으로 이동
  late Animation<Offset> _moveToCapture;
  late Animation<double> _scaleDown;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),  // 총 2초
    );

    final center = Offset(
      widget.screenSize.width / 2,
      widget.screenSize.height / 2,
    );

    // Phase 1 (0% ~ 30%): 손패 → 중앙
    _moveToCenter = Tween<Offset>(
      begin: widget.startPosition,
      end: center,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
    ));

    _scaleUp = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
      ),
    );

    // Phase 2 (30% ~ 70%): 중앙 정지 + 텍스트 표시
    _textOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.75),
    ));

    _textScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.45, curve: Curves.elasticOut),
      ),
    );

    // Phase 3 (70% ~ 100%): 중앙 → 점수패 영역
    _moveToCapture = Tween<Offset>(
      begin: center,
      end: widget.endPosition,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeInCubic),
    ));

    _scaleDown = Tween<double>(begin: 1.8, end: 0.6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInCubic),
      ),
    );

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = Offset(
      widget.screenSize.width / 2,
      widget.screenSize.height / 2,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 현재 위치 계산
        Offset currentPosition;
        double currentScale;

        if (_controller.value < 0.3) {
          // Phase 1: 손패 → 중앙
          currentPosition = _moveToCenter.value;
          currentScale = _scaleUp.value;
        } else if (_controller.value < 0.7) {
          // Phase 2: 중앙에서 정지
          currentPosition = center;
          currentScale = 1.8;
        } else {
          // Phase 3: 중앙 → 점수패
          currentPosition = _moveToCapture.value;
          currentScale = _scaleDown.value;
        }

        return Stack(
          children: [
            // 배경 어둡게 (중앙 표시 중에만)
            if (_controller.value >= 0.25 && _controller.value <= 0.75)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.5 * (1 - ((_controller.value - 0.5).abs() * 4).clamp(0.0, 1.0)),
                  child: Container(color: Colors.black),
                ),
              ),

            // 보너스 카드
            Positioned(
              left: currentPosition.dx - 40,
              top: currentPosition.dy - 60,
              child: Opacity(
                opacity: _fadeOut.value,
                child: Transform.scale(
                  scale: currentScale,
                  child: Container(
                    width: 80,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.cardHighlight,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cardHighlight.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/${widget.card.imagePath}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.primaryDark,
                            child: const Center(
                              child: Text(
                                '보너스',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // "보너스패 사용" 텍스트
            Positioned(
              left: center.dx - 100,
              top: center.dy + 80,
              child: Opacity(
                opacity: _textOpacity.value,
                child: Transform.scale(
                  scale: _textScale.value,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.cardHighlight.withValues(alpha: 0.9),
                          AppColors.primaryLight.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cardHighlight.withValues(alpha: 0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Text(
                      '보너스패 사용!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
