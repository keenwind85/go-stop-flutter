import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/card_data.dart';
import '../../config/constants.dart';

/// 화투 카드 컴포넌트
class CardComponent extends SpriteComponent with TapCallbacks, HoverCallbacks {
  // 이미지 캐시 (전역)
  static final Map<String, ui.Image> _imageCache = {};
  static bool _cacheInitialized = false;
  final CardData cardData;
  bool isFlipped;
  bool isSelected = false;
  bool isHighlighted = false;
  bool isInteractive;

  Sprite? frontSprite;
  Sprite? backSprite;

  Function(CardComponent)? onCardTap;
  double _originalY = 0;

  RectangleComponent? _highlightBorder;
  RectangleComponent? _glowEffect;

  CardComponent({
    required this.cardData,
    this.isFlipped = false,
    this.isInteractive = true,
    this.onCardTap,
    Vector2? position,
    Vector2? size,
  }) : super(
          position: position,
          size: size ?? Vector2(GameConstants.cardWidth, GameConstants.cardHeight),
          anchor: Anchor.center,
        );

  /// Flutter rootBundle을 사용한 이미지 로드 (웹 호환)
  static Future<ui.Image> _loadImage(String path) async {
    if (_imageCache.containsKey(path)) {
      return _imageCache[path]!;
    }

    final assetPath = 'assets/$path';
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;

    _imageCache[path] = image;
    return image;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      // 앞면 스프라이트 로드 (Flutter rootBundle 사용)
      final frontImage = await _loadImage(cardData.imagePath);
      frontSprite = Sprite(frontImage);

      // 뒷면 스프라이트 로드
      final backImage = await _loadImage('cards/back_of_card.png');
      backSprite = Sprite(backImage);

      sprite = isFlipped ? backSprite : frontSprite;
      _originalY = position.y;

      // 글로우 이펙트 (특수 이벤트용)
      _glowEffect = RectangleComponent(
        size: Vector2(size.x + 16, size.y + 16),
        position: Vector2(-8, -8),
        paint: Paint()
          ..color = AppColors.accent.withValues(alpha: 0.0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      add(_glowEffect!);

      // 하이라이트 테두리 생성
      _highlightBorder = RectangleComponent(
        size: Vector2(size.x + 8, size.y + 8),
        position: Vector2(-4, -4),
        paint: Paint()
          ..color = AppColors.cardHighlight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _highlightBorder!.opacity = 0;
      add(_highlightBorder!);
    } catch (e) {
      print('[CardComponent] Error loading sprites: $e');
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isInteractive) return;
    onCardTap?.call(this);
  }

  @override
  void onHoverEnter() {
    if (!isInteractive || isSelected) return;
    _animateHover(true);
  }

  @override
  void onHoverExit() {
    if (!isInteractive || isSelected) return;
    _animateHover(false);
  }

  void _animateHover(bool hover) {
    final targetY = hover ? _originalY - 12 : _originalY;
    add(
      MoveEffect.to(
        Vector2(position.x, targetY),
        EffectController(duration: 0.12, curve: Curves.easeOut),
      ),
    );
  }

  /// 카드 선택 상태 설정
  void setSelected(bool selected) {
    isSelected = selected;
    _highlightBorder?.opacity = selected ? 1 : 0;

    final targetY = selected ? _originalY - 16 : _originalY;
    add(
      MoveEffect.to(
        Vector2(position.x, targetY),
        EffectController(
          duration: 0.15,
          curve: selected ? Curves.easeOutBack : Curves.easeOut,
        ),
      ),
    );
  }

  /// 매칭 하이라이트 설정
  void setHighlighted(bool highlighted) {
    isHighlighted = highlighted;
    _highlightBorder?.opacity = highlighted ? 0.7 : 0;
  }

  /// 카드 이동 애니메이션
  Future<void> moveTo(Vector2 target, {double duration = 0.3}) async {
    _originalY = target.y;
    final effect = MoveEffect.to(
      target,
      EffectController(duration: duration, curve: Curves.easeOut),
    );
    add(effect);
    await effect.removed;
  }

  /// 기준 Y 위치 업데이트 (호버 애니메이션 기준점)
  void updateOriginalY(double y) {
    _originalY = y;
  }

  /// 카드 뒤집기 애니메이션
  Future<void> flip({bool showFront = true}) async {
    // X축 스케일 축소
    final scaleDown = ScaleEffect.to(
      Vector2(0, scale.y),
      EffectController(duration: 0.1, curve: Curves.easeIn),
    );
    add(scaleDown);
    await scaleDown.removed;

    // 스프라이트 변경
    sprite = showFront ? frontSprite : backSprite;
    isFlipped = !showFront;

    // X축 스케일 확대
    final scaleUp = ScaleEffect.to(
      Vector2(1, 1),
      EffectController(duration: 0.1, curve: Curves.easeOut),
    );
    add(scaleUp);
    await scaleUp.removed;
  }

  /// 앞면 표시
  void showFront() {
    sprite = frontSprite;
    isFlipped = false;
  }

  /// 뒷면 표시
  void showBack() {
    sprite = backSprite;
    isFlipped = true;
  }

  void setOriginalY(double y) => _originalY = y;

  // ==================== 향상된 애니메이션 ====================

  /// 카드 딜링 애니메이션 (화면 밖에서 날아오며 회전)
  Future<void> dealAnimation({
    required Vector2 from,
    required Vector2 to,
    double duration = 0.4,
    double delay = 0.0,
  }) async {
    // 초기 위치 설정
    position = from;
    scale = Vector2.all(0.3);
    angle = math.pi / 6; // 약간 회전된 상태로 시작

    if (delay > 0) {
      await Future.delayed(Duration(milliseconds: (delay * 1000).toInt()));
    }

    // 이동 + 스케일 + 회전을 동시에
    final moveEffect = MoveEffect.to(
      to,
      EffectController(duration: duration, curve: Curves.easeOutCubic),
    );

    final scaleEffect = ScaleEffect.to(
      Vector2.all(1.0),
      EffectController(duration: duration, curve: Curves.easeOutBack),
    );

    final rotateEffect = RotateEffect.to(
      0,
      EffectController(duration: duration, curve: Curves.easeOutCubic),
    );

    add(moveEffect);
    add(scaleEffect);
    add(rotateEffect);

    await moveEffect.removed;
    _originalY = to.y;
  }

  /// 카드 캡처 애니메이션 (먹은 패로 날아감)
  Future<void> captureAnimation({
    required Vector2 target,
    double duration = 0.35,
  }) async {
    // 먼저 살짝 위로 튀어오름
    final bounceUp = MoveEffect.by(
      Vector2(0, -25),
      EffectController(duration: 0.08, curve: Curves.easeOut),
    );
    add(bounceUp);
    await bounceUp.removed;

    // 스케일 살짝 키움
    final scaleUp = ScaleEffect.to(
      Vector2.all(1.15),
      EffectController(duration: 0.06, curve: Curves.easeOut),
    );
    add(scaleUp);
    await scaleUp.removed;

    // 목표 지점으로 회전하며 이동 + 스케일 축소
    final moveToTarget = MoveEffect.to(
      target,
      EffectController(duration: duration, curve: Curves.easeInCubic),
    );

    final scaleDown = ScaleEffect.to(
      Vector2.all(0.4),
      EffectController(duration: duration, curve: Curves.easeIn),
    );

    final rotate = RotateEffect.by(
      math.pi * 2,
      EffectController(duration: duration, curve: Curves.easeInCubic),
    );

    add(moveToTarget);
    add(scaleDown);
    add(rotate);

    await moveToTarget.removed;
  }

  /// 뻑 애니메이션 (카드가 바닥에 쌓이며 흔들림)
  Future<void> pukAnimation() async {
    // 좌우로 흔들리는 애니메이션
    for (int i = 0; i < 3; i++) {
      final shakeRight = MoveEffect.by(
        Vector2(8, 0),
        EffectController(duration: 0.05),
      );
      add(shakeRight);
      await shakeRight.removed;

      final shakeLeft = MoveEffect.by(
        Vector2(-16, 0),
        EffectController(duration: 0.1),
      );
      add(shakeLeft);
      await shakeLeft.removed;

      final shakeBack = MoveEffect.by(
        Vector2(8, 0),
        EffectController(duration: 0.05),
      );
      add(shakeBack);
      await shakeBack.removed;
    }

    // 빨간 글로우 효과
    _showGlow(Colors.red, duration: 0.5);
  }

  /// 싹쓸이 애니메이션 (화려한 수집 효과)
  Future<void> sweepAnimation({required Vector2 target}) async {
    // 노란 글로우 효과
    _showGlow(Colors.amber, duration: 0.6);

    // 스케일 펄스
    final pulseUp = ScaleEffect.to(
      Vector2.all(1.3),
      EffectController(duration: 0.15, curve: Curves.easeOut),
    );
    add(pulseUp);
    await pulseUp.removed;

    // 회전하며 목표 지점으로
    final moveToTarget = MoveEffect.to(
      target,
      EffectController(duration: 0.4, curve: Curves.easeInOutCubic),
    );

    final scaleDown = ScaleEffect.to(
      Vector2.all(0.5),
      EffectController(duration: 0.4, curve: Curves.easeIn),
    );

    final rotate = RotateEffect.by(
      math.pi * 3,
      EffectController(duration: 0.4, curve: Curves.easeInOutCubic),
    );

    add(moveToTarget);
    add(scaleDown);
    add(rotate);

    await moveToTarget.removed;
  }

  /// 쪽 애니메이션 (덱 카드가 바닥 카드와 매칭)
  Future<void> kissAnimation() async {
    // 초록 글로우
    _showGlow(Colors.green, duration: 0.4);

    // 살짝 점프
    final jumpUp = MoveEffect.by(
      Vector2(0, -20),
      EffectController(duration: 0.1, curve: Curves.easeOut),
    );
    add(jumpUp);
    await jumpUp.removed;

    final jumpDown = MoveEffect.by(
      Vector2(0, 20),
      EffectController(duration: 0.1, curve: Curves.easeIn),
    );
    add(jumpDown);
    await jumpDown.removed;
  }

  /// 흔들기/폭탄 선언 애니메이션
  Future<void> shakeOrBombAnimation({bool isBomb = false}) async {
    final color = isBomb ? Colors.orange : Colors.purple;
    _showGlow(color, duration: 0.8);

    // 강한 흔들림
    for (int i = 0; i < 5; i++) {
      final intensity = isBomb ? 12.0 : 8.0;

      final shakeRight = MoveEffect.by(
        Vector2(intensity, 0),
        EffectController(duration: 0.03),
      );
      add(shakeRight);
      await shakeRight.removed;

      final shakeLeft = MoveEffect.by(
        Vector2(-intensity * 2, 0),
        EffectController(duration: 0.06),
      );
      add(shakeLeft);
      await shakeLeft.removed;

      final shakeBack = MoveEffect.by(
        Vector2(intensity, 0),
        EffectController(duration: 0.03),
      );
      add(shakeBack);
      await shakeBack.removed;
    }

    if (isBomb) {
      // 폭탄: 스케일 펄스 효과
      final pulse1 = ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(duration: 0.1, curve: Curves.easeOut),
      );
      add(pulse1);
      await pulse1.removed;

      final pulse2 = ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.1, curve: Curves.easeIn),
      );
      add(pulse2);
      await pulse2.removed;
    }
  }

  /// 따닥 애니메이션 (2쌍 매칭)
  Future<void> ttadakAnimation() async {
    _showGlow(Colors.cyan, duration: 0.5);

    // 빠른 2회 점프
    for (int i = 0; i < 2; i++) {
      final jumpUp = MoveEffect.by(
        Vector2(0, -15),
        EffectController(duration: 0.08, curve: Curves.easeOut),
      );
      add(jumpUp);
      await jumpUp.removed;

      final jumpDown = MoveEffect.by(
        Vector2(0, 15),
        EffectController(duration: 0.08, curve: Curves.easeIn),
      );
      add(jumpDown);
      await jumpDown.removed;
    }
  }

  /// 설사 애니메이션 (3장 매칭)
  Future<void> sulsaAnimation() async {
    _showGlow(Colors.pink, duration: 0.6);

    // 회전하며 확대
    final scaleUp = ScaleEffect.to(
      Vector2.all(1.25),
      EffectController(duration: 0.2, curve: Curves.easeOut),
    );
    final rotate = RotateEffect.by(
      math.pi / 4,
      EffectController(duration: 0.2, curve: Curves.easeOut),
    );
    add(scaleUp);
    add(rotate);
    await scaleUp.removed;

    // 원래대로
    final scaleDown = ScaleEffect.to(
      Vector2.all(1.0),
      EffectController(duration: 0.15, curve: Curves.easeIn),
    );
    final rotateBack = RotateEffect.to(
      0,
      EffectController(duration: 0.15, curve: Curves.easeIn),
    );
    add(scaleDown);
    add(rotateBack);
    await scaleDown.removed;
  }

  /// Go 선언 애니메이션
  Future<void> goAnimation() async {
    _showGlow(Colors.blue, duration: 0.4);

    // 위로 살짝 튀어오름
    final jump = MoveEffect.by(
      Vector2(0, -10),
      EffectController(duration: 0.1, curve: Curves.easeOut),
    );
    add(jump);
    await jump.removed;

    final fall = MoveEffect.by(
      Vector2(0, 10),
      EffectController(duration: 0.1, curve: Curves.bounceOut),
    );
    add(fall);
    await fall.removed;
  }

  /// 승리 애니메이션 (카드가 반짝이며 떠오름)
  Future<void> victoryAnimation({double delay = 0.0}) async {
    if (delay > 0) {
      await Future.delayed(Duration(milliseconds: (delay * 1000).toInt()));
    }

    _showGlow(Colors.amber, duration: 1.5);

    // 떠오르며 반짝임
    final rise = MoveEffect.by(
      Vector2(0, -30),
      EffectController(
        duration: 0.8,
        curve: Curves.easeOutCubic,
        reverseDuration: 0.8,
        infinite: true,
      ),
    );
    add(rise);

    // 살짝 회전
    final wobble = RotateEffect.by(
      0.1,
      EffectController(
        duration: 0.5,
        reverseDuration: 0.5,
        infinite: true,
      ),
    );
    add(wobble);
  }

  /// 글로우 효과 표시
  void _showGlow(Color color, {double duration = 0.5}) {
    if (_glowEffect == null) return;

    // 수동 페이드 인/아웃 애니메이션
    _animateGlow(color, duration);
  }

  /// 글로우 애니메이션 (수동 opacity 관리)
  Future<void> _animateGlow(Color color, double duration) async {
    if (_glowEffect == null) return;

    final fadeInDuration = duration * 0.3;
    final holdDuration = duration * 0.4;
    final fadeOutDuration = duration * 0.3;

    // 페이드 인
    final fadeInSteps = (fadeInDuration * 60).toInt();
    for (int i = 0; i <= fadeInSteps; i++) {
      if (_glowEffect == null || !_glowEffect!.isMounted) return;
      final alpha = (i / fadeInSteps) * 0.6;
      _glowEffect!.paint.color = color.withValues(alpha: alpha);
      await Future.delayed(Duration(milliseconds: (fadeInDuration * 1000 / fadeInSteps).toInt()));
    }

    // 유지
    await Future.delayed(Duration(milliseconds: (holdDuration * 1000).toInt()));

    // 페이드 아웃
    final fadeOutSteps = (fadeOutDuration * 60).toInt();
    for (int i = fadeOutSteps; i >= 0; i--) {
      if (_glowEffect == null || !_glowEffect!.isMounted) return;
      final alpha = (i / fadeOutSteps) * 0.6;
      _glowEffect!.paint.color = color.withValues(alpha: alpha);
      await Future.delayed(Duration(milliseconds: (fadeOutDuration * 1000 / fadeOutSteps).toInt()));
    }
  }

  /// 카드 사라지기 애니메이션
  Future<void> fadeOutAnimation({double duration = 0.3}) async {
    final scaleDown = ScaleEffect.to(
      Vector2.all(0.5),
      EffectController(duration: duration, curve: Curves.easeIn),
    );

    add(scaleDown);

    // 수동 opacity 애니메이션
    final steps = (duration * 60).toInt();
    final stepDuration = duration / steps;
    for (int i = steps; i >= 0; i--) {
      if (!isMounted) return;
      opacity = i / steps;
      await Future.delayed(Duration(milliseconds: (stepDuration * 1000).toInt()));
    }
  }

  /// 카드 나타나기 애니메이션
  Future<void> fadeInAnimation({double duration = 0.3, double delay = 0.0}) async {
    opacity = 0;
    scale = Vector2.all(0.5);

    if (delay > 0) {
      await Future.delayed(Duration(milliseconds: (delay * 1000).toInt()));
    }

    final scaleUp = ScaleEffect.to(
      Vector2.all(1.0),
      EffectController(duration: duration, curve: Curves.easeOutBack),
    );

    add(scaleUp);

    // 수동 opacity 애니메이션
    final steps = (duration * 60).toInt();
    final stepDuration = duration / steps;
    for (int i = 0; i <= steps; i++) {
      if (!isMounted) return;
      opacity = i / steps;
      await Future.delayed(Duration(milliseconds: (stepDuration * 1000).toInt()));
    }
  }

  /// 카드 강조 펄스 애니메이션 (내 턴 표시 등)
  void startPulseAnimation() {
    final pulse = ScaleEffect.to(
      Vector2.all(1.05),
      EffectController(
        duration: 0.5,
        reverseDuration: 0.5,
        infinite: true,
        curve: Curves.easeInOut,
      ),
    );
    add(pulse);
  }

  /// 모든 이펙트 중지
  void stopAllEffects() {
    removeWhere((component) => component is Effect);
    scale = Vector2.all(1.0);
    angle = 0;
    _highlightBorder?.opacity = 0;
    if (_glowEffect != null) {
      _glowEffect!.opacity = 0;
    }
  }
}
