import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// 光끼 게이지 위젯 (불타는 애니메이션 아이콘 + 게이지)
class GwangkkiGauge extends StatefulWidget {
  final double score; // 0~100
  final bool showWarning; // 100점일 때 경고 문구 표시 여부
  final bool compact; // 컴팩트 모드 (게임 화면용)
  final bool showLabel; // "光끼 게이지" 라벨 표시 여부
  final VoidCallback? onActivatePressed; // 발동 버튼 콜백
  final bool canActivate; // 발동 가능 여부

  const GwangkkiGauge({
    super.key,
    required this.score,
    this.showWarning = true,
    this.compact = false,
    this.showLabel = false,
    this.onActivatePressed,
    this.canActivate = false,
  });

  @override
  State<GwangkkiGauge> createState() => _GwangkkiGaugeState();
}

class _GwangkkiGaugeState extends State<GwangkkiGauge>
    with TickerProviderStateMixin {
  late AnimationController _flameController;
  late AnimationController _glowController;
  late Animation<double> _flameAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // 불꽃 애니메이션
    _flameController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _flameAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOut),
    );

    // 빛나는 효과 애니메이션
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flameController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color _getGaugeColor() {
    if (widget.score >= 100) {
      return Colors.red;
    } else if (widget.score >= 70) {
      return Colors.orange;
    } else if (widget.score >= 40) {
      return Colors.amber;
    } else {
      return Colors.yellow.shade700;
    }
  }

  double _getGlowIntensity() {
    // 점수가 높을수록 빛나는 효과 강해짐
    return (widget.score / 100).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final gaugeColor = _getGaugeColor();
    final glowIntensity = _getGlowIntensity();

    if (widget.compact) {
      return _buildCompactGauge(gaugeColor, glowIntensity);
    }
    return _buildFullGauge(gaugeColor, glowIntensity);
  }

  Widget _buildCompactGauge(Color gaugeColor, double glowIntensity) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 불꽃 아이콘
        _buildFlameIcon(18),
        const SizedBox(width: 4),
        // 게이지
        SizedBox(
          width: 50,
          child: _buildGaugeBar(gaugeColor, glowIntensity, height: 8),
        ),
        // 발동 버튼
        if (widget.canActivate && widget.onActivatePressed != null) ...[
          const SizedBox(width: 6),
          _buildActivateButton(compact: true),
        ],
      ],
    );
  }

  Widget _buildFullGauge(Color gaugeColor, double glowIntensity) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨 표시
        if (widget.showLabel) ...[
          Text(
            '光끼 게이지',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 불꽃 아이콘
            _buildFlameIcon(24),
            const SizedBox(width: 6),
            // 게이지
            SizedBox(
              width: 80,
              child: _buildGaugeBar(gaugeColor, glowIntensity, height: 12),
            ),
          ],
        ),
        // 경고 문구
        if (widget.showWarning && widget.score >= 100) ...[
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2 + _glowAnimation.value * 0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: _glowAnimation.value),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.red.withValues(alpha: 0.7 + _glowAnimation.value * 0.3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '위험: 光끼 모드 발동 가능',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.7 + _glowAnimation.value * 0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFlameIcon(double size) {
    return AnimatedBuilder(
      animation: _flameAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _flameAnimation.value,
          child: Lottie.asset(
            'assets/etc/Fire.json',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.local_fire_department,
                size: size,
                color: Colors.orange,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGaugeBar(Color gaugeColor, double glowIntensity, {double height = 12}) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: gaugeColor.withValues(alpha: 0.3 + glowIntensity * _glowAnimation.value * 0.4),
              width: 1,
            ),
            boxShadow: glowIntensity > 0.5
                ? [
                    BoxShadow(
                      color: gaugeColor.withValues(alpha: glowIntensity * _glowAnimation.value * 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 게이지 바
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (widget.score / 100).clamp(0.0, 1.0),
                    heightFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            gaugeColor.withValues(alpha: 0.8),
                            gaugeColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 빛나는 오버레이
                if (glowIntensity > 0.3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (widget.score / 100).clamp(0.0, 1.0),
                      heightFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: _glowAnimation.value * glowIntensity * 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivateButton({bool compact = false}) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onActivatePressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade700,
                  Colors.orange.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(compact ? 4 : 6),
              border: Border.all(
                color: Colors.yellow.withValues(alpha: 0.5 + _glowAnimation.value * 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3 + _glowAnimation.value * 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.2 + _glowAnimation.value * 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt,
                  size: compact ? 12 : 16,
                  color: Colors.yellow,
                ),
                SizedBox(width: compact ? 2 : 4),
                Text(
                  '光끼 발동',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 光끼 모드 발동 알림 오버레이
class GwangkkiModeAlert extends StatefulWidget {
  final String activatorName;
  final bool isMyActivation;
  final VoidCallback? onDismiss;

  const GwangkkiModeAlert({
    super.key,
    required this.activatorName,
    this.isMyActivation = false,
    this.onDismiss,
  });

  @override
  State<GwangkkiModeAlert> createState() => _GwangkkiModeAlertState();
}

class _GwangkkiModeAlertState extends State<GwangkkiModeAlert>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _sirenController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _sirenAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sirenController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _sirenAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_sirenController);

    // 3초 후 자동 닫기
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sirenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _sirenAnimation]),
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.7 + _sirenAnimation.value * 0.2),
          child: Center(
            child: Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.shade900,
                      Colors.orange.shade800,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _sirenAnimation.value > 0.5
                        ? Colors.yellow
                        : Colors.red,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_sirenAnimation.value > 0.5
                              ? Colors.yellow
                              : Colors.red)
                          .withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 사이렌 아이콘
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSirenIcon(),
                        const SizedBox(width: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.yellow, Colors.orange],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.local_fire_department,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildSirenIcon(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 발동 메시지
                    Text(
                      '${widget.activatorName}님이 광끼 모드를 발동하였습니다',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.activatorName}님이 승리 시\n플레이어의 모든 코인을 독식합니다!',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildSirenIcon() {
    return AnimatedBuilder(
      animation: _sirenAnimation,
      builder: (context, child) {
        return Icon(
          Icons.warning_amber_rounded,
          size: 36,
          color: _sirenAnimation.value > 0.5 ? Colors.yellow : Colors.red,
        );
      },
    );
  }
}

/// 광끼 게이지 분노 애니메이션 (게임 중 축적 시 표시)
class GwangkkiAngerAnimation extends StatefulWidget {
  final int points; // 축적된 점수
  final VoidCallback? onComplete;

  const GwangkkiAngerAnimation({
    super.key,
    required this.points,
    this.onComplete,
  });

  @override
  State<GwangkkiAngerAnimation> createState() => _GwangkkiAngerAnimationState();
}

class _GwangkkiAngerAnimationState extends State<GwangkkiAngerAnimation>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _shakeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 슬라이드 + 페이드 애니메이션 (아래서 위로 올라갔다가 사라짐)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: const Offset(0, -1.0),
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    // 흔들림 애니메이션
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    // 애니메이션 시작
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // 흔들림 효과 (5회 반복)
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      await _shakeController.forward();
      await _shakeController.reverse();
    }

    // 슬라이드 시작
    if (mounted) {
      _slideController.forward();
    }

    // 애니메이션 완료 대기 후 콜백
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _shakeAnimation, _fadeAnimation]),
      builder: (context, child) {
        // 페이드 아웃 (마지막 20%에서 사라짐)
        double opacity = _fadeAnimation.value;
        if (_slideController.value > 0.7) {
          opacity = 1.0 - ((_slideController.value - 0.7) / 0.3);
        }

        return SlideTransition(
          position: _slideAnimation,
          child: Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade800.withValues(alpha: 0.95),
                      Colors.orange.shade700.withValues(alpha: 0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.yellow.withValues(alpha: 0.7),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '😡',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '아오! 화가난다! +${widget.points}점',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 2,
                          ),
                        ],
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

/// 光끼 모드 활성 표시 배너
class GwangkkiModeBanner extends StatefulWidget {
  final String activatorName;

  const GwangkkiModeBanner({
    super.key,
    required this.activatorName,
  });

  @override
  State<GwangkkiModeBanner> createState() => _GwangkkiModeBannerState();
}

class _GwangkkiModeBannerState extends State<GwangkkiModeBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade900.withValues(alpha: 0.8),
                Colors.orange.shade800.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _animation.value > 0.5 ? Colors.yellow : Colors.red,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (_animation.value > 0.5 ? Colors.yellow : Colors.red)
                    .withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 16,
                color: _animation.value > 0.5 ? Colors.yellow : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                '光끼 모드! (${widget.activatorName})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.local_fire_department,
                size: 16,
                color: _animation.value > 0.5 ? Colors.yellow : Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }
}
