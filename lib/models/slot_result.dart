/// 슬롯머신 결과 타입
enum SlotResultType {
  jackpot,     // 특별월 3매치 (1,3,8,11,12월 - 광 카드)
  tripleMatch, // 일반월 3매치
  doubleMatch, // 2매치
  noMatch,     // 꽝
}

/// 슬롯머신 결과 모델
class SlotResult {
  final List<int> reels;         // [month1, month2, month3] (1-12)
  final SlotResultType type;
  final double multiplier;
  final int reward;
  final int betAmount;

  const SlotResult({
    required this.reels,
    required this.type,
    required this.multiplier,
    required this.reward,
    required this.betAmount,
  });

  /// 특별월 (광 카드 기반) - 잭팟 대상
  static const Set<int> specialMonths = {1, 3, 8, 11, 12};

  /// 월별 테마 이름
  static const Map<int, String> monthNames = {
    1: '송학',
    2: '매조',
    3: '벚꽃',
    4: '흑싸리',
    5: '난초',
    6: '모란',
    7: '홍싸리',
    8: '공산',
    9: '국진',
    10: '단풍',
    11: '오동',
    12: '비',
  };

  /// 특별월별 잭팟 배당
  static const Map<int, double> jackpotMultipliers = {
    1: 50.0,   // 송학 (광) - 최고 배당
    3: 45.0,   // 벚꽃 (광)
    8: 45.0,   // 공산 (광)
    11: 40.0,  // 오동 (광)
    12: 35.0,  // 비 (광)
  };

  /// 결과가 잭팟인지
  bool get isJackpot => type == SlotResultType.jackpot;

  /// 결과가 당첨인지 (꽝 제외)
  bool get isWin => type != SlotResultType.noMatch;

  /// 결과 타입에 따른 한글 설명
  String get resultDescription {
    switch (type) {
      case SlotResultType.jackpot:
        final month = reels.first;
        return '🎉 잭팟! ${monthNames[month]} 3매치!';
      case SlotResultType.tripleMatch:
        final month = reels.first;
        return '🎴 ${monthNames[month]} 3매치!';
      case SlotResultType.doubleMatch:
        return '🎯 2매치!';
      case SlotResultType.noMatch:
        return '😢 꽝!';
    }
  }

  /// 결과 메시지 (보상 포함)
  String get resultMessage {
    if (reward > 0) {
      return '$resultDescription +$reward 코인!';
    } else if (reward < 0) {
      return '$resultDescription $reward 코인';
    } else {
      return resultDescription;
    }
  }

  @override
  String toString() {
    return 'SlotResult(reels: $reels, type: $type, multiplier: $multiplier, reward: $reward)';
  }
}
