import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 쓸어담기 웨이브 효과
///
/// 카드들이 한 곳으로 쓸려가는 시각적 효과
class SweepWaveEffect extends StatefulWidget {
  /// 시작 위치들 (카드들의 원래 위치)
  final List<Offset> startPositions;

  /// 목표 위치 (쓸려가는 곳)
  final Offset targetPosition;

  /// 웨이브 색상
  final Color color;

  /// 애니메이션 지속 시간
  final Duration duration;

  /// 완료 콜백
  final VoidCallback? onComplete;

  const SweepWaveEffect({
    super.key,
    required this.startPositions,
    required this.targetPosition,
    this.color = const Color(0xFF4FC3F7),
    this.duration = const Duration(milliseconds: 600),
    this.onComplete,
  });

  @override
  State<SweepWaveEffect> createState() => _SweepWaveEffectState();
}

class _SweepWaveEffectState extends State<SweepWaveEffect>
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
          painter: SweepWavePainter(
            startPositions: widget.startPositions,
            targetPosition: widget.targetPosition,
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// 쓸어담기 웨이브 Painter
class SweepWavePainter extends CustomPainter {
  final List<Offset> startPositions;
  final Offset targetPosition;
  final double progress;
  final Color color;

  SweepWavePainter({
    required this.startPositions,
    required this.targetPosition,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (startPositions.isEmpty) return;

    // 중심점 계산
    final centerX = startPositions.map((p) => p.dx).reduce((a, b) => a + b) /
        startPositions.length;
    final centerY = startPositions.map((p) => p.dy).reduce((a, b) => a + b) /
        startPositions.length;
    final center = Offset(centerX, centerY);

    // 1. 수렴 웨이브 (각 카드 위치에서 중심으로)
    if (progress < 0.5) {
      final convergeProgress = progress / 0.5;

      for (int i = 0; i < startPositions.length; i++) {
        final start = startPositions[i];
        final current = Offset.lerp(start, center, convergeProgress)!;

        // 트레일 효과
        final trailOpacity = (1.0 - convergeProgress) * 0.4;
        _drawTrail(canvas, start, current, trailOpacity);

        // 파티클
        final particleOpacity = (1.0 - convergeProgress) * 0.6;
        _drawParticle(canvas, current, particleOpacity, i);
      }
    }

    // 2. 집중 글로우 (0.3 ~ 0.6)
    if (progress > 0.3 && progress < 0.6) {
      final glowProgress = (progress - 0.3) / 0.3;
      final glowOpacity = math.sin(glowProgress * math.pi) * 0.5;
      final glowRadius = 40.0 + 20.0 * glowProgress;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: glowOpacity),
            color.withValues(alpha: glowOpacity * 0.3),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // 3. 목표로 이동하는 스트림 (0.4 ~ 1.0)
    if (progress > 0.4) {
      final streamProgress = (progress - 0.4) / 0.6;
      final currentPos = Offset.lerp(center, targetPosition,
          Curves.easeInQuart.transform(streamProgress))!;

      // 스트림 트레일
      final streamOpacity = (1.0 - streamProgress) * 0.6;
      _drawStreamTrail(canvas, center, currentPos, streamOpacity);

      // 스트림 헤드
      if (streamProgress < 0.9) {
        final headOpacity = (1.0 - streamProgress) * 0.8;
        _drawStreamHead(canvas, currentPos, headOpacity);
      }
    }

    // 4. 도착 플래시 (0.85 ~ 1.0)
    if (progress > 0.85) {
      final flashProgress = (progress - 0.85) / 0.15;
      final flashOpacity = (1.0 - flashProgress) * 0.7;
      final flashRadius = 30.0 * (1 + flashProgress);

      final flashPaint = Paint()
        ..color = color.withValues(alpha: flashOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(targetPosition, flashRadius, flashPaint);
    }
  }

  void _drawTrail(Canvas canvas, Offset start, Offset end, double opacity) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: opacity),
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);
  }

  void _drawParticle(Canvas canvas, Offset pos, double opacity, int index) {
    final particlePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final radius = 4.0 + (index % 3) * 2.0;
    canvas.drawCircle(pos, radius, particlePaint);
  }

  void _drawStreamTrail(Canvas canvas, Offset start, Offset end, double opacity) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // 곡선 경로
    final controlPoint = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - 30,
    );

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      end.dx,
      end.dy,
    );

    final trailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: opacity * 0.3),
          color.withValues(alpha: opacity),
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, trailPaint);
  }

  void _drawStreamHead(Canvas canvas, Offset pos, double opacity) {
    // 글로우 효과
    final glowPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(pos, 15, glowPaint);

    // 중심 밝은 점
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity);

    canvas.drawCircle(pos, 6, centerPaint);
  }

  @override
  bool shouldRepaint(SweepWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 간단한 쓸어담기 라인 효과
class SweepLineEffect extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const SweepLineEffect({
    super.key,
    required this.startPosition,
    required this.endPosition,
    this.color = const Color(0xFF4FC3F7),
    this.duration = const Duration(milliseconds: 400),
    this.onComplete,
  });

  @override
  State<SweepLineEffect> createState() => _SweepLineEffectState();
}

class _SweepLineEffectState extends State<SweepLineEffect>
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
          painter: SweepLinePainter(
            startPosition: widget.startPosition,
            endPosition: widget.endPosition,
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class SweepLinePainter extends CustomPainter {
  final Offset startPosition;
  final Offset endPosition;
  final double progress;
  final Color color;

  SweepLinePainter({
    required this.startPosition,
    required this.endPosition,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final easedProgress = Curves.easeInOutCubic.transform(progress);
    final currentEnd = Offset.lerp(startPosition, endPosition, easedProgress)!;

    // 페이드 아웃되는 트레일 시작점
    final trailStart = progress > 0.3
        ? Offset.lerp(startPosition, endPosition, (progress - 0.3) / 0.7)!
        : startPosition;

    // 메인 라인
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.8 * (1 - progress * 0.5)),
        ],
      ).createShader(Rect.fromPoints(trailStart, currentEnd))
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(trailStart, currentEnd, linePaint);

    // 헤드 글로우
    if (progress < 0.95) {
      final headOpacity = (1 - progress) * 0.7;
      final headPaint = Paint()
        ..color = Colors.white.withValues(alpha: headOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      canvas.drawCircle(currentEnd, 8, headPaint);
    }
  }

  @override
  bool shouldRepaint(SweepLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 쓸어담기 효과 관리자
class SweepWaveManager extends StatefulWidget {
  final Widget child;

  const SweepWaveManager({
    super.key,
    required this.child,
  });

  static SweepWaveManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<SweepWaveManagerState>();
  }

  @override
  State<SweepWaveManager> createState() => SweepWaveManagerState();
}

class SweepWaveManagerState extends State<SweepWaveManager> {
  final List<_SweepData> _activeSweeps = [];
  int _sweepIdCounter = 0;

  /// 웨이브 효과 추가
  void addSweepWave({
    required List<Offset> startPositions,
    required Offset targetPosition,
    Color color = const Color(0xFF4FC3F7),
    Duration duration = const Duration(milliseconds: 600),
  }) {
    final id = _sweepIdCounter++;
    setState(() {
      _activeSweeps.add(_SweepData(
        id: id,
        startPositions: startPositions,
        targetPosition: targetPosition,
        color: color,
        duration: duration,
        isLine: false,
      ));
    });
  }

  /// 라인 효과 추가
  void addSweepLine({
    required Offset startPosition,
    required Offset endPosition,
    Color color = const Color(0xFF4FC3F7),
    Duration duration = const Duration(milliseconds: 400),
  }) {
    final id = _sweepIdCounter++;
    setState(() {
      _activeSweeps.add(_SweepData(
        id: id,
        startPositions: [startPosition],
        targetPosition: endPosition,
        color: color,
        duration: duration,
        isLine: true,
      ));
    });
  }

  void _removeSweep(int id) {
    setState(() {
      _activeSweeps.removeWhere((s) => s.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeSweeps.map((sweep) => sweep.isLine
            ? SweepLineEffect(
                key: ValueKey(sweep.id),
                startPosition: sweep.startPositions.first,
                endPosition: sweep.targetPosition,
                color: sweep.color,
                duration: sweep.duration,
                onComplete: () => _removeSweep(sweep.id),
              )
            : SweepWaveEffect(
                key: ValueKey(sweep.id),
                startPositions: sweep.startPositions,
                targetPosition: sweep.targetPosition,
                color: sweep.color,
                duration: sweep.duration,
                onComplete: () => _removeSweep(sweep.id),
              )),
      ],
    );
  }
}

class _SweepData {
  final int id;
  final List<Offset> startPositions;
  final Offset targetPosition;
  final Color color;
  final Duration duration;
  final bool isLine;

  _SweepData({
    required this.id,
    required this.startPositions,
    required this.targetPosition,
    required this.color,
    required this.duration,
    required this.isLine,
  });
}
