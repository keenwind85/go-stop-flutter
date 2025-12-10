import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/card_data.dart';
import 'card_journey.dart';

/// 카드 애니메이션 상태 데이터
class CardAnimationState {
  final CardData card;
  final Offset position;
  final double rotation;
  final double scale;
  final double opacity;
  final bool showFront;
  final double flipProgress; // 0.0 = 뒷면, 1.0 = 앞면
  final CardAnimationPhase phase;
  final bool showImpactEffect;

  const CardAnimationState({
    required this.card,
    required this.position,
    this.rotation = 0,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.showFront = true,
    this.flipProgress = 1.0,
    this.phase = CardAnimationPhase.idle,
    this.showImpactEffect = false,
  });

  CardAnimationState copyWith({
    CardData? card,
    Offset? position,
    double? rotation,
    double? scale,
    double? opacity,
    bool? showFront,
    double? flipProgress,
    CardAnimationPhase? phase,
    bool? showImpactEffect,
  }) {
    return CardAnimationState(
      card: card ?? this.card,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      showFront: showFront ?? this.showFront,
      flipProgress: flipProgress ?? this.flipProgress,
      phase: phase ?? this.phase,
      showImpactEffect: showImpactEffect ?? this.showImpactEffect,
    );
  }
}

/// 멀티 카드 애니메이션 상태 (여러 장 동시 이동)
class MultiCardAnimationState {
  final List<CardAnimationState> cards;
  final CardAnimationPhase phase;
  final Offset? gatherPoint; // 모이는 지점

  const MultiCardAnimationState({
    required this.cards,
    this.phase = CardAnimationPhase.idle,
    this.gatherPoint,
  });
}

/// 카드 애니메이터 - 모든 카드 이동 애니메이션 관리
class CardAnimator {
  final TickerProvider vsync;
  final VoidCallback onUpdate;
  final VoidCallback? onImpact; // 착지 시 효과음 콜백
  final VoidCallback? onSweep; // 쓸어담기 효과음 콜백

  // 현재 진행 중인 애니메이션
  final List<_ActiveAnimation> _activeAnimations = [];
  bool _isDisposed = false;

  CardAnimator({
    required this.vsync,
    required this.onUpdate,
    this.onImpact,
    this.onSweep,
  });

  /// 현재 애니메이션 중인 모든 카드 상태
  List<CardAnimationState> get animatingCards =>
      _activeAnimations.expand((a) => a.currentStates).toList();

  /// 애니메이션 진행 중 여부
  bool get isAnimating => _activeAnimations.isNotEmpty;

  /// 시나리오 A: 손패 → 바닥 (패 내기)
  Future<void> playHandToFloor({
    required CardData card,
    required Offset startPosition,
    required Offset endPosition,
    Duration duration = const Duration(milliseconds: 450),
  }) async {
    if (_isDisposed) return;

    final completer = Completer<void>();
    final random = math.Random();
    final targetRotation = (random.nextDouble() - 0.5) * 0.3; // 살짝 기울기

    final controller = AnimationController(
      vsync: vsync,
      duration: duration,
    );

    final animation = _ActiveAnimation(
      controller: controller,
      cards: [card],
      startPositions: [startPosition],
      endPositions: [endPosition],
      type: CardJourneyType.handToFloor,
    );

    // 애니메이션 값 계산
    controller.addListener(() {
      if (_isDisposed) return;

      final t = controller.value;
      final phase = _calculatePhase(t);

      // 포물선 위치 계산
      final position = PhysicsPositionCalculator.calculateParabolicPosition(
        start: startPosition,
        end: endPosition,
        t: Curves.easeOutQuart.transform(t),
        arcHeight: 60 + random.nextDouble() * 20,
      );

      // 회전 계산 (던지는 동안 회전 + 공기 저항으로 감쇠)
      final baseRotation = CardRotationCalculator.calculateDynamicRotation(
        t,
        targetRotation,
      );
      final throwRotation = AirResistanceSimulator.applyDrag(t, baseRotation);

      // 스케일 계산
      double scale;
      if (t < 0.8) {
        scale = CardScaleCalculator.calculateFlightScale(t / 0.8);
      } else {
        scale = CardScaleCalculator.calculateImpactScale((t - 0.8) / 0.2);
      }

      // 착지 효과
      final showImpact = t > 0.85 && t < 0.95;
      if (t > 0.85 && t < 0.87 && onImpact != null) {
        onImpact!();
      }

      animation.currentStates = [
        CardAnimationState(
          card: card,
          position: position,
          rotation: throwRotation,
          scale: scale,
          phase: phase,
          showImpactEffect: showImpact,
        ),
      ];

      onUpdate();
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _activeAnimations.remove(animation);
        controller.dispose();
        if (!completer.isCompleted) {
          completer.complete();
        }
        onUpdate();
      }
    });

    _activeAnimations.add(animation);
    controller.forward();

    return completer.future;
  }

  /// 시나리오 B: 덱 → 뒤집기 → 바닥
  /// 개선: 공중 대기 시간 증가 (300ms → 600ms), 목적지로 던지기 애니메이션 분리
  Future<void> playDeckFlipToFloor({
    required CardData card,
    required Offset deckPosition,
    required Offset endPosition,
    Duration flipDuration = const Duration(milliseconds: 400),
    Duration moveDuration = const Duration(milliseconds: 400), // 350→400ms 던지기 시간 증가
    Duration pauseDuration = const Duration(milliseconds: 600), // 300→600ms 카드 확인 시간 증가
  }) async {
    if (_isDisposed) return;

    final completer = Completer<void>();
    final random = math.Random();

    // 중간 위치 (덱 위쪽에서 플립)
    final flipPosition = Offset(
      deckPosition.dx,
      deckPosition.dy - 80,
    );

    // Phase 1: 덱에서 올라오면서 뒤집기
    final flipController = AnimationController(
      vsync: vsync,
      duration: flipDuration,
    );

    final animation = _ActiveAnimation(
      controller: flipController,
      cards: [card],
      startPositions: [deckPosition],
      endPositions: [endPosition],
      type: CardJourneyType.deckFlipToFloor,
    );

    _activeAnimations.add(animation);

    // Phase 1: Flip
    flipController.addListener(() {
      if (_isDisposed) return;

      final t = flipController.value;

      // 위로 올라오는 이동
      final y = deckPosition.dy - 80 * Curves.easeOutCubic.transform(t);
      final position = Offset(deckPosition.dx, y);

      // 3D 플립 회전 (Y축)
      final flipProgress = t;

      // 스케일 (올라오면서 커짐)
      final scale = 1.0 + 0.2 * Curves.easeOut.transform(t);

      animation.currentStates = [
        CardAnimationState(
          card: card,
          position: position,
          scale: scale,
          flipProgress: flipProgress,
          showFront: flipProgress > 0.5,
          phase: CardAnimationPhase.flipping,
        ),
      ];

      onUpdate();
    });

    await flipController.forward();

    // Pause
    await Future.delayed(pauseDuration);

    if (_isDisposed) {
      flipController.dispose();
      return;
    }

    // Phase 2: 바닥으로 이동
    final moveController = AnimationController(
      vsync: vsync,
      duration: moveDuration,
    );

    animation.controller.dispose();
    animation.controller = moveController;

    final targetRotation = (random.nextDouble() - 0.5) * 0.2;

    moveController.addListener(() {
      if (_isDisposed) return;

      final t = moveController.value;

      // 개선된 포물선 이동: 더 높고 자연스러운 "던지기" 궤적
      // 거리에 비례하여 arcHeight 동적 계산
      final distance = (endPosition - flipPosition).distance;
      final dynamicArcHeight = 60 + distance * 0.15; // 거리가 멀수록 더 높은 포물선

      final position = PhysicsPositionCalculator.calculateParabolicPosition(
        start: flipPosition,
        end: endPosition,
        t: Curves.easeOutQuart.transform(t),
        arcHeight: dynamicArcHeight,
      );

      // 회전: 던지는 동안 더 역동적인 회전 + 공기 저항으로 감쇠
      final baseRotation = CardRotationCalculator.calculateDynamicRotation(
        t,
        targetRotation * 1.5, // 회전 강도 증가
      );
      final throwRotation = AirResistanceSimulator.applyDrag(t, baseRotation);

      // 스케일: 날아가는 동안 약간 커졌다가 착지 시 정상화
      double scale;
      if (t < 0.3) {
        // 날아가기 시작: 약간 커짐
        scale = 1.2 + 0.1 * Curves.easeOut.transform(t / 0.3);
      } else if (t < 0.8) {
        // 비행 중: 점점 작아짐
        scale = 1.3 - 0.3 * ((t - 0.3) / 0.5);
      } else {
        // 착지 충격
        scale = CardScaleCalculator.calculateImpactScale((t - 0.8) / 0.2);
      }

      final showImpact = t > 0.85 && t < 0.95;
      if (t > 0.85 && t < 0.87 && onImpact != null) {
        onImpact!();
      }

      animation.currentStates = [
        CardAnimationState(
          card: card,
          position: position,
          rotation: throwRotation,
          scale: scale,
          phase: t < 0.85 ? CardAnimationPhase.throwing : CardAnimationPhase.impact,
          showImpactEffect: showImpact,
        ),
      ];

      onUpdate();
    });

    moveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _activeAnimations.remove(animation);
        moveController.dispose();
        if (!completer.isCompleted) {
          completer.complete();
        }
        onUpdate();
      }
    });

    moveController.forward();

    return completer.future;
  }

  /// 시나리오 C: 바닥 → 획득 영역 (패 가져오기)
  Future<void> playFloorToCapture({
    required List<CardData> cards,
    required List<Offset> startPositions,
    required Offset endPosition,
    Duration gatherDuration = const Duration(milliseconds: 200),
    Duration sweepDuration = const Duration(milliseconds: 350),
  }) async {
    if (_isDisposed) return;
    if (cards.isEmpty) return;
    if (startPositions.isEmpty) return;

    final completer = Completer<void>();

    // startPositions 길이를 cards 길이에 맞춤 (방어적 코딩)
    // 부족한 위치는 마지막 위치로 채움
    final safePositions = List<Offset>.generate(
      cards.length,
      (i) => i < startPositions.length
          ? startPositions[i]
          : startPositions.last,
    );

    // 중심점 계산 (모이는 지점)
    final centerX = safePositions.map((p) => p.dx).reduce((a, b) => a + b) /
        safePositions.length;
    final centerY = safePositions.map((p) => p.dy).reduce((a, b) => a + b) /
        safePositions.length;
    final gatherPoint = Offset(centerX, centerY);

    // Phase 1: 모으기
    final gatherController = AnimationController(
      vsync: vsync,
      duration: gatherDuration,
    );

    final animation = _ActiveAnimation(
      controller: gatherController,
      cards: cards,
      startPositions: safePositions,
      endPositions: [endPosition],
      type: CardJourneyType.floorToCapture,
    );

    _activeAnimations.add(animation);

    gatherController.addListener(() {
      if (_isDisposed) return;

      final t = Curves.easeOutCubic.transform(gatherController.value);

      animation.currentStates = List.generate(cards.length, (i) {
        final position = Offset.lerp(safePositions[i], gatherPoint, t)!;
        final rotation = (1 - t) * (i - cards.length / 2) * 0.1;

        return CardAnimationState(
          card: cards[i],
          position: position,
          rotation: rotation,
          scale: 1.0 + 0.1 * t, // 모이면서 약간 커짐
          phase: CardAnimationPhase.gathering,
        );
      });

      onUpdate();
    });

    await gatherController.forward();

    if (_isDisposed) {
      gatherController.dispose();
      return;
    }

    // Phase 2: 쓸어담기
    final sweepController = AnimationController(
      vsync: vsync,
      duration: sweepDuration,
    );

    animation.controller.dispose();
    animation.controller = sweepController;

    if (onSweep != null) {
      onSweep!();
    }

    sweepController.addListener(() {
      if (_isDisposed) return;

      // easeInExpo: 점점 빨라지는 커브
      final t = Curves.easeInExpo.transform(sweepController.value);

      // 베지어 곡선으로 휘어지며 이동
      final controlPoint = Offset(
        (gatherPoint.dx + endPosition.dx) / 2,
        gatherPoint.dy - 50,
      );

      final position = PhysicsPositionCalculator.calculateBezierPosition(
        start: gatherPoint,
        end: endPosition,
        t: t,
        controlPoint: controlPoint,
      );

      // 스케일 (점점 작아짐)
      final scale = CardScaleCalculator.calculateCollectScale(t);

      // 투명도 (끝에서 페이드 아웃)
      final opacity = t > 0.8 ? 1.0 - (t - 0.8) / 0.2 : 1.0;

      // 회전 (빠르게 돌면서 이동)
      final rotation = t * math.pi * 2;

      animation.currentStates = List.generate(cards.length, (i) {
        // 각 카드가 약간씩 다른 오프셋으로
        final offset = Offset(
          (i - cards.length / 2) * 3 * (1 - t),
          (i - cards.length / 2) * 2 * (1 - t),
        );

        return CardAnimationState(
          card: cards[i],
          position: position + offset,
          rotation: rotation + i * 0.1,
          scale: scale,
          opacity: opacity,
          phase: CardAnimationPhase.sweeping,
        );
      });

      onUpdate();
    });

    sweepController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _activeAnimations.remove(animation);
        sweepController.dispose();
        if (!completer.isCompleted) {
          completer.complete();
        }
        onUpdate();
      }
    });

    sweepController.forward();

    return completer.future;
  }

  /// 상대방 카드 내기 애니메이션 (위에서 아래로)
  Future<void> playOpponentToFloor({
    required CardData card,
    required Offset startPosition,
    required Offset endPosition,
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    if (_isDisposed) return;

    final completer = Completer<void>();
    final random = math.Random();
    final targetRotation = (random.nextDouble() - 0.5) * 0.3;

    final controller = AnimationController(
      vsync: vsync,
      duration: duration,
    );

    final animation = _ActiveAnimation(
      controller: controller,
      cards: [card],
      startPositions: [startPosition],
      endPositions: [endPosition],
      type: CardJourneyType.opponentToFloor,
    );

    controller.addListener(() {
      if (_isDisposed) return;

      final t = controller.value;

      // 위에서 아래로 포물선
      final position = PhysicsPositionCalculator.calculateParabolicPosition(
        start: startPosition,
        end: endPosition,
        t: Curves.easeOutQuart.transform(t),
        arcHeight: 40,
      );

      // 회전 계산 (공기 저항으로 감쇠)
      final baseRotation = CardRotationCalculator.calculateDynamicRotation(
        t,
        targetRotation,
      );
      final rotation = AirResistanceSimulator.applyDrag(t, baseRotation);

      double scale;
      if (t < 0.8) {
        scale = CardScaleCalculator.calculateFlightScale(t / 0.8);
      } else {
        scale = CardScaleCalculator.calculateImpactScale((t - 0.8) / 0.2);
      }

      final showImpact = t > 0.85 && t < 0.95;
      if (t > 0.85 && t < 0.87 && onImpact != null) {
        onImpact!();
      }

      animation.currentStates = [
        CardAnimationState(
          card: card,
          position: position,
          rotation: rotation,
          scale: scale,
          phase: _calculatePhase(t),
          showImpactEffect: showImpact,
        ),
      ];

      onUpdate();
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _activeAnimations.remove(animation);
        controller.dispose();
        if (!completer.isCompleted) {
          completer.complete();
        }
        onUpdate();
      }
    });

    _activeAnimations.add(animation);
    controller.forward();

    return completer.future;
  }

  /// 진행 중인 모든 애니메이션 취소
  void cancelAll() {
    for (final animation in _activeAnimations) {
      animation.controller.dispose();
    }
    _activeAnimations.clear();
    onUpdate();
  }

  CardAnimationPhase _calculatePhase(double t) {
    if (t < 0.1) return CardAnimationPhase.lift;
    if (t < 0.85) return CardAnimationPhase.throwing;
    if (t < 0.95) return CardAnimationPhase.impact;
    return CardAnimationPhase.completed;
  }

  void dispose() {
    _isDisposed = true;
    cancelAll();
  }
}

/// 활성 애니메이션 추적
class _ActiveAnimation {
  AnimationController controller;
  final List<CardData> cards;
  final List<Offset> startPositions;
  final List<Offset> endPositions;
  final CardJourneyType type;
  List<CardAnimationState> currentStates;

  _ActiveAnimation({
    required this.controller,
    required this.cards,
    required this.startPositions,
    required this.endPositions,
    required this.type,
  }) : currentStates = [];
}
