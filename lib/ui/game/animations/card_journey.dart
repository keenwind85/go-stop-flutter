import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/card_data.dart';

/// 카드 이동 여정 타입
enum CardJourneyType {
  /// 시나리오 A: 손패 → 바닥 (패 내기)
  handToFloor,

  /// 시나리오 B: 덱 → 뒤집기 → 바닥
  deckFlipToFloor,

  /// 시나리오 C: 바닥 → 획득 영역 (패 가져오기)
  floorToCapture,

  /// 상대방 손패 → 바닥 (상대 턴)
  opponentToFloor,

  /// 바닥 → 상대방 획득 영역
  floorToOpponentCapture,
}

/// 카드 애니메이션 상태
enum CardAnimationPhase {
  idle,
  lift,      // 들어올리기
  throwing,  // 던지기 (포물선)
  flipping,  // 뒤집기
  impact,    // 착지 충격
  gathering, // 모으기
  sweeping,  // 쓸어담기
  stacking,  // 쌓기
  completed,
}

/// 카드 여정 데이터
class CardJourneyData {
  final CardData card;
  final CardJourneyType type;
  final Offset startPosition;
  final Offset endPosition;
  final bool showFront;
  final List<CardData>? additionalCards; // 여러 장 동시 이동 시

  const CardJourneyData({
    required this.card,
    required this.type,
    required this.startPosition,
    required this.endPosition,
    this.showFront = true,
    this.additionalCards,
  });

  /// 모든 카드 리스트 (주 카드 + 추가 카드)
  List<CardData> get allCards => [card, ...?additionalCards];

  /// 카드 개수
  int get cardCount => 1 + (additionalCards?.length ?? 0);
}

/// 물리 기반 커브 - 포물선 이동
class ParabolicCurve extends Curve {
  final double height; // 포물선 최고점 높이 비율 (0.0 ~ 1.0)

  const ParabolicCurve({this.height = 0.3});

  @override
  double transformInternal(double t) {
    // 포물선 공식: y = -4h(t - 0.5)^2 + h + t
    // 이동은 선형이지만 수직 오프셋은 포물선
    return t;
  }

  /// 주어진 t에서의 수직 오프셋 계산
  double getVerticalOffset(double t) {
    // 포물선: 0에서 시작, 0.5에서 최대, 1에서 0
    return -4 * height * math.pow(t - 0.5, 2) + height;
  }
}

/// 커스텀 바운스 커브 - 착지 시 탄성
class ImpactBounceCurve extends Curve {
  final double bounceIntensity;
  final int bounceCount;

  const ImpactBounceCurve({
    this.bounceIntensity = 0.3,
    this.bounceCount = 2,
  });

  @override
  double transformInternal(double t) {
    if (t < 0.6) {
      // 빠른 착지 (ease-in)
      return Curves.easeIn.transform(t / 0.6) * 1.0;
    } else {
      // 바운스 효과
      final bounceT = (t - 0.6) / 0.4;
      final decay = math.pow(0.5, bounceT * bounceCount);
      final bounce = math.sin(bounceT * math.pi * bounceCount) * bounceIntensity * decay;
      return 1.0 + bounce;
    }
  }
}

/// 탄성 착지 커브
class ElasticImpactCurve extends Curve {
  @override
  double transformInternal(double t) {
    if (t == 0 || t == 1) return t;

    // 빠른 접근 후 탄성 반동
    if (t < 0.7) {
      return Curves.easeOutCubic.transform(t / 0.7);
    } else {
      final elasticT = (t - 0.7) / 0.3;
      final elastic = math.sin(elasticT * math.pi * 2) * 0.05 * (1 - elasticT);
      return 1.0 + elastic;
    }
  }
}

/// 쓸어담기 커브 - 점점 빨라짐
class SweepCurve extends Curve {
  @override
  double transformInternal(double t) {
    // 처음에는 천천히, 끝으로 갈수록 급가속
    return math.pow(t, 2.5).toDouble();
  }
}

/// 카드 회전 계산 유틸리티
class CardRotationCalculator {
  static final _random = math.Random();

  /// 던지기 중 랜덤 회전값 생성
  static double generateThrowRotation() {
    // -30도 ~ +30도 사이의 랜덤 회전
    return (_random.nextDouble() - 0.5) * math.pi / 3;
  }

  /// 시간에 따른 동적 회전 계산
  static double calculateDynamicRotation(double t, double baseRotation) {
    // 포물선 정점에서 회전이 최대
    final rotationProgress = math.sin(t * math.pi);
    return baseRotation * rotationProgress;
  }

  /// 3D 플립 회전 계산 (Y축 기준)
  static double calculateFlipRotation(double t) {
    // 0 -> π (180도 회전)
    return t * math.pi;
  }
}

/// 물리 기반 위치 계산기
class PhysicsPositionCalculator {
  /// 포물선 경로 계산
  static Offset calculateParabolicPosition({
    required Offset start,
    required Offset end,
    required double t,
    double arcHeight = 80.0,
  }) {
    // 선형 보간 위치
    final linearX = start.dx + (end.dx - start.dx) * t;
    final linearY = start.dy + (end.dy - start.dy) * t;

    // 포물선 오프셋 (위로 볼록)
    final parabolicOffset = -4 * arcHeight * math.pow(t - 0.5, 2) + arcHeight;

    return Offset(linearX, linearY - parabolicOffset);
  }

  /// 베지어 곡선 경로 계산 (더 자연스러운 곡선)
  static Offset calculateBezierPosition({
    required Offset start,
    required Offset end,
    required double t,
    Offset? controlPoint,
  }) {
    // 제어점이 없으면 자동 계산
    final cp = controlPoint ??
        Offset(
          (start.dx + end.dx) / 2,
          math.min(start.dy, end.dy) - 100,
        );

    // 2차 베지어 곡선: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
    final oneMinusT = 1 - t;
    final x = oneMinusT * oneMinusT * start.dx +
        2 * oneMinusT * t * cp.dx +
        t * t * end.dx;
    final y = oneMinusT * oneMinusT * start.dy +
        2 * oneMinusT * t * cp.dy +
        t * t * end.dy;

    return Offset(x, y);
  }

  /// 중력 가속도 시뮬레이션
  static Offset calculateGravityPosition({
    required Offset start,
    required Offset end,
    required double t,
    double gravity = 1500.0, // 픽셀/초²
    double initialVelocityY = -400.0, // 초기 상승 속도
  }) {
    final duration = 0.5; // 기준 시간
    final time = t * duration;

    // 수평 이동 (등속)
    final x = start.dx + (end.dx - start.dx) * t;

    // 수직 이동 (중력 영향)
    // y = y0 + v0*t + 0.5*g*t²
    final y = start.dy + initialVelocityY * time + 0.5 * gravity * time * time;

    // 목표 지점을 넘어가지 않도록 보간
    final targetY = start.dy + (end.dy - start.dy) * t;
    final blendedY = y * (1 - t) + targetY * t;

    return Offset(x, blendedY);
  }
}

/// 스케일 계산기
class CardScaleCalculator {
  /// 비행 중 스케일 (공중에서 약간 크게)
  static double calculateFlightScale(double t) {
    // 0 -> 1.15 -> 1.0 (중간에 최대)
    final scaleBoost = math.sin(t * math.pi) * 0.15;
    return 1.0 + scaleBoost;
  }

  /// 착지 충격 스케일 (탄성 바운스 적용)
  static double calculateImpactScale(double t) {
    if (t < 0.25) {
      // 첫 번째 찌그러짐 (바닥에 닿는 순간)
      return 1.0 - 0.12 * (t / 0.25);
    } else if (t < 0.5) {
      // 첫 번째 바운스 (튀어오름)
      final bounceT = (t - 0.25) / 0.25;
      return 0.88 + 0.18 * math.sin(bounceT * math.pi);
    } else if (t < 0.75) {
      // 두 번째 작은 바운스
      final bounceT = (t - 0.5) / 0.25;
      return 1.0 + 0.06 * math.sin(bounceT * math.pi) * (1 - bounceT);
    } else {
      // 정상화 (감쇠 바운스)
      final settleT = (t - 0.75) / 0.25;
      return 1.0 + 0.02 * math.sin(settleT * math.pi * 2) * (1 - settleT);
    }
  }

  /// 수집 시 스케일 (점점 작아짐)
  static double calculateCollectScale(double t) {
    // 1.0 -> 0.6
    return 1.0 - 0.4 * Curves.easeInQuart.transform(t);
  }
}

/// 공기 저항 시뮬레이터
class AirResistanceSimulator {
  /// 공기 저항에 의한 회전 감쇠 계산
  ///
  /// 카드가 공중을 날아가면서 회전 속도가 점점 줄어드는 효과
  /// t: 0.0 ~ 1.0 (애니메이션 진행도)
  /// baseRotation: 초기 회전값
  static double applyDrag(double t, double baseRotation) {
    // 이차 함수로 감쇠 (처음엔 빠르게, 나중엔 천천히 감소)
    final drag = 1.0 - (0.4 * t * t);
    return baseRotation * drag;
  }

  /// 속도 감쇠 계산 (포물선 이동에 적용)
  ///
  /// 공기 저항으로 인해 수평 이동 속도가 살짝 줄어드는 효과
  static double calculateVelocityDecay(double t) {
    // 선형 감쇠 (약하게 적용)
    return 1.0 - (0.15 * t);
  }
}
