import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// 흔들기/폭탄 가능 카드 강조 표시기
class ShakeBombIndicator extends PositionComponent {
  final bool isBomb;
  final Vector2 cardSize;

  late RectangleComponent _border;
  late RectangleComponent _glow;
  double _animationPhase = 0;
  double _opacity = 1.0;
  bool _isFadingOut = false;

  ShakeBombIndicator({
    required Vector2 position,
    required this.cardSize,
    this.isBomb = false,
  }) : super(
          position: position,
          size: cardSize,
          anchor: Anchor.center,
          priority: 50,
        );

  Color get _color => isBomb ? Colors.orange : Colors.purple;
  String get _label => isBomb ? '폭탄' : '흔들기';

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 글로우 효과
    _glow = RectangleComponent(
      size: Vector2(cardSize.x + 20, cardSize.y + 20),
      position: Vector2(-10, -10),
      paint: Paint()
        ..color = _color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    add(_glow);

    // 테두리
    _border = RectangleComponent(
      size: cardSize,
      paint: Paint()
        ..color = _color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    add(_border);

    // 라벨
    final textPaint = TextPaint(
      style: TextStyle(
        color: _color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 2),
        ],
      ),
    );

    final labelComponent = TextComponent(
      text: _label,
      textRenderer: textPaint,
      anchor: Anchor.center,
      position: Vector2(cardSize.x / 2, -12),
    );
    add(labelComponent);

    // 펄스 애니메이션
    add(
      ScaleEffect.to(
        Vector2.all(1.05),
        EffectController(
          duration: 0.4,
          reverseDuration: 0.4,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 페이드 아웃 중이면 opacity 감소
    if (_isFadingOut) {
      _opacity -= dt * 5; // 0.2초 동안 페이드 아웃
      if (_opacity <= 0) {
        _opacity = 0;
        removeFromParent();
        return;
      }
    }

    _animationPhase += dt * 3;
    if (_animationPhase > math.pi * 2) {
      _animationPhase -= math.pi * 2;
    }

    // 글로우 알파 애니메이션
    final alpha = (0.3 + 0.2 * math.sin(_animationPhase)) * _opacity;
    _glow.paint.color = _color.withValues(alpha: alpha);

    // 테두리 알파 업데이트
    _border.paint.color = _color.withValues(alpha: _opacity);
  }

  /// 페이드 아웃 후 제거
  Future<void> fadeOutAndRemove() async {
    _isFadingOut = true;
    // 페이드 아웃이 완료될 때까지 대기
    while (_opacity > 0 && isMounted) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }
}

/// 흔들기/폭탄 가능 카드 그룹 표시기 관리자
class ShakeBombIndicatorManager extends Component {
  final List<ShakeBombIndicator> _indicators = [];

  /// 흔들기 가능 카드 그룹에 표시기 추가
  void addShakeIndicators(List<Vector2> cardPositions, Vector2 cardSize) {
    for (final pos in cardPositions) {
      final indicator = ShakeBombIndicator(
        position: pos,
        cardSize: cardSize,
        isBomb: false,
      );
      _indicators.add(indicator);
      add(indicator);
    }
  }

  /// 폭탄 가능 카드 그룹에 표시기 추가
  void addBombIndicators(List<Vector2> cardPositions, Vector2 cardSize) {
    for (final pos in cardPositions) {
      final indicator = ShakeBombIndicator(
        position: pos,
        cardSize: cardSize,
        isBomb: true,
      );
      _indicators.add(indicator);
      add(indicator);
    }
  }

  /// 모든 표시기 제거
  Future<void> clearAll() async {
    final futures = <Future>[];
    for (final indicator in _indicators) {
      futures.add(indicator.fadeOutAndRemove());
    }
    await Future.wait(futures);
    _indicators.clear();
  }

  /// 즉시 제거
  void clearImmediately() {
    for (final indicator in _indicators) {
      indicator.removeFromParent();
    }
    _indicators.clear();
  }
}
