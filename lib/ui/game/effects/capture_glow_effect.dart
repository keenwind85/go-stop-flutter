import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 카드 획득 시 빛나는 글로우 효과
///
/// 카드를 획득할 때 카드 주변에서 빛이 발산하는 효과
class CaptureGlowEffect extends StatefulWidget {
  /// 글로우 중심 위치
  final Offset position;

  /// 글로우 색상 (카드 종류에 따라 다름)
  final Color color;

  /// 글로우 크기
  final double size;

  /// 애니메이션 지속 시간
  final Duration duration;

  /// 완료 콜백
  final VoidCallback? onComplete;

  const CaptureGlowEffect({
    super.key,
    required this.position,
    this.color = const Color(0xFFFFD700), // 기본: 골드
    this.size = 100.0,
    this.duration = const Duration(milliseconds: 500),
    this.onComplete,
  });

  @override
  State<CaptureGlowEffect> createState() => _CaptureGlowEffectState();
}

class _CaptureGlowEffectState extends State<CaptureGlowEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
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
          painter: CaptureGlowPainter(
            center: widget.position,
            progress: _controller.value,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

/// 획득 글로우 Painter
class CaptureGlowPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final Color color;
  final double size;

  CaptureGlowPainter({
    required this.center,
    required this.progress,
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // 1. 내부 글로우 (밝은 중심)
    final innerGlowProgress = Curves.easeOut.transform(progress);
    final innerRadius = size * 0.3 * innerGlowProgress;
    final innerOpacity = (1.0 - progress) * 0.8;

    if (innerOpacity > 0) {
      final innerPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: innerOpacity),
            color.withValues(alpha: innerOpacity * 0.5),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: innerRadius));

      canvas.drawCircle(center, innerRadius, innerPaint);
    }

    // 2. 외부 확산 글로우
    final outerProgress = Curves.easeOutCubic.transform(progress);
    final outerRadius = size * outerProgress;
    final outerOpacity = (1.0 - progress * 0.8) * 0.4;

    if (outerOpacity > 0) {
      final outerPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: outerOpacity * 0.3),
            color.withValues(alpha: outerOpacity),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

      canvas.drawCircle(center, outerRadius, outerPaint);
    }

    // 3. 반짝이는 파티클 효과 (8개의 작은 빛)
    if (progress < 0.8) {
      final particleProgress = progress / 0.8;
      final particleOpacity = (1.0 - particleProgress) * 0.9;

      for (int i = 0; i < 8; i++) {
        final angle = (i / 8) * math.pi * 2;
        final distance = size * 0.4 * particleProgress;

        // 살짝 지그재그 움직임
        final wobble = math.sin(particleProgress * math.pi * 3 + i) * 5;

        final particleCenter = Offset(
          center.dx + math.cos(angle) * distance + wobble,
          center.dy + math.sin(angle) * distance,
        );

        final particleRadius = 4.0 * (1 - particleProgress * 0.5);

        final particlePaint = Paint()
          ..color = Colors.white.withValues(alpha: particleOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

        canvas.drawCircle(particleCenter, particleRadius, particlePaint);
      }
    }

    // 4. 스파클 링 (빠르게 확산하는 링)
    if (progress > 0.1 && progress < 0.6) {
      final ringProgress = (progress - 0.1) / 0.5;
      final ringRadius = size * 0.8 * ringProgress;
      final ringOpacity = (1.0 - ringProgress) * 0.6;
      final strokeWidth = 2.0 * (1.0 - ringProgress);

      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, ringRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(CaptureGlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.center != center;
  }
}

/// 카드 종류별 글로우 색상
class CaptureGlowColors {
  /// 광 (밝은 금색)
  static const Color gwang = Color(0xFFFFD700);

  /// 띠 (붉은색)
  static const Color ddi = Color(0xFFFF6B6B);

  /// 피 (녹색)
  static const Color pi = Color(0xFF4ECB71);

  /// 열끗 (파란색)
  static const Color yeol = Color(0xFF4A90D9);

  /// 쌍피 (보라색)
  static const Color ssangPi = Color(0xFF9B59B6);

  /// 기본 (흰색)
  static const Color defaultColor = Colors.white;
}

/// 다중 글로우 관리자
class CaptureGlowManager extends StatefulWidget {
  final Widget child;

  const CaptureGlowManager({
    super.key,
    required this.child,
  });

  static CaptureGlowManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<CaptureGlowManagerState>();
  }

  @override
  State<CaptureGlowManager> createState() => CaptureGlowManagerState();
}

class CaptureGlowManagerState extends State<CaptureGlowManager> {
  final List<_GlowData> _activeGlows = [];
  int _glowIdCounter = 0;

  /// 글로우 효과 추가
  void addGlow({
    required Offset position,
    Color color = CaptureGlowColors.defaultColor,
    double size = 100.0,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final id = _glowIdCounter++;
    setState(() {
      _activeGlows.add(_GlowData(
        id: id,
        position: position,
        color: color,
        size: size,
        duration: duration,
      ));
    });
  }

  void _removeGlow(int id) {
    setState(() {
      _activeGlows.removeWhere((g) => g.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeGlows.map((glow) => CaptureGlowEffect(
              key: ValueKey(glow.id),
              position: glow.position,
              color: glow.color,
              size: glow.size,
              duration: glow.duration,
              onComplete: () => _removeGlow(glow.id),
            )),
      ],
    );
  }
}

class _GlowData {
  final int id;
  final Offset position;
  final Color color;
  final double size;
  final Duration duration;

  _GlowData({
    required this.id,
    required this.position,
    required this.color,
    required this.size,
    required this.duration,
  });
}
