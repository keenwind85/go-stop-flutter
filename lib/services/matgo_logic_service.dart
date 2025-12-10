import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_data.dart';
import '../models/game_room.dart';
import '../models/captured_cards.dart';
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

  const GameEndCheckResult({
    this.endState = GameEndState.none,
    this.winner,
    this.finalScore = 0,
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

  /// 덱/손패 소진 시 게임 종료 조건 체크
  ///
  /// 규칙:
  /// 1. 양쪽 모두 7점 미만 + 고 선언자 없음 = 나가리
  /// 2. 고 선언자가 있는 경우:
  ///    - 상대방이 7점 미만 = 고 선언자 자동 승리 (autoWin)
  ///    - 상대방이 7점 이상 = 고박! 상대방 승리 (gobak)
  /// 3. 한 명만 7점 이상 (고 선언자 없음) = 7점 이상인 플레이어 승리 (강제 스톱)
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
  }) {
    final threshold = GameConstants.goStopThreshold;

    // 고 선언자 확인
    final iHaveGo = myGoCount > 0;
    final opponentHasGo = opponentGoCount > 0;

    // 케이스 1: 내가 고를 선언한 상태
    if (iHaveGo) {
      if (opponentScore >= threshold) {
        // 고박! 상대방이 7점 이상 도달 → 상대방 승리
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: opponentCaptured,
          opponentCaptures: myCaptured,
          goCount: 0,  // 고박당한 쪽은 고 카운트 0
          playerMultiplier: opponentMultiplier,
          isGobak: true,  // 고박 배수 적용
        );
        return GameEndCheckResult(
          endState: GameEndState.gobak,
          winner: opponentUid,
          finalScore: finalResult.finalScore,
        );
      } else {
        // 상대방 7점 미만 → 내가 자동 승리 (강제 스톱)
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: myCaptured,
          opponentCaptures: opponentCaptured,
          goCount: myGoCount,
          playerMultiplier: myMultiplier,
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
        // 고박! 내가 7점 이상 도달 → 내가 승리
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: myCaptured,
          opponentCaptures: opponentCaptured,
          goCount: 0,
          playerMultiplier: myMultiplier,
          isGobak: true,
        );
        return GameEndCheckResult(
          endState: GameEndState.gobak,
          winner: myUid,
          finalScore: finalResult.finalScore,
        );
      } else {
        // 내가 7점 미만 → 상대방 자동 승리
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: opponentCaptured,
          opponentCaptures: myCaptured,
          goCount: opponentGoCount,
          playerMultiplier: opponentMultiplier,
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
      // 양쪽 모두 7점 미만 = 나가리
      return const GameEndCheckResult(endState: GameEndState.nagari);
    }

    // 케이스 4: 한 명이 7점 이상 (고 없이 덱 소진) - 7점 이상인 사람이 강제 스톱
    if (myScore >= threshold) {
      final finalResult = ScoreCalculator.calculateFinalScore(
        myCaptures: myCaptured,
        opponentCaptures: opponentCaptured,
        goCount: 0,
        playerMultiplier: myMultiplier,
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
      );
      return GameEndCheckResult(
        endState: GameEndState.win,
        winner: opponentUid,
        finalScore: finalResult.finalScore,
      );
    }
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

  /// 게임 초기화 (방장이 호출)
  Future<GameState?> initializeGame({
    required String roomId,
    required String hostUid,
    required String guestUid,
    required String hostName,
    required String guestName,
    int gameCount = 0,
    String? lastWinner,
  }) async {
    final deck = DeckGenerator.generateDeck();
    final dealResult = DeckGenerator.dealCards(deck);

    // 선 결정
    final firstTurnResult = determineFirstTurn(
      hostUid: hostUid,
      guestUid: guestUid,
      hostHand: dealResult.player1Hand,
      guestHand: dealResult.player2Hand,
      gameCount: gameCount,
      lastWinner: lastWinner,
      hostName: hostName,
      guestName: guestName,
    );

    print('[MatgoLogic] First turn: ${firstTurnResult.firstPlayerUid}, reason: ${firstTurnResult.reason}');

    // 총통 체크
    if (dealResult.player1Chongtong && dealResult.player2Chongtong) {
      // 둘 다 총통 -> 나가리 (양쪽 카드 모두 표시)
      final allChongtongCards = [
        ...dealResult.player1ChongtongCards,
        ...dealResult.player2ChongtongCards,
      ];
      final gameState = GameState(
        turn: firstTurnResult.firstPlayerUid,
        deck: dealResult.deck,
        floorCards: dealResult.floorCards,
        player1Hand: dealResult.player1Hand,
        player2Hand: dealResult.player2Hand,
        player1Captured: const CapturedCards(),
        player2Captured: const CapturedCards(),
        scores: const ScoreInfo(),
        endState: GameEndState.nagari,
        lastEvent: SpecialEvent.chongtong,
        chongtongCards: allChongtongCards,
        chongtongPlayer: null, // 둘 다 총통이므로 null
        firstTurnPlayer: firstTurnResult.firstPlayerUid,
        firstTurnDecidingMonth: firstTurnResult.decidingMonth,
        firstTurnReason: firstTurnResult.reason,
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
        player1Captured: const CapturedCards(),
        player2Captured: const CapturedCards(),
        scores: const ScoreInfo(player1Score: GameConstants.chongtongScore),
        endState: GameEndState.chongtong,
        winner: hostUid,
        finalScore: GameConstants.chongtongScore,
        lastEvent: SpecialEvent.chongtong,
        chongtongCards: dealResult.player1ChongtongCards,
        chongtongPlayer: hostUid,
        firstTurnPlayer: firstTurnResult.firstPlayerUid,
        firstTurnDecidingMonth: firstTurnResult.decidingMonth,
        firstTurnReason: firstTurnResult.reason,
      );

      await _roomService.updateGameState(roomId: roomId, gameState: gameState);
      await _roomService.startGame(roomId);
      return gameState;
    } else if (dealResult.player2Chongtong) {
      // 게스트 총통 승리
      final gameState = GameState(
        turn: firstTurnResult.firstPlayerUid,
        deck: dealResult.deck,
        floorCards: dealResult.floorCards,
        player1Hand: dealResult.player1Hand,
        player2Hand: dealResult.player2Hand,
        player1Captured: const CapturedCards(),
        player2Captured: const CapturedCards(),
        scores: const ScoreInfo(player2Score: GameConstants.chongtongScore),
        endState: GameEndState.chongtong,
        winner: guestUid,
        finalScore: GameConstants.chongtongScore,
        lastEvent: SpecialEvent.chongtong,
        chongtongCards: dealResult.player2ChongtongCards,
        chongtongPlayer: guestUid,
        firstTurnPlayer: firstTurnResult.firstPlayerUid,
        firstTurnDecidingMonth: firstTurnResult.decidingMonth,
        firstTurnReason: firstTurnResult.reason,
      );

      await _roomService.updateGameState(roomId: roomId, gameState: gameState);
      await _roomService.startGame(roomId);
      return gameState;
    }

    // 정상 게임 시작
    // 바닥에서 가져온 보너스 카드는 선공 플레이어에게
    var player1Captured = const CapturedCards();
    var player2Captured = const CapturedCards();
    if (dealResult.bonusFromFloor.isNotEmpty) {
      // 선이 방장이면 방장에게, 게스트면 게스트에게
      if (firstTurnResult.firstPlayerUid == hostUid) {
        player1Captured = player1Captured.addCards(dealResult.bonusFromFloor);
      } else {
        player2Captured = player2Captured.addCards(dealResult.bonusFromFloor);
      }
    }

    final gameState = GameState(
      turn: firstTurnResult.firstPlayerUid,
      deck: dealResult.deck,
      floorCards: dealResult.floorCards,
      player1Hand: dealResult.player1Hand,
      player2Hand: dealResult.player2Hand,
      player1Captured: player1Captured,
      player2Captured: player2Captured,
      scores: const ScoreInfo(),
      firstTurnPlayer: firstTurnResult.firstPlayerUid,
      firstTurnDecidingMonth: firstTurnResult.decidingMonth,
      firstTurnReason: firstTurnResult.reason,
      turnStartTime: DateTime.now().millisecondsSinceEpoch,
    );

    await _roomService.updateGameState(roomId: roomId, gameState: gameState);
    await _roomService.startGame(roomId);

    print('[MatgoLogic] Game initialized for room: $roomId');
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

        final isPlayer1 = playerNumber == 1;
        var myHand = List<CardData>.from(
          isPlayer1 ? current.player1Hand : current.player2Hand,
        );
        var myCaptured = isPlayer1 ? current.player1Captured : current.player2Captured;
        var opponentCaptured = isPlayer1 ? current.player2Captured : current.player1Captured;
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
          deckCard = deck.removeAt(0);

          // 보너스 카드는 즉시 획득
          if (deckCard.isBonus) {
            myCaptured = myCaptured.addCard(deckCard);
            deckCard = null;
            // 다시 뒤집기
            if (deck.isNotEmpty) {
              deckCard = deck.removeAt(0);
            }
          }

          if (deckCard != null) {
            final deckMatching = floorCards.where((c) => c.month == deckCard!.month).toList();

            if (deckMatching.isEmpty) {
              // 덱 카드 매칭 없음

              // 쪽 체크: 내 패가 안 맞았는데 덱 카드가 내 패와 같은 월
              if (!firstMatched && deckCard.month == card.month) {
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
              // 뻑 체크: 내 패가 바닥과 맞았는데, 덱 카드도 같은 월
              if (firstMatched && deckCard.month == card.month) {
                // 뻑! 3장을 바닥에 두고 종료
                floorCards.addAll(firstCapture);
                floorCards.add(deckCard);
                firstCapture = [];
                pukCards = [card, ...matchingFloor.take(1), deckCard];
                pukOwner = myUid;
                event = SpecialEvent.puk;
              } else {
                // 따닥 체크: 내 패가 맞고, 덱 카드도 다른 패와 맞음
                if (firstMatched) {
                  // 따닥! 2쌍 모두 획득 + 피 1장 뺏기
                  secondCapture = [deckCard, deckMatching.first];
                  floorCards.removeWhere((c) => c.id == deckMatching.first.id);
                  event = SpecialEvent.ttadak;
                  piToSteal += 1;
                } else {
                  // 일반 1장 매칭
                  secondCapture = [deckCard, deckMatching.first];
                  floorCards.removeWhere((c) => c.id == deckMatching.first.id);
                }
              }
            } else if (deckMatching.length == 2) {
              // 덱 카드 2장 매칭 -> 사용자 선택 필요
              // 손패에서 먹은 카드 정보 저장
              CardData? handMatchCard;
              if (firstMatched && firstCapture.length >= 2) {
                handMatchCard = firstCapture[1]; // 손패로 먹은 바닥 카드
              }

              // 현재 상태까지 저장하고 선택 대기 상태로 반환
              return GameState(
                turn: current.turn,
                deck: deck,
                floorCards: floorCards,
                player1Hand: isPlayer1 ? myHand : List<CardData>.from(current.player1Hand),
                player2Hand: isPlayer1 ? List<CardData>.from(current.player2Hand) : myHand,
                player1Captured: isPlayer1 ? myCaptured : current.player1Captured,
                player2Captured: isPlayer1 ? current.player2Captured : myCaptured,
                scores: scores,
                lastEvent: event,
                lastEventPlayer: event != SpecialEvent.none ? myUid : null,
                pukCards: pukCards,
                pukOwner: pukOwner,
                waitingForDeckSelection: true,
                deckSelectionPlayer: myUid,
                deckCard: deckCard,
                deckMatchingCards: deckMatching,
                pendingHandCard: card,
                pendingHandMatch: handMatchCard,
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
        if (floorCards.isEmpty && (firstCapture.isNotEmpty || secondCapture.isNotEmpty)) {
          if (event == SpecialEvent.none) {
            event = SpecialEvent.sweep;
          }
          piToSteal += 1;
        }

        // 피 뺏기
        for (int i = 0; i < piToSteal; i++) {
          final (newOpponent, stolenPi) = opponentCaptured.removePi();
          if (stolenPi != null) {
            opponentCaptured = newOpponent;
            myCaptured = myCaptured.addCard(stolenPi);
          }
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);
        final opponentScore = ScoreCalculator.calculateScore(opponentCaptured);

        // Go/Stop 체크 (7점 이상)
        bool waitingForGoStop = false;
        String? goStopPlayer;

        if (myScore.baseTotal >= GameConstants.goStopThreshold) {
          waitingForGoStop = true;
          goStopPlayer = myUid;
        }

        // 다음 턴 결정 (Go/Stop 대기 중이면 턴 유지)
        final nextTurn = waitingForGoStop ? myUid : opponentUid;

        // 게임 종료 체크 (덱 소진 시)
        GameEndState endState = GameEndState.none;
        String? winner;
        int finalScore = 0;

        if (deck.isEmpty && myHand.isEmpty && !waitingForGoStop) {
          // 덱과 손패가 모두 소진되었을 때 게임 종료 조건 체크
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
          );

          endState = endResult.endState;
          winner = endResult.winner;
          finalScore = endResult.finalScore;
        }

        // 새로운 게임 상태 반환
        return current.copyWith(
          turn: nextTurn,
          turnStartTime: DateTime.now().millisecondsSinceEpoch,  // 턴 타이머 리셋
          deck: deck,
          floorCards: floorCards,
          player1Hand: isPlayer1 ? myHand : current.player1Hand,
          player2Hand: isPlayer1 ? current.player2Hand : myHand,
          player1Captured: isPlayer1 ? myCaptured : opponentCaptured,
          player2Captured: isPlayer1 ? opponentCaptured : myCaptured,
          scores: ScoreInfo(
            player1Score: isPlayer1 ? myScore.baseTotal : opponentScore.baseTotal,
            player2Score: isPlayer1 ? opponentScore.baseTotal : myScore.baseTotal,
            player1GoCount: scores.player1GoCount,
            player2GoCount: scores.player2GoCount,
            player1Multiplier: scores.player1Multiplier,
            player2Multiplier: scores.player2Multiplier,
            player1Shaking: scores.player1Shaking,
            player2Shaking: scores.player2Shaking,
          ),
          lastEvent: event,
          lastEventPlayer: event != SpecialEvent.none ? myUid : null,
          pukCards: pukCards,
          pukOwner: pukOwner,
          endState: endState,
          winner: winner,
          finalScore: finalScore,
          waitingForGoStop: waitingForGoStop,
          goStopPlayer: goStopPlayer,
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

        final isPlayer1 = playerNumber == 1;
        var myHand = List<CardData>.from(
          isPlayer1 ? current.player1Hand : current.player2Hand,
        );

        // 손패가 비어있어야 함
        if (myHand.isNotEmpty) {
          print('[MatgoLogic] flipDeckOnly: Hand is not empty, use playCard instead');
          return current;
        }

        var myCaptured = isPlayer1 ? current.player1Captured : current.player2Captured;
        var opponentCaptured = isPlayer1 ? current.player2Captured : current.player1Captured;
        var floorCards = List<CardData>.from(current.floorCards);
        var deck = List<CardData>.from(current.deck);
        var pukCards = List<CardData>.from(current.pukCards);
        var pukOwner = current.pukOwner;
        var scores = current.scores;

        // 발생한 이벤트들
        SpecialEvent event = SpecialEvent.none;
        int piToSteal = 0;

        // 덱에서 카드 뒤집기
        List<CardData> capture = [];
        CardData? deckCard;

        if (deck.isEmpty) {
          print('[MatgoLogic] flipDeckOnly: Deck is empty');
          return current;
        }

        deckCard = deck.removeAt(0);

        // 보너스 카드는 즉시 획득
        if (deckCard.isBonus) {
          myCaptured = myCaptured.addCard(deckCard);
          deckCard = null;
          // 다시 뒤집기
          if (deck.isNotEmpty) {
            deckCard = deck.removeAt(0);
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
        if (floorCards.isEmpty && capture.isNotEmpty) {
          if (event == SpecialEvent.none) {
            event = SpecialEvent.sweep;
          }
          piToSteal += 1;
        }

        // 피 뺏기
        for (int i = 0; i < piToSteal; i++) {
          final (newOpponent, stolenPi) = opponentCaptured.removePi();
          if (stolenPi != null) {
            opponentCaptured = newOpponent;
            myCaptured = myCaptured.addCard(stolenPi);
          }
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);
        final opponentScore = ScoreCalculator.calculateScore(opponentCaptured);

        // Go/Stop 체크 (7점 이상)
        bool waitingForGoStop = false;
        String? goStopPlayer;

        if (myScore.baseTotal >= GameConstants.goStopThreshold) {
          waitingForGoStop = true;
          goStopPlayer = myUid;
        }

        // 다음 턴 결정
        final nextTurn = waitingForGoStop ? myUid : opponentUid;

        // 게임 종료 체크 (덱 소진 시)
        final opponentHand = isPlayer1 ? current.player2Hand : current.player1Hand;
        GameEndState endState = GameEndState.none;
        String? winner;
        int finalScore = 0;

        if (deck.isEmpty && !waitingForGoStop) {
          // 덱이 소진되었을 때 게임 종료 조건 체크
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
          );

          endState = endResult.endState;
          winner = endResult.winner;
          finalScore = endResult.finalScore;
        }

        print('[MatgoLogic] flipDeckOnly: 덱 카드 뒤집기 완료 - event: $event, capture: ${capture.length}장');

        // 새로운 게임 상태 반환
        return current.copyWith(
          turn: nextTurn,
          turnStartTime: DateTime.now().millisecondsSinceEpoch,  // 턴 타이머 리셋
          deck: deck,
          floorCards: floorCards,
          player1Hand: current.player1Hand,
          player2Hand: current.player2Hand,
          player1Captured: isPlayer1 ? myCaptured : opponentCaptured,
          player2Captured: isPlayer1 ? opponentCaptured : myCaptured,
          scores: ScoreInfo(
            player1Score: isPlayer1 ? myScore.baseTotal : opponentScore.baseTotal,
            player2Score: isPlayer1 ? opponentScore.baseTotal : myScore.baseTotal,
            player1GoCount: scores.player1GoCount,
            player2GoCount: scores.player2GoCount,
            player1Multiplier: scores.player1Multiplier,
            player2Multiplier: scores.player2Multiplier,
            player1Shaking: scores.player1Shaking,
            player2Shaking: scores.player2Shaking,
          ),
          lastEvent: event,
          lastEventPlayer: event != SpecialEvent.none ? myUid : null,
          pukCards: pukCards,
          pukOwner: pukOwner,
          endState: endState,
          winner: winner,
          finalScore: finalScore,
          waitingForGoStop: waitingForGoStop,
          goStopPlayer: goStopPlayer,
        );
      },
    );
  }

  /// Go 선언
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

        final isPlayer1 = playerNumber == 1;
        final currentGoCount = isPlayer1
            ? current.scores.player1GoCount
            : current.scores.player2GoCount;

        return current.copyWith(
          turn: opponentUid,  // 턴 넘기기
          turnStartTime: DateTime.now().millisecondsSinceEpoch,  // 턴 타이머 리셋
          waitingForGoStop: false,
          clearGoStopPlayer: true,
          scores: current.scores.copyWith(
            player1GoCount: isPlayer1 ? currentGoCount + 1 : null,
            player2GoCount: isPlayer1 ? null : currentGoCount + 1,
          ),
        );
      },
    );
  }

  /// Stop 선언 (게임 종료)
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

        final isPlayer1 = playerNumber == 1;
        final myCaptured = isPlayer1 ? current.player1Captured : current.player2Captured;
        final opponentCaptured = isPlayer1 ? current.player2Captured : current.player1Captured;

        // 고 횟수와 플레이어 배수
        final goCount = isPlayer1
            ? current.scores.player1GoCount
            : current.scores.player2GoCount;
        final playerMultiplier = isPlayer1
            ? current.scores.player1Multiplier
            : current.scores.player2Multiplier;

        // 최종 점수 계산 (새 ScoreCalculator 사용)
        final finalResult = ScoreCalculator.calculateFinalScore(
          myCaptures: myCaptured,
          opponentCaptures: opponentCaptured,
          goCount: goCount,
          playerMultiplier: playerMultiplier,
        );

        return current.copyWith(
          waitingForGoStop: false,
          clearGoStopPlayer: true,
          endState: GameEndState.win,
          winner: myUid,
          finalScore: finalResult.finalScore,
        );
      },
    );
  }

  /// 덱 카드 선택 완료 (더미 패 뒤집기 시 2장 매칭 선택)
  Future<bool> selectDeckMatchCard({
    required String roomId,
    required String myUid,
    required String opponentUid,
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

        final isPlayer1 = playerNumber == 1;
        var myCaptured = isPlayer1 ? current.player1Captured : current.player2Captured;
        var opponentCaptured = isPlayer1 ? current.player2Captured : current.player1Captured;
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

        // 따닥 체크
        SpecialEvent event = SpecialEvent.none;
        int piToSteal = 0;
        if (firstMatched) {
          event = SpecialEvent.ttadak;
          piToSteal += 1;
        }

        // 카드 획득
        myCaptured = myCaptured.addCards(firstCapture);
        myCaptured = myCaptured.addCards(secondCapture);

        // 싹쓸이 체크
        if (floorCards.isEmpty && (firstCapture.isNotEmpty || secondCapture.isNotEmpty)) {
          if (event == SpecialEvent.none) {
            event = SpecialEvent.sweep;
          }
          piToSteal += 1;
        }

        // 피 뺏기
        for (int i = 0; i < piToSteal; i++) {
          final (newOpponent, stolenPi) = opponentCaptured.removePi();
          if (stolenPi != null) {
            opponentCaptured = newOpponent;
            myCaptured = myCaptured.addCard(stolenPi);
          }
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);
        final opponentScore = ScoreCalculator.calculateScore(opponentCaptured);

        // Go/Stop 체크
        bool waitingForGoStop = false;
        String? goStopPlayer;

        if (myScore.baseTotal >= GameConstants.goStopThreshold) {
          waitingForGoStop = true;
          goStopPlayer = myUid;
        }

        // 게임 종료 체크 (덱 소진 시)
        GameEndState endState = GameEndState.none;
        String? winner;
        int finalScore = 0;

        final myHandEmpty = isPlayer1
            ? current.player1Hand.isEmpty
            : current.player2Hand.isEmpty;
        final opponentHandEmpty = isPlayer1
            ? current.player2Hand.isEmpty
            : current.player1Hand.isEmpty;

        if (current.deck.isEmpty && myHandEmpty && opponentHandEmpty && !waitingForGoStop) {
          // 덱과 손패가 모두 소진되었을 때 게임 종료 조건 체크
          final scores = current.scores;
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
          );

          endState = endResult.endState;
          winner = endResult.winner;
          finalScore = endResult.finalScore;
        }

        return GameState(
          turn: waitingForGoStop ? myUid : opponentUid,
          turnStartTime: DateTime.now().millisecondsSinceEpoch,  // 턴 타이머 리셋
          deck: current.deck,
          floorCards: floorCards,
          player1Hand: current.player1Hand,
          player2Hand: current.player2Hand,
          player1Captured: isPlayer1 ? myCaptured : opponentCaptured,
          player2Captured: isPlayer1 ? opponentCaptured : myCaptured,
          scores: scores.copyWith(
            player1Score: isPlayer1 ? myScore.baseTotal : opponentScore.baseTotal,
            player2Score: isPlayer1 ? opponentScore.baseTotal : myScore.baseTotal,
          ),
          lastEvent: event,
          lastEventPlayer: event != SpecialEvent.none ? myUid : null,
          pukCards: current.pukCards,
          pukOwner: current.pukOwner,
          endState: endState,
          winner: winner,
          finalScore: finalScore,
          waitingForGoStop: waitingForGoStop,
          goStopPlayer: goStopPlayer,
          waitingForDeckSelection: false,
          deckSelectionPlayer: null,
          deckCard: null,
          deckMatchingCards: const [],
          pendingHandCard: null,
          pendingHandMatch: null,
        );
      },
    );
  }

  /// 흔들기 선언
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

        final isPlayer1 = playerNumber == 1;
        final myHand = isPlayer1 ? current.player1Hand : current.player2Hand;

        // 해당 월 카드가 3장 있는지 확인
        final monthCards = myHand.where((c) => c.month == month).toList();
        if (monthCards.length < 3) {
          return current;
        }

        // 흔들기 적용 (배수 2배) - 양쪽 플레이어에게 카드 공개
        return current.copyWith(
          lastEvent: SpecialEvent.shake,
          lastEventPlayer: myUid,
          shakeCards: monthCards,  // 흔들기 카드 공개 (양쪽 모두 볼 수 있음)
          shakePlayer: myUid,
          scores: current.scores.copyWith(
            player1Multiplier: isPlayer1 ? current.scores.player1Multiplier * 2 : null,
            player2Multiplier: isPlayer1 ? null : current.scores.player2Multiplier * 2,
            player1Shaking: isPlayer1 ? true : null,
            player2Shaking: isPlayer1 ? null : true,
          ),
        );
      },
    );
  }

  /// 보너스 카드 사용 (턴 시작 시, 턴 소비 없이 즉시 점수패로 획득)
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

        final isPlayer1 = playerNumber == 1;
        var myHand = List<CardData>.from(
          isPlayer1 ? current.player1Hand : current.player2Hand,
        );
        var myCaptured = isPlayer1 ? current.player1Captured : current.player2Captured;

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
          player1Hand: isPlayer1 ? myHand : current.player1Hand,
          player2Hand: isPlayer1 ? current.player2Hand : myHand,
          player1Captured: isPlayer1 ? myCaptured : current.player1Captured,
          player2Captured: isPlayer1 ? current.player2Captured : myCaptured,
          scores: current.scores.copyWith(
            player1Score: isPlayer1 ? myScore.baseTotal : null,
            player2Score: isPlayer1 ? null : myScore.baseTotal,
          ),
          lastEvent: SpecialEvent.bonusCardUsed,
          lastEventPlayer: myUid,
        );
      },
    );
  }

  /// 폭탄 선언 (손에 3장 + 바닥에 1장 = 4장 한번에 획득)
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

        final isPlayer1 = playerNumber == 1;
        var myHand = List<CardData>.from(
          isPlayer1 ? current.player1Hand : current.player2Hand,
        );
        var myCaptured = isPlayer1 ? current.player1Captured : current.player2Captured;
        var opponentCaptured = isPlayer1 ? current.player2Captured : current.player1Captured;
        var floorCards = List<CardData>.from(current.floorCards);

        // 손에 해당 월 3장, 바닥에 1장 확인
        final handCards = myHand.where((c) => c.month == month).toList();
        final floorCard = floorCards.where((c) => c.month == month).toList();

        if (handCards.length != 3 || floorCard.length != 1) {
          return current;
        }

        // 4장 모두 획득
        for (final c in handCards) {
          myHand.removeWhere((h) => h.id == c.id);
          myCaptured = myCaptured.addCard(c);
        }
        floorCards.removeWhere((f) => f.id == floorCard.first.id);
        myCaptured = myCaptured.addCard(floorCard.first);

        // 피 1장 뺏기
        final (newOpponent, stolenPi) = opponentCaptured.removePi();
        if (stolenPi != null) {
          opponentCaptured = newOpponent;
          myCaptured = myCaptured.addCard(stolenPi);
        }

        // 점수 계산
        final myScore = ScoreCalculator.calculateScore(myCaptured);
        final opponentScore = ScoreCalculator.calculateScore(opponentCaptured);

        return current.copyWith(
          player1Hand: isPlayer1 ? myHand : current.player1Hand,
          player2Hand: isPlayer1 ? current.player2Hand : myHand,
          player1Captured: isPlayer1 ? myCaptured : opponentCaptured,
          player2Captured: isPlayer1 ? opponentCaptured : myCaptured,
          floorCards: floorCards,
          lastEvent: SpecialEvent.bomb,
          lastEventPlayer: myUid,
          scores: current.scores.copyWith(
            player1Score: isPlayer1 ? myScore.baseTotal : opponentScore.baseTotal,
            player2Score: isPlayer1 ? opponentScore.baseTotal : myScore.baseTotal,
            player1Multiplier: isPlayer1 ? current.scores.player1Multiplier * 2 : null,
            player2Multiplier: isPlayer1 ? null : current.scores.player2Multiplier * 2,
            player1Bomb: isPlayer1 ? true : null,
            player2Bomb: isPlayer1 ? null : true,
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

    final isPlayer1 = playerNumber == 1;
    final myHand = isPlayer1 ? gameState.player1Hand : gameState.player2Hand;

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
}
