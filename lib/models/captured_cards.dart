import 'card_data.dart';

/// 플레이어가 먹은 카드들 (타입별로 분류)
class CapturedCards {
  final List<CardData> kwang;   // 광
  final List<CardData> animal;  // 열끗
  final List<CardData> ribbon;  // 띠
  final List<CardData> pi;      // 피

  const CapturedCards({
    this.kwang = const [],
    this.animal = const [],
    this.ribbon = const [],
    this.pi = const [],
  });

  /// 전체 먹은 카드 수
  int get totalCount => kwang.length + animal.length + ribbon.length + pi.length;

  /// 모든 먹은 카드 목록 (디버그용)
  List<CardData> get allCards => [...kwang, ...animal, ...ribbon, ...pi];

  /// 피 장수 계산 (쌍피, 보너스피는 2장으로 계산)
  int get piCount {
    int count = 0;
    for (final card in pi) {
      count += card.piCount;
    }
    return count;
  }

  Map<String, dynamic> toJson() {
    return {
      'kwang': kwang.map((c) => c.toJson()).toList(),
      'animal': animal.map((c) => c.toJson()).toList(),
      'ribbon': ribbon.map((c) => c.toJson()).toList(),
      'pi': pi.map((c) => c.toJson()).toList(),
    };
  }

  factory CapturedCards.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CapturedCards();

    return CapturedCards(
      kwang: _parseCardList(json['kwang']),
      animal: _parseCardList(json['animal']),
      ribbon: _parseCardList(json['ribbon']),
      pi: _parseCardList(json['pi']),
    );
  }

  static List<CardData> _parseCardList(dynamic list) {
    if (list == null) return [];
    return (list as List)
        .map((e) => CardData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  CapturedCards copyWith({
    List<CardData>? kwang,
    List<CardData>? animal,
    List<CardData>? ribbon,
    List<CardData>? pi,
  }) {
    return CapturedCards(
      kwang: kwang ?? this.kwang,
      animal: animal ?? this.animal,
      ribbon: ribbon ?? this.ribbon,
      pi: pi ?? this.pi,
    );
  }

  /// 카드 추가
  CapturedCards addCard(CardData card) {
    switch (card.type) {
      case CardType.kwang:
        return copyWith(kwang: [...kwang, card]);
      case CardType.animal:
        return copyWith(animal: [...animal, card]);
      case CardType.ribbon:
        return copyWith(ribbon: [...ribbon, card]);
      case CardType.pi:
      case CardType.doublePi:
      case CardType.bonusPi:
        return copyWith(pi: [...pi, card]);
    }
  }

  /// 여러 카드 추가
  CapturedCards addCards(List<CardData> cards) {
    var result = this;
    for (final card in cards) {
      result = result.addCard(card);
    }
    return result;
  }

  /// 피 카드 제거 (피 뺏기용)
  /// 일반 피부터 먼저 제거, 없으면 쌍피/보너스피 제거
  (CapturedCards, CardData?) removePi() {
    if (pi.isEmpty) return (this, null);

    // 일반 피 우선 제거
    final normalPi = pi.where((c) => c.type == CardType.pi).toList();
    if (normalPi.isNotEmpty) {
      final toRemove = normalPi.first;
      return (copyWith(pi: pi.where((c) => c.id != toRemove.id).toList()), toRemove);
    }

    // 쌍피/보너스피 제거
    final toRemove = pi.first;
    return (copyWith(pi: pi.where((c) => c.id != toRemove.id).toList()), toRemove);
  }
}
