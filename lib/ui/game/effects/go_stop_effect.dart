import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 고/스톱 결정 타입
enum GoStopDecision {
  /// 고 - 게임 계속
  go,

  /// 스톱 - 게임 종료
  stop,

  /// 승리
  win,

  /// 패배
  lose,
}

/// 고/스톱 결정 효과 위젯
class GoStopEffect extends StatefulWidget {
  /// 효과 중심 위치
  final Offset position;

  /// 결정 타입
  final GoStopDecision decision;

  /// 고 횟수 (고인 경우에만 사용)
  final int goCount;

  /// 완료 콜백
  final VoidCallback? onComplete;

  const GoStopEffect({
    super.key,
    required this.position,
    required this.decision,
    this.goCount = 1,
    this.onComplete,
  });

  @override
  State<GoStopEffect> createState() => _GoStopEffectState();
}

class _GoStopEffectState extends State<GoStopEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getDuration(),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _controller.forward();
  }

  Duration _getDuration() {
    switch (widget.decision) {
      case GoStopDecision.go:
        return const Duration(milliseconds: 800);
      case GoStopDecision.stop:
        return const Duration(milliseconds: 1000);
      case GoStopDecision.win:
        return const Duration(milliseconds: 1500);
      case GoStopDecision.lose:
        return const Duration(milliseconds: 1000);
    }
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
          painter: _getPainter(),
        );
      },
    );
  }

  CustomPainter _getPainter() {
    switch (widget.decision) {
      case GoStopDecision.go:
        return GoEffectPainter(
          center: widget.position,
          progress: _controller.value,
          goCount: widget.goCount,
        );
      case GoStopDecision.stop:
        return StopEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
      case GoStopDecision.win:
        return WinEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
      case GoStopDecision.lose:
        return LoseEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
    }
  }
}

/// 고 효과 - 화염 + 상승 에너지
class GoEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final int goCount;

  GoEffectPainter({
    required this.center,
    required this.progress,
    required this.goCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 화염 배경 글로우
    if (progress < 0.7) {
      final glowProgress = progress / 0.7;
      final glowOpacity = math.sin(glowProgress * math.pi) * 0.4;
      final glowRadius = 80.0 + 40.0 * glowProgress;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6600).withValues(alpha: glowOpacity),
            const Color(0xFFFF3300).withValues(alpha: glowOpacity * 0.5),
            const Color(0xFFFF0000).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // 2. 상승하는 화염 파티클
    if (progress > 0.1 && progress < 0.8) {
      final flameProgress = (progress - 0.1) / 0.7;
      final random = math.Random(42);

      for (int i = 0; i < 15; i++) {
        final xOffset = (random.nextDouble() - 0.5) * 80;
        final yOffset = -100 * flameProgress + random.nextDouble() * 30;
        final flameOpacity = (1.0 - flameProgress) * 0.8;
        final flameSize = 8.0 + random.nextDouble() * 8 * (1 - flameProgress);

        final flamePos = center.translate(xOffset, yOffset);

        final flamePaint = Paint()
          ..color = Color.lerp(
            const Color(0xFFFFAA00),
            const Color(0xFFFF3300),
            random.nextDouble(),
          )!.withValues(alpha: flameOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawCircle(flamePos, flameSize, flamePaint);
      }
    }

    // 3. 중앙 폭발
    if (progress > 0.2 && progress < 0.5) {
      final burstProgress = (progress - 0.2) / 0.3;
      final burstOpacity = (1.0 - burstProgress) * 0.9;
      final burstRadius = 50.0 * Curves.easeOut.transform(burstProgress);

      // 외곽 링들
      for (int i = 0; i < 3; i++) {
        final ringProgress = (burstProgress - i * 0.1).clamp(0.0, 1.0);
        final ringRadius = burstRadius * (1 + i * 0.3);
        final ringOpacity = burstOpacity * (1 - i * 0.2);

        final ringPaint = Paint()
          ..color = const Color(0xFFFFAA00).withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * (1 - ringProgress);

        canvas.drawCircle(center, ringRadius, ringPaint);
      }
    }

    // 4. 텍스트 "고!" 또는 "N고!"
    if (progress > 0.3 && progress < 0.95) {
      final textProgress = (progress - 0.3) / 0.65;
      final textOpacity = textProgress < 0.2
          ? textProgress / 0.2
          : (1.0 - (textProgress - 0.2) / 0.8);
      final textScale = 1.0 + 0.5 * Curves.elasticOut.transform(
          textProgress.clamp(0.0, 0.5) * 2);

      final goText = goCount > 1 ? '$goCount고!' : '고!';
      _drawGoText(canvas, goText, center, textOpacity, textScale);
    }
  }

  void _drawGoText(Canvas canvas, String text, Offset pos, double opacity, double scale) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: 36 * scale,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: const Color(0xFFFF3300).withValues(alpha: opacity),
              blurRadius: 10,
            ),
            Shadow(
              color: const Color(0xFFFF6600).withValues(alpha: opacity * 0.5),
              blurRadius: 20,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    canvas.save();
    canvas.translate(
      pos.dx - textPainter.width / 2,
      pos.dy - textPainter.height / 2 - 20,
    );
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GoEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 스톱 효과 - 결정적인 멈춤 + 확산
class StopEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  StopEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 배경 어둡게
    if (progress < 0.3) {
      final darkProgress = progress / 0.3;
      final darkOpacity = darkProgress * 0.3;

      final darkPaint = Paint()
        ..color = Colors.black.withValues(alpha: darkOpacity);

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        darkPaint,
      );
    }

    // 2. 중앙 임팩트 웨이브
    if (progress > 0.1 && progress < 0.6) {
      final waveProgress = (progress - 0.1) / 0.5;

      for (int i = 0; i < 3; i++) {
        final individualProgress = (waveProgress - i * 0.15).clamp(0.0, 1.0);
        if (individualProgress <= 0) continue;

        final waveRadius = 120.0 * Curves.easeOut.transform(individualProgress);
        final waveOpacity = (1.0 - individualProgress) * 0.5;
        final strokeWidth = 4.0 * (1 - individualProgress * 0.7);

        final wavePaint = Paint()
          ..color = const Color(0xFF4A90D9).withValues(alpha: waveOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

        canvas.drawCircle(center, waveRadius, wavePaint);
      }
    }

    // 3. 팔각형 스톱 사인
    if (progress > 0.2 && progress < 0.9) {
      final signProgress = (progress - 0.2) / 0.7;
      final signOpacity = signProgress < 0.2
          ? signProgress / 0.2
          : (1.0 - (signProgress - 0.2) / 0.8) * 0.9;
      final signScale = Curves.elasticOut.transform(signProgress.clamp(0.0, 0.6) / 0.6);

      _drawStopSign(canvas, center, signOpacity, signScale * 50);
    }

    // 4. 텍스트 "스톱!"
    if (progress > 0.4 && progress < 0.95) {
      final textProgress = (progress - 0.4) / 0.55;
      final textOpacity = textProgress < 0.2
          ? textProgress / 0.2
          : (1.0 - (textProgress - 0.2) / 0.8);
      final textScale = 0.9 + 0.3 * Curves.easeOut.transform(
          textProgress.clamp(0.0, 0.4) * 2.5);

      _drawStopText(canvas, '스톱!', center.translate(0, 60), textOpacity, textScale);
    }
  }

  void _drawStopSign(Canvas canvas, Offset pos, double opacity, double radius) {
    final path = Path();
    final sides = 8;

    for (int i = 0; i < sides; i++) {
      final angle = (i / sides) * math.pi * 2 - math.pi / 2;
      final x = pos.dx + math.cos(angle) * radius;
      final y = pos.dy + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // 배경
    final bgPaint = Paint()
      ..color = const Color(0xFF4A90D9).withValues(alpha: opacity * 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, bgPaint);

    // 테두리
    final borderPaint = Paint()
      ..color = const Color(0xFF4A90D9).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawPath(path, borderPaint);
  }

  void _drawStopText(Canvas canvas, String text, Offset pos, double opacity, double scale) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF4A90D9).withValues(alpha: opacity),
          fontSize: 32 * scale,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: opacity * 0.3),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    canvas.save();
    canvas.translate(
      pos.dx - textPainter.width / 2,
      pos.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(StopEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 승리 효과 - 골드 폭죽 + 환호
class WinEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  WinEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 골드 글로우 배경
    if (progress < 0.8) {
      final glowProgress = progress / 0.8;
      final glowOpacity = math.sin(glowProgress * math.pi) * 0.3;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: glowOpacity),
            const Color(0xFFFFAA00).withValues(alpha: glowOpacity * 0.5),
            Colors.transparent,
          ],
          radius: 0.8,
        ).createShader(Rect.fromCenter(
          center: center,
          width: size.width,
          height: size.height,
        ));

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
    }

    // 2. 폭죽 파티클
    if (progress > 0.1) {
      final particleProgress = (progress - 0.1) / 0.9;
      final random = math.Random(123);

      for (int burst = 0; burst < 3; burst++) {
        final burstDelay = burst * 0.2;
        final burstProgress = ((particleProgress - burstDelay) / (1 - burstDelay))
            .clamp(0.0, 1.0);

        if (burstProgress <= 0) continue;

        final burstCenter = Offset(
          center.dx + (burst - 1) * 80,
          center.dy - 50 + burst * 20,
        );

        for (int i = 0; i < 12; i++) {
          final angle = (i / 12) * math.pi * 2;
          final distance = 80.0 * Curves.easeOut.transform(burstProgress);
          final particleOpacity = (1.0 - burstProgress * 0.8) * 0.8;

          final particlePos = Offset(
            burstCenter.dx + math.cos(angle) * distance,
            burstCenter.dy + math.sin(angle) * distance +
                burstProgress * 30, // 중력 효과
          );

          final particleColor = [
            const Color(0xFFFFD700),
            const Color(0xFFFF6B6B),
            const Color(0xFF4ECB71),
            const Color(0xFF4A90D9),
          ][i % 4];

          final particlePaint = Paint()
            ..color = particleColor.withValues(alpha: particleOpacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

          canvas.drawCircle(particlePos, 4 * (1 - burstProgress * 0.5), particlePaint);
        }
      }
    }

    // 3. 별 스파클
    if (progress > 0.3 && progress < 0.9) {
      final sparkleProgress = (progress - 0.3) / 0.6;
      final random = math.Random(456);

      for (int i = 0; i < 8; i++) {
        final sparkleDelay = random.nextDouble() * 0.3;
        final individualProgress = ((sparkleProgress - sparkleDelay) / (1 - sparkleDelay))
            .clamp(0.0, 1.0);

        if (individualProgress <= 0 || individualProgress >= 1) continue;

        final sparkleOpacity = math.sin(individualProgress * math.pi);
        final sparklePos = Offset(
          center.dx + (random.nextDouble() - 0.5) * 200,
          center.dy + (random.nextDouble() - 0.5) * 150,
        );

        _drawStar(canvas, sparklePos, sparkleOpacity * 0.9, 10 + random.nextDouble() * 8);
      }
    }

    // 4. 텍스트 "승리!"
    if (progress > 0.2 && progress < 0.95) {
      final textProgress = (progress - 0.2) / 0.75;
      final textOpacity = textProgress < 0.2
          ? textProgress / 0.2
          : (1.0 - (textProgress - 0.2) / 0.8) * 0.95;
      final textScale = 1.0 + 0.5 * Curves.elasticOut.transform(
          textProgress.clamp(0.0, 0.5) * 2);

      _drawWinText(canvas, '승리!', center, textOpacity, textScale);
    }
  }

  void _drawStar(Canvas canvas, Offset pos, double opacity, double size) {
    final path = Path();
    final points = 4;
    final innerRadius = size * 0.4;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i / (points * 2)) * math.pi * 2 - math.pi / 2;
      final radius = i.isEven ? size : innerRadius;
      final x = pos.dx + math.cos(angle) * radius;
      final y = pos.dy + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  void _drawWinText(Canvas canvas, String text, Offset pos, double opacity, double scale) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFD700).withValues(alpha: opacity),
          fontSize: 48 * scale,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: const Color(0xFFFF6600).withValues(alpha: opacity),
              blurRadius: 10,
            ),
            Shadow(
              color: Colors.black.withValues(alpha: opacity * 0.5),
              blurRadius: 5,
              offset: const Offset(2, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    canvas.save();
    canvas.translate(
      pos.dx - textPainter.width / 2,
      pos.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(WinEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 패배 효과 - 어둠 + 슬픔
class LoseEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  LoseEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 어두운 배경
    final darkOpacity = progress.clamp(0.0, 0.5) * 0.4;
    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: darkOpacity);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), darkPaint);

    // 2. 하강하는 파티클
    if (progress > 0.1 && progress < 0.9) {
      final particleProgress = (progress - 0.1) / 0.8;
      final random = math.Random(789);

      for (int i = 0; i < 10; i++) {
        final xOffset = (random.nextDouble() - 0.5) * 150;
        final yOffset = 80 * particleProgress + random.nextDouble() * 20;
        final particleOpacity = (1.0 - particleProgress) * 0.5;

        final particlePos = center.translate(xOffset, yOffset);

        final particlePaint = Paint()
          ..color = const Color(0xFF666666).withValues(alpha: particleOpacity);

        canvas.drawCircle(particlePos, 3 + random.nextDouble() * 3, particlePaint);
      }
    }

    // 3. 텍스트 "패배..."
    if (progress > 0.3 && progress < 0.95) {
      final textProgress = (progress - 0.3) / 0.65;
      final textOpacity = textProgress < 0.3
          ? textProgress / 0.3
          : (1.0 - (textProgress - 0.3) / 0.7) * 0.8;

      _drawLoseText(canvas, '패배...', center, textOpacity);
    }
  }

  void _drawLoseText(Canvas canvas, String text, Offset pos, double opacity) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF888888).withValues(alpha: opacity),
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    canvas.save();
    canvas.translate(
      pos.dx - textPainter.width / 2,
      pos.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LoseEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 고/스톱 효과 관리자
class GoStopEffectManager extends StatefulWidget {
  final Widget child;

  const GoStopEffectManager({
    super.key,
    required this.child,
  });

  static GoStopEffectManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<GoStopEffectManagerState>();
  }

  @override
  State<GoStopEffectManager> createState() => GoStopEffectManagerState();
}

class GoStopEffectManagerState extends State<GoStopEffectManager> {
  final List<_GoStopData> _activeEffects = [];
  int _effectIdCounter = 0;

  /// 고/스톱 효과 추가
  void addEffect({
    required Offset position,
    required GoStopDecision decision,
    int goCount = 1,
  }) {
    final id = _effectIdCounter++;
    setState(() {
      _activeEffects.add(_GoStopData(
        id: id,
        position: position,
        decision: decision,
        goCount: goCount,
      ));
    });
  }

  void _removeEffect(int id) {
    setState(() {
      _activeEffects.removeWhere((e) => e.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeEffects.map((effect) => GoStopEffect(
              key: ValueKey(effect.id),
              position: effect.position,
              decision: effect.decision,
              goCount: effect.goCount,
              onComplete: () => _removeEffect(effect.id),
            )),
      ],
    );
  }
}

class _GoStopData {
  final int id;
  final Offset position;
  final GoStopDecision decision;
  final int goCount;

  _GoStopData({
    required this.id,
    required this.position,
    required this.decision,
    required this.goCount,
  });
}
