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
/// 
/// 점수 계산 규칙:
/// 1. 기본 점수 = 광 + 열끗 + 띠 + 피 + 특수 조합(고도리, 홍단, 청단, 초단)
/// 2. 고 보너스: 1고 +1점, 2고 +2점, 3고+ ×2^(고-2)배
/// 3. 흔들기/폭탄: 각 ×2배 (playerMultiplier에 반영)
/// 4. 멍따(열끗 7장+): ×2배 (점수 배수)
/// 
/// 코인 정산 배수 (별도 처리 - CoinService):
/// - 광박(상대 광 0장): ×2 코인
/// - 피박: ×2 코인
/// - 고박: ×2 코인
class FinalScoreResult {
  final ScoreResult baseScore;
  final int goCount;           // 고 횟수
  final int goAdditive;        // 고 추가 점수 (1고=+1, 2고=+2)
  final int goMultiplier;      // 고 배수 (3고+=×2, ×4, ×8...)
  final bool isPiBak;          // 피박 (상대 피 X장 이하) - 코인 정산용
  final bool isGwangBak;       // 광박 (상대 광 0장) - 코인 정산용
  final bool isMeongTta;       // 멍따 (내가 열끗 7장 이상) - 점수 배수
  final int playerMultiplier;  // 흔들기/폭탄 배수
  final int finalScore;        // 최종 점수
  final bool isGobak;          // 고박 - 코인 정산용

  const FinalScoreResult({
    required this.baseScore,
    this.goCount = 0,
    this.goAdditive = 0,
    this.goMultiplier = 1,
    this.isPiBak = false,
    this.isGwangBak = false,
    this.isMeongTta = false,
    this.playerMultiplier = 1,
    this.finalScore = 0,
    this.isGobak = false,
  });
  
  /// 점수에 적용된 총 배수 (고 배수 × 흔들기/폭탄 × 멍따)
  int get totalScoreMultiplier {
    int mult = goMultiplier * playerMultiplier;
    if (isMeongTta) mult *= 2;
    return mult;
  }
  
  /// 코인 정산 시 적용되는 배수 (광박, 피박, 고박)
  int get coinSettlementMultiplier {
    int mult = 1;
    if (isGwangBak) mult *= 2;
    if (isPiBak) mult *= 2;
    if (isGobak) mult *= 2;
    return mult;
  }
}

/// 맞고 점수 계산기
class ScoreCalculator {
  // 월별 카드 속성 정의
  static const List<int> redRibbonMonths = [1, 2, 3];    // 홍단 (송학, 매화, 벚꽃)
  static const List<int> blueRibbonMonths = [6, 9, 10];  // 청단 (모란, 국화, 단풍)
  static const List<int> greenRibbonMonths = [4, 5, 7];  // 초단 (등나무, 창포, 싸리)
  static const List<int> birdMonths = [2, 4, 8];         // 고도리 (매화, 등나무, 공산)
  static const int rainKwangMonth = 12;                   // 비광 (12월 비)

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
  /// 
  /// 새로운 점수 계산 규칙:
  /// 1. 기본 점수 계산
  /// 2. 고 보너스 적용: 1고 +1점, 2고 +2점, 3고+ ×배수
  /// 3. 흔들기/폭탄 배수 적용
  /// 4. 멍따(내 열끗 7장+) ×2 적용
  /// 
  /// 박 규칙은 점수에 적용되지 않고 코인 정산 시에만 적용:
  /// - 광박(상대 광 0장): 코인 ×2
  /// - 피박(상대 피 X장 이하): 코인 ×2
  /// - 고박: 코인 ×2
  static FinalScoreResult calculateFinalScore({
    required CapturedCards myCaptures,
    required CapturedCards opponentCaptures,
    required int goCount,
    required int playerMultiplier,
    bool isGobak = false,  // 고박 여부
    GameMode gameMode = GameMode.matgo,  // 게임 모드 (피박 기준 결정)
  }) {
    final baseScore = calculateScore(myCaptures);

    // 고 보너스 계산 (새로운 규칙)
    final goBonus = calculateGoBonus(goCount);

    // 박 규칙 체크 (코인 정산용으로만 사용)
    final isPiBak = opponentCaptures.piCount <= gameMode.piBakThreshold;
    final isGwangBak = opponentCaptures.kwang.isEmpty;  // 상대 광 0장
    
    // 멍따: 내가 열끗 7장 이상 보유 (점수 ×2)
    final isMeongTta = myCaptures.animal.length >= 7;

    // 점수 배수 계산 (고 배수 × 흔들기/폭탄 × 멍따)
    // 박 규칙은 점수 배수에 포함하지 않음 (코인 정산에서 처리)
    int scoreMultiplier = goBonus.multiplier * playerMultiplier;
    if (isMeongTta) scoreMultiplier *= 2;

    // 최종 점수 = (기본 점수 + 고 추가점) × 배수
    final finalScore = (baseScore.baseTotal + goBonus.additive) * scoreMultiplier;

    return FinalScoreResult(
      baseScore: baseScore,
      goCount: goCount,
      goAdditive: goBonus.additive,
      goMultiplier: goBonus.multiplier,
      isPiBak: isPiBak,
      isGwangBak: isGwangBak,
      isMeongTta: isMeongTta,
      playerMultiplier: playerMultiplier,
      finalScore: finalScore,
      isGobak: isGobak,
    );
  }

  /// 고 점수 계산 (새로운 규칙)
  /// - 1고: 기본점수 + 1점
  /// - 2고: 기본점수 + 2점
  /// - 3고 이상: 기본점수 × 2^(고 횟수 - 2)
  ///   3고=x2, 4고=x4, 5고=x8, 6고=x16, 7고=x32, 8고=x64, 9고=x128, 10고=x256
  static ({int additive, int multiplier}) calculateGoBonus(int goCount) {
    if (goCount == 0) return (additive: 0, multiplier: 1);
    if (goCount == 1) return (additive: 1, multiplier: 1);  // +1점
    if (goCount == 2) return (additive: 2, multiplier: 1);  // +2점
    // 3고 이상: 2^(goCount-2) 배
    // 3고=2^1=2, 4고=2^2=4, 5고=2^3=8, ...
    final multiplier = 1 << (goCount - 2);  // 비트 시프트로 2의 거듭제곱 계산
    return (additive: 0, multiplier: multiplier);
  }

  

  /// 광 점수 계산
  static int _calculateKwangScore(List<CardData> kwangCards) {
    final count = kwangCards.length;
    final hasRainKwang = kwangCards.any((c) => c.month == rainKwangMonth);

    if (count >= 5) return 15;      // 오광
    if (count == 4) return 4;       // 사광
    if (count == 3) {
      if (hasRainKwang) return 2;   // 비광 포함 삼광 (비삼광)
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
      if (hasRainKwang) return '비삼광 (비광 포함 3장)';
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
