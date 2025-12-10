import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 특수 이벤트 타입
enum SpecialEventType {
  /// 쪽 - 바닥에 같은 월의 카드가 1장 있을 때 가져감
  jjok,

  /// 뻑 - 같은 월 카드 3장이 바닥에 있을 때 내 카드로 못 가져감
  ppuk,

  /// 따닥 - 손에서 낸 카드와 덱에서 뒤집은 카드가 같은 월
  ddadak,

  /// 자뻑 - 덱에서 뒤집은 카드가 뻑을 만듦
  jappuk,

  /// 쓸 - 바닥 카드를 모두 가져감
  ssul,
}

/// 특수 이벤트 효과 위젯
class SpecialEventEffect extends StatefulWidget {
  /// 효과 중심 위치
  final Offset position;

  /// 이벤트 타입
  final SpecialEventType eventType;

  /// 완료 콜백
  final VoidCallback? onComplete;

  const SpecialEventEffect({
    super.key,
    required this.position,
    required this.eventType,
    this.onComplete,
  });

  @override
  State<SpecialEventEffect> createState() => _SpecialEventEffectState();
}

class _SpecialEventEffectState extends State<SpecialEventEffect>
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
    switch (widget.eventType) {
      case SpecialEventType.jjok:
        return const Duration(milliseconds: 600);
      case SpecialEventType.ppuk:
        return const Duration(milliseconds: 800);
      case SpecialEventType.ddadak:
        return const Duration(milliseconds: 700);
      case SpecialEventType.jappuk:
        return const Duration(milliseconds: 900);
      case SpecialEventType.ssul:
        return const Duration(milliseconds: 800);
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
    switch (widget.eventType) {
      case SpecialEventType.jjok:
        return JjokEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
      case SpecialEventType.ppuk:
        return PpukEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
      case SpecialEventType.ddadak:
        return DdadakEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
      case SpecialEventType.jappuk:
        return JappukEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
      case SpecialEventType.ssul:
        return SsulEffectPainter(
          center: widget.position,
          progress: _controller.value,
        );
    }
  }
}

/// 쪽 효과 - 빠른 섬광 + 별 모양
class JjokEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  JjokEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 중앙 섬광
    if (progress < 0.4) {
      final flashProgress = progress / 0.4;
      final flashOpacity = math.sin(flashProgress * math.pi) * 0.9;
      final flashRadius = 30.0 + 20.0 * flashProgress;

      final flashPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: flashOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawCircle(center, flashRadius, flashPaint);
    }

    // 2. 별 모양 방사선 (6개)
    if (progress > 0.1 && progress < 0.8) {
      final rayProgress = (progress - 0.1) / 0.7;
      final rayOpacity = (1.0 - rayProgress) * 0.8;
      final rayLength = 60.0 * Curves.easeOut.transform(rayProgress);

      for (int i = 0; i < 6; i++) {
        final angle = (i / 6) * math.pi * 2 - math.pi / 2;

        final startPoint = Offset(
          center.dx + math.cos(angle) * 15,
          center.dy + math.sin(angle) * 15,
        );

        final endPoint = Offset(
          center.dx + math.cos(angle) * rayLength,
          center.dy + math.sin(angle) * rayLength,
        );

        final rayPaint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: rayOpacity)
          ..strokeWidth = 3.0 * (1 - rayProgress * 0.5)
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(startPoint, endPoint, rayPaint);
      }
    }

    // 3. 텍스트 "쪽!"
    if (progress > 0.2 && progress < 0.9) {
      final textProgress = (progress - 0.2) / 0.7;
      final textOpacity = textProgress < 0.3
          ? textProgress / 0.3
          : (1.0 - (textProgress - 0.3) / 0.7);
      final textScale = 0.8 + 0.4 * Curves.elasticOut.transform(
          textProgress.clamp(0.0, 0.5) * 2);

      _drawText(canvas, '쪽!', center.translate(0, -50),
          const Color(0xFF00E5FF), textOpacity, textScale);
    }
  }

  @override
  bool shouldRepaint(JjokEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 뻑 효과 - X 표시 + 흔들림 + 경고색
class PpukEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  PpukEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 흔들림 오프셋
    final shakeOffset = progress < 0.5
        ? math.sin(progress * math.pi * 8) * 5 * (1 - progress * 2)
        : 0.0;
    final shakenCenter = center.translate(shakeOffset, 0);

    // 1. 배경 원 (경고색)
    final bgProgress = Curves.easeOut.transform(progress.clamp(0.0, 0.5) * 2);
    final bgOpacity = (1.0 - progress) * 0.3;
    final bgRadius = 50.0 * bgProgress;

    final bgPaint = Paint()
      ..color = const Color(0xFFFF4444).withValues(alpha: bgOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(shakenCenter, bgRadius, bgPaint);

    // 2. X 표시
    if (progress > 0.1 && progress < 0.9) {
      final xProgress = (progress - 0.1) / 0.8;
      final xOpacity = xProgress < 0.3
          ? xProgress / 0.3
          : (1.0 - (xProgress - 0.3) / 0.7);
      final xSize = 35.0 * Curves.easeOut.transform(xProgress.clamp(0.0, 0.5) * 2);

      final xPaint = Paint()
        ..color = const Color(0xFFFF4444).withValues(alpha: xOpacity)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      // X의 두 선
      canvas.drawLine(
        shakenCenter.translate(-xSize, -xSize),
        shakenCenter.translate(xSize, xSize),
        xPaint,
      );
      canvas.drawLine(
        shakenCenter.translate(xSize, -xSize),
        shakenCenter.translate(-xSize, xSize),
        xPaint,
      );
    }

    // 3. 텍스트 "뻑!"
    if (progress > 0.3 && progress < 0.95) {
      final textProgress = (progress - 0.3) / 0.65;
      final textOpacity = textProgress < 0.3
          ? textProgress / 0.3
          : (1.0 - (textProgress - 0.3) / 0.7);

      _drawText(canvas, '뻑!', shakenCenter.translate(0, -60),
          const Color(0xFFFF4444), textOpacity, 1.2);
    }
  }

  @override
  bool shouldRepaint(PpukEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 따닥 효과 - 더블 임팩트 + 스파크
class DdadakEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  DdadakEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 첫 번째 임팩트 (0.0 ~ 0.4)
    if (progress < 0.4) {
      final impact1Progress = progress / 0.4;
      _drawImpact(canvas, center.translate(-20, 0), impact1Progress,
          const Color(0xFFFFAA00));
    }

    // 2. 두 번째 임팩트 (0.2 ~ 0.6)
    if (progress > 0.2 && progress < 0.6) {
      final impact2Progress = (progress - 0.2) / 0.4;
      _drawImpact(canvas, center.translate(20, 0), impact2Progress,
          const Color(0xFFFF6600));
    }

    // 3. 스파크 효과 (0.3 ~ 0.8)
    if (progress > 0.3 && progress < 0.8) {
      final sparkProgress = (progress - 0.3) / 0.5;
      _drawSparks(canvas, center, sparkProgress);
    }

    // 4. 텍스트 "따닥!"
    if (progress > 0.4 && progress < 0.95) {
      final textProgress = (progress - 0.4) / 0.55;
      final textOpacity = textProgress < 0.3
          ? textProgress / 0.3
          : (1.0 - (textProgress - 0.3) / 0.7);
      final textScale = 0.8 + 0.4 * Curves.elasticOut.transform(
          textProgress.clamp(0.0, 0.5) * 2);

      _drawText(canvas, '따닥!', center.translate(0, -55),
          const Color(0xFFFFAA00), textOpacity, textScale);
    }
  }

  void _drawImpact(Canvas canvas, Offset pos, double progress, Color color) {
    final opacity = math.sin(progress * math.pi) * 0.8;
    final radius = 25.0 * Curves.easeOut.transform(progress);

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawCircle(pos, radius, paint);
  }

  void _drawSparks(Canvas canvas, Offset pos, double progress) {
    final sparkOpacity = (1.0 - progress) * 0.9;
    final random = math.Random(42); // 고정 시드로 일관된 패턴

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2 + random.nextDouble() * 0.5;
      final distance = 30.0 + 50.0 * progress + random.nextDouble() * 20;

      final sparkPos = Offset(
        pos.dx + math.cos(angle) * distance,
        pos.dy + math.sin(angle) * distance,
      );

      final sparkPaint = Paint()
        ..color = const Color(0xFFFFDD00).withValues(alpha: sparkOpacity)
        ..strokeWidth = 2.0 * (1 - progress * 0.5)
        ..strokeCap = StrokeCap.round;

      // 작은 선으로 스파크 표현
      final sparkEnd = Offset(
        sparkPos.dx + math.cos(angle) * 8,
        sparkPos.dy + math.sin(angle) * 8,
      );

      canvas.drawLine(sparkPos, sparkEnd, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(DdadakEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 자뻑 효과 - 경고 + 폭발
class JappukEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  JappukEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 경고 깜빡임 (0.0 ~ 0.4)
    if (progress < 0.4) {
      final blinkProgress = progress / 0.4;
      final blinkOpacity = math.sin(blinkProgress * math.pi * 3) * 0.6;

      final blinkPaint = Paint()
        ..color = const Color(0xFFFF0000).withValues(alpha: blinkOpacity.abs())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawCircle(center, 60, blinkPaint);
    }

    // 2. 폭발 효과 (0.3 ~ 0.8)
    if (progress > 0.3 && progress < 0.8) {
      final explosionProgress = (progress - 0.3) / 0.5;
      final explosionOpacity = (1.0 - explosionProgress) * 0.7;
      final explosionRadius = 80.0 * Curves.easeOut.transform(explosionProgress);

      // 내부 원
      final innerPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: explosionOpacity),
            const Color(0xFFFF6600).withValues(alpha: explosionOpacity * 0.7),
            const Color(0xFFFF0000).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: explosionRadius));

      canvas.drawCircle(center, explosionRadius, innerPaint);

      // 외부 링
      final ringPaint = Paint()
        ..color = const Color(0xFFFF4400).withValues(alpha: explosionOpacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1 - explosionProgress);

      canvas.drawCircle(center, explosionRadius * 1.2, ringPaint);
    }

    // 3. 느낌표 (0.2 ~ 0.9)
    if (progress > 0.2 && progress < 0.9) {
      final excProgress = (progress - 0.2) / 0.7;
      final excOpacity = excProgress < 0.3
          ? excProgress / 0.3
          : (1.0 - (excProgress - 0.3) / 0.7);

      _drawExclamation(canvas, center, excOpacity);
    }

    // 4. 텍스트 "자뻑!"
    if (progress > 0.5 && progress < 0.98) {
      final textProgress = (progress - 0.5) / 0.48;
      final textOpacity = textProgress < 0.3
          ? textProgress / 0.3
          : (1.0 - (textProgress - 0.3) / 0.7);

      _drawText(canvas, '자뻑!', center.translate(0, -70),
          const Color(0xFFFF4400), textOpacity, 1.3);
    }
  }

  void _drawExclamation(Canvas canvas, Offset pos, double opacity) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // 느낌표 몸통
    final bodyPath = Path()
      ..moveTo(pos.dx - 6, pos.dy - 25)
      ..lineTo(pos.dx + 6, pos.dy - 25)
      ..lineTo(pos.dx + 4, pos.dy + 5)
      ..lineTo(pos.dx - 4, pos.dy + 5)
      ..close();

    canvas.drawPath(bodyPath, paint);

    // 느낌표 점
    canvas.drawCircle(pos.translate(0, 15), 5, paint);
  }

  @override
  bool shouldRepaint(JappukEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 쓸 효과 - 웨이브 + 휩쓸기
class SsulEffectPainter extends CustomPainter {
  final Offset center;
  final double progress;

  SsulEffectPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 물결 웨이브 (왼쪽에서 오른쪽으로)
    final waveProgress = Curves.easeInOut.transform(progress);
    final waveWidth = 300.0;
    final waveX = center.dx - waveWidth / 2 + waveWidth * waveProgress;

    for (int i = 0; i < 3; i++) {
      final waveOffset = i * 15.0;
      final waveOpacity = (1.0 - progress) * 0.4 * (1 - i * 0.2);

      final wavePaint = Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: waveOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0 - i * 1.0;

      final wavePath = Path();
      wavePath.moveTo(waveX - waveOffset, center.dy - 50);

      for (double y = -50; y <= 50; y += 5) {
        final waveAmplitude = 10.0 * math.sin((y + progress * 100) * 0.1);
        wavePath.lineTo(waveX - waveOffset + waveAmplitude, center.dy + y);
      }

      canvas.drawPath(wavePath, wavePaint);
    }

    // 2. 글로우 트레일
    if (progress > 0.1) {
      final trailOpacity = (1.0 - progress) * 0.3;
      final trailPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(waveProgress * 2 - 1, 0),
          end: Alignment(waveProgress * 2 - 1 + 0.3, 0),
          colors: [
            const Color(0xFF4FC3F7).withValues(alpha: 0),
            const Color(0xFF4FC3F7).withValues(alpha: trailOpacity),
            const Color(0xFF4FC3F7).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCenter(
          center: center,
          width: waveWidth,
          height: 120,
        ));

      canvas.drawRect(
        Rect.fromCenter(center: center, width: waveWidth, height: 100),
        trailPaint,
      );
    }

    // 3. 텍스트 "쓸!"
    if (progress > 0.3 && progress < 0.9) {
      final textProgress = (progress - 0.3) / 0.6;
      final textOpacity = textProgress < 0.3
          ? textProgress / 0.3
          : (1.0 - (textProgress - 0.3) / 0.7);
      final textX = center.dx - 100 + 200 * waveProgress;

      _drawText(canvas, '쓸!', Offset(textX, center.dy - 60),
          const Color(0xFF4FC3F7), textOpacity, 1.1);
    }
  }

  @override
  bool shouldRepaint(SsulEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 텍스트 그리기 헬퍼
void _drawText(Canvas canvas, String text, Offset position,
    Color color, double opacity, double scale) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: opacity),
        fontSize: 24 * scale,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: opacity * 0.5),
            blurRadius: 4,
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
    position.dx - textPainter.width / 2,
    position.dy - textPainter.height / 2,
  );
  textPainter.paint(canvas, Offset.zero);
  canvas.restore();
}

/// 특수 이벤트 관리자
class SpecialEventEffectManager extends StatefulWidget {
  final Widget child;

  const SpecialEventEffectManager({
    super.key,
    required this.child,
  });

  static SpecialEventEffectManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<SpecialEventEffectManagerState>();
  }

  @override
  State<SpecialEventEffectManager> createState() =>
      SpecialEventEffectManagerState();
}

class SpecialEventEffectManagerState extends State<SpecialEventEffectManager> {
  final List<_EventData> _activeEvents = [];
  int _eventIdCounter = 0;

  /// 특수 이벤트 효과 추가
  void addEvent({
    required Offset position,
    required SpecialEventType eventType,
  }) {
    final id = _eventIdCounter++;
    setState(() {
      _activeEvents.add(_EventData(
        id: id,
        position: position,
        eventType: eventType,
      ));
    });
  }

  void _removeEvent(int id) {
    setState(() {
      _activeEvents.removeWhere((e) => e.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeEvents.map((event) => SpecialEventEffect(
              key: ValueKey(event.id),
              position: event.position,
              eventType: event.eventType,
              onComplete: () => _removeEvent(event.id),
            )),
      ],
    );
  }
}

class _EventData {
  final int id;
  final Offset position;
  final SpecialEventType eventType;

  _EventData({
    required this.id,
    required this.position,
    required this.eventType,
  });
}
