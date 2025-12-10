import 'package:flame/components.dart';
import '../../models/card_data.dart';
import '../../models/game_room.dart';
import '../components/card_component.dart';

/// 턴 애니메이션 결과
class TurnAnimationResult {
  final List<CardData> capturedCards;
  final SpecialEvent event;
  final bool isPuk;

  const TurnAnimationResult({
    this.capturedCards = const [],
    this.event = SpecialEvent.none,
    this.isPuk = false,
  });
}

/// 턴 흐름 애니메이션 컨트롤러
/// 카드 플레이부터 점수 획득까지의 애니메이션 시퀀스를 관리
class TurnAnimationController extends Component {
  final double animationSpeed;

  TurnAnimationController({this.animationSpeed = 1.0});

  /// 카드 플레이 애니메이션 전체 시퀀스
  /// 1. 손패 카드를 바닥으로 이동
  /// 2. 매칭 여부에 따라 접촉 또는 바닥에 놓기
  /// 3. 덱 카드 뒤집기
  /// 4. 덱 카드 매칭 처리
  /// 5. 획득 카드 점수패로 이동
  Future<TurnAnimationResult> playTurnAnimation({
    required CardComponent handCard,
    required List<CardComponent> matchingFloorCards,
    required CardComponent? deckCard,
    required List<CardComponent> deckMatchingFloorCards,
    required Vector2 floorCenter,
    required Vector2 scorePilePosition,
    required Vector2 deckPosition,
    required Function(SpecialEvent event, Vector2 position)? onSpecialEvent,
  }) async {
    final capturedCards = <CardData>[];
    var event = SpecialEvent.none;

    // === 1단계: 손패 카드 처리 ===
    final handMatched = matchingFloorCards.isNotEmpty;

    if (handMatched) {
      // 바닥패와 짝이 맞음 → 카드들이 접촉
      await _animateCardContact(
        handCard,
        matchingFloorCards,
        floorCenter,
      );
    } else {
      // 바닥패와 짝이 없음 → 바닥에 카드 던지기
      await _animateCardToFloor(handCard, floorCenter);
    }

    // === 2단계: 덱 카드 뒤집기 및 표시 ===
    if (deckCard != null) {
      // 덱에서 카드 뒤집기
      await _animateDeckFlip(deckCard, deckPosition, floorCenter);

      // 약간의 딜레이로 카드 확인 시간 제공
      await Future.delayed(Duration(milliseconds: (400 / animationSpeed).toInt()));

      final deckMatched = deckMatchingFloorCards.isNotEmpty;

      // === 특수 상황 체크 ===

      // 뻑 체크: 손패가 매칭되었고, 덱 카드가 같은 월
      if (handMatched && deckCard.cardData.month == handCard.cardData.month) {
        // 뻑 발생!
        event = SpecialEvent.puk;

        // 뻑 텍스트 표시
        final textPosition = Vector2(
          (handCard.position.x + deckCard.position.x) / 2,
          floorCenter.y - 30,
        );
        onSpecialEvent?.call(event, textPosition);

        // 모든 카드를 바닥에 쌓기
        await _animatePukStack(
          handCard,
          matchingFloorCards.first,
          deckCard,
          floorCenter,
        );

        return TurnAnimationResult(
          event: event,
          isPuk: true,
        );
      }

      // 쪽 체크: 손패가 매칭 안 되었고, 덱 카드가 손패와 같은 월
      if (!handMatched && deckCard.cardData.month == handCard.cardData.month) {
        // 쪽 발생!
        event = SpecialEvent.kiss;

        // 쪽 텍스트 표시
        final textPosition = Vector2(
          (handCard.position.x + deckCard.position.x) / 2,
          floorCenter.y - 30,
        );
        onSpecialEvent?.call(event, textPosition);

        // 카드 접촉 애니메이션
        await _animateKissContact(handCard, deckCard);

        // 2장 획득
        capturedCards.add(handCard.cardData);
        capturedCards.add(deckCard.cardData);

        // 점수패로 이동
        await _animateCapture([handCard, deckCard], scorePilePosition);

        return TurnAnimationResult(
          capturedCards: capturedCards,
          event: event,
        );
      }

      // 따닥 체크: 손패가 매칭되었고, 덱 카드도 다른 바닥패와 매칭
      if (handMatched && deckMatched &&
          deckCard.cardData.month != handCard.cardData.month) {
        // 따닥 발생!
        event = SpecialEvent.ttadak;

        final textPosition = floorCenter - Vector2(0, 30);
        onSpecialEvent?.call(event, textPosition);

        // 덱 카드와 바닥패 접촉
        await _animateCardContact(
          deckCard,
          deckMatchingFloorCards,
          deckCard.position,
        );
      }

      // === 3단계: 덱 카드 처리 ===
      if (deckMatched) {
        // 덱 카드가 바닥패와 매칭
        capturedCards.add(deckCard.cardData);
        for (final fc in deckMatchingFloorCards) {
          capturedCards.add(fc.cardData);
        }
      } else {
        // 덱 카드 매칭 없음 → 바닥에 놓기
        await _animateCardToFloor(deckCard, _getEmptyFloorPosition(floorCenter));
      }
    }

    // === 4단계: 손패 매칭 카드 획득 처리 ===
    if (handMatched) {
      capturedCards.add(handCard.cardData);
      for (final fc in matchingFloorCards) {
        capturedCards.add(fc.cardData);
      }
    }

    // === 5단계: 획득 카드 점수패로 이동 ===
    if (capturedCards.isNotEmpty) {
      final cardsToCapture = <CardComponent>[];

      if (handMatched) {
        cardsToCapture.add(handCard);
        cardsToCapture.addAll(matchingFloorCards);
      }

      if (deckCard != null && deckMatchingFloorCards.isNotEmpty) {
        cardsToCapture.add(deckCard);
        cardsToCapture.addAll(deckMatchingFloorCards);
      }

      await _animateCapture(cardsToCapture, scorePilePosition);
    }

    return TurnAnimationResult(
      capturedCards: capturedCards,
      event: event,
    );
  }

  /// 카드 접촉 애니메이션 (매칭 시)
  Future<void> _animateCardContact(
    CardComponent playedCard,
    List<CardComponent> matchingCards,
    Vector2 targetCenter,
  ) async {
    // 카드들의 중심점 계산
    final centerX = matchingCards.isEmpty
        ? targetCenter.x
        : matchingCards.map((c) => c.position.x).reduce((a, b) => a + b) /
            matchingCards.length;
    final centerY = matchingCards.isEmpty
        ? targetCenter.y
        : matchingCards.map((c) => c.position.y).reduce((a, b) => a + b) /
            matchingCards.length;

    // 플레이 카드를 매칭 카드 위치로 이동
    await playedCard.moveTo(
      Vector2(centerX, centerY - 10),
      duration: 0.25 / animationSpeed,
    );

    // 살짝 겹치는 효과
    for (int i = 0; i < matchingCards.length; i++) {
      matchingCards[i].moveTo(
        Vector2(centerX + (i - matchingCards.length / 2) * 8, centerY + 5),
        duration: 0.15 / animationSpeed,
      );
    }

    await Future.delayed(Duration(milliseconds: (150 / animationSpeed).toInt()));
  }

  /// 카드를 바닥에 던지는 애니메이션 (매칭 실패 시)
  Future<void> _animateCardToFloor(CardComponent card, Vector2 targetPosition) async {
    // 살짝 위로 튀어오르며 이동
    final midPoint = Vector2(
      (card.position.x + targetPosition.x) / 2,
      card.position.y - 30,
    );

    await card.moveTo(midPoint, duration: 0.12 / animationSpeed);
    await card.moveTo(targetPosition, duration: 0.18 / animationSpeed);
  }

  /// 덱 카드 뒤집기 애니메이션
  Future<void> _animateDeckFlip(
    CardComponent deckCard,
    Vector2 deckPosition,
    Vector2 displayPosition,
  ) async {
    // 덱 위치에서 중앙으로 이동
    final showPosition = Vector2(
      displayPosition.x + 50,
      displayPosition.y,
    );

    await deckCard.moveTo(showPosition, duration: 0.2 / animationSpeed);

    // 카드 뒤집기
    await deckCard.flip(showFront: true);
  }

  /// 쪽 접촉 애니메이션
  Future<void> _animateKissContact(
    CardComponent handCard,
    CardComponent deckCard,
  ) async {
    // 두 카드가 만나는 애니메이션
    final meetPoint = Vector2(
      (handCard.position.x + deckCard.position.x) / 2,
      (handCard.position.y + deckCard.position.y) / 2,
    );

    await Future.wait([
      handCard.moveTo(meetPoint - Vector2(10, 0), duration: 0.2 / animationSpeed),
      deckCard.moveTo(meetPoint + Vector2(10, 0), duration: 0.2 / animationSpeed),
    ]);

    // 쪽 이펙트
    await handCard.kissAnimation();
    await deckCard.kissAnimation();
  }

  /// 뻑 카드 쌓기 애니메이션
  Future<void> _animatePukStack(
    CardComponent handCard,
    CardComponent floorCard,
    CardComponent deckCard,
    Vector2 stackPosition,
  ) async {
    // 3장의 카드를 겹쳐서 쌓기
    await Future.wait([
      handCard.moveTo(stackPosition, duration: 0.2 / animationSpeed),
      floorCard.moveTo(stackPosition + Vector2(4, 4), duration: 0.2 / animationSpeed),
      deckCard.moveTo(stackPosition + Vector2(8, 8), duration: 0.2 / animationSpeed),
    ]);

    // 뻑 흔들림 효과
    await handCard.pukAnimation();
    await floorCard.pukAnimation();
    await deckCard.pukAnimation();
  }

  /// 카드 획득 애니메이션
  Future<void> _animateCapture(
    List<CardComponent> cards,
    Vector2 scorePilePosition,
  ) async {
    final futures = <Future>[];

    for (int i = 0; i < cards.length; i++) {
      // 약간의 딜레이로 순차적 효과
      final delay = i * 0.05 / animationSpeed;

      futures.add(Future.delayed(
        Duration(milliseconds: (delay * 1000).toInt()),
        () => cards[i].captureAnimation(
          target: scorePilePosition + Vector2(i * 5, 0),
        ),
      ));
    }

    await Future.wait(futures);
  }

  /// 빈 바닥 위치 계산
  Vector2 _getEmptyFloorPosition(Vector2 center) {
    // 기존 바닥 카드들의 위치를 피해서 빈 공간 찾기
    // 간단히 중앙에서 약간 오프셋된 위치 반환
    return center + Vector2(20, 15);
  }
}
