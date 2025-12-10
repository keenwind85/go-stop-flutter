import 'dart:math';
import '../../models/card_data.dart';
import '../../config/constants.dart';

/// 카드 분배 결과
class DealResult {
  final List<CardData> deck;          // 남은 덱
  final List<CardData> player1Hand;   // 방장 손패
  final List<CardData> player2Hand;   // 게스트 손패
  final List<CardData> floorCards;    // 바닥 패
  final bool player1Chongtong;        // 방장 총통 여부
  final bool player2Chongtong;        // 게스트 총통 여부
  final List<CardData> player1ChongtongCards; // 방장 총통 카드들
  final List<CardData> player2ChongtongCards; // 게스트 총통 카드들
  final List<CardData> bonusFromFloor; // 바닥에서 가져온 보너스 카드 (선공에게)

  const DealResult({
    required this.deck,
    required this.player1Hand,
    required this.player2Hand,
    required this.floorCards,
    this.player1Chongtong = false,
    this.player2Chongtong = false,
    this.player1ChongtongCards = const [],
    this.player2ChongtongCards = const [],
    this.bonusFromFloor = const [],
  });
}

/// 화투 덱 생성 및 분배
class DeckGenerator {
  /// 50장 화투 덱 생성 (48장 + 보너스 피 2장)
  static List<CardData> generateDeck() {
    final deck = <CardData>[];

    // 월별 카드 타입 정의
    // 쌍피: 11월 4번, 12월 4번 (국진이), 그리고 일부 월의 쌍피
    // 실제 화투: 9월, 10월에 쌍피가 있음
    const monthTypes = <int, List<CardType>>{
      1: [CardType.kwang, CardType.ribbon, CardType.ribbon, CardType.pi],
      2: [CardType.animal, CardType.ribbon, CardType.pi, CardType.pi],
      3: [CardType.kwang, CardType.ribbon, CardType.pi, CardType.pi],
      4: [CardType.animal, CardType.ribbon, CardType.pi, CardType.pi],
      5: [CardType.animal, CardType.ribbon, CardType.pi, CardType.pi],
      6: [CardType.animal, CardType.ribbon, CardType.pi, CardType.pi],
      7: [CardType.animal, CardType.ribbon, CardType.pi, CardType.pi],
      8: [CardType.kwang, CardType.animal, CardType.pi, CardType.pi],
      9: [CardType.animal, CardType.ribbon, CardType.doublePi, CardType.pi], // 9월 쌍피
      10: [CardType.animal, CardType.ribbon, CardType.doublePi, CardType.pi], // 10월 쌍피
      11: [CardType.kwang, CardType.animal, CardType.ribbon, CardType.doublePi], // 11월 쌍피
      12: [CardType.kwang, CardType.animal, CardType.ribbon, CardType.doublePi], // 12월 쌍피 (국진이)
    };

    for (int month = 1; month <= 12; month++) {
      final types = monthTypes[month]!;
      for (int i = 0; i < 4; i++) {
        final id = '${month.toString().padLeft(2, '0')}_${i + 1}';
        deck.add(CardData(
          id: id,
          month: month,
          index: i + 1,
          type: types[i],
        ));
      }
    }

    // 보너스 피 2장 추가 (월 = 0, 쌍피로 계산)
    for (int i = 1; i <= 2; i++) {
      deck.add(CardData(
        id: 'bonus_$i',
        month: 0, // 보너스 카드는 월이 없음
        index: i,
        type: CardType.bonusPi,
      ));
    }

    return deck;
  }

  /// 총통 체크 (같은 월 4장이 손에 있는지)
  static int? checkChongtong(List<CardData> hand) {
    final monthCount = <int, int>{};
    for (final card in hand) {
      if (card.month > 0) { // 보너스 카드 제외
        monthCount[card.month] = (monthCount[card.month] ?? 0) + 1;
      }
    }
    for (final entry in monthCount.entries) {
      if (entry.value == 4) {
        return entry.key; // 총통인 월 반환
      }
    }
    return null;
  }

  /// 덱을 섞고 분배 (손패 10장씩, 바닥 8장)
  static DealResult dealCards(List<CardData> deck) {
    final shuffled = List<CardData>.from(deck)..shuffle(Random());

    var player1Hand = <CardData>[];
    var player2Hand = <CardData>[];
    var floorCards = <CardData>[];
    var remainingDeck = <CardData>[];
    final bonusFromFloor = <CardData>[];

    int index = 0;

    // 방장에게 10장
    for (int i = 0; i < GameConstants.cardsPerPlayer; i++) {
      player1Hand.add(shuffled[index++]);
    }

    // 게스트에게 10장
    for (int i = 0; i < GameConstants.cardsPerPlayer; i++) {
      player2Hand.add(shuffled[index++]);
    }

    // 바닥에 8장
    for (int i = 0; i < GameConstants.fieldCardCount; i++) {
      floorCards.add(shuffled[index++]);
    }

    // 나머지는 덱에
    while (index < shuffled.length) {
      remainingDeck.add(shuffled[index++]);
    }

    // 바닥의 보너스 카드는 선공(방장)이 즉시 가져감
    final floorBonusCards = floorCards.where((c) => c.isBonus).toList();
    for (final bonus in floorBonusCards) {
      floorCards.remove(bonus);
      bonusFromFloor.add(bonus);
      // 덱에서 새 카드를 꺼내 바닥에 추가
      if (remainingDeck.isNotEmpty) {
        floorCards.add(remainingDeck.removeAt(0));
      }
    }

    // 총통 체크
    final player1ChongtongMonth = checkChongtong(player1Hand);
    final player2ChongtongMonth = checkChongtong(player2Hand);

    // 총통 카드들 추출
    List<CardData> player1ChongtongCards = [];
    List<CardData> player2ChongtongCards = [];

    if (player1ChongtongMonth != null) {
      player1ChongtongCards = player1Hand
          .where((c) => c.month == player1ChongtongMonth)
          .toList();
    }
    if (player2ChongtongMonth != null) {
      player2ChongtongCards = player2Hand
          .where((c) => c.month == player2ChongtongMonth)
          .toList();
    }

    return DealResult(
      deck: remainingDeck,
      player1Hand: player1Hand,
      player2Hand: player2Hand,
      floorCards: floorCards,
      player1Chongtong: player1ChongtongMonth != null,
      player2Chongtong: player2ChongtongMonth != null,
      player1ChongtongCards: player1ChongtongCards,
      player2ChongtongCards: player2ChongtongCards,
      bonusFromFloor: bonusFromFloor,
    );
  }

  /// 손에 같은 월 3장이 있는지 확인 (흔들기용)
  static List<int> checkShakeable(List<CardData> hand) {
    final result = <int>[];
    final monthCount = <int, int>{};
    for (final card in hand) {
      if (card.month > 0) {
        monthCount[card.month] = (monthCount[card.month] ?? 0) + 1;
      }
    }
    for (final entry in monthCount.entries) {
      if (entry.value >= 3) {
        result.add(entry.key);
      }
    }
    return result;
  }
}
