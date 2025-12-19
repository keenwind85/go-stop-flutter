import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_data.dart';
import '../models/game_room.dart';
import '../models/captured_cards.dart';
import '../models/item_data.dart';
import '../game/systems/deck_generator.dart';
import '../game/systems/score_calculator.dart';
import '../config/constants.dart';
import 'room_service.dart';

/// MatgoLogicService Provider
final matgoLogicServiceProvider = Provider<MatgoLogicService>((ref) {
  final roomService = ref.read(roomServiceProvider);
  return MatgoLogicService(roomService);
});

/// 카드 플레이 결과
class PlayResult {
  final List<CardData> capturedCards;     // 획득한 카드들
  final SpecialEvent event;               // 발생한 특수 이벤트
  final int piStolen;                     // 뺏은 피 개수
  final bool needsSelection;              // 2장 매칭 시 선택 필요
  final List<CardData> selectionOptions;  // 선택 가능한 카드들

  const PlayResult({
    this.capturedCards = const [],
    this.event = SpecialEvent.none,
    this.piStolen = 0,
    this.needsSelection = false,
    this.selectionOptions = const [],
  });
}

/// 게임 종료 체크 결과
class GameEndCheckResult {
  final GameEndState endState;
  final String? winner;
  final int finalScore;
  final bool isGobak;  // 고박 여부

  const GameEndCheckResult({
    this.endState = GameEndState.none,
    this.winner,
    this.finalScore = 0,
    this.isGobak = false,
  });
}

/// 선 결정 결과
class FirstTurnResult {
  final String firstPlayerUid;    // 선 플레이어 UID
  final int decidingMonth;        // 결정에 사용된 월
  final String reason;            // 결정 사유 (표시용)
  final bool isRematch;           // 재대결 여부

  const FirstTurnResult({
    required this.firstPlayerUid,
    required this.decidingMonth,
    required this.reason,
    this.isRematch = false,
  });
}

/// 맞고 게임 로직 서비스
/// 턴을 가진 플레이어가 로직을 수행하고 DB를 업데이트
class MatgoLogicService {
  final RoomService _roomService;

  MatgoLogicService(this._roomService);

  /// 덱에서 카드를 뽑는 헬퍼 함수 (光의 기운 효과 적용)
  /// gwangPriorityTurns > 0이면 덱에서 광 카드를 우선 선택
  static CardData _drawFromDeck(List<CardData> deck, int gwangPriorityTurns) {
    if (deck.isEmpty) {
      throw StateError('덱이 비어있습니다');
    }

    if (gwangPriorityTurns > 0) {
      // 덱에서 광 카드 찾기
      final gwangCardIndex = deck.indexWhere(
        (card) => card.type == CardType.kwang,
      );
      if (gwangCardIndex >= 0) {
        print('[MatgoLogicService] 光의 기운 효과 발동! 광 카드 우선 선택: ${deck[gwangCardIndex].id}');
        return deck.removeAt(gwangCardIndex);
      }
    }

    // 광 카드가 없거나 효과가 없으면 첫 번째 카드 반환
    return deck.removeAt(0);
  }

  /// 9월 열끗 카드인지 확인 (09month_1.png)
  /// 9월 열끗은 획득 시 열끗/쌍피 선택 가능
  static bool isSeptemberAnimalCard(CardData card) {
    return card.month == 9 && card.type == CardType.animal;
  }

  /// 획득 카드 목록에서 9월 열끗 찾기
  static CardData? findSeptemberAnimalCard(List<CardData> cards) {
    try {
      return cards.firstWhere((c) => isSeptemberAnimalCard(c));
    } catch (_) {
      return null;
    }
  }

  /// 덱/손패 소진 시 게임 종료 조건 체크
  ///
  /// 규칙 (모드별 승리 점수: 맞고 7점, 고스톱 3점):
  /// 1. 양쪽 모두 승리 점수 미만 + 고 선언자 없음 = 나가리
  /// 2. 고 선언자가 있는 경우:
  ///    - 상대방이 승리 점수 미만 = 고 선언자 자동 승리 (autoWin)
  ///    - 상대방이 승리 점수 이상 = 고박! 상대방 승리 (gobak)
  /// 3. 한 명만 승리 점수 이상 (고 선언자 없음) = 해당 플레이어 승리 (강제 스톱)
  GameEndCheckResult checkGameEndOnExhaustion({
    required int myScore,
    required int opponentScore,
    required int myGoCount,
    required int opponentGoCount,
    required String myUid,
    required String opponentUid,
    required int myMultiplier,
    required int opponentMultiplier,
    required CapturedCards myCaptured,
    required CapturedCards opponentCaptured,
    required GameMode gameMode,
  }) {
    final threshold = gameMode.winThreshold;

    // 고 선언자 확인
    final iHaveGo = myGoCount > 0;
    final opponentHasGo = opponentGoCount > 0;

    // 케이스 1: 내가 고를 선언한 상태
    if (iHaveGo) {
      if (opponentScore >= threshold) {
        // 고박! 상대방이 승리 점수 이상 도달 → 상대방 승리
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: opponentCaptured,
          opponentCaptures: myCaptured,
          goCount: 0,  // 고박당한 쪽은 고 카운트 0
          playerMultiplier: opponentMultiplier,
          isGobak: true,  // 고박 배수 적용
          gameMode: gameMode,
        );
        return GameEndCheckResult(
          endState: GameEndState.gobak,
          winner: opponentUid,
          finalScore: finalResult.finalScore,
          isGobak: true,
        );
      } else {
        // 상대방 승리 점수 미만 → 내가 자동 승리 (강제 스톱)
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: myCaptured,
          opponentCaptures: opponentCaptured,
          goCount: myGoCount,
          playerMultiplier: myMultiplier,
          gameMode: gameMode,
        );
        return GameEndCheckResult(
          endState: GameEndState.autoWin,
          winner: myUid,
          finalScore: finalResult.finalScore,
        );
      }
    }

    // 케이스 2: 상대방이 고를 선언한 상태
    if (opponentHasGo) {
      if (myScore >= threshold) {
        // 고박! 내가 승리 점수 이상 도달 → 내가 승리
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: myCaptured,
          opponentCaptures: opponentCaptured,
          goCount: 0,
          playerMultiplier: myMultiplier,
          isGobak: true,
          gameMode: gameMode,
        );
        return GameEndCheckResult(
          endState: GameEndState.gobak,
          winner: myUid,
          finalScore: finalResult.finalScore,
          isGobak: true,
        );
      } else {
        // 내가 승리 점수 미만 → 상대방 자동 승리
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: opponentCaptured,
          opponentCaptures: myCaptured,
          goCount: opponentGoCount,
          playerMultiplier: opponentMultiplier,
          gameMode: gameMode,
        );
        return GameEndCheckResult(
          endState: GameEndState.autoWin,
          winner: opponentUid,
          finalScore: finalResult.finalScore,
        );
      }
    }

    // 케이스 3: 아무도 고를 선언하지 않은 상태
    if (myScore < threshold && opponentScore < threshold) {
      // 양쪽 모두 승리 점수 미만 = 나가리
      return const GameEndCheckResult(endState: GameEndState.nagari);
    }

    // 케이스 4: 한 명이 승리 점수 이상 (고 없이 덱 소진) - 해당 사람이 강제 스톱
    if (myScore >= threshold) {
      final finalResult = ScoreCalculator.calculateFinalScore(
        myCaptures: myCaptured,
        opponentCaptures: opponentCaptured,
        goCount: 0,
        playerMultiplier: myMultiplier,
        gameMode: gameMode,
      );
      return GameEndCheckResult(
        endState: GameEndState.win,
        winner: myUid,
        finalScore: finalResult.finalScore,
      );
    } else {
      final finalResult = ScoreCalculator.calculateFinalScore(
        myCaptures: opponentCaptured,
        opponentCaptures: myCaptured,
        goCount: 0,
        playerMultiplier: opponentMultiplier,
        gameMode: gameMode,
      );
      return GameEndCheckResult(
        endState: GameEndState.win,
        winner: opponentUid,
        finalScore: finalResult.finalScore,
      );
    }
  }

  /// 3인 고스톱 덱/손패 소진 시 게임 종료 조건 체크
  ///
  /// 3인 고스톱 규칙:
  /// 1. 덱 소진 시 고박 판정 없음
  /// 2. 3명의 점수를 비교하여 가장 높은 사람이 승리
  /// 3. 최고 점수가 동점이면 나가리
  /// 4. 모두 승리 점수(3점) 미만이면 나가리
  GameEndCheckResult checkGameEndOnExhaustion3P({
    required List<({String uid, int score})> playerScores,
    required GameMode gameMode,
  }) {
    final threshold = gameMode.winThreshold;

    // 점수 내림차순 정렬
    final sortedScores = List<({String uid, int score})>.from(playerScores)
      ..sort((a, b) => b.score.compareTo(a.score));

    final highestScore = sortedScores[0].score;
    final secondScore = sortedScores[1].score;

    // 모두 승리 점수 미만이면 나가리
    if (highestScore < threshold) {
      return const GameEndCheckResult(endState: GameEndState.nagari);
    }

    // 1등과 2등이 동점이면 나가리
    if (highestScore == secondScore) {
      return const GameEndCheckResult(endState: GameEndState.nagari);
    }

    // 단독 1등이 승리 점수 이상이면 승리
    final winnerUid = sortedScores[0].uid;
    return GameEndCheckResult(
      endState: GameEndState.win,
      winner: winnerUid,
      finalScore: highestScore,
      isGobak: false,  // 3인 덱 소진 시 고박 없음
    );
  }

  /// 카드 타입 우선순위 반환 (광 > 열끗 > 띠 > 피)
  int _getCardTypePriority(CardType type) {
    switch (type) {
      case CardType.kwang:
        return 4;
      case CardType.animal:
        return 3;
      case CardType.ribbon:
        return 2;
      case CardType.pi:
      case CardType.doublePi:
      case CardType.bonusPi:
        return 1;
    }
  }

  /// 손패에서 가장 높은 월의 카드를 찾음 (월 기준, 동일 월일 경우 카드 타입으로 결정)
  /// 반환: (가장 높은 월, 해당 카드)
  (int, CardData?) _findHighestMonthCard(List<CardData> hand) {
    if (hand.isEmpty) return (0, null);

    // 월 기준 내림차순 정렬 후, 같은 월 내에서는 타입 우선순위로 정렬
    final sortedHand = List<CardData>.from(hand)
      ..sort((a, b) {
        // 먼저 월 비교 (내림차순)
        if (a.month != b.month) {
          return b.month.compareTo(a.month);
        }
        // 같은 월이면 타입 우선순위 비교 (내림차순)
        return _getCardTypePriority(b.type).compareTo(_getCardTypePriority(a.type));
      });

    return (sortedHand.first.month, sortedHand.first);
  }

  /// 선 결정 (첫 게임: 카드 비교, 재대결: 이전 승자)
  FirstTurnResult determineFirstTurn({
    required String hostUid,
    required String guestUid,
    required List<CardData> hostHand,
    required List<CardData> guestHand,
    required int gameCount,
    String? lastWinner,
    required String hostName,
    required String guestName,
  }) {
    // 재대결인 경우 이전 승자가 선
    if (gameCount > 0 && lastWinner != null) {
      final winnerName = lastWinner == hostUid ? hostName : guestName;
      return FirstTurnResult(
        firstPlayerUid: lastWinner,
        decidingMonth: 0,
        reason: '$winnerName님이 이전 판 승자로 선이 되었습니다',
        isRematch: true,
      );
    }

    // 첫 게임: 카드 비교로 선 결정
    final (hostHighestMonth, hostCard) = _findHighestMonthCard(hostHand);
    final (guestHighestMonth, guestCard) = _findHighestMonthCard(guestHand);

    // 월 비교
    if (hostHighestMonth > guestHighestMonth) {
      return FirstTurnResult(
        firstPlayerUid: hostUid,
        decidingMonth: hostHighestMonth,
        reason: '$hostName님이 $hostHighestMonth월 패를 보유하여 선이 되었습니다',
      );
    } else if (guestHighestMonth > hostHighestMonth) {
      return FirstTurnResult(
        firstPlayerUid: guestUid,
        decidingMonth: guestHighestMonth,
        reason: '$guestName님이 $guestHighestMonth월 패를 보유하여 선이 되었습니다',
      );
    }

    // 같은 월인 경우 카드 타입으로 결정 (광 > 열끗 > 띠 > 피)
    if (hostCard != null && guestCard != null) {
      final hostPriority = _getCardTypePriority(hostCard.type);
      final guestPriority = _getCardTypePriority(guestCard.type);

      if (hostPriority > guestPriority) {
        final typeName = _getCardTypeName(hostCard.type);
        return FirstTurnResult(
          firstPlayerUid: hostUid,
          decidingMonth: hostHighestMonth,
          reason: '$hostName님이 $hostHighestMonth월 $typeName을 보유하여 선이 되었습니다',
        );
      } else if (guestPriority > hostPriority) {
        final typeName = _getCardTypeName(guestCard.type);
        return FirstTurnResult(
          firstPlayerUid: guestUid,
          decidingMonth: guestHighestMonth,
          reason: '$guestName님이 $guestHighestMonth월 $typeName을 보유하여 선이 되었습니다',
        );
      }

      // 같은 월, 같은 타입 → 다음으로 높은 월 비교
      // 이미 정렬된 상태에서 첫 번째 카드를 제외하고 다시 비교
      final hostRemaining = hostHand.where((c) => c.month != hostHighestMonth).toList();
      final guestRemaining = guestHand.where((c) => c.month != guestHighestMonth).toList();

      if (hostRemaining.isNotEmpty && guestRemaining.isNotEmpty) {
        final (hostNext, _) = _findHighestMonthCard(hostRemaining);
        final (guestNext, _) = _findHighestMonthCard(guestRemaining);

        if (hostNext > guestNext) {
          return FirstTurnResult(
            firstPlayerUid: hostUid,
            decidingMonth: hostNext,
            reason: '$hostName님이 두 번째로 높은 $hostNext월 패를 보유하여 선이 되었습니다',
          );
        } else if (guestNext > hostNext) {
          return FirstTurnResult(
            firstPlayerUid: guestUid,
            decidingMonth: guestNext,
            reason: '$guestName님이 두 번째로 높은 $guestNext월 패를 보유하여 선이 되었습니다',
          );
        }
      }
    }

    // 완전히 동일한 경우 방장이 선 (기본)
    return FirstTurnResult(
      firstPlayerUid: hostUid,
      decidingMonth: hostHighestMonth,
      reason: '$hostName님이 방장으로 선이 되었습니다',
    );
  }

  /// 선 결정 (고스톱 3인 모드용)
  FirstTurnResult determineFirstTurn3P({
    required String hostUid,
    required String guestUid,
    required String guest2Uid,
    required List<CardData> hostHand,
    required List<CardData> guestHand,
    required List<CardData> guest2Hand,
    required int gameCount,
    String? lastWinner,
    required String hostName,
    required String guestName,
    required String guest2Name,
  }) {
    // 재대결인 경우 이전 승자가 선
    if (gameCount > 0 && lastWinner != null) {
      String winnerName;
      if (lastWinner == hostUid) {
        winnerName = hostName;
      } else if (lastWinner == guestUid) {
        winnerName = guestName;
      } else {
        winnerName = guest2Name;
      }
      return FirstTurnResult(
        firstPlayerUid: lastWinner,
        decidingMonth: 0,
        reason: '$winnerName님이 이전 판 승자로 선이 되었습니다',
        isRematch: true,
      );
    }

    // 첫 게임: 카드 비교로 선 결정 (3명 모두 비교)
    final (hostHighestMonth, hostCard) = _findHighestMonthCard(hostHand);
    final (guestHighestMonth, guestCard) = _findHighestMonthCard(guestHand);
    final (guest2HighestMonth, guest2Card) = _findHighestMonthCard(guest2Hand);

    // 플레이어 정보를 리스트로 관리
    final players = [
      (uid: hostUid, name: hostName, month: hostHighestMonth, card: hostCard, hand: hostHand),
      (uid: guestUid, name: guestName, month: guestHighestMonth, card: guestCard, hand: guestHand),
      (uid: guest2Uid, name: guest2Name, month: guest2HighestMonth, card: guest2Card, hand: guest2Hand),
    ];

    // 가장 높은 월을 가진 플레이어들 찾기
    final maxMonth = [hostHighestMonth, guestHighestMonth, guest2HighestMonth].reduce((a, b) => a > b ? a : b);
    final topPlayers = players.where((p) => p.month == maxMonth).toList();

    if (topPlayers.length == 1) {
      // 한 명만 최고 월 보유
      final winner = topPlayers.first;
      return FirstTurnResult(
        firstPlayerUid: winner.uid,
        decidingMonth: winner.month,
        reason: '${winner.name}님이 ${winner.month}월 패를 보유하여 선이 되었습니다',
      );
    }

    // 같은 월인 경우 카드 타입으로 결정 (광 > 열끗 > 띠 > 피)
    if (topPlayers.every((p) => p.card != null)) {
      final withPriority = topPlayers.map((p) => (
        player: p,
        priority: _getCardTypePriority(p.card!.type),
      )).toList();
      
      final maxPriority = withPriority.map((p) => p.priority).reduce((a, b) => a > b ? a : b);
      final topByType = withPriority.where((p) => p.priority == maxPriority).toList();

      if (topByType.length == 1) {
        final winner = topByType.first.player;
        final typeName = _getCardTypeName(winner.card!.type);
        return FirstTurnResult(
          firstPlayerUid: winner.uid,
          decidingMonth: winner.month,
          reason: '${winner.name}님이 ${winner.month}월 $typeName을 보유하여 선이 되었습니다',
        );
      }

      // 같은 타입인 경우 두 번째로 높은 월 비교
      for (final player in topByType) {
        final remaining = player.player.hand.where((c) => c.month != maxMonth).toList();
        if (remaining.isNotEmpty) {
          final (nextMonth, _) = _findHighestMonthCard(remaining);
          // 두 번째 월도 비교 (단순화: 첫 번째로 더 높은 두 번째 월을 가진 플레이어)
          // 더 정교한 비교가 필요하면 추가 로직 구현
        }
      }
    }

    // 완전히 동일한 경우 방장이 선 (기본)
    return FirstTurnResult(
      firstPlayerUid: hostUid,
      decidingMonth: maxMonth,
      reason: '$hostName님이 방장으로 선이 되었습니다',
    );
  }

  /// 카드 타입 이름 반환
  String _getCardTypeName(CardType type) {
    switch (type) {
      case CardType.kwang:
        return '광';
      case CardType.animal:
        return '열끗';
      case CardType.ribbon:
        return '띠';
      case CardType.pi:
      case CardType.doublePi:
      case CardType.bonusPi:
        return '피';
    }
  }

  /// 다음 턴 플레이어 결정 (2인/3인 모드 지원)
  /// - 2인 모드: 현재 플레이어의 상대방 반환
  /// - 3인 모드: turnOrder 순환 (방장 → 게스트1 → 게스트2 → 방장...)
  String _getNextTurn(List<String> turnOrder, String currentPlayerUid) {
    if (turnOrder.length > 2) {
      // 3인 모드: turnOrder 순환
      final currentIndex = turnOrder.indexOf(currentPlayerUid);
      if (currentIndex == -1) {
        // 예외 상황: 현재 플레이어가 목록에 없으면 첫 번째 플레이어 반환
        return turnOrder.first;
      }
      final nextIndex = (currentIndex + 1) % turnOrder.length;
      return turnOrder[nextIndex];
    }
    // 2인 모드: 현재 플레이어가 아닌 상대방 반환
    return turnOrder.firstWhere(
      (uid) => uid != currentPlayerUid,
      orElse: () => turnOrder.first,
    );
  }

  /// 플레이어별 고 횟수 가져오기
  int _getPlayerGoCount(ScoreInfo scores, int playerNumber) {
    switch (playerNumber) {
      case 1:
        return scores.player1GoCount;
      case 2:
        return scores.player2GoCount;
      case 3:
        return scores.player3GoCount;
      default:
        return 0;
    }
  }

  /// 플레이어별 점수 가져오기
  int _getPlayerScore(ScoreInfo scores, int playerNumber) {
    switch (playerNumber) {
      case 1:
        return scores.player1Score;
      case 2:
        return scores.player2Score;
      case 3:
        return scores.player3Score;
      default:
        return 0;
    }
  }

  /// 플레이어별 배수 가져오기
  int _getPlayerMultiplier(ScoreInfo scores, int playerNumber) {
    switch (playerNumber) {
      case 1:
        return scores.player1Multiplier;
      case 2:
        return scores.player2Multiplier;
      case 3:
        return scores.player3Multiplier;
      default:
        return 1;
    }
  }

  /// 게임 초기화 (방장이 호출)
  /// - 맞고 (2인): hostUid, guestUid 필수
  /// - 고스톱 (3인): guest2Uid, guest2Name 추가 필수
  Future<GameState?> initializeGame({
    required String roomId,
    required String hostUid,
    required String guestUid,
    required String hostName,
    required String guestName,
    String? guest2Uid,      // 고스톱 3인용
    String? guest2Name,     // 고스톱 3인용
    int gameCount = 0,
    String? lastWinner,
    GameMode gameMode = GameMode.matgo,
  }) async {
    final deck = DeckGenerator.generateDeck();
    final dealResult = DeckGenerator.dealCards(deck, gameMode: gameMode);

    // 턴 순서 설정 (고스톱 3인은 방장 → 게스트1 → 게스트2 순환)
    final turnOrder = gameMode == GameMode.gostop && guest2Uid != null
        ? [hostUid, guestUid, guest2Uid]
        : [hostUid, guestUid];

    // 선 결정 (고스톱 3인 모드는 3명 모두 비교)
    final FirstTurnResult firstTurnResult;
    if (gameMode == GameMode.gostop && guest2Uid != null && guest2Name != null) {
      firstTurnResult = determineFirstTurn3P(
        hostUid: hostUid,
        guestUid: guestUid,
        guest2Uid: guest2Uid,
        hostHand: dealResult.player1Hand,
        guestHand: dealResult.player2Hand,
        guest2Hand: dealResult.player3Hand,
        gameCount: gameCount,
        lastWinner: lastWinner,
        hostName: hostName,
        guestName: guestName,
        guest2Name: guest2Name,
      );
    } else {
      firstTurnResult = determineFirstTurn(
        hostUid: hostUid,
        guestUid: guestUid,
        hostHand: dealResult.player1Hand,
        guestHand: dealResult.player2Hand,
        gameCount: gameCount,
        lastWinner: lastWinner,
        hostName: hostName,
        guestName: guestName,
      );
    }

    print('[MatgoLogic] First turn: ${firstTurnResult.firstPlayerUid}, reason: ${firstTurnResult.reason}');

    // 총통 체크 (고스톱 3인 모드에서는 3명 모두 체크)
    final multipleChongtong = [
      dealResult.player1Chongtong,
      dealResult.player2Chongtong,
      dealResult.player3Chongtong,
    ].where((c) => c).length > 1;

    if (multipleChongtong) {
      // 2명 이상 총통 -> 나가리 (모든 총통 카드 표시)
      final allChongtongCards = [
        ...dealResult.player1ChongtongCards,
        ...dealResult.player2ChongtongCards,
        ...dealResult.player3ChongtongCards,
      ];
      final gameState = GameState(
        turn: firstTurnResult.firstPlayerUid,
        deck: dealResult.deck,
        floorCards: dealResult.floorCards,
        player1Hand: dealResult.player1Hand,
        player2Hand: dealResult.player2Hand,
        player3Hand: dealResult.player3Hand,
        player1Captured: const CapturedCards(),
        player2Captured: const CapturedCards(),
        player3Captured: const CapturedCards(),
        scores: const ScoreInfo(),
        endState: GameEndState.nagari,
        lastEvent: SpecialEvent.chongtong,
        lastEventAt: DateTime.now().millisecondsSinceEpoch,
        chongtongCards: allChongtongCards,
        chongtongPlayer: null, // 다수 총통이므로 null
        firstTurnPlayer: firstTurnResult.firstPlayerUid,
        firstTurnDecidingMonth: firstTurnResult.decidingMonth,
        firstTurnReason: firstTurnResult.reason,
        gameMode: gameMode,
        turnOrder: turnOrder,
        currentTurnIndex: turnOrder.indexOf(firstTurnResult.firstPlayerUid),
      );

      await _roomService.updateGameState(roomId: roomId, gameState: gameState);
      await _roomService.startGame(roomId);
      return gameState;
    } else if (dealResult.player1Chongtong) {
      // 방장 총통 승리
      final gameState = GameState(
        turn: firstTurnResult.firstPlayerUid,
        deck: dealResult.deck,
        floorCards: dealResult.floorCards,
        player1Hand: dealResult.player1Hand,
        player2Hand: dealResult.player2Hand,
        player3Hand: dealResult.player3Hand,
        player1Captured: const CapturedCards(),
        player2Captured: const CapturedCards(),
        player3Captured: const CapturedCards(),
        scores: const ScoreInfo(player1Score: GameConstants.chongtongScore),
        endState: GameEndState.chongtong,
        winner: hostUid,
        finalScore: GameConstants.chongtongScore,
        lastEvent: SpecialEvent.chongtong,
        lastEventAt: DateTime.now().millisecondsSinceEpoch,
        chongtongCards: dealResult.player1ChongtongCards,
        chongtongPlayer: hostUid,
        firstTurnPlayer: firstTurnResult.firstPlayerUid,
        firstTurnDecidingMonth: firstTurnResult.decidingMonth,
        firstTurnReason: firstTurnResult.reason,
        gameMode: gameMode,
        turnOrder: turnOrder,
        currentTurnIndex: turnOrder.indexOf(firstTurnResult.firstPlayerUid),
      );

      await _roomService.updateGameState(roomId: roomId, gameState: gameState);
      await _roomService.startGame(roomId);
      return gameState;
    } else if (dealResult.player2Chongtong) {
      // 게스트1 총통 승리
      final gameState = GameState(
        turn: firstTurnResult.firstPlayerUid,
        deck: dealResult.deck,
        floorCards: dealResult.floorCards,
        player1Hand: dealResult.player1Hand,
        player2Hand: dealResult.player2Hand,
        player3Hand: dealResult.player3Hand,
        player1Captured: const CapturedCards(),
        player2Captured: const CapturedCards(),
        player3Captured: const CapturedCards(),
        scores: const ScoreInfo(player2Score: GameConstants.chongtongScore),
        endState: GameEndState.chongtong,
        winner: guestUid,
        finalScore: GameConstants.chongtongScore,
        lastEvent: SpecialEvent.chongtong,
        lastEventAt: DateTime.now().millisecondsSinceEpoch,
        chongtongCards: dealResult.player2ChongtongCards,
        chongtongPlayer: guestUid,
        firstTurnPlayer: firstTurnResult.firstPlayerUid,
        firstTurnDecidingMonth: firstTurnResult.decidingMonth,
        firstTurnReason: firstTurnResult.reason,
        gameMode: gameMode,
        turnOrder: turnOrder,
        currentTurnIndex: turnOrder.indexOf(firstTurnResult.firstPlayerUid),
      );

      await _roomService.updateGameState(roomId: roomId, gameState: gameState);
      await _roomService.startGame(roomId);
      return gameState;
    } else if (dealResult.player3Chongtong && guest2Uid != null) {
      // 게스트2 총통 승리 (고스톱 3인 전용)
      final gameState = GameState(
        turn: firstTurnResult.firstPlayerUid,
        deck: dealResult.deck,
        floorCards: dealResult.floorCards,
        player1Hand: dealResult.player1Hand,
        player2Hand: dealResult.player2Hand,
        player3Hand: dealResult.player3Hand,
        player1Captured: const CapturedCards(),
        player2Captured: const CapturedCards(),
        player3Captured: const CapturedCards(),
        scores: const ScoreInfo(player3Score: GameConstants.chongtongScore),
        endState: GameEndState.chongtong,
        winner: guest2Uid,
        finalScore: GameConstants.chongtongScore,
        lastEvent: SpecialEvent.chongtong,
        lastEventAt: DateTime.now().millisecondsSinceEpoch,
        chongtongCards: dealResult.player3ChongtongCards,
        chongtongPlayer: guest2Uid,
        firstTurnPlayer: firstTurnResult.firstPlayerUid,
        firstTurnDecidingMonth: firstTurnResult.decidingMonth,
        firstTurnReason: firstTurnResult.reason,
        gameMode: gameMode,
        turnOrder: turnOrder,
        currentTurnIndex: turnOrder.indexOf(firstTurnResult.firstPlayerUid),
      );

      await _roomService.updateGameState(roomId: roomId, gameState: gameState);
      await _roomService.startGame(roomId);
      return gameState;
    }

    // 정상 게임 시작
    // 바닥에서 가져온 보너스 카드는 선공 플레이어에게
    var player1Captured = const CapturedCards();
    var player2Captured = const CapturedCards();
    var player3Captured = const CapturedCards();
    
    print('[MatgoLogic] bonusFromFloor: ${dealResult.bonusFromFloor.length}장');
    print('[MatgoLogic] firstTurnPlayer: ${firstTurnResult.firstPlayerUid}');
    print('[MatgoLogic] hostUid: $hostUid, guestUid: $guestUid, guest2Uid: $guest2Uid');
    
    if (dealResult.bonusFromFloor.isNotEmpty) {
      // 선공 플레이어에게 보너스 카드 부여
      if (firstTurnResult.firstPlayerUid == hostUid) {
        player1Captured = player1Captured.addCards(dealResult.bonusFromFloor);
        print('[MatgoLogic] 보너스 카드 ${dealResult.bonusFromFloor.length}장을 player1(host)에게 부여');
      } else if (firstTurnResult.firstPlayerUid == guestUid) {
        player2Captured = player2Captured.addCards(dealResult.bonusFromFloor);
        print('[MatgoLogic] 보너스 카드 ${dealResult.bonusFromFloor.length}장을 player2(guest1)에게 부여');
      } else if (guest2Uid != null && firstTurnResult.firstPlayerUid == guest2Uid) {
        player3Captured = player3Captured.addCards(dealResult.bonusFromFloor);
        print('[MatgoLogic] 보너스 카드 ${dealResult.bonusFromFloor.length}장을 player3(guest2)에게 부여');
      } else {
        print('[MatgoLogic] 경고: 보너스 카드가 있지만 선공 플레이어를 찾을 수 없음!');
      }
    }
    
    print('[MatgoLogic] player1Captured.pi: ${player1Captured.pi.length}장');
    print('[MatgoLogic] player2Captured.pi: ${player2Captured.pi.length}장');
    print('[MatgoLogic] player3Captured.pi: ${player3Captured.pi.length}장');

    final gameState = GameState(
      turn: firstTurnResult.firstPlayerUid,
      deck: dealResult.deck,
      floorCards: dealResult.floorCards,
      player1Hand: dealResult.player1Hand,
      player2Hand: dealResult.player2Hand,
      player3Hand: dealResult.player3Hand,
      player1Captured: player1Captured,
      player2Captured: player2Captured,
      player3Captured: player3Captured,
      scores: const ScoreInfo(),
      firstTurnPlayer: firstTurnResult.firstPlayerUid,
      firstTurnDecidingMonth: firstTurnResult.decidingMonth,
      firstTurnReason: firstTurnResult.reason,
      turnStartTime: DateTime.now().millisecondsSinceEpoch,
      gameMode: gameMode,
      turnOrder: turnOrder,
      currentTurnIndex: turnOrder.indexOf(firstTurnResult.firstPlayerUid),
    );

    await _roomService.updateGameState(roomId: roomId, gameState: gameState);
    await _roomService.startGame(roomId);

    print('[MatgoLogic] Game initialized for room: $roomId, mode: ${gameMode.displayName}');
    return gameState;
  }

  /// 카드 플레이 (내 손에서 카드를 낸다)
  Future<bool> playCard({
    required String roomId,
    required String myUid,
    required String opponentUid,
    required CardData card,
    required int playerNumber,
    CardData? selectedFloorCard,  // 매칭 카드가 2장일 때 선택한 카드
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        // 내 턴인지 확인
        if (current.turn != myUid) {
          print('[MatgoLogic] Not my turn!');
          return current;
        }

        // Go/Stop 대기 중이면 카드 못 냄
        if (current.waitingForGoStop) {
          print('[MatgoLogic] Waiting for Go/Stop decision');
          return current;
        }

        // 덱 카드 선택 대기 중이면 카드 못 냄
        if (current.waitingForDeckSelection) {
          print('[MatgoLogic] Waiting for deck card selection');
          return current;
        }

        // 플레이어별 손패와 획득패 가져오기 (3인 고스톱 지원)
        List<CardData> myHand;
        CapturedCards myCaptured;
        
        switch (playerNumber) {
          case 1:
            myHand = List<CardData>.from(current.player1Hand);
            myCaptured = current.player1Captured;
            break;
          case 2:
            myHand = List<CardData>.from(current.player2Hand);
            myCaptured = current.player2Captured;
            break;
          case 3:
            myHand = List<CardData>.from(current.player3Hand);
            myCaptured = current.player3Captured;
            break;
          default:
            myHand = List<CardData>.from(current.player1Hand);
            myCaptured = current.player1Captured;
        }
        
        // 피 뺏기 대상 (2인: 상대방 1명 / 3인: 상대방 2명 모두)
        final isGostopMode = current.gameMode == GameMode.gostop;
        var opponent1Captured = playerNumber == 1 
            ? current.player2Captured 
            : current.player1Captured;
        // 3인 모드에서 두 번째 상대방 (player3 또는 피 뺏기 대상이 아닌 플레이어)
        var opponent2Captured = isGostopMode
            ? (playerNumber == 3 
                ? current.player2Captured  // player3이면 player2가 두 번째 상대
                : current.player3Captured) // player1/2이면 player3이 두 번째 상대
            : current.player1Captured;  // 2인 모드에서는 사용 안 함
        // 하위 호환성을 위한 opponentCaptured 별칭 (기존 코드에서 사용)
        var opponentCaptured = opponent1Captured;
        var floorCards = List<CardData>.from(current.floorCards);
        var deck = List<CardData>.from(current.deck);
        var pukCards = List<CardData>.from(current.pukCards);
        var pukOwner = current.pukOwner;
        var scores = current.scores;

        // 손패에서 카드 제거
        myHand.removeWhere((c) => c.id == card.id);

        // 발생한 이벤트들
        SpecialEvent event = SpecialEvent.none;
        int piToSteal = 0;

        // 光의 기운 아이템 효과 (덱에서 광 카드 우선 선택)
        // 현재 player3ItemEffects는 지원하지 않음 (3인 게임에서 아이템 미지원)
        final myItemEffects = playerNumber == 1 
            ? current.player1ItemEffects 
            : (playerNumber == 2 ? current.player2ItemEffects : null);
        final gwangPriorityTurns = myItemEffects?.gwangPriorityTurns ?? 0;

        // 바닥에서 같은 월 카드 찾기
        final matchingFloor = floorCards.where((c) => c.month == card.month).toList();

        // 1단계: 패 내기
        List<CardData> firstCapture = [];
        bool firstMatched = false;

        if (matchingFloor.isEmpty) {
          // 매칭 없음 -> 바닥에 놓기
          floorCards.add(card);
        } else if (matchingFloor.length == 1) {
          // 1장 매칭 -> 둘 다 획득
          firstCapture = [card, matchingFloor.first];
          floorCards.removeWhere((c) => c.id == matchingFloor.first.id);
          firstMatched = true;
        } else if (matchingFloor.length == 2) {
          // 2장 매칭 -> 선택한 카드 또는 첫 번째 카드 획득
          final toCapture = selectedFloorCard ?? matchingFloor.first;
          firstCapture = [card, toCapture];
          floorCards.removeWhere((c) => c.id == toCapture.id);
          firstMatched = true;
        } else if (matchingFloor.length == 3) {
          // 3장 매칭 -> 뻑 획득인지 설사인지 구분
          firstCapture = [card, ...matchingFloor];
          for (final c in matchingFloor) {
            floorCards.removeWhere((fc) => fc.id == c.id);
          }
          firstMatched = true;

          // 뻑 카드인지 확인 (pukCards의 모든 ID가 matchingFloor에 포함되는지)
          final isPukCapture = pukCards.isNotEmpty &&
              pukCards.every((pc) => matchingFloor.any((mf) => mf.id == pc.id));

          if (isPukCapture) {
            // 뻑 카드 획득
            if (pukOwner == myUid) {
              // 자뻑: 내가 싼 뻑을 내가 먹음 -> 피 2장 뺏기
              event = SpecialEvent.jaPuk;
              piToSteal += 2;
            } else {
              // 타뻑: 상대가 싼 뻑을 내가 먹음 -> 피 1장 뺏기
              event = SpecialEvent.puk; // 뻑 획득 이벤트
              piToSteal += 1;
            }
            // 뻑 상태 초기화
            pukCards = [];
            pukOwner = null;
          } else {
            // 일반 설사
            event = SpecialEvent.sulsa;
            piToSteal += 1;
          }
        }

        // 2단계: 덱에서 카드 뒤집기
        List<CardData> secondCapture = [];
        CardData? deckCard;

        if (deck.isNotEmpty) {
          deckCard = _drawFromDeck(deck, gwangPriorityTurns);

          // 보너스 카드는 즉시 획득
          if (deckCard.isBonus) {
            myCaptured = myCaptured.addCard(deckCard);
            deckCard = null;
            // 다시 뒤집기
            if (deck.isNotEmpty) {
              deckCard = _drawFromDeck(deck, gwangPriorityTurns);
            }
          }

          if (deckCard != null) {
            final deckMatching = floorCards.where((c) => c.month == deckCard!.month).toList();

            if (deckMatching.isEmpty) {
              // 덱 카드 매칭 없음

              // 뻑 체크: 내 패가 바닥 1장과 맞았는데, 덱 카드도 같은 월
              // (바닥 카드를 이미 firstCapture로 가져갔으므로 deckMatching이 비어있음)
              if (firstMatched && matchingFloor.length == 1 && deckCard.month == card.month) {
                // 뻑! 3장을 바닥에 두고 종료
                floorCards.addAll(firstCapture);
                floorCards.add(deckCard);
                firstCapture = [];
                pukCards = [card, matchingFloor.first, deckCard];
                pukOwner = myUid;
                event = SpecialEvent.puk;
              } else if (!firstMatched && deckCard.month == card.month) {
                // 쪽 체크: 내 패가 안 맞았는데 덱 카드가 내 패와 같은 월
                // 쪽! 2장 획득 + 피 1장 뺏기
                secondCapture = [card, deckCard];
                // 바닥에서 내 카드 제거 (방금 놓았으니)
                floorCards.removeWhere((c) => c.id == card.id);
                event = SpecialEvent.kiss;
                piToSteal += 1;
              } else {
                // 그냥 바닥에 놓기
                floorCards.add(deckCard);
              }
            } else if (deckMatching.length == 1) {
              // 쪽 체크: 내 패가 안 맞아서 바닥에 놓았는데, 덱 카드가 내 패와 같은 월
              // deckMatching.first가 방금 놓은 내 카드인 경우
              if (!firstMatched && deckMatching.first.id == card.id) {
                // 쪽! 2장 획득 + 피 1장 뺏기
                secondCapture = [card, deckCard];
                floorCards.removeWhere((c) => c.id == card.id);
                event = SpecialEvent.kiss;
                piToSteal += 1;
              } else if (firstMatched) {
                // 따닥 체크: 4장 모두 같은 월이어야 함
                //
                // 따닥 정의:
                // - 바닥에 같은 월 2장이 있고
                // - 내가 같은 월 1장을 내서 1장과 매칭
                // - 덱에서 뒤집힌 카드도 같은 월이어서 남은 1장과 매칭
                // → 4장 모두 획득 + 피 1장 뺏기
                //
                // 조건: 내 패(card), 덱 카드(deckCard), 덱 매칭 카드(deckMatching.first) 모두 같은 월

                secondCapture = [deckCard, deckMatching.first];
                floorCards.removeWhere((c) => c.id == deckMatching.first.id);

                // 4장 모두 같은 월인지 확인 (내 패 월 == 덱 카드 월)
                if (card.month == deckCard.month) {
                  event = SpecialEvent.ttadak;
                  piToSteal += 1;
                }
                // 다른 월이면 그냥 2쌍 매칭 (따닥 아님)
              } else {
                // 일반 1장 매칭 (손패 안 맞음, 덱 카드만 맞음)
                secondCapture = [deckCard, deckMatching.first];
                floorCards.removeWhere((c) => c.id == deckMatching.first.id);
              }
            } else if (deckMatching.length == 2) {
              // 덱 카드 2장 매칭 -> 사용자 선택 필요
              // 손패에서 먹은 카드 정보 저장
              CardData? handMatchCard;
              if (firstMatched && firstCapture.length >= 2) {
                handMatchCard = firstCapture[1]; // 손패로 먹은 바닥 카드
              }

              // 현재 상태까지 저장하고 선택 대기 상태로 반환 (3인 고스톱 지원)
              return GameState(
                turn: current.turn,
                deck: deck,
                floorCards: floorCards,
                player1Hand: playerNumber == 1 ? myHand : List<CardData>.from(current.player1Hand),
                player2Hand: playerNumber == 2 ? myHand : List<CardData>.from(current.player2Hand),
                player3Hand: playerNumber == 3 ? myHand : List<CardData>.from(current.player3Hand),
                player1Captured: playerNumber == 1 ? myCaptured : current.player1Captured,
                player2Captured: playerNumber == 2 ? myCaptured : current.player2Captured,
                player3Captured: playerNumber == 3 ? myCaptured : current.player3Captured,
                scores: scores,
                lastEvent: event,
                lastEventPlayer: event != SpecialEvent.none ? myUid : null,
                lastEventAt: event != SpecialEvent.none ? DateTime.now().millisecondsSinceEpoch : null,
                pukCards: pukCards,
                pukOwner: pukOwner,
                waitingForDeckSelection: true,
                deckSelectionPlayer: myUid,
                deckCard: deckCard,
                deckMatchingCards: deckMatching,
                pendingHandCard: card,
                pendingHandMatch: handMatchCard,
                player1ItemEffects: current.player1ItemEffects,
                player2ItemEffects: current.player2ItemEffects,
                lastItemUsed: current.lastItemUsed,
                lastItemUsedBy: current.lastItemUsedBy,
                lastItemUsedAt: current.lastItemUsedAt,
                gameMode: current.gameMode,
                turnOrder: current.turnOrder,
                currentTurnIndex: current.currentTurnIndex,
              );
            } else if (deckMatching.length == 3) {
              // 덱 카드 3장 매칭 (설사)
              secondCapture = [deckCard, ...deckMatching];
              for (final c in deckMatching) {
                floorCards.removeWhere((fc) => fc.id == c.id);
              }
              if (event != SpecialEvent.sulsa) {
                event = SpecialEvent.sulsa;
              }
              piToSteal += 1;
            }
          }
        }

        // 카드 획득
        myCaptured = myCaptured.addCards(firstCapture);
        myCaptured = myCaptured.addCards(secondCapture);

        // 싹쓸이 체크: 턴 종료 시 바닥이 비어있음
        // 싹쓸이는 다른 이벤트(따닥 등)와 동시에 발생할 수 있음
        // 싹쓸이가 더 중요하므로 이벤트를 덮어씀
        if (floorCards.isEmpty && (firstCapture.isNotEmpty || secondCapture.isNotEmpty)) {
          // 따닥 + 싹쓸이인 경우 피 뺏기는 따닥에서 이미 1장 처리됨
          // 싹쓸이 추가 피 뺏기
          piToSteal += 1;
          event = SpecialEvent.sweep;  // 싹쓸이 이벤트로 설정 (따닥보다 우선)
        }

        // 피 뺏기 (3인 모드에서는 두 상대방 모두에게서 뺏음)
        int actualPiStolen = 0;
        List<String> piStolenFromPlayers = [];
        for (int i = 0; i < piToSteal; i++) {
          // 첫 번째 상대방에게서 피 뺏기
          final (newOpponent1, stolenPi1) = opponent1Captured.removePi();
          if (stolenPi1 != null) {
            opponent1Captured = newOpponent1;
            myCaptured = myCaptured.addCard(stolenPi1);
            actualPiStolen++;
            // 첫 번째 상대방 UID 추적
            if (current.turnOrder.length > 1) {
              final opponent1Uid = playerNumber == 1 ? current.turnOrder[1] : current.turnOrder[0];
              if (!piStolenFromPlayers.contains(opponent1Uid)) {
                piStolenFromPlayers.add(opponent1Uid);
              }
            }
          }
          
          // 3인 모드에서는 두 번째 상대방에게서도 피 뺏기
          if (isGostopMode && current.turnOrder.length > 2) {
            final (newOpponent2, stolenPi2) = opponent2Captured.removePi();
            if (stolenPi2 != null) {
              opponent2Captured = newOpponent2;
              myCaptured = myCaptured.addCard(stolenPi2);
              actualPiStolen++;
              // 두 번째 상대방 UID 추적
              final opponent2Uid = playerNumber == 3 ? current.turnOrder[1] : current.turnOrder[2];
              if (!piStolenFromPlayers.contains(opponent2Uid)) {
                piStolenFromPlayers.add(opponent2Uid);
              }
            }
          }
        }
        // 하위 호환성을 위해 opponentCaptured도 업데이트
        opponentCaptured = opponent1Captured;

        // 9월 열끗 선택 체크: 획득 카드 중 9월 열끗이 있으면 선택 대기
        final allCapturedCards = [...firstCapture, ...secondCapture];
        final septemberAnimal = findSeptemberAnimalCard(allCapturedCards);
        if (septemberAnimal != null) {
          print('[MatgoLogic] September animal card detected in playCard, waiting for choice');
          // 현재 상태를 저장하고 9월 열끗 선택 대기 상태로 전환 (3인 고스톱 지원)
          // 피 뺏기 반영된 획득패 계산
          CapturedCards sept1Captured, sept2Captured, sept3Captured;
          if (playerNumber == 1) {
            sept1Captured = myCaptured;
            sept2Captured = opponent1Captured;
            sept3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
          } else if (playerNumber == 2) {
            sept1Captured = opponent1Captured;
            sept2Captured = myCaptured;
            sept3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
          } else {
            sept1Captured = opponent1Captured;
            sept2Captured = isGostopMode ? opponent2Captured : current.player2Captured;
            sept3Captured = myCaptured;
          }
          
          return GameState(
            turn: current.turn, // 턴 유지
            turnStartTime: DateTime.now().millisecondsSinceEpoch,
            deck: deck,
            floorCards: floorCards,
            player1Hand: playerNumber == 1 ? myHand : List<CardData>.from(current.player1Hand),
            player2Hand: playerNumber == 2 ? myHand : List<CardData>.from(current.player2Hand),
            player3Hand: playerNumber == 3 ? myHand : List<CardData>.from(current.player3Hand),
            player1Captured: sept1Captured,
            player2Captured: sept2Captured,
            player3Captured: sept3Captured,
            scores: current.scores,
            lastEvent: event,
            lastEventPlayer: event != SpecialEvent.none ? myUid : null,
            lastEventAt: event != SpecialEvent.none ? DateTime.now().millisecondsSinceEpoch : null,
            pukCards: pukCards,
            pukOwner: pukOwner,
            waitingForSeptemberChoice: true,
            septemberChoicePlayer: myUid,
            pendingSeptemberCard: septemberAnimal,
            player1ItemEffects: current.player1ItemEffects,
            player2ItemEffects: current.player2ItemEffects,
            lastItemUsed: current.lastItemUsed,
            lastItemUsedBy: current.lastItemUsedBy,
            lastItemUsedAt: current.lastItemUsedAt,
            gameMode: current.gameMode,
            turnOrder: current.turnOrder,
            currentTurnIndex: current.currentTurnIndex,
          );
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);
        final opponentScore = ScoreCalculator.calculateScore(opponentCaptured);

        // Go/Stop 체크 (승리 점수 이상이고, 점수가 실제로 올랐을 때만)
        bool waitingForGoStop = false;
        String? goStopPlayer;

        // 현재 플레이어의 고 횟수와 이전 점수 확인
        final myGoCount = _getPlayerGoCount(current.scores, playerNumber);
        final myPrevScore = _getPlayerScore(current.scores, playerNumber);

        if (myScore.baseTotal >= current.gameMode.winThreshold) {
          // 고 선언 전이거나, 고 선언 후 점수가 올랐을 때만 Go/Stop 트리거
          if (myGoCount == 0 || myScore.baseTotal > myPrevScore) {
            waitingForGoStop = true;
            goStopPlayer = myUid;
          }
        }

        // 다음 턴 결정 (Go/Stop 대기 중이면 턴 유지)
        final nextTurn = waitingForGoStop
            ? myUid
            : _getNextTurn(current.turnOrder, myUid);

        // 게임 종료 체크 (덱 소진 시)
        GameEndState endState = GameEndState.none;
        String? winner;
        int finalScore = 0;

        if (deck.isEmpty && myHand.isEmpty && !waitingForGoStop) {
          // 덱과 손패가 모두 소진되었을 때 게임 종료 조건 체크
          final myGoCount = _getPlayerGoCount(scores, playerNumber);
          final opponentGoCount = _getPlayerGoCount(scores, playerNumber == 1 ? 2 : 1);
          final myMultiplier = _getPlayerMultiplier(scores, playerNumber);
          final opponentMultiplier = _getPlayerMultiplier(scores, playerNumber == 1 ? 2 : 1);

          final endResult = checkGameEndOnExhaustion(
            myScore: myScore.baseTotal,
            opponentScore: opponentScore.baseTotal,
            myGoCount: myGoCount,
            opponentGoCount: opponentGoCount,
            myUid: myUid,
            opponentUid: opponentUid,
            myMultiplier: myMultiplier,
            opponentMultiplier: opponentMultiplier,
            myCaptured: myCaptured,
            opponentCaptured: opponentCaptured,
            gameMode: current.gameMode,
          );

          endState = endResult.endState;
          winner = endResult.winner;
          finalScore = endResult.finalScore;
        }

        // 플레이어별 손패 업데이트 (3인 고스톱 지원)
        List<CardData> newPlayer1Hand = playerNumber == 1 ? myHand : List<CardData>.from(current.player1Hand);
        List<CardData> newPlayer2Hand = playerNumber == 2 ? myHand : List<CardData>.from(current.player2Hand);
        List<CardData> newPlayer3Hand = playerNumber == 3 ? myHand : List<CardData>.from(current.player3Hand);
        
        // 플레이어별 획득패 업데이트 (피 뺏기 반영)
        // playerNumber가 현재 플레이어이고, 상대방에게서 피를 뺏었을 경우 반영
        CapturedCards newPlayer1Captured;
        CapturedCards newPlayer2Captured;
        CapturedCards newPlayer3Captured;
        
        if (playerNumber == 1) {
          // player1이 턴: player2, player3에게서 피 뺏음
          newPlayer1Captured = myCaptured;
          newPlayer2Captured = opponent1Captured;  // 첫 번째 상대 (피 뺏김)
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;  // 3인 모드시 두 번째 상대
        } else if (playerNumber == 2) {
          // player2가 턴: player1, player3에게서 피 뺏음
          newPlayer1Captured = opponent1Captured;  // 첫 번째 상대 (피 뺏김)
          newPlayer2Captured = myCaptured;
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;  // 3인 모드시 두 번째 상대
        } else {
          // player3가 턴: player1, player2에게서 피 뺏음
          newPlayer1Captured = opponent1Captured;  // 첫 번째 상대 (피 뺏김)
          newPlayer2Captured = isGostopMode ? opponent2Captured : current.player2Captured;  // 3인 모드시 두 번째 상대
          newPlayer3Captured = myCaptured;
        }

        // 멍따 체크 (열끗 7장 이상)
        final player1HasMeongTta = newPlayer1Captured.animal.length >= 7;
        final player2HasMeongTta = newPlayer2Captured.animal.length >= 7;
        final player3HasMeongTta = newPlayer3Captured.animal.length >= 7;
        
        // 새로 멍따가 된 경우 이벤트 트리거 (기존에 메인 이벤트가 없을 때만)
        final bool wasPlayer1MeongTta = scores.player1MeongTta;
        final bool wasPlayer2MeongTta = scores.player2MeongTta;
        final bool wasPlayer3MeongTta = scores.player3MeongTta;
        
        List<CardData>? meongTtaCardsToShow;
        String? meongTtaPlayerUid;
        
        if (event == SpecialEvent.none) {
          if (playerNumber == 1 && player1HasMeongTta && !wasPlayer1MeongTta) {
            event = SpecialEvent.meongTta;
            meongTtaCardsToShow = newPlayer1Captured.animal;
            meongTtaPlayerUid = myUid;
          } else if (playerNumber == 2 && player2HasMeongTta && !wasPlayer2MeongTta) {
            event = SpecialEvent.meongTta;
            meongTtaCardsToShow = newPlayer2Captured.animal;
            meongTtaPlayerUid = myUid;
          } else if (playerNumber == 3 && player3HasMeongTta && !wasPlayer3MeongTta) {
            event = SpecialEvent.meongTta;
            meongTtaCardsToShow = newPlayer3Captured.animal;
            meongTtaPlayerUid = myUid;
          }
        }

        // 새로운 게임 상태 반환
        return current.copyWith(
          turn: nextTurn,
          currentTurnIndex: current.turnOrder.indexOf(nextTurn),  // 3인 모드 턴 인덱스 업데이트
          turnStartTime: DateTime.now().millisecondsSinceEpoch,  // 턴 타이머 리셋
          deck: deck,
          floorCards: floorCards,
          player1Hand: newPlayer1Hand,
          player2Hand: newPlayer2Hand,
          player3Hand: newPlayer3Hand,
          player1Captured: newPlayer1Captured,
          player2Captured: newPlayer2Captured,
          player3Captured: newPlayer3Captured,
          scores: ScoreInfo(
            player1Score: playerNumber == 1 ? myScore.baseTotal : scores.player1Score,
            player2Score: playerNumber == 2 ? myScore.baseTotal : scores.player2Score,
            player3Score: playerNumber == 3 ? myScore.baseTotal : scores.player3Score,
            player1GoCount: scores.player1GoCount,
            player2GoCount: scores.player2GoCount,
            player3GoCount: scores.player3GoCount,
            player1Multiplier: scores.player1Multiplier,
            player2Multiplier: scores.player2Multiplier,
            player3Multiplier: scores.player3Multiplier,
            player1Shaking: scores.player1Shaking,
            player2Shaking: scores.player2Shaking,
            player3Shaking: scores.player3Shaking,
            player1MeongTta: player1HasMeongTta,
            player2MeongTta: player2HasMeongTta,
            player3MeongTta: player3HasMeongTta,
          ),
          lastEvent: event,
          lastEventPlayer: event != SpecialEvent.none ? myUid : null,
          lastEventAt: event != SpecialEvent.none ? DateTime.now().millisecondsSinceEpoch : null,
          meongTtaCards: meongTtaCardsToShow ?? [],
          meongTtaPlayer: meongTtaPlayerUid,
          pukCards: pukCards,
          pukOwner: pukOwner,
          endState: endState,
          winner: winner,
          finalScore: finalScore,
          isGobak: endState != GameEndState.none ? (endState == GameEndState.gobak) : null,
          waitingForGoStop: waitingForGoStop,
          goStopPlayer: goStopPlayer,
          piStolenCount: actualPiStolen,
          piStolenFromPlayers: piStolenFromPlayers,
        );
      },
    );
  }

  /// 손패 없이 덱만 뒤집기 (손패가 소진된 상태에서 턴 진행)
  ///
  /// 맞고 규칙: 손패가 모두 떨어진 플레이어는 손패를 내지 않고
  /// 덱에서 카드만 뒤집어서 턴을 진행할 수 있음
  Future<bool> flipDeckOnly({
    required String roomId,
    required String myUid,
    required String opponentUid,
    required int playerNumber,
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        // 내 턴인지 확인
        if (current.turn != myUid) {
          print('[MatgoLogic] flipDeckOnly: Not my turn!');
          return current;
        }

        // Go/Stop 대기 중이면 불가
        if (current.waitingForGoStop) {
          print('[MatgoLogic] flipDeckOnly: Waiting for Go/Stop decision');
          return current;
        }

        // 3인 모드 여부 확인
        final isGostopMode = current.gameMode == GameMode.gostop;
        
        // 플레이어별 손패 및 획득패 설정
        List<CardData> myHand;
        CapturedCards myCaptured;
        
        switch (playerNumber) {
          case 1:
            myHand = List<CardData>.from(current.player1Hand);
            myCaptured = current.player1Captured;
            break;
          case 2:
            myHand = List<CardData>.from(current.player2Hand);
            myCaptured = current.player2Captured;
            break;
          case 3:
            myHand = List<CardData>.from(current.player3Hand);
            myCaptured = current.player3Captured;
            break;
          default:
            myHand = List<CardData>.from(current.player1Hand);
            myCaptured = current.player1Captured;
        }

        // 손패가 비어있어야 함
        if (myHand.isNotEmpty) {
          print('[MatgoLogic] flipDeckOnly: Hand is not empty, use playCard instead');
          return current;
        }

        // 피 뺏기 대상 (2인: 상대방 1명 / 3인: 상대방 2명 모두)
        var opponent1Captured = playerNumber == 1 
            ? current.player2Captured 
            : current.player1Captured;
        var opponent2Captured = isGostopMode
            ? (playerNumber == 3 
                ? current.player2Captured 
                : current.player3Captured)
            : current.player1Captured;
        var opponentCaptured = opponent1Captured;
        var floorCards = List<CardData>.from(current.floorCards);
        var deck = List<CardData>.from(current.deck);
        var pukCards = List<CardData>.from(current.pukCards);
        var pukOwner = current.pukOwner;
        var scores = current.scores;

        // 발생한 이벤트들
        SpecialEvent event = SpecialEvent.none;
        int piToSteal = 0;

        // 光의 기운 아이템 효과 (덱에서 광 카드 우선 선택)
        final myItemEffects = switch (playerNumber) {
          1 => current.player1ItemEffects,
          2 => current.player2ItemEffects,
          3 => current.player3ItemEffects,
          _ => current.player1ItemEffects,
        };
        final gwangPriorityTurns = myItemEffects?.gwangPriorityTurns ?? 0;

        // 덱에서 카드 뒤집기
        List<CardData> capture = [];
        CardData? deckCard;

        if (deck.isEmpty) {
          print('[MatgoLogic] flipDeckOnly: Deck is empty');
          return current;
        }

        deckCard = _drawFromDeck(deck, gwangPriorityTurns);

        // 보너스 카드는 즉시 획득
        if (deckCard.isBonus) {
          myCaptured = myCaptured.addCard(deckCard);
          deckCard = null;
          // 다시 뒤집기
          if (deck.isNotEmpty) {
            deckCard = _drawFromDeck(deck, gwangPriorityTurns);
          }
        }

        if (deckCard != null) {
          final deckMatching = floorCards.where((c) => c.month == deckCard!.month).toList();

          if (deckMatching.isEmpty) {
            // 덱 카드 매칭 없음 -> 바닥에 놓기
            floorCards.add(deckCard);
          } else if (deckMatching.length == 1) {
            // 1장 매칭 -> 둘 다 획득
            capture = [deckCard, deckMatching.first];
            floorCards.removeWhere((c) => c.id == deckMatching.first.id);
          } else if (deckMatching.length == 2) {
            // 2장 매칭 -> 첫 번째 카드와 획득
            capture = [deckCard, deckMatching.first];
            floorCards.removeWhere((c) => c.id == deckMatching.first.id);
          } else if (deckMatching.length == 3) {
            // 3장 매칭 -> 뻑 획득인지 설사인지 구분
            capture = [deckCard, ...deckMatching];
            for (final c in deckMatching) {
              floorCards.removeWhere((fc) => fc.id == c.id);
            }

            // 뻑 카드인지 확인
            final isPukCapture = pukCards.isNotEmpty &&
                pukCards.every((pc) => deckMatching.any((mf) => mf.id == pc.id));

            if (isPukCapture) {
              // 뻑 카드 획득
              if (pukOwner == myUid) {
                // 자뻑
                event = SpecialEvent.jaPuk;
                piToSteal += 2;
              } else {
                // 타뻑
                event = SpecialEvent.puk;
                piToSteal += 1;
              }
              pukCards = [];
              pukOwner = null;
            } else {
              // 일반 설사
              event = SpecialEvent.sulsa;
              piToSteal += 1;
            }
          }
        }

        // 카드 획득
        myCaptured = myCaptured.addCards(capture);

        // 싹쓸이 체크
        // 싹쓸이는 다른 이벤트와 동시에 발생할 수 있으므로 덮어씀
        if (floorCards.isEmpty && capture.isNotEmpty) {
          piToSteal += 1;
          event = SpecialEvent.sweep;
        }

        // 피 뺏기 (3인 모드에서는 두 상대방 모두에게서 뺏음)
        int actualPiStolen = 0;
        List<String> piStolenFromPlayers = [];
        for (int i = 0; i < piToSteal; i++) {
          // 첫 번째 상대방에게서 피 뺏기
          final (newOpponent1, stolenPi1) = opponent1Captured.removePi();
          if (stolenPi1 != null) {
            opponent1Captured = newOpponent1;
            myCaptured = myCaptured.addCard(stolenPi1);
            actualPiStolen++;
            if (current.turnOrder.length > 1) {
              final opponent1Uid = playerNumber == 1 ? current.turnOrder[1] : current.turnOrder[0];
              if (!piStolenFromPlayers.contains(opponent1Uid)) {
                piStolenFromPlayers.add(opponent1Uid);
              }
            }
          }
          
          // 3인 모드에서는 두 번째 상대방에게서도 피 뺏기
          if (isGostopMode && current.turnOrder.length > 2) {
            final (newOpponent2, stolenPi2) = opponent2Captured.removePi();
            if (stolenPi2 != null) {
              opponent2Captured = newOpponent2;
              myCaptured = myCaptured.addCard(stolenPi2);
              actualPiStolen++;
              final opponent2Uid = playerNumber == 3 ? current.turnOrder[1] : current.turnOrder[2];
              if (!piStolenFromPlayers.contains(opponent2Uid)) {
                piStolenFromPlayers.add(opponent2Uid);
              }
            }
          }
        }
        opponentCaptured = opponent1Captured;

        // 9월 열끗 선택 체크: 획득 카드 중 9월 열끗이 있으면 선택 대기
        final septemberAnimalFlip = findSeptemberAnimalCard(capture);
        if (septemberAnimalFlip != null) {
          print('[MatgoLogic] September animal card detected in flipDeckOnly, waiting for choice');
          // 피 뺏기 반영된 획득패 계산
          CapturedCards sept1Captured, sept2Captured, sept3Captured;
          if (playerNumber == 1) {
            sept1Captured = myCaptured;
            sept2Captured = opponent1Captured;
            sept3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
          } else if (playerNumber == 2) {
            sept1Captured = opponent1Captured;
            sept2Captured = myCaptured;
            sept3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
          } else {
            sept1Captured = opponent1Captured;
            sept2Captured = isGostopMode ? opponent2Captured : current.player2Captured;
            sept3Captured = myCaptured;
          }
          
          return GameState(
            turn: current.turn,
            turnStartTime: DateTime.now().millisecondsSinceEpoch,
            deck: deck,
            floorCards: floorCards,
            player1Hand: current.player1Hand,
            player2Hand: current.player2Hand,
            player3Hand: current.player3Hand,
            player1Captured: sept1Captured,
            player2Captured: sept2Captured,
            player3Captured: sept3Captured,
            scores: current.scores,
            lastEvent: event,
            lastEventPlayer: event != SpecialEvent.none ? myUid : null,
            lastEventAt: event != SpecialEvent.none ? DateTime.now().millisecondsSinceEpoch : null,
            pukCards: pukCards,
            pukOwner: pukOwner,
            waitingForSeptemberChoice: true,
            septemberChoicePlayer: myUid,
            pendingSeptemberCard: septemberAnimalFlip,
            player1ItemEffects: current.player1ItemEffects,
            player2ItemEffects: current.player2ItemEffects,
            lastItemUsed: current.lastItemUsed,
            lastItemUsedBy: current.lastItemUsedBy,
            lastItemUsedAt: current.lastItemUsedAt,
            gameMode: current.gameMode,
            turnOrder: current.turnOrder,
            currentTurnIndex: current.currentTurnIndex,
          );
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);
        final opponentScore = ScoreCalculator.calculateScore(opponentCaptured);

        // Go/Stop 체크 (승리 점수 이상이고, 점수가 실제로 올랐을 때만)
        bool waitingForGoStop = false;
        String? goStopPlayer;

        // 현재 플레이어의 고 횟수와 이전 점수 확인
        final myGoCountFlip = _getPlayerGoCount(current.scores, playerNumber);
        final myPrevScoreFlip = _getPlayerScore(current.scores, playerNumber);

        if (myScore.baseTotal >= current.gameMode.winThreshold) {
          // 고 선언 전이거나, 고 선언 후 점수가 올랐을 때만 Go/Stop 트리거
          if (myGoCountFlip == 0 || myScore.baseTotal > myPrevScoreFlip) {
            waitingForGoStop = true;
            goStopPlayer = myUid;
          }
        }

        // 다음 턴 결정 (Go/Stop 대기 중이면 턴 유지)
        final nextTurn = waitingForGoStop
            ? myUid
            : _getNextTurn(current.turnOrder, myUid);

        // 게임 종료 체크 (덱 소진 시)
        GameEndState endState = GameEndState.none;
        String? winner;
        int finalScore = 0;

        // 모든 플레이어의 손패가 비었는지 확인
        final allHandsEmpty = current.player1Hand.isEmpty &&
            current.player2Hand.isEmpty &&
            (!isGostopMode || current.player3Hand.isEmpty);

        // 덱 소진 시 게임 종료 체크
        if (deck.isEmpty && allHandsEmpty && !waitingForGoStop) {
          if (isGostopMode) {
            // 3인 고스톱 모드: 점수 비교로 승자 결정 (고박 없음)
            final player1Score = ScoreCalculator.calculateScore(
              playerNumber == 1 ? myCaptured : opponent1Captured
            ).baseTotal;
            final player2Score = ScoreCalculator.calculateScore(
              playerNumber == 2 ? myCaptured : (playerNumber == 1 ? opponent1Captured : opponent2Captured)
            ).baseTotal;
            final player3Score = ScoreCalculator.calculateScore(
              playerNumber == 3 ? myCaptured : opponent2Captured
            ).baseTotal;
            
            final playerScores = [
              (uid: current.turnOrder.isNotEmpty ? current.turnOrder[0] : myUid, score: player1Score),
              (uid: current.turnOrder.length > 1 ? current.turnOrder[1] : opponentUid, score: player2Score),
              (uid: current.turnOrder.length > 2 ? current.turnOrder[2] : '', score: player3Score),
            ];
            
            final endResult = checkGameEndOnExhaustion3P(
              playerScores: playerScores,
              gameMode: current.gameMode,
            );
            
            endState = endResult.endState;
            winner = endResult.winner;
            finalScore = endResult.finalScore;
          } else {
            // 2인 맞고 모드: 기존 로직 (고박 포함)
            final isPlayer1 = playerNumber == 1;
            final opponentScoreResult = ScoreCalculator.calculateScore(opponent1Captured);
            
            final myGoCount = isPlayer1 ? scores.player1GoCount : scores.player2GoCount;
            final opponentGoCount = isPlayer1 ? scores.player2GoCount : scores.player1GoCount;
            final myMultiplier = isPlayer1 ? scores.player1Multiplier : scores.player2Multiplier;
            final opponentMultiplier = isPlayer1 ? scores.player2Multiplier : scores.player1Multiplier;

            final endResult = checkGameEndOnExhaustion(
              myScore: myScore.baseTotal,
              opponentScore: opponentScoreResult.baseTotal,
              myGoCount: myGoCount,
              opponentGoCount: opponentGoCount,
              myUid: myUid,
              opponentUid: opponentUid,
              myMultiplier: myMultiplier,
              opponentMultiplier: opponentMultiplier,
              myCaptured: myCaptured,
              opponentCaptured: opponent1Captured,
              gameMode: current.gameMode,
            );

            endState = endResult.endState;
            winner = endResult.winner;
            finalScore = endResult.finalScore;
          }
        }

        print('[MatgoLogic] flipDeckOnly: 덱 카드 뒤집기 완료 - event: $event, capture: ${capture.length}장');

        // 플레이어별 획득패 업데이트 (피 뺏기 반영)
        CapturedCards newPlayer1Captured, newPlayer2Captured, newPlayer3Captured;
        if (playerNumber == 1) {
          newPlayer1Captured = myCaptured;
          newPlayer2Captured = opponent1Captured;
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
        } else if (playerNumber == 2) {
          newPlayer1Captured = opponent1Captured;
          newPlayer2Captured = myCaptured;
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
        } else {
          newPlayer1Captured = opponent1Captured;
          newPlayer2Captured = isGostopMode ? opponent2Captured : current.player2Captured;
          newPlayer3Captured = myCaptured;
        }

        // 멍따 체크 (열끗 7장 이상)
        final player1HasMeongTta = newPlayer1Captured.animal.length >= 7;
        final player2HasMeongTta = newPlayer2Captured.animal.length >= 7;
        final player3HasMeongTta = newPlayer3Captured.animal.length >= 7;
        
        // 새로 멍따가 된 경우 이벤트 트리거 (기존에 메인 이벤트가 없을 때만)
        final bool wasPlayer1MeongTta = scores.player1MeongTta;
        final bool wasPlayer2MeongTta = scores.player2MeongTta;
        final bool wasPlayer3MeongTta = scores.player3MeongTta;
        
        List<CardData>? meongTtaCardsToShow;
        String? meongTtaPlayerUid;
        
        if (event == SpecialEvent.none) {
          if (playerNumber == 1 && player1HasMeongTta && !wasPlayer1MeongTta) {
            event = SpecialEvent.meongTta;
            meongTtaCardsToShow = newPlayer1Captured.animal;
            meongTtaPlayerUid = myUid;
          } else if (playerNumber == 2 && player2HasMeongTta && !wasPlayer2MeongTta) {
            event = SpecialEvent.meongTta;
            meongTtaCardsToShow = newPlayer2Captured.animal;
            meongTtaPlayerUid = myUid;
          } else if (playerNumber == 3 && player3HasMeongTta && !wasPlayer3MeongTta) {
            event = SpecialEvent.meongTta;
            meongTtaCardsToShow = newPlayer3Captured.animal;
            meongTtaPlayerUid = myUid;
          }
        }

        // 새로운 게임 상태 반환
        return current.copyWith(
          turn: nextTurn,
          currentTurnIndex: current.turnOrder.indexOf(nextTurn),  // 3인 모드 턴 인덱스 업데이트
          turnStartTime: DateTime.now().millisecondsSinceEpoch,  // 턴 타이머 리셋
          deck: deck,
          floorCards: floorCards,
          player1Hand: current.player1Hand,
          player2Hand: current.player2Hand,
          player3Hand: current.player3Hand,
          player1Captured: newPlayer1Captured,
          player2Captured: newPlayer2Captured,
          player3Captured: newPlayer3Captured,
          scores: ScoreInfo(
            player1Score: playerNumber == 1 ? myScore.baseTotal : scores.player1Score,
            player2Score: playerNumber == 2 ? myScore.baseTotal : scores.player2Score,
            player3Score: playerNumber == 3 ? myScore.baseTotal : scores.player3Score,
            player1GoCount: scores.player1GoCount,
            player2GoCount: scores.player2GoCount,
            player3GoCount: scores.player3GoCount,
            player1Multiplier: scores.player1Multiplier,
            player2Multiplier: scores.player2Multiplier,
            player3Multiplier: scores.player3Multiplier,
            player1Shaking: scores.player1Shaking,
            player2Shaking: scores.player2Shaking,
            player3Shaking: scores.player3Shaking,
            player1MeongTta: player1HasMeongTta,
            player2MeongTta: player2HasMeongTta,
            player3MeongTta: player3HasMeongTta,
          ),
          lastEvent: event,
          lastEventPlayer: event != SpecialEvent.none ? myUid : null,
          lastEventAt: event != SpecialEvent.none ? DateTime.now().millisecondsSinceEpoch : null,
          meongTtaCards: meongTtaCardsToShow ?? [],
          meongTtaPlayer: meongTtaPlayerUid,
          pukCards: pukCards,
          pukOwner: pukOwner,
          endState: endState,
          winner: winner,
          finalScore: finalScore,
          isGobak: endState != GameEndState.none ? (endState == GameEndState.gobak) : null,
          waitingForGoStop: waitingForGoStop,
          goStopPlayer: goStopPlayer,
          piStolenCount: actualPiStolen,
          piStolenFromPlayers: piStolenFromPlayers,
        );
      },
    );
  }

  /// Go 선언 (3인 고스톱 모드 지원)
  Future<bool> declareGo({
    required String roomId,
    required String myUid,
    required String opponentUid,
    required int playerNumber,
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        if (current.goStopPlayer != myUid) {
          return current;
        }

        final isGostopMode = current.gameMode == GameMode.gostop;

        // 3인 고스톱 모드 지원: playerNumber에 따라 올바른 고 횟수 선택
        final currentGoCount = switch (playerNumber) {
          1 => current.scores.player1GoCount,
          2 => current.scores.player2GoCount,
          3 => current.scores.player3GoCount,
          _ => current.scores.player1GoCount,
        };
        final newGoCount = currentGoCount + 1;

        // 모든 플레이어 손패가 비었는지 확인 (3인 고스톱 모드 지원)
        final allHandsEmpty = current.player1Hand.isEmpty &&
            current.player2Hand.isEmpty &&
            (!isGostopMode || current.player3Hand.isEmpty);

        // 덱도 비었는지 확인
        final deckEmpty = current.deck.isEmpty;

        // 손패와 덱이 모두 비었으면 더 이상 진행 불가 → 고 선언자 승리
        if (allHandsEmpty && deckEmpty) {
          // 3인 고스톱 모드 지원: playerNumber에 따라 올바른 획득패 선택
          final myCaptured = switch (playerNumber) {
            1 => current.player1Captured,
            2 => current.player2Captured,
            3 => current.player3Captured,
            _ => current.player1Captured,
          };
          // 점수 계산을 위한 대표 상대 획득패 (첫 번째 상대)
          final opponentCaptured = switch (playerNumber) {
            1 => current.player2Captured,
            2 => current.player1Captured,
            3 => current.player1Captured,
            _ => current.player2Captured,
          };

          final playerMultiplier = switch (playerNumber) {
            1 => current.scores.player1Multiplier,
            2 => current.scores.player2Multiplier,
            3 => current.scores.player3Multiplier,
            _ => current.scores.player1Multiplier,
          };

          // 최종 점수 계산 (고 횟수 반영)
          final finalResult = ScoreCalculator.calculateFinalScore(
            myCaptures: myCaptured,
            opponentCaptures: opponentCaptured,
            goCount: newGoCount,
            playerMultiplier: playerMultiplier,
            gameMode: current.gameMode,
          );

          return current.copyWith(
            waitingForGoStop: false,
            clearGoStopPlayer: true,
            scores: current.scores.copyWith(
              player1GoCount: playerNumber == 1 ? newGoCount : null,
              player2GoCount: playerNumber == 2 ? newGoCount : null,
              player3GoCount: playerNumber == 3 ? newGoCount : null,
            ),
            endState: GameEndState.win,
            winner: myUid,
            finalScore: finalResult.finalScore,
          );
        }

        // 정상적인 경우: 턴을 넘기고 게임 계속
        // 3인 고스톱 모드: turnOrder 기반 다음 턴 결정
        final nextTurn = _getNextTurn(current.turnOrder, myUid);
        final nextTurnIndex = current.turnOrder.indexOf(nextTurn);

        return current.copyWith(
          turn: nextTurn,
          currentTurnIndex: nextTurnIndex >= 0 ? nextTurnIndex : current.currentTurnIndex,
          turnStartTime: DateTime.now().millisecondsSinceEpoch,
          waitingForGoStop: false,
          clearGoStopPlayer: true,
          scores: current.scores.copyWith(
            player1GoCount: playerNumber == 1 ? newGoCount : null,
            player2GoCount: playerNumber == 2 ? newGoCount : null,
            player3GoCount: playerNumber == 3 ? newGoCount : null,
          ),
        );
      },
    );
  }

  /// Stop 선언 (게임 종료) - 3인 고스톱 모드 지원
  Future<bool> declareStop({
    required String roomId,
    required String myUid,
    required int playerNumber,
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        if (current.goStopPlayer != myUid) {
          return current;
        }

        // 3인 고스톱 모드 지원: playerNumber에 따라 올바른 획득패 선택
        final myCaptured = switch (playerNumber) {
          1 => current.player1Captured,
          2 => current.player2Captured,
          3 => current.player3Captured,
          _ => current.player1Captured,
        };
        // 점수 계산을 위한 대표 상대 획득패 (첫 번째 상대)
        final opponentCaptured = switch (playerNumber) {
          1 => current.player2Captured,
          2 => current.player1Captured,
          3 => current.player1Captured,
          _ => current.player2Captured,
        };

        // 3인 고스톱 모드 지원: 고 횟수와 플레이어 배수
        final goCount = switch (playerNumber) {
          1 => current.scores.player1GoCount,
          2 => current.scores.player2GoCount,
          3 => current.scores.player3GoCount,
          _ => current.scores.player1GoCount,
        };
        final playerMultiplier = switch (playerNumber) {
          1 => current.scores.player1Multiplier,
          2 => current.scores.player2Multiplier,
          3 => current.scores.player3Multiplier,
          _ => current.scores.player1Multiplier,
        };

        // 상대방 고 횟수 확인 (고박 체크용) - 3인 모드에서는 다른 플레이어들 중 최대 고 횟수
        final opponentGoCount = switch (playerNumber) {
          1 => [current.scores.player2GoCount, current.scores.player3GoCount].reduce((a, b) => a > b ? a : b),
          2 => [current.scores.player1GoCount, current.scores.player3GoCount].reduce((a, b) => a > b ? a : b),
          3 => [current.scores.player1GoCount, current.scores.player2GoCount].reduce((a, b) => a > b ? a : b),
          _ => current.scores.player2GoCount,
        };

        // 고박 여부: 상대방이 고를 선언한 상태에서 내가 스톱으로 역전 승리
        final isGobak = opponentGoCount > 0;

        // 최종 점수 계산 (새 ScoreCalculator 사용)
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: myCaptured,
          opponentCaptures: opponentCaptured,
          goCount: goCount,
          playerMultiplier: playerMultiplier,
          isGobak: isGobak,
          gameMode: current.gameMode,
        );

        return current.copyWith(
          waitingForGoStop: false,
          clearGoStopPlayer: true,
          endState: isGobak ? GameEndState.gobak : GameEndState.win,
          winner: myUid,
          finalScore: finalResult.finalScore,
          isGobak: isGobak,
        );
      },
    );
  }

  /// 덱 카드 선택 완료 (더미 패 뒤집기 시 2장 매칭 선택)
  /// 2인/3인 모드 모두 지원
  Future<bool> selectDeckMatchCard({
    required String roomId,
    required String myUid,
    required String opponentUid,  // 2인 모드에서 사용, 3인 모드에서는 turnOrder로 대체
    required int playerNumber,
    required CardData selectedFloorCard,  // 선택한 바닥 카드
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        // 덱 선택 대기 중인지 확인
        if (!current.waitingForDeckSelection || current.deckSelectionPlayer != myUid) {
          print('[MatgoLogic] Not waiting for deck selection');
          return current;
        }

        final deckCard = current.deckCard;
        if (deckCard == null) {
          print('[MatgoLogic] No deck card to process');
          return current;
        }

        // 3인 고스톱 모드 여부 확인
        final isGostopMode = current.gameMode == GameMode.gostop;

        // 플레이어별 획득패 설정 (3인 모드 지원)
        var myCaptured = switch (playerNumber) {
          1 => current.player1Captured,
          2 => current.player2Captured,
          3 => current.player3Captured,
          _ => current.player1Captured,
        };

        // 상대방 획득패 설정 (피 뺏기용)
        var opponent1Captured = playerNumber == 1
            ? current.player2Captured
            : current.player1Captured;
        var opponent2Captured = isGostopMode
            ? (playerNumber == 3
                ? current.player2Captured
                : current.player3Captured)
            : const CapturedCards();

        var floorCards = List<CardData>.from(current.floorCards);
        var scores = current.scores;

        // 손패로 먹은 카드 처리 (firstCapture)
        List<CardData> firstCapture = [];
        bool firstMatched = false;
        if (current.pendingHandCard != null && current.pendingHandMatch != null) {
          firstCapture = [current.pendingHandCard!, current.pendingHandMatch!];
          firstMatched = true;
        }

        // 덱 카드로 선택한 바닥 카드 획득 (secondCapture)
        List<CardData> secondCapture = [deckCard, selectedFloorCard];
        floorCards.removeWhere((c) => c.id == selectedFloorCard.id);

        // 따닥 체크: 4장 모두 같은 월이어야 함
        SpecialEvent event = SpecialEvent.none;
        int piToSteal = 0;
        if (firstMatched &&
            current.pendingHandCard != null &&
            current.pendingHandCard!.month == deckCard.month) {
          event = SpecialEvent.ttadak;
          piToSteal += 1;
        }

        // 카드 획득
        myCaptured = myCaptured.addCards(firstCapture);
        myCaptured = myCaptured.addCards(secondCapture);

        // 싹쓸이 체크
        if (floorCards.isEmpty && (firstCapture.isNotEmpty || secondCapture.isNotEmpty)) {
          piToSteal += 1;
          event = SpecialEvent.sweep;
        }

        // 피 뺏기 (3인 모드: 2명의 상대방에게서 뺏음)
        int actualPiStolen = 0;
        final List<String> piStolenFromPlayers = [];
        
        // 상대방1 UID 결정
        final opponent1Uid = playerNumber == 1
            ? current.turnOrder.length > 1 ? current.turnOrder[1] : opponentUid
            : current.turnOrder.isNotEmpty ? current.turnOrder[0] : opponentUid;
        // 상대방2 UID 결정 (3인 모드)
        final opponent2Uid = isGostopMode && current.turnOrder.length > 2
            ? (playerNumber == 3 ? current.turnOrder[1] : current.turnOrder[2])
            : '';

        for (int i = 0; i < piToSteal; i++) {
          // 첫 번째 상대에게서 피 뺏기
          final (newOpponent1, stolenPi1) = opponent1Captured.removePi();
          if (stolenPi1 != null) {
            opponent1Captured = newOpponent1;
            myCaptured = myCaptured.addCard(stolenPi1);
            actualPiStolen++;
            if (!piStolenFromPlayers.contains(opponent1Uid)) {
              piStolenFromPlayers.add(opponent1Uid);
            }
          } else if (isGostopMode) {
            // 3인 모드: 첫 번째 상대에게 피가 없으면 두 번째 상대에게서
            final (newOpponent2, stolenPi2) = opponent2Captured.removePi();
            if (stolenPi2 != null) {
              opponent2Captured = newOpponent2;
              myCaptured = myCaptured.addCard(stolenPi2);
              actualPiStolen++;
              if (!piStolenFromPlayers.contains(opponent2Uid)) {
                piStolenFromPlayers.add(opponent2Uid);
              }
            }
          }
        }

        // 9월 열끗 선택 체크
        final allCapturedDeck = [...firstCapture, ...secondCapture];
        final septemberAnimalDeck = findSeptemberAnimalCard(allCapturedDeck);
        if (septemberAnimalDeck != null) {
          print('[MatgoLogic] September animal card detected in selectDeckMatchCard, waiting for choice');
          
          // 플레이어별 획득패 업데이트 (피 뺏기 반영)
          CapturedCards sept1Captured, sept2Captured, sept3Captured;
          if (playerNumber == 1) {
            sept1Captured = myCaptured;
            sept2Captured = opponent1Captured;
            sept3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
          } else if (playerNumber == 2) {
            sept1Captured = opponent1Captured;
            sept2Captured = myCaptured;
            sept3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
          } else {
            sept1Captured = opponent1Captured;
            sept2Captured = isGostopMode ? opponent2Captured : current.player2Captured;
            sept3Captured = myCaptured;
          }
          
          return GameState(
            turn: current.turn,
            turnStartTime: DateTime.now().millisecondsSinceEpoch,
            deck: current.deck,
            floorCards: floorCards,
            player1Hand: current.player1Hand,
            player2Hand: current.player2Hand,
            player3Hand: current.player3Hand,
            player1Captured: sept1Captured,
            player2Captured: sept2Captured,
            player3Captured: sept3Captured,
            scores: current.scores,
            lastEvent: event,
            lastEventPlayer: event != SpecialEvent.none ? myUid : null,
            lastEventAt: event != SpecialEvent.none ? DateTime.now().millisecondsSinceEpoch : null,
            pukCards: current.pukCards,
            pukOwner: current.pukOwner,
            waitingForDeckSelection: false,
            deckSelectionPlayer: null,
            deckCard: null,
            deckMatchingCards: const [],
            pendingHandCard: null,
            pendingHandMatch: null,
            waitingForSeptemberChoice: true,
            septemberChoicePlayer: myUid,
            pendingSeptemberCard: septemberAnimalDeck,
            gameMode: current.gameMode,
            turnOrder: current.turnOrder,
            currentTurnIndex: current.currentTurnIndex,
            player1ItemEffects: current.player1ItemEffects,
            player2ItemEffects: current.player2ItemEffects,
            player3ItemEffects: current.player3ItemEffects,
            lastItemUsed: current.lastItemUsed,
            lastItemUsedBy: current.lastItemUsedBy,
            lastItemUsedAt: current.lastItemUsedAt,
          );
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);

        // Go/Stop 체크 (승리 점수 이상이고, 점수가 실제로 올랐을 때만)
        bool waitingForGoStop = false;
        String? goStopPlayer;

        // 현재 플레이어의 고 횟수와 이전 점수 확인
        final myGoCountDeck = _getPlayerGoCount(current.scores, playerNumber);
        final myPrevScoreDeck = _getPlayerScore(current.scores, playerNumber);

        if (myScore.baseTotal >= current.gameMode.winThreshold) {
          // 고 선언 전이거나, 고 선언 후 점수가 올랐을 때만 Go/Stop 트리거
          if (myGoCountDeck == 0 || myScore.baseTotal > myPrevScoreDeck) {
            waitingForGoStop = true;
            goStopPlayer = myUid;
          }
        }

        // 다음 턴 결정 (Go/Stop 대기 중이면 턴 유지)
        final nextTurn = waitingForGoStop
            ? myUid
            : _getNextTurn(current.turnOrder, myUid);

        // 게임 종료 체크 (덱 소진 시)
        GameEndState endState = GameEndState.none;
        String? winner;
        int finalScore = 0;
        bool isGobak = false;

        // 모든 플레이어의 손패가 비었는지 확인
        final allHandsEmpty = current.player1Hand.isEmpty &&
            current.player2Hand.isEmpty &&
            (!isGostopMode || current.player3Hand.isEmpty);

        if (current.deck.isEmpty && allHandsEmpty && !waitingForGoStop) {
          if (isGostopMode) {
            // 3인 고스톱 모드: 점수 비교로 승자 결정
            final player1Score = ScoreCalculator.calculateScore(current.player1Captured).baseTotal;
            final player2Score = ScoreCalculator.calculateScore(current.player2Captured).baseTotal;
            final player3Score = ScoreCalculator.calculateScore(current.player3Captured).baseTotal;
            
            // 내 점수는 피 뺏기가 반영된 myCaptured로 계산
            final myFinalScore = myScore.baseTotal;
            final scores = [
              (uid: current.turnOrder.isNotEmpty ? current.turnOrder[0] : myUid, score: playerNumber == 1 ? myFinalScore : player1Score),
              (uid: current.turnOrder.length > 1 ? current.turnOrder[1] : opponentUid, score: playerNumber == 2 ? myFinalScore : player2Score),
              (uid: current.turnOrder.length > 2 ? current.turnOrder[2] : '', score: playerNumber == 3 ? myFinalScore : player3Score),
            ];
            
            final endResult = checkGameEndOnExhaustion3P(
              playerScores: scores,
              gameMode: current.gameMode,
            );
            
            endState = endResult.endState;
            winner = endResult.winner;
            finalScore = endResult.finalScore;
          } else {
            // 2인 맞고 모드: 기존 로직
            final opponentScore = ScoreCalculator.calculateScore(opponent1Captured);
            final myGoCount = _getPlayerGoCount(scores, playerNumber);
            final opponentGoCount = _getPlayerGoCount(scores, playerNumber == 1 ? 2 : 1);
            final myMultiplier = _getPlayerMultiplier(scores, playerNumber);
            final opponentMultiplier = _getPlayerMultiplier(scores, playerNumber == 1 ? 2 : 1);

            final endResult = checkGameEndOnExhaustion(
              myScore: myScore.baseTotal,
              opponentScore: opponentScore.baseTotal,
              myGoCount: myGoCount,
              opponentGoCount: opponentGoCount,
              myUid: myUid,
              opponentUid: opponentUid,
              myMultiplier: myMultiplier,
              opponentMultiplier: opponentMultiplier,
              myCaptured: myCaptured,
              opponentCaptured: opponent1Captured,
              gameMode: current.gameMode,
            );

            endState = endResult.endState;
            winner = endResult.winner;
            finalScore = endResult.finalScore;
            isGobak = endResult.isGobak;
          }
        }

        // 플레이어별 획득패 업데이트 (피 뺏기 반영)
        CapturedCards newPlayer1Captured, newPlayer2Captured, newPlayer3Captured;
        if (playerNumber == 1) {
          newPlayer1Captured = myCaptured;
          newPlayer2Captured = opponent1Captured;
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
        } else if (playerNumber == 2) {
          newPlayer1Captured = opponent1Captured;
          newPlayer2Captured = myCaptured;
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
        } else {
          newPlayer1Captured = opponent1Captured;
          newPlayer2Captured = isGostopMode ? opponent2Captured : current.player2Captured;
          newPlayer3Captured = myCaptured;
        }

        // 점수 업데이트
        final newScores = scores.copyWith(
          player1Score: playerNumber == 1 ? myScore.baseTotal : ScoreCalculator.calculateScore(newPlayer1Captured).baseTotal,
          player2Score: playerNumber == 2 ? myScore.baseTotal : ScoreCalculator.calculateScore(newPlayer2Captured).baseTotal,
          player3Score: isGostopMode && playerNumber == 3 ? myScore.baseTotal : (isGostopMode ? ScoreCalculator.calculateScore(newPlayer3Captured).baseTotal : scores.player3Score),
        );

        return GameState(
          turn: waitingForGoStop ? myUid : nextTurn,
          turnStartTime: DateTime.now().millisecondsSinceEpoch,
          deck: current.deck,
          floorCards: floorCards,
          player1Hand: current.player1Hand,
          player2Hand: current.player2Hand,
          player3Hand: current.player3Hand,
          player1Captured: newPlayer1Captured,
          player2Captured: newPlayer2Captured,
          player3Captured: newPlayer3Captured,
          scores: newScores,
          lastEvent: event,
          lastEventPlayer: event != SpecialEvent.none ? myUid : null,
          lastEventAt: event != SpecialEvent.none ? DateTime.now().millisecondsSinceEpoch : null,
          pukCards: current.pukCards,
          pukOwner: current.pukOwner,
          endState: endState,
          winner: winner,
          finalScore: finalScore,
          isGobak: isGobak,
          waitingForGoStop: waitingForGoStop,
          goStopPlayer: goStopPlayer,
          waitingForDeckSelection: false,
          deckSelectionPlayer: null,
          deckCard: null,
          deckMatchingCards: const [],
          pendingHandCard: null,
          pendingHandMatch: null,
          piStolenCount: actualPiStolen,
          piStolenFromPlayers: piStolenFromPlayers,
          gameMode: current.gameMode,
          turnOrder: current.turnOrder,
          currentTurnIndex: current.currentTurnIndex,
          player1ItemEffects: current.player1ItemEffects,
          player2ItemEffects: current.player2ItemEffects,
          player3ItemEffects: current.player3ItemEffects,
          lastItemUsed: current.lastItemUsed,
          lastItemUsedBy: current.lastItemUsedBy,
          lastItemUsedAt: current.lastItemUsedAt,
        );
      },
    );
  }

  /// 흔들기 선언
  /// 흔들기 선언 (2인/3인 모드 모두 지원)
  Future<bool> declareShake({
    required String roomId,
    required String myUid,
    required int playerNumber,
    required int month,  // 흔들기할 월
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        if (current.turn != myUid) {
          return current;
        }

        // 플레이어 번호에 따른 손패 선택
        final myHand = switch (playerNumber) {
          1 => current.player1Hand,
          2 => current.player2Hand,
          3 => current.player3Hand,
          _ => current.player1Hand,
        };

        // 해당 월 카드가 3장 있는지 확인
        final monthCards = myHand.where((c) => c.month == month).toList();
        if (monthCards.length < 3) {
          return current;
        }

        // 흔들기 적용 (배수 2배) - 모든 플레이어에게 카드 공개
        return current.copyWith(
          lastEvent: SpecialEvent.shake,
          lastEventPlayer: myUid,
          lastEventAt: DateTime.now().millisecondsSinceEpoch,
          shakeCards: monthCards,  // 흔들기 카드 공개 (모든 플레이어 볼 수 있음)
          shakePlayer: myUid,
          scores: current.scores.copyWith(
            player1Multiplier: playerNumber == 1 ? current.scores.player1Multiplier * 2 : null,
            player2Multiplier: playerNumber == 2 ? current.scores.player2Multiplier * 2 : null,
            player3Multiplier: playerNumber == 3 ? current.scores.player3Multiplier * 2 : null,
            player1Shaking: playerNumber == 1 ? true : null,
            player2Shaking: playerNumber == 2 ? true : null,
            player3Shaking: playerNumber == 3 ? true : null,
          ),
        );
      },
    );
  }

  /// 보너스 카드 사용 (턴 시작 시, 턴 소비 없이 즉시 점수패로 획득)
  /// 2인/3인 모드 모두 지원
  ///
  /// - 내 턴 시작 시점에만 사용 가능
  /// - 사용 즉시 점수패(피) 영역으로 이동 (쌍피로 계산)
  /// - 턴이 소비되지 않음 (일반 카드 플레이 계속 가능)
  Future<bool> useBonusCard({
    required String roomId,
    required String myUid,
    required CardData bonusCard,
    required int playerNumber,
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        // 내 턴인지 확인
        if (current.turn != myUid) {
          print('[MatgoLogic] useBonusCard: Not my turn!');
          return current;
        }

        // Go/Stop 대기 중이면 사용 불가
        if (current.waitingForGoStop) {
          print('[MatgoLogic] useBonusCard: Waiting for Go/Stop decision');
          return current;
        }

        // 플레이어별 손패와 획득패 가져오기 (3인 고스톱 지원)
        var myHand = List<CardData>.from(switch (playerNumber) {
          1 => current.player1Hand,
          2 => current.player2Hand,
          3 => current.player3Hand,
          _ => current.player1Hand,
        });
        var myCaptured = switch (playerNumber) {
          1 => current.player1Captured,
          2 => current.player2Captured,
          3 => current.player3Captured,
          _ => current.player1Captured,
        };

        // 보너스 카드가 손패에 있는지 확인
        final hasBonusCard = myHand.any((c) => c.id == bonusCard.id && c.isBonus);
        if (!hasBonusCard) {
          print('[MatgoLogic] useBonusCard: Bonus card not in hand');
          return current;
        }

        // 손패에서 보너스 카드 제거
        myHand.removeWhere((c) => c.id == bonusCard.id);

        // 점수패(피)에 보너스 카드 추가 (쌍피로 계산됨)
        myCaptured = myCaptured.addCard(bonusCard);

        // 점수 재계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);

        // 새로운 게임 상태 반환 (턴 유지 - 턴을 소비하지 않음!)
        return current.copyWith(
          // turn은 그대로 유지 (턴 소비 안 함)
          player1Hand: playerNumber == 1 ? myHand : current.player1Hand,
          player2Hand: playerNumber == 2 ? myHand : current.player2Hand,
          player3Hand: playerNumber == 3 ? myHand : current.player3Hand,
          player1Captured: playerNumber == 1 ? myCaptured : current.player1Captured,
          player2Captured: playerNumber == 2 ? myCaptured : current.player2Captured,
          player3Captured: playerNumber == 3 ? myCaptured : current.player3Captured,
          scores: current.scores.copyWith(
            player1Score: playerNumber == 1 ? myScore.baseTotal : null,
            player2Score: playerNumber == 2 ? myScore.baseTotal : null,
            player3Score: playerNumber == 3 ? myScore.baseTotal : null,
          ),
          lastEvent: SpecialEvent.bonusCardUsed,
          lastEventPlayer: myUid,
          lastEventAt: DateTime.now().millisecondsSinceEpoch,  // 연속 이벤트 감지용
        );
      },
    );
  }

  /// 폭탄 선언 1단계 - 오버레이 표시를 위한 상태 설정
  /// 손에 3장 + 바닥에 1장을 보여주고, 실제 처리는 executeBomb에서 수행
  Future<bool> declareBomb({
    required String roomId,
    required String myUid,
    required String opponentUid,
    required int playerNumber,
    required int month,  // 폭탄할 월
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        if (current.turn != myUid) {
          return current;
        }

        // 플레이어별 손패 가져오기 (3인 고스톱 지원)
        final myHand = switch (playerNumber) {
          1 => current.player1Hand,
          2 => current.player2Hand,
          3 => current.player3Hand,
          _ => current.player1Hand,
        };
        final floorCards = current.floorCards;

        // 손에 해당 월 3장, 바닥에 1장 확인
        final handCards = myHand.where((c) => c.month == month).toList();
        final floorCard = floorCards.where((c) => c.month == month).toList();

        if (handCards.length != 3 || floorCard.length != 1) {
          return current;
        }

        // 오버레이 표시를 위한 상태만 설정 (실제 카드 이동은 하지 않음)
        return current.copyWith(
          bombCards: handCards,        // 손패의 3장 (던질 카드들)
          bombPlayer: myUid,           // 폭탄 사용자
          bombTargetCard: floorCard.first,  // 바닥의 1장 (획득할 카드)
          lastEvent: SpecialEvent.bomb,
          lastEventPlayer: myUid,
          lastEventAt: DateTime.now().millisecondsSinceEpoch,
        );
      },
    );
  }

  /// 폭탄 선언 2단계 - 실제 카드 이동 실행
  /// 오버레이 종료 후 호출: 손패 3장 + 바닥 1장 = 4장 모두 획득
  Future<bool> executeBomb({
    required String roomId,
    required String myUid,
    required String opponentUid,
    required int playerNumber,
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        // 폭탄 상태 확인
        if (current.bombPlayer != myUid ||
            current.bombCards.isEmpty ||
            current.bombTargetCard == null) {
          return current;
        }

        // 3인 모드 여부 확인
        final isGostopMode = current.gameMode == GameMode.gostop;
        
        // 플레이어별 손패 및 획득패 설정
        List<CardData> myHand;
        CapturedCards myCaptured;
        
        switch (playerNumber) {
          case 1:
            myHand = List<CardData>.from(current.player1Hand);
            myCaptured = current.player1Captured;
            break;
          case 2:
            myHand = List<CardData>.from(current.player2Hand);
            myCaptured = current.player2Captured;
            break;
          case 3:
            myHand = List<CardData>.from(current.player3Hand);
            myCaptured = current.player3Captured;
            break;
          default:
            myHand = List<CardData>.from(current.player1Hand);
            myCaptured = current.player1Captured;
        }
        
        // 피 뺏기 대상 (2인: 상대방 1명 / 3인: 상대방 2명 모두)
        var opponent1Captured = playerNumber == 1 
            ? current.player2Captured 
            : current.player1Captured;
        var opponent2Captured = isGostopMode
            ? (playerNumber == 3 
                ? current.player2Captured 
                : current.player3Captured)
            : current.player1Captured;
        
        var floorCards = List<CardData>.from(current.floorCards);

        // 손패에서 3장 제거하고 획득 (4장 모두 획득)
        for (final c in current.bombCards) {
          myHand.removeWhere((h) => h.id == c.id);
          myCaptured = myCaptured.addCard(c);
        }

        // 바닥의 대상 카드 1장도 획득
        floorCards.removeWhere((f) => f.id == current.bombTargetCard!.id);
        myCaptured = myCaptured.addCard(current.bombTargetCard!);

        // 피 뺏기 (3인 모드에서는 두 상대방 모두에게서 뺏음)
        int actualPiStolen = 0;
        List<String> piStolenFromPlayers = [];
        
        // 첫 번째 상대방에게서 피 뺏기
        final (newOpponent1, stolenPi1) = opponent1Captured.removePi();
        if (stolenPi1 != null) {
          opponent1Captured = newOpponent1;
          myCaptured = myCaptured.addCard(stolenPi1);
          actualPiStolen++;
          if (current.turnOrder.length > 1) {
            final opponent1Uid = playerNumber == 1 ? current.turnOrder[1] : current.turnOrder[0];
            piStolenFromPlayers.add(opponent1Uid);
          }
        }
        
        // 3인 모드에서는 두 번째 상대방에게서도 피 뺏기
        if (isGostopMode && current.turnOrder.length > 2) {
          final (newOpponent2, stolenPi2) = opponent2Captured.removePi();
          if (stolenPi2 != null) {
            opponent2Captured = newOpponent2;
            myCaptured = myCaptured.addCard(stolenPi2);
            actualPiStolen++;
            final opponent2Uid = playerNumber == 3 ? current.turnOrder[1] : current.turnOrder[2];
            piStolenFromPlayers.add(opponent2Uid);
          }
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);

        // 플레이어별 획득패 업데이트 (피 뺏기 반영)
        CapturedCards newPlayer1Captured, newPlayer2Captured, newPlayer3Captured;
        if (playerNumber == 1) {
          newPlayer1Captured = myCaptured;
          newPlayer2Captured = opponent1Captured;
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
        } else if (playerNumber == 2) {
          newPlayer1Captured = opponent1Captured;
          newPlayer2Captured = myCaptured;
          newPlayer3Captured = isGostopMode ? opponent2Captured : current.player3Captured;
        } else {
          newPlayer1Captured = opponent1Captured;
          newPlayer2Captured = isGostopMode ? opponent2Captured : current.player2Captured;
          newPlayer3Captured = myCaptured;
        }

        // 점수 업데이트를 위한 각 플레이어 점수 계산
        final opponent1Score = ScoreCalculator.calculateScore(opponent1Captured);
        final opponent2Score = isGostopMode 
            ? ScoreCalculator.calculateScore(opponent2Captured)
            : ScoreResult();

        return current.copyWith(
          piStolenCount: actualPiStolen,
          piStolenFromPlayers: piStolenFromPlayers,
          player1Hand: playerNumber == 1 ? myHand : current.player1Hand,
          player2Hand: playerNumber == 2 ? myHand : current.player2Hand,
          player3Hand: playerNumber == 3 ? myHand : current.player3Hand,
          player1Captured: newPlayer1Captured,
          player2Captured: newPlayer2Captured,
          player3Captured: newPlayer3Captured,
          floorCards: floorCards,
          bombCards: [],  // 폭탄 상태 초기화
          clearBombPlayer: true,
          clearBombTargetCard: true,
          scores: current.scores.copyWith(
            player1Score: playerNumber == 1 ? myScore.baseTotal 
                : (playerNumber == 2 ? opponent1Score.baseTotal : opponent1Score.baseTotal),
            player2Score: playerNumber == 2 ? myScore.baseTotal 
                : (playerNumber == 1 ? opponent1Score.baseTotal 
                    : (isGostopMode ? opponent2Score.baseTotal : current.scores.player2Score)),
            player3Score: isGostopMode ? (playerNumber == 3 ? myScore.baseTotal : opponent2Score.baseTotal) : null,
            player1Multiplier: playerNumber == 1 ? current.scores.player1Multiplier * 2 : null,
            player2Multiplier: playerNumber == 2 ? current.scores.player2Multiplier * 2 : null,
            player3Multiplier: playerNumber == 3 ? current.scores.player3Multiplier * 2 : null,
            player1Bomb: playerNumber == 1 ? true : null,
            player2Bomb: playerNumber == 2 ? true : null,
            player3Bomb: playerNumber == 3 ? true : null,
          ),
        );
      },
    );
  }

  /// 타임아웃 시 자동 플레이
  ///
  /// 턴 타이머가 만료되면 자동으로 손패에서 카드를 선택하여 플레이합니다.
  /// 가능하면 바닥 카드와 매칭되는 카드를 선택하고, 없으면 첫 번째 카드를 버립니다.
  Future<bool> autoPlayOnTimeout({
    required String roomId,
    required String myUid,
    required String opponentUid,
    required int playerNumber,
  }) async {
    // 먼저 현재 게임 상태를 읽어옴
    final room = await _roomService.getRoom(roomId);
    if (room == null || room.gameState == null) {
      print('[MatgoLogic] autoPlayOnTimeout: Room or gameState is null');
      return false;
    }

    final gameState = room.gameState!;

    // 내 턴인지 확인
    if (gameState.turn != myUid) {
      print('[MatgoLogic] autoPlayOnTimeout: Not my turn');
      return false;
    }

    // 게임이 종료되었는지 확인
    if (gameState.endState != GameEndState.none) {
      print('[MatgoLogic] autoPlayOnTimeout: Game already ended');
      return false;
    }

    // Go/Stop 대기 중이면 자동으로 Go 선언
    if (gameState.waitingForGoStop && gameState.goStopPlayer == myUid) {
      print('[MatgoLogic] autoPlayOnTimeout: Auto declaring Go');
      return await declareGo(
        roomId: roomId,
        myUid: myUid,
        opponentUid: opponentUid,
        playerNumber: playerNumber,
      );
    }

    // 덱 선택 대기 중이면 첫 번째 선택지를 자동 선택
    if (gameState.waitingForDeckSelection && gameState.deckSelectionPlayer == myUid) {
      if (gameState.deckMatchingCards.isNotEmpty) {
        print('[MatgoLogic] autoPlayOnTimeout: Auto selecting deck match');
        return await selectDeckMatchCard(
          roomId: roomId,
          myUid: myUid,
          opponentUid: opponentUid,
          playerNumber: playerNumber,
          selectedFloorCard: gameState.deckMatchingCards.first,
        );
      }
    }

    // 3인 고스톱 모드 지원: playerNumber에 따라 올바른 손패 선택
    final myHand = switch (playerNumber) {
      1 => gameState.player1Hand,
      2 => gameState.player2Hand,
      3 => gameState.player3Hand,
      _ => gameState.player1Hand,
    };

    // 손패가 비어있으면 덱만 뒤집기
    if (myHand.isEmpty) {
      print('[MatgoLogic] autoPlayOnTimeout: Hand is empty, flipping deck only');
      return await flipDeckOnly(
        roomId: roomId,
        myUid: myUid,
        opponentUid: opponentUid,
        playerNumber: playerNumber,
      );
    }

    // 바닥 카드와 매칭되는 손패 카드 찾기
    CardData? cardToPlay;
    CardData? matchingFloorCard;

    for (final handCard in myHand) {
      // 보너스 카드는 스킵
      if (handCard.isBonus) continue;

      final matches = gameState.floorCards
          .where((f) => f.month == handCard.month)
          .toList();

      if (matches.isNotEmpty) {
        cardToPlay = handCard;
        matchingFloorCard = matches.first;
        break;
      }
    }

    // 매칭되는 카드가 없으면 첫 번째 일반 카드 선택
    if (cardToPlay == null) {
      cardToPlay = myHand.firstWhere(
        (c) => !c.isBonus,
        orElse: () => myHand.first,
      );
    }

    print('[MatgoLogic] autoPlayOnTimeout: Auto playing card ${cardToPlay.id}');

    // 카드 플레이 실행
    return await playCard(
      roomId: roomId,
      myUid: myUid,
      opponentUid: opponentUid,
      playerNumber: playerNumber,
      card: cardToPlay,
      selectedFloorCard: matchingFloorCard,
    );
  }

  /// 남은 턴 시간 계산 (초 단위)
  static int getRemainingTurnTime(GameState gameState, {int turnDuration = 60}) {
    if (gameState.turnStartTime == null) {
      return turnDuration;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - gameState.turnStartTime!) ~/ 1000;
    final remaining = turnDuration - elapsed;

    return remaining > 0 ? remaining : 0;
  }

  /// 턴 타임아웃 여부 확인
  static bool isTurnTimedOut(GameState gameState, {int turnDuration = 60}) {
    return getRemainingTurnTime(gameState, turnDuration: turnDuration) <= 0;
  }

  /// 9월 열끗 선택 완료 처리
  /// 2인/3인 모드 모두 지원
  ///
  /// [useAsAnimal] true면 열끗(동물)으로, false면 쌍피로 사용
  Future<bool> completeSeptemberChoice({
    required String roomId,
    required String myUid,
    required String opponentUid,  // 2인 모드에서 사용
    required int playerNumber,
    required bool useAsAnimal,
  }) async {
    return await _roomService.updateGameStateWithTransaction(
      roomId: roomId,
      updater: (current) {
        // 9월 열끗 선택 대기 상태인지 확인
        if (!current.waitingForSeptemberChoice) {
          print('[MatgoLogic] Not waiting for September choice');
          return current;
        }

        // 선택 권한이 있는지 확인
        if (current.septemberChoicePlayer != myUid) {
          print('[MatgoLogic] Not my turn to choose September card');
          return current;
        }

        final pendingCard = current.pendingSeptemberCard;
        if (pendingCard == null) {
          print('[MatgoLogic] No pending September card');
          return current;
        }

        // 3인 고스톱 모드 여부
        final isGostopMode = current.gameMode == GameMode.gostop;

        // 플레이어별 획득패 설정 (3인 모드 지원)
        var myCaptured = switch (playerNumber) {
          1 => current.player1Captured,
          2 => current.player2Captured,
          3 => current.player3Captured,
          _ => current.player1Captured,
        };

        // 쌍피로 선택한 경우: animal에서 제거하고 pi에 쌍피로 추가
        if (!useAsAnimal) {
          // animal 목록에서 해당 카드 제거
          final animalList = List<CardData>.from(myCaptured.animal);
          animalList.removeWhere((c) => c.id == pendingCard.id);

          // 쌍피로 변환된 카드 생성 (타입만 doublePi로 변경)
          final asDoublePi = CardData(
            id: pendingCard.id,
            month: pendingCard.month,
            index: pendingCard.index,
            type: CardType.doublePi,
          );

          // pi 목록에 추가
          final piList = List<CardData>.from(myCaptured.pi);
          piList.add(asDoublePi);

          // 새로운 CapturedCards 생성
          myCaptured = CapturedCards(
            kwang: myCaptured.kwang,
            animal: animalList,
            ribbon: myCaptured.ribbon,
            pi: piList,
          );

          print('[MatgoLogic] September animal card converted to doublePi');
        } else {
          print('[MatgoLogic] September animal card kept as animal');
        }

        // 점수 재계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);

        // Go/Stop 체크
        bool waitingForGoStop = false;
        String? goStopPlayer;

        if (myScore.baseTotal >= current.gameMode.winThreshold) {
          waitingForGoStop = true;
          goStopPlayer = myUid;
        }

        // 다음 턴 결정 (Go/Stop 대기 중이면 턴 유지)
        final nextTurn = waitingForGoStop
            ? myUid
            : _getNextTurn(current.turnOrder, myUid);

        // 게임 종료 체크
        GameEndState endState = GameEndState.none;
        String? winner;
        int finalScore = 0;
        bool isGobak = false;

        final deck = current.deck;
        
        // 내 손패 확인 (3인 모드 지원)
        final myHand = switch (playerNumber) {
          1 => current.player1Hand,
          2 => current.player2Hand,
          3 => current.player3Hand,
          _ => current.player1Hand,
        };

        // 모든 플레이어의 손패가 비었는지 확인
        final allHandsEmpty = current.player1Hand.isEmpty &&
            current.player2Hand.isEmpty &&
            (!isGostopMode || current.player3Hand.isEmpty);

        if (deck.isEmpty && allHandsEmpty && !waitingForGoStop) {
          if (isGostopMode) {
            // 3인 고스톱 모드: 점수 비교로 승자 결정 (고박 없음)
            final player1Score = playerNumber == 1 
                ? myScore.baseTotal 
                : ScoreCalculator.calculateScore(current.player1Captured).baseTotal;
            final player2Score = playerNumber == 2 
                ? myScore.baseTotal 
                : ScoreCalculator.calculateScore(current.player2Captured).baseTotal;
            final player3Score = playerNumber == 3 
                ? myScore.baseTotal 
                : ScoreCalculator.calculateScore(current.player3Captured).baseTotal;
            
            final playerScores = [
              (uid: current.turnOrder.isNotEmpty ? current.turnOrder[0] : myUid, score: player1Score),
              (uid: current.turnOrder.length > 1 ? current.turnOrder[1] : opponentUid, score: player2Score),
              (uid: current.turnOrder.length > 2 ? current.turnOrder[2] : '', score: player3Score),
            ];
            
            final endResult = checkGameEndOnExhaustion3P(
              playerScores: playerScores,
              gameMode: current.gameMode,
            );
            
            endState = endResult.endState;
            winner = endResult.winner;
            finalScore = endResult.finalScore;
          } else {
            // 2인 맞고 모드: 기존 로직
            final scores = current.scores;
            final isPlayer1 = playerNumber == 1;
            final opponentCaptured = isPlayer1 ? current.player2Captured : current.player1Captured;
            final opponentScore = ScoreCalculator.calculateScore(opponentCaptured);
            
            final myGoCount = isPlayer1 ? scores.player1GoCount : scores.player2GoCount;
            final opponentGoCount = isPlayer1 ? scores.player2GoCount : scores.player1GoCount;
            final myMultiplier = isPlayer1 ? scores.player1Multiplier : scores.player2Multiplier;
            final opponentMultiplier = isPlayer1 ? scores.player2Multiplier : scores.player1Multiplier;

            final endResult = checkGameEndOnExhaustion(
              myScore: myScore.baseTotal,
              opponentScore: opponentScore.baseTotal,
              myGoCount: myGoCount,
              opponentGoCount: opponentGoCount,
              myUid: myUid,
              opponentUid: opponentUid,
              myMultiplier: myMultiplier,
              opponentMultiplier: opponentMultiplier,
              myCaptured: myCaptured,
              opponentCaptured: opponentCaptured,
              gameMode: current.gameMode,
            );

            endState = endResult.endState;
            winner = endResult.winner;
            finalScore = endResult.finalScore;
            isGobak = endResult.isGobak;
          }
        }

        // 플레이어별 획득패 및 점수 업데이트 (3인 모드 지원)
        CapturedCards newPlayer1Captured, newPlayer2Captured, newPlayer3Captured;
        int newPlayer1Score, newPlayer2Score, newPlayer3Score;
        
        if (playerNumber == 1) {
          newPlayer1Captured = myCaptured;
          newPlayer2Captured = current.player2Captured;
          newPlayer3Captured = current.player3Captured;
          newPlayer1Score = myScore.baseTotal;
          newPlayer2Score = current.scores.player2Score;
          newPlayer3Score = current.scores.player3Score;
        } else if (playerNumber == 2) {
          newPlayer1Captured = current.player1Captured;
          newPlayer2Captured = myCaptured;
          newPlayer3Captured = current.player3Captured;
          newPlayer1Score = current.scores.player1Score;
          newPlayer2Score = myScore.baseTotal;
          newPlayer3Score = current.scores.player3Score;
        } else {
          newPlayer1Captured = current.player1Captured;
          newPlayer2Captured = current.player2Captured;
          newPlayer3Captured = myCaptured;
          newPlayer1Score = current.scores.player1Score;
          newPlayer2Score = current.scores.player2Score;
          newPlayer3Score = myScore.baseTotal;
        }

        return current.copyWith(
          turn: nextTurn,
          currentTurnIndex: current.turnOrder.indexOf(nextTurn),
          turnStartTime: DateTime.now().millisecondsSinceEpoch,
          player1Captured: newPlayer1Captured,
          player2Captured: newPlayer2Captured,
          player3Captured: newPlayer3Captured,
          scores: ScoreInfo(
            player1Score: newPlayer1Score,
            player2Score: newPlayer2Score,
            player3Score: newPlayer3Score,
            player1GoCount: current.scores.player1GoCount,
            player2GoCount: current.scores.player2GoCount,
            player3GoCount: current.scores.player3GoCount,
            player1Multiplier: current.scores.player1Multiplier,
            player2Multiplier: current.scores.player2Multiplier,
            player3Multiplier: current.scores.player3Multiplier,
            player1Shaking: current.scores.player1Shaking,
            player2Shaking: current.scores.player2Shaking,
            player3Shaking: current.scores.player3Shaking,
            player1Bomb: current.scores.player1Bomb,
            player2Bomb: current.scores.player2Bomb,
            player3Bomb: current.scores.player3Bomb,
          ),
          endState: endState,
          winner: winner,
          finalScore: finalScore,
          isGobak: isGobak,
          waitingForGoStop: waitingForGoStop,
          goStopPlayer: goStopPlayer,
          waitingForSeptemberChoice: false,
          clearSeptemberChoicePlayer: true,
          clearPendingSeptemberCard: true,
        );
      },
    );
  }
}
