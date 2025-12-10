import '../../models/card_data.dart';
import '../../models/captured_cards.dart';
import '../../config/constants.dart';

/// 점수 상세 내역
class ScoreDetail {
  final String name;
  final int points;
  final String description;

  const ScoreDetail({
    required this.name,
    required this.points,
    required this.description,
  });
}

/// 점수 계산 결과
class ScoreResult {
  final int kwangScore;
  final int animalScore;
  final int ribbonScore;
  final int piScore;
  final int godoriBonus;      // 고도리 보너스
  final int hongdanBonus;     // 홍단 보너스
  final int cheongdanBonus;   // 청단 보너스
  final int chodanBonus;      // 초단 보너스
  final List<ScoreDetail> details;  // 상세 점수 내역

  const ScoreResult({
    this.kwangScore = 0,
    this.animalScore = 0,
    this.ribbonScore = 0,
    this.piScore = 0,
    this.godoriBonus = 0,
    this.hongdanBonus = 0,
    this.cheongdanBonus = 0,
    this.chodanBonus = 0,
    this.details = const [],
  });

  /// 기본 점수 합계 (배수 적용 전)
  int get baseTotal =>
      kwangScore + animalScore + ribbonScore + piScore +
      godoriBonus + hongdanBonus + cheongdanBonus + chodanBonus;

  /// Go/Stop 선언 가능 여부 (7점 이상)
  bool get canDeclareGoStop => baseTotal >= GameConstants.goStopThreshold;
}

/// 최종 점수 계산 결과 (배수 적용 후)
class FinalScoreResult {
  final ScoreResult baseScore;
  final int goCount;           // 고 횟수
  final int goMultiplier;      // 고 배수 (고 1회=2배, 2회=4배, 3회+=1배씩 추가)
  final bool isPiBak;          // 피박 (상대 피 9장 이하)
  final bool isGwangBak;       // 광박 (상대 광 0장)
  final bool isMeongTtarigi;   // 멍따리기 (상대 열끗 0장)
  final int playerMultiplier;  // 흔들기/폭탄 배수
  final int finalScore;        // 최종 점수
  final bool isGobak;          // 고박 (상대가 고 선언 후 내가 7점 도달)

  const FinalScoreResult({
    required this.baseScore,
    this.goCount = 0,
    this.goMultiplier = 1,
    this.isPiBak = false,
    this.isGwangBak = false,
    this.isMeongTtarigi = false,
    this.playerMultiplier = 1,
    this.finalScore = 0,
    this.isGobak = false,
  });
}

/// 맞고 점수 계산기
class ScoreCalculator {
  // 월별 카드 속성 정의
  static const List<int> redRibbonMonths = [1, 2, 3];    // 홍단 (송학, 매화, 벚꽃)
  static const List<int> blueRibbonMonths = [6, 9, 10];  // 청단 (모란, 국화, 단풍)
  static const List<int> greenRibbonMonths = [4, 5, 7];  // 초단 (등나무, 창포, 싸리)
  static const List<int> birdMonths = [2, 4, 8];         // 고도리 (매화, 등나무, 공산)
  static const int rainKwangMonth = 11;                   // 비광 (오동)

  /// 점수 계산 (기본)
  static ScoreResult calculateScore(CapturedCards captured) {
    final details = <ScoreDetail>[];

    // 광 점수
    final kwangScore = _calculateKwangScore(captured.kwang);
    if (kwangScore > 0) {
      details.add(ScoreDetail(
        name: '광',
        points: kwangScore,
        description: _getKwangDescription(captured.kwang),
      ));
    }

    // 고도리 점수 (새 3장)
    final godoriBonus = _calculateGodoriBonus(captured.animal);
    if (godoriBonus > 0) {
      details.add(const ScoreDetail(
        name: '고도리',
        points: 5,
        description: '2월, 4월, 8월 열끗 3장',
      ));
    }

    // 열끗 점수 (5장부터 1점씩)
    final animalScore = _calculateAnimalScore(captured.animal);
    if (animalScore > 0) {
      details.add(ScoreDetail(
        name: '열끗',
        points: animalScore,
        description: '${captured.animal.length}장 (5장+${captured.animal.length - 5})',
      ));
    }

    // 홍단 점수 (1, 2, 3월 띠)
    final hongdanBonus = _calculateHongdanBonus(captured.ribbon);
    if (hongdanBonus > 0) {
      details.add(const ScoreDetail(
        name: '홍단',
        points: 3,
        description: '1월, 2월, 3월 띠 3장',
      ));
    }

    // 청단 점수 (6, 9, 10월 띠)
    final cheongdanBonus = _calculateCheongdanBonus(captured.ribbon);
    if (cheongdanBonus > 0) {
      details.add(const ScoreDetail(
        name: '청단',
        points: 3,
        description: '6월, 9월, 10월 띠 3장',
      ));
    }

    // 초단 점수 (4, 5, 7월 띠)
    final chodanBonus = _calculateChodanBonus(captured.ribbon);
    if (chodanBonus > 0) {
      details.add(const ScoreDetail(
        name: '초단',
        points: 3,
        description: '4월, 5월, 7월 띠 3장',
      ));
    }

    // 띠 점수 (5장부터 1점씩)
    final ribbonScore = _calculateRibbonScore(captured.ribbon);
    if (ribbonScore > 0) {
      details.add(ScoreDetail(
        name: '띠',
        points: ribbonScore,
        description: '${captured.ribbon.length}장 (5장+${captured.ribbon.length - 5})',
      ));
    }

    // 피 점수 (10장부터 1점씩)
    final piScore = _calculatePiScore(captured);
    if (piScore > 0) {
      details.add(ScoreDetail(
        name: '피',
        points: piScore,
        description: '${captured.piCount}장 (10장+${captured.piCount - 10})',
      ));
    }

    return ScoreResult(
      kwangScore: kwangScore,
      animalScore: animalScore,
      ribbonScore: ribbonScore,
      piScore: piScore,
      godoriBonus: godoriBonus,
      hongdanBonus: hongdanBonus,
      cheongdanBonus: cheongdanBonus,
      chodanBonus: chodanBonus,
      details: details,
    );
  }

  /// 최종 점수 계산 (배수 적용)
  static FinalScoreResult calculateFinalScore({
    required CapturedCards myCaptures,
    required CapturedCards opponentCaptures,
    required int goCount,
    required int playerMultiplier,
    bool isGobak = false,  // 고박 여부 (상대가 고를 선언한 후 내가 7점 도달)
  }) {
    final baseScore = calculateScore(myCaptures);

    // 고 배수 계산
    final goMultiplier = _calculateGoMultiplier(goCount);

    // 박 규칙 체크
    final isPiBak = opponentCaptures.piCount < 10;  // 피 10장 미만
    final isGwangBak = opponentCaptures.kwang.isEmpty;  // 광 0장
    final isMeongTtarigi = opponentCaptures.animal.isEmpty;  // 열끗 0장

    // 배수 계산
    int totalMultiplier = goMultiplier * playerMultiplier;
    if (isPiBak) totalMultiplier *= 2;
    if (isGwangBak) totalMultiplier *= 2;
    if (isMeongTtarigi) totalMultiplier *= 2;
    if (isGobak) totalMultiplier *= 2;  // 고박 2배

    final finalScore = baseScore.baseTotal * totalMultiplier;

    return FinalScoreResult(
      baseScore: baseScore,
      goCount: goCount,
      goMultiplier: goMultiplier,
      isPiBak: isPiBak,
      isGwangBak: isGwangBak,
      isMeongTtarigi: isMeongTtarigi,
      playerMultiplier: playerMultiplier,
      finalScore: finalScore,
      isGobak: isGobak,
    );
  }

  /// 고 배수 계산
  static int _calculateGoMultiplier(int goCount) {
    if (goCount == 0) return 1;
    if (goCount == 1) return 2;      // 원고: 2배
    if (goCount == 2) return 4;      // 이고: 4배
    return 4 + (goCount - 2);        // 삼고 이상: 4배 + 1배씩 추가
  }

  /// 광 점수 계산
  static int _calculateKwangScore(List<CardData> kwangCards) {
    final count = kwangCards.length;
    final hasRainKwang = kwangCards.any((c) => c.month == rainKwangMonth);

    if (count >= 5) return 15;      // 오광
    if (count == 4) return 4;       // 사광
    if (count == 3) {
      if (hasRainKwang) return 2;   // 비광 포함 삼광
      return 3;                      // 삼광
    }
    return 0;
  }

  /// 광 설명 텍스트
  static String _getKwangDescription(List<CardData> kwangCards) {
    final count = kwangCards.length;
    final hasRainKwang = kwangCards.any((c) => c.month == rainKwangMonth);

    if (count >= 5) return '오광 (광 5장)';
    if (count == 4) return '사광 (광 4장)';
    if (count == 3) {
      if (hasRainKwang) return '비광 삼광 (비광 포함 3장)';
      return '삼광 (광 3장)';
    }
    return '';
  }

  /// 고도리 보너스 계산 (2, 4, 8월 열끗)
  static int _calculateGodoriBonus(List<CardData> animalCards) {
    final birdCards = animalCards.where((c) => birdMonths.contains(c.month)).toList();
    return birdCards.length >= 3 ? 5 : 0;
  }

  /// 열끗 점수 계산 (5장부터 1점씩)
  static int _calculateAnimalScore(List<CardData> animalCards) {
    final count = animalCards.length;
    if (count >= 5) return count - 4;
    return 0;
  }

  /// 홍단 보너스 계산 (1, 2, 3월 띠)
  static int _calculateHongdanBonus(List<CardData> ribbonCards) {
    final redRibbons = ribbonCards.where((c) => redRibbonMonths.contains(c.month)).toList();
    return redRibbons.length >= 3 ? 3 : 0;
  }

  /// 청단 보너스 계산 (6, 9, 10월 띠)
  static int _calculateCheongdanBonus(List<CardData> ribbonCards) {
    final blueRibbons = ribbonCards.where((c) => blueRibbonMonths.contains(c.month)).toList();
    return blueRibbons.length >= 3 ? 3 : 0;
  }

  /// 초단 보너스 계산 (4, 5, 7월 띠)
  static int _calculateChodanBonus(List<CardData> ribbonCards) {
    final greenRibbons = ribbonCards.where((c) => greenRibbonMonths.contains(c.month)).toList();
    return greenRibbons.length >= 3 ? 3 : 0;
  }

  /// 띠 점수 계산 (5장부터 1점씩)
  static int _calculateRibbonScore(List<CardData> ribbonCards) {
    final count = ribbonCards.length;
    if (count >= 5) return count - 4;
    return 0;
  }

  /// 피 점수 계산 (10장부터 1점씩, 쌍피/보너스피는 2장으로 계산)
  static int _calculatePiScore(CapturedCards captured) {
    final count = captured.piCount;  // piCount는 쌍피를 2장으로 계산
    if (count >= 10) return count - 9;
    return 0;
  }

  /// Go/Stop 판단 가능 여부 (7점 이상일 때)
  static bool canDeclareGoOrStop(CapturedCards captured) {
    final score = calculateScore(captured);
    return score.canDeclareGoStop;
  }
}
