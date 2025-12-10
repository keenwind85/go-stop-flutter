import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 착지 충격파 이펙트 위젯
///
/// 카드가 바닥에 착지할 때 원형 파동이 퍼져나가는 효과
class RippleEffect extends StatefulWidget {
  /// 충격파 중심 위치
  final Offset position;

  /// 충격파 색상 (기본: 흰색)
  final Color color;

  /// 최대 반지름
  final double maxRadius;

  /// 애니메이션 지속 시간
  final Duration duration;

  /// 파동 개수 (동심원)
  final int rippleCount;

  /// 완료 콜백
  final VoidCallback? onComplete;

  const RippleEffect({
    super.key,
    required this.position,
    this.color = Colors.white,
    this.maxRadius = 80.0,
    this.duration = const Duration(milliseconds: 400),
    this.rippleCount = 2,
    this.onComplete,
  });

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
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
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: RipplePainter(
            center: widget.position,
            progress: _animation.value,
            color: widget.color,
            maxRadius: widget.maxRadius,
            rippleCount: widget.rippleCount,
          ),
        );
      },
    );
  }
}

/// 충격파 CustomPainter
class RipplePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final Color color;
  final double maxRadius;
  final int rippleCount;

  RipplePainter({
    required this.center,
    required this.progress,
    required this.color,
    required this.maxRadius,
    required this.rippleCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < rippleCount; i++) {
      // 각 파동의 시작 지연 (0.0, 0.15, 0.3, ...)
      final delay = i * 0.15;
      final adjustedProgress = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);

      if (adjustedProgress <= 0) continue;

      // 반지름 계산 (점점 커짐)
      final radius = maxRadius * adjustedProgress;

      // 투명도 계산 (점점 흐려짐)
      final opacity = (1.0 - adjustedProgress) * 0.6;

      // 선 두께 (시작은 두껍고 끝은 얇게)
      final strokeWidth = 3.0 * (1.0 - adjustedProgress * 0.7);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.center != center;
  }
}

/// 다중 충격파 관리자
///
/// 여러 개의 충격파를 동시에 관리
class RippleEffectManager extends StatefulWidget {
  final Widget child;

  const RippleEffectManager({
    super.key,
    required this.child,
  });

  static RippleEffectManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<RippleEffectManagerState>();
  }

  @override
  State<RippleEffectManager> createState() => RippleEffectManagerState();
}

class RippleEffectManagerState extends State<RippleEffectManager> {
  final List<_RippleData> _activeRipples = [];
  int _rippleIdCounter = 0;

  /// 충격파 추가
  void addRipple({
    required Offset position,
    Color color = Colors.white,
    double maxRadius = 80.0,
    Duration duration = const Duration(milliseconds: 400),
    int rippleCount = 2,
  }) {
    final id = _rippleIdCounter++;
    setState(() {
      _activeRipples.add(_RippleData(
        id: id,
        position: position,
        color: color,
        maxRadius: maxRadius,
        duration: duration,
        rippleCount: rippleCount,
      ));
    });
  }

  void _removeRipple(int id) {
    setState(() {
      _activeRipples.removeWhere((r) => r.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeRipples.map((ripple) => RippleEffect(
          key: ValueKey(ripple.id),
          position: ripple.position,
          color: ripple.color,
          maxRadius: ripple.maxRadius,
          duration: ripple.duration,
          rippleCount: ripple.rippleCount,
          onComplete: () => _removeRipple(ripple.id),
        )),
      ],
    );
  }
}

class _RippleData {
  final int id;
  final Offset position;
  final Color color;
  final double maxRadius;
  final Duration duration;
  final int rippleCount;

  _RippleData({
    required this.id,
    required this.position,
    required this.color,
    required this.maxRadius,
    required this.duration,
    required this.rippleCount,
  });
}

/// 강화된 충격파 (착지 임팩트용)
///
/// 일반 충격파 + 중앙 플래시 효과
class ImpactRippleEffect extends StatefulWidget {
  final Offset position;
  final Color color;
  final VoidCallback? onComplete;

  const ImpactRippleEffect({
    super.key,
    required this.position,
    this.color = Colors.white,
    this.onComplete,
  });

  @override
  State<ImpactRippleEffect> createState() => _ImpactRippleEffectState();
}

class _ImpactRippleEffectState extends State<ImpactRippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
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
        return CustomPaint(
          size: Size.infinite,
          painter: ImpactRipplePainter(
            center: widget.position,
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// 강화된 충격파 Painter
class ImpactRipplePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final Color color;

  ImpactRipplePainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 중앙 플래시 (빠르게 나타났다 사라짐)
    if (progress < 0.3) {
      final flashProgress = progress / 0.3;
      final flashOpacity = math.sin(flashProgress * math.pi) * 0.8;
      final flashRadius = 20.0 + 15.0 * flashProgress;

      final flashPaint = Paint()
        ..color = color.withValues(alpha: flashOpacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(center, flashRadius, flashPaint);
    }

    // 2. 외곽 충격파 (2개의 동심원)
    for (int i = 0; i < 2; i++) {
      final delay = i * 0.12;
      final waveProgress = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);

      if (waveProgress <= 0) continue;

      // Ease out for natural deceleration
      final easedProgress = Curves.easeOutCubic.transform(waveProgress);

      final radius = 100.0 * easedProgress;
      final opacity = (1.0 - waveProgress) * 0.5;
      final strokeWidth = 2.5 * (1.0 - waveProgress * 0.6);

      final wavePaint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, wavePaint);
    }

    // 3. 바닥 그림자 효과 (착지감 강조)
    if (progress < 0.5) {
      final shadowProgress = progress / 0.5;
      final shadowOpacity = (1.0 - shadowProgress) * 0.3;
      final shadowScaleX = 1.0 + shadowProgress * 0.5;
      final shadowScaleY = 0.3 + shadowProgress * 0.2;

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: shadowOpacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.save();
      canvas.translate(center.dx, center.dy + 5);
      canvas.scale(shadowScaleX, shadowScaleY);
      canvas.drawCircle(Offset.zero, 30, shadowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ImpactRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.center != center;
  }
}
