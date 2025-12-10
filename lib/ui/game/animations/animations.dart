/// 카드 애니메이션 시스템
///
/// 물리 기반의 생동감 넘치는 카드 이동 애니메이션을 제공합니다.
///
/// 주요 시나리오:
/// - 시나리오 A: 손패 → 바닥 (패 내기)
/// - 시나리오 B: 덱 → 뒤집기 → 바닥
/// - 시나리오 C: 바닥 → 획득 영역 (패 가져오기)
///
/// 사용 예시:
/// ```dart
/// // 컨트롤러 생성
/// final animationController = CardAnimationController();
///
/// // 초기화 (State의 initState에서)
/// animationController.initialize(this); // TickerProviderStateMixin 필요
///
/// // 카드 내기 애니메이션
/// await animationController.animatePlayCard(
///   card: selectedCard,
///   from: handCardPosition,
///   to: floorPosition,
/// );
///
/// // 덱에서 뒤집기 애니메이션
/// await animationController.animateFlipFromDeck(
///   card: drawnCard,
///   deckPosition: deckCenter,
///   floorPosition: targetFloorPosition,
/// );
///
/// // 카드 획득 애니메이션
/// await animationController.animateCollectCards(
///   cards: matchedCards,
///   fromPositions: cardPositions,
///   toPosition: captureZonePosition,
///   bonusCount: 2, // optional
/// );
/// ```
library;

export 'card_journey.dart';
export 'card_animator.dart';
export 'card_animation_controller.dart';
export 'animated_card_overlay.dart';
