import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 카드 매칭 화살표 표시기
class ArrowIndicator extends PositionComponent with HasPaint {
  final Vector2 startPoint;
  final Vector2 endPoint;
  final Color color;

  double _animationPhase = 0;
  double _opacity = 1.0;

  ArrowIndicator({
    required this.startPoint,
    required this.endPoint,
    this.color = const Color(0xFFFFD700),
  }) : super(priority: 100);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationPhase += dt * 3;
    if (_animationPhase > math.pi * 2) {
      _animationPhase -= math.pi * 2;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_opacity <= 0) return;

    final direction = endPoint - startPoint;
    final distance = direction.length;
    final normalizedDir = direction.normalized();

    // 애니메이션된 시작/끝 포인트 (약간 줄여서)
    final animOffset = 10 + 5 * math.sin(_animationPhase);
    final actualStart = startPoint + normalizedDir * animOffset;
    final actualEnd = endPoint - normalizedDir * animOffset;

    // 현재 opacity 적용
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // 글로우 효과
    canvas.drawLine(
      Offset(actualStart.x, actualStart.y),
      Offset(actualEnd.x, actualEnd.y),
      glowPaint,
    );

    // 메인 라인
    canvas.drawLine(
      Offset(actualStart.x, actualStart.y),
      Offset(actualEnd.x, actualEnd.y),
      arrowPaint,
    );

    // 화살표 머리
    _drawArrowHead(canvas, actualEnd, normalizedDir, arrowPaint);

    // 대시 애니메이션 효과
    _drawAnimatedDashes(canvas, actualStart, actualEnd, distance);
  }

  void _drawArrowHead(Canvas canvas, Vector2 tip, Vector2 direction, Paint arrowPaint) {
    final arrowSize = 12.0;
    final angle = math.atan2(direction.y, direction.x);

    final leftAngle = angle + math.pi * 0.8;
    final rightAngle = angle - math.pi * 0.8;

    final leftPoint = Vector2(
      tip.x + arrowSize * math.cos(leftAngle),
      tip.y + arrowSize * math.sin(leftAngle),
    );

    final rightPoint = Vector2(
      tip.x + arrowSize * math.cos(rightAngle),
      tip.y + arrowSize * math.sin(rightAngle),
    );

    final path = Path()
      ..moveTo(tip.x, tip.y)
      ..lineTo(leftPoint.x, leftPoint.y)
      ..moveTo(tip.x, tip.y)
      ..lineTo(rightPoint.x, rightPoint.y);

    canvas.drawPath(path, arrowPaint);
  }

  void _drawAnimatedDashes(Canvas canvas, Vector2 start, Vector2 end, double distance) {
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * _opacity)
      ..style = PaintingStyle.fill;

    final direction = (end - start).normalized();
    final dashCount = (distance / 20).floor();

    for (int i = 0; i < dashCount; i++) {
      final t = (i / dashCount + _animationPhase / (math.pi * 2)) % 1.0;
      final pos = start + direction * (distance * t);
      final alpha = (1 - (t * 2 - 1).abs()) * 0.8 * _opacity;

      dashPaint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(pos.x, pos.y), 3, dashPaint);
    }
  }

  /// 페이드 아웃
  Future<void> fadeOut({double duration = 0.3}) async {
    final steps = (duration * 60).toInt();
    final stepDuration = duration / steps;

    for (int i = steps; i >= 0; i--) {
      _opacity = i / steps;
      await Future.delayed(Duration(milliseconds: (stepDuration * 1000).toInt()));
    }
  }
}

/// 여러 화살표를 관리하는 컨테이너
class ArrowIndicatorManager extends Component {
  final List<ArrowIndicator> _arrows = [];

  /// 화살표 추가
  void addArrow(Vector2 from, Vector2 to, {Color? color}) {
    final arrow = ArrowIndicator(
      startPoint: from,
      endPoint: to,
      color: color ?? const Color(0xFFFFD700),
    );
    _arrows.add(arrow);
    add(arrow);
  }

  /// 모든 화살표 제거
  void clearArrows() {
    for (final arrow in _arrows) {
      arrow.removeFromParent();
    }
    _arrows.clear();
  }

  /// 페이드 아웃 후 제거
  Future<void> fadeOutAndClear() async {
    final futures = <Future>[];

    for (final arrow in _arrows) {
      futures.add(arrow.fadeOut());
    }

    await Future.wait(futures);
    clearArrows();
  }
}
