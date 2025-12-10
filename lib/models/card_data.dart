/// 화투 카드 타입
enum CardType {
  kwang,  // 광
  animal, // 열끗 (동물)
  ribbon, // 띠
  pi,     // 피
  doublePi, // 쌍피 (2장으로 계산)
  bonusPi,  // 보너스 피 (2장으로 계산)
}

/// 화투 카드 데이터 모델
class CardData {
  final String id;      // 고유 ID (예: "01_1")
  final int month;      // 월 (1-12)
  final int index;      // 해당 월의 카드 인덱스 (1-4)
  final CardType type;  // 카드 타입

  const CardData({
    required this.id,
    required this.month,
    required this.index,
    required this.type,
  });

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': month,
      'index': index,
      'type': type.name,
    };
  }

  /// JSON에서 생성
  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      id: json['id'] as String,
      month: json['month'] as int,
      index: json['index'] as int,
      type: CardType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CardType.pi,
      ),
    );
  }

  /// 이미지 경로 반환
  String get imagePath {
    // 보너스 카드는 별도 경로
    if (type == CardType.bonusPi) {
      return 'cards/bonus_$index.png';
    }
    final monthStr = month.toString().padLeft(2, '0');
    return 'cards/${monthStr}month_$index.png';
  }

  /// 피 장수로 계산 (쌍피, 보너스피는 2장)
  int get piCount {
    if (type == CardType.doublePi || type == CardType.bonusPi) {
      return 2;
    }
    if (type == CardType.pi) {
      return 1;
    }
    return 0;
  }

  /// 보너스 카드인지 확인
  bool get isBonus => type == CardType.bonusPi;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CardData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CardData($id, $month월, $type)';
}
