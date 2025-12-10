import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// 카드 위에 표시되는 텍스트 오버레이 (뻑, 쪽 등)
class CardTextOverlay extends PositionComponent {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final bool animate;

  late TextPaint _textPaint;
  late RectangleComponent _background;
  late RectangleComponent _glow;
  late TextComponent _textComponent;
  double _pulsePhase = 0;
  bool _isPulsing = true;
  double _opacity = 1.0;
  bool _isFadingOut = false;

  CardTextOverlay({
    required this.text,
    required Vector2 position,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
    this.fontSize = 24,
    this.animate = true,
  }) : super(
          position: position,
          anchor: Anchor.center,
          priority: 200,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _textPaint = TextPaint(
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
    );

    // 텍스트 크기 계산
    _textComponent = TextComponent(
      text: text,
      textRenderer: _textPaint,
    );
    final textSize = _textComponent.size;

    // 배경 생성
    final padding = 16.0;
    _background = RectangleComponent(
      size: Vector2(textSize.x + padding * 2, textSize.y + padding),
      position: Vector2(-textSize.x / 2 - padding, -textSize.y / 2 - padding / 2),
      paint: Paint()
        ..color = backgroundColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );

    // 글로우 효과
    _glow = RectangleComponent(
      size: Vector2(textSize.x + padding * 2 + 8, textSize.y + padding + 8),
      position: Vector2(-textSize.x / 2 - padding - 4, -textSize.y / 2 - padding / 2 - 4),
      paint: Paint()
        ..color = backgroundColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    add(_glow);
    add(_background);

    // 텍스트 추가
    _textComponent.position = Vector2(-textSize.x / 2, -textSize.y / 2);
    add(_textComponent);

    if (animate) {
      // 등장 애니메이션
      scale = Vector2.zero();
      add(
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.3, curve: Curves.elasticOut),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 페이드 아웃 중이면 opacity 감소
    if (_isFadingOut) {
      _opacity -= dt * 3.3; // 약 0.3초 동안 페이드 아웃
      if (_opacity <= 0) {
        _opacity = 0;
        removeFromParent();
        return;
      }
      _updateOpacity();
    }

    if (_isPulsing && animate && !_isFadingOut) {
      _pulsePhase += dt * 4;
      final pulse = 1 + 0.05 * math.sin(_pulsePhase);
      scale = Vector2.all(pulse);
    }
  }

  void _updateOpacity() {
    _background.paint.color = backgroundColor.withValues(alpha: 0.9 * _opacity);
    _glow.paint.color = backgroundColor.withValues(alpha: 0.4 * _opacity);

    // 텍스트 색상 업데이트
    _textComponent.textRenderer = TextPaint(
      style: TextStyle(
        color: textColor.withValues(alpha: _opacity),
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: _opacity),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
    );
  }

  /// 흔들기 애니메이션
  Future<void> shake() async {
    for (int i = 0; i < 3; i++) {
      final shakeRight = MoveEffect.by(
        Vector2(6, 0),
        EffectController(duration: 0.05),
      );
      add(shakeRight);
      await shakeRight.removed;

      final shakeLeft = MoveEffect.by(
        Vector2(-12, 0),
        EffectController(duration: 0.1),
      );
      add(shakeLeft);
      await shakeLeft.removed;

      final shakeBack = MoveEffect.by(
        Vector2(6, 0),
        EffectController(duration: 0.05),
      );
      add(shakeBack);
      await shakeBack.removed;
    }
  }

  /// 페이드 아웃 후 제거
  Future<void> fadeOutAndRemove({double delay = 0}) async {
    if (delay > 0) {
      await Future.delayed(Duration(milliseconds: (delay * 1000).toInt()));
    }

    _isPulsing = false;
    _isFadingOut = true;

    // 스케일 다운 효과
    add(
      ScaleEffect.to(
        Vector2.all(0.5),
        EffectController(duration: 0.3, curve: Curves.easeIn),
      ),
    );

    // 페이드 아웃이 완료될 때까지 대기
    while (_opacity > 0 && isMounted) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }
}

/// 뻑 텍스트 오버레이
class PpukTextOverlay extends CardTextOverlay {
  PpukTextOverlay({required super.position})
      : super(
          text: '뻑',
          backgroundColor: Colors.orange,
          fontSize: 28,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await shake();
  }
}

/// 쪽 텍스트 오버레이
class JjokTextOverlay extends CardTextOverlay {
  JjokTextOverlay({required super.position})
      : super(
          text: '쪽',
          backgroundColor: Colors.pink,
          fontSize: 28,
        );
}

/// 따닥 텍스트 오버레이
class TtadakTextOverlay extends CardTextOverlay {
  TtadakTextOverlay({required super.position})
      : super(
          text: '따닥',
          backgroundColor: Colors.purple,
          fontSize: 24,
        );
}

/// 싹쓸이 텍스트 오버레이
class SweepTextOverlay extends CardTextOverlay {
  SweepTextOverlay({required super.position})
      : super(
          text: '싹쓸이',
          backgroundColor: Colors.blue,
          fontSize: 24,
        );
}

/// 설사 텍스트 오버레이
class SulsaTextOverlay extends CardTextOverlay {
  SulsaTextOverlay({required super.position})
      : super(
          text: '설사',
          backgroundColor: Colors.green,
          fontSize: 24,
        );
}
