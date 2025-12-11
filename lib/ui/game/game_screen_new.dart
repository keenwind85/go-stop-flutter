import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card_data.dart';
import '../../models/game_room.dart';
import '../../models/user_wallet.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/matgo_logic_service.dart';
import '../../services/sound_service.dart';
import '../../services/coin_service.dart';
import '../../game/systems/score_calculator.dart';
import '../widgets/game_result_dialog.dart';
import '../widgets/special_event_overlay.dart';
import '../widgets/card_selection_dialog.dart';
import '../widgets/action_buttons.dart';
import '../widgets/shake_cards_overlay.dart';
import '../widgets/chongtong_cards_overlay.dart';
import '../screens/lobby_screen.dart';
import 'widgets/opponent_zone.dart';
import 'widgets/floor_zone.dart';
import 'widgets/player_zone.dart';
import 'animations/animations.dart';
import '../widgets/screen_size_warning_overlay.dart';
import '../widgets/retro_background.dart';
import '../widgets/retro_button.dart';
import '../widgets/gwangkki_gauge.dart';
import '../widgets/first_turn_overlay.dart';
import '../../config/constants.dart';

/// 디자인 가이드 기반 색상


/// 새로운 세로형 모바일 맞고 게임 화면
///
/// 레이아웃 비율:
/// - Top Zone (상대방): 20%
/// - Center Zone (바닥): 40%
/// - Bottom Zone (플레이어): 40%
class GameScreenNew extends ConsumerStatefulWidget {
  final String roomId;
  final bool isHost;

  const GameScreenNew({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  ConsumerState<GameScreenNew> createState() => _GameScreenNewState();
}

class _GameScreenNewState extends ConsumerState<GameScreenNew>
    with TickerProviderStateMixin {
  StreamSubscription<GameRoom?>? _roomSubscription;
  GameRoom? _currentRoom;
  bool _isGameStarted = false;

  // 코인 잔액 상태
  StreamSubscription<UserWallet?>? _myWalletSubscription;
  StreamSubscription<UserWallet?>? _opponentWalletSubscription;
  int? _myCoinBalance;
  int? _opponentCoinBalance;

  // 게임 결과 코인 정산 정보
  int? _coinTransferAmount;
  bool _coinSettlementDone = false;

  // UI 상태
  SpecialEvent _lastShownEvent = SpecialEvent.none;
  bool _showingEvent = false;
  bool _showingGoStop = false;
  bool _showingResult = false;
  bool _rematchRequested = false;
  bool _opponentRematchRequested = false;

  // 재대결 타이머 상태
  Timer? _rematchTimer;
  int _rematchCountdown = 15;
  bool _opponentLeftDuringRematch = false;

  // 카드 선택 상태 (손패 2장 매칭)
  bool _showingCardSelection = false;
  List<CardData> _selectionOptions = [];
  CardData? _playedCardForSelection;
  CardData? _selectedHandCard;

  // 덱 카드 선택 상태 (더미 패 2장 매칭)
  bool _showingDeckSelection = false;
  List<CardData> _deckSelectionOptions = [];
  CardData? _deckCardForSelection;

  // 보너스 카드 사용 애니메이션 상태
  bool _showingBonusCardEffect = false;
  CardData? _bonusCardForEffect;
  Offset? _bonusCardStartPosition;
  Offset? _bonusCardEndPosition;

  // 흔들기 카드 공개 오버레이 상태
  bool _showingShakeCards = false;
  List<CardData> _shakeCards = [];

  // 총통 카드 공개 오버레이 상태
  bool _showingChongtongCards = false;
  List<CardData> _chongtongCards = [];
  String? _chongtongWinnerName;

  // 선 결정 오버레이 상태
  bool _showingFirstTurnOverlay = false;
  String? _firstTurnReason;
  String? _firstTurnPlayerName;
  bool _firstTurnIsMe = false;

  // 光끼 모드 상태
  bool _gwangkkiModeActive = false;
  bool _showingGwangkkiAlert = false;
  String? _gwangkkiActivator;
  double _myGwangkkiScore = 0;
  bool _canActivateGwangkki = false;

  // 턴 타이머 상태
  Timer? _turnTimer;
  int _remainingSeconds = 60;
  static const int _turnDuration = 60;  // 60초 턴 제한

  // 사운드
  late SoundService _soundService;

  // 애니메이션 컨트롤러
  late AnimationController _pulseController;

  // 이전 게임 상태 추적 (애니메이션 트리거용)
  GameState? _previousGameState;
  bool _processingAnimations = false;

  /// 덱에서 바닥으로 애니메이션 중인 카드 ID들
  /// 이 Set에 포함된 카드는 FloorZone에서 숨겨져서 중복 표시 방지
  final Set<String> _animatingDeckCardIds = {};

  // 카드 애니메이션 시스템
  late CardAnimationController _cardAnimController;
  final CardPositionTracker _positionTracker = CardPositionTracker();
  final GlobalKey _deckKey = GlobalKey();
  final GlobalKey _playerCaptureKey = GlobalKey();
  final GlobalKey _opponentCaptureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _soundService = ref.read(soundServiceProvider);
    _soundService.initialize();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 카드 애니메이션 컨트롤러 초기화
    _cardAnimController = CardAnimationController();
    _cardAnimController.initialize(
      this,
      onImpactSound: () => _soundService.playCardPlace(),
      onSweepSound: () => _soundService.playSpecialEvent(SpecialEvent.none),
    );
    _cardAnimController.addListener(() {
      if (mounted) setState(() {});
    });

    _listenToRoom();
    _listenToCoins();
  }

  void _listenToRoom() {
    final roomService = ref.read(roomServiceProvider);
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    _roomSubscription = roomService.watchRoom(widget.roomId).listen((room) {
      if (room == null) {
        _showRoomDeletedDialog();
        return;
      }

      final previousRoom = _currentRoom;

      // ★ 중요: setState 전에 현재 바닥 카드 위치를 캡처 (애니메이션용)
      // setState 후에는 UI가 리빌드되어 GlobalKey가 사라질 수 있음
      final cachedFloorPositions = <String, Offset>{};
      if (previousRoom?.gameState != null) {
        for (final card in previousRoom!.gameState!.floorCards) {
          final pos = _positionTracker.getCardPosition('floor_${card.id}');
          if (pos != null) {
            cachedFloorPositions['floor_${card.id}'] = pos;
          }
        }
      }

      // 이전 재대결 상태 저장
      final wasOpponentRematchRequested = _opponentRematchRequested;
      final wasRematchRequested = _rematchRequested;

      final newOpponentRematchRequested = widget.isHost
          ? room.guestRematchRequest
          : room.hostRematchRequest;

      // 光끼 모드 상태 변경 감지
      final wasGwangkkiActive = _gwangkkiModeActive;
      final newGwangkkiActive = room.gwangkkiModeActive;
      final newGwangkkiActivator = room.gwangkkiActivator;

      setState(() {
        _currentRoom = room;
        _rematchRequested = widget.isHost
            ? room.hostRematchRequest
            : room.guestRematchRequest;
        _opponentRematchRequested = newOpponentRematchRequested;
        _gwangkkiModeActive = newGwangkkiActive;
        _gwangkkiActivator = newGwangkkiActivator;
      });

      // 光끼 모드가 새로 활성화되면 알림 표시
      if (!wasGwangkkiActive && newGwangkkiActive) {
        _showGwangkkiModeAlert();
      }

      // 상대방 코인 구독 업데이트 (게스트가 입장했을 때)
      if (previousRoom?.guest == null && room.guest != null) {
        _updateOpponentCoinSubscription();
      }

      // 재대결 대기 중 상대방이 나갔는지 확인
      if (_showingResult && wasRematchRequested && !_opponentLeftDuringRematch) {
        // 게스트가 나갔는지 확인 (이전에 있었는데 없어짐)
        if (previousRoom?.guest != null && room.guest == null) {
          _opponentLeftDuringRematch = true;
          _showOpponentLeftDialog();
          return;
        }
      }

      // 내가 재대결 요청 후 상대방이 수락한 경우 알림
      if (wasRematchRequested &&
          !wasOpponentRematchRequested &&
          newOpponentRematchRequested &&
          room.bothWantRematch) {
        _showRematchAcceptedDialog();
      }

      // 양쪽 모두 재대결 요청 시 게임 재시작
      if (room.bothWantRematch && widget.isHost) {
        _cancelRematchTimer();
        _startRematch();
      }

      // 호스트이고 방이 가득 찼으면 게임 시작
      if (widget.isHost &&
          room.isFull &&
          room.state == RoomState.waiting &&
          !_isGameStarted) {
        _startGame();
      }

      // 게임 상태 업데이트
      if (room.gameState != null) {
        // 선 결정 오버레이 표시 (게임이 처음 시작된 경우)
        if (previousRoom?.gameState == null &&
            room.gameState!.firstTurnReason != null &&
            !_showingFirstTurnOverlay) {
          // 선 플레이어 이름 결정
          String? firstPlayerName;
          if (room.gameState!.firstTurnPlayer == room.host.uid) {
            firstPlayerName = room.host.displayName;
          } else if (room.guest != null &&
              room.gameState!.firstTurnPlayer == room.guest!.uid) {
            firstPlayerName = room.guest!.displayName;
          }

          if (firstPlayerName != null) {
            setState(() {
              _firstTurnReason = room.gameState!.firstTurnReason;
              _firstTurnPlayerName = firstPlayerName;
              _firstTurnIsMe = room.gameState!.firstTurnPlayer == myUid;
              _showingFirstTurnOverlay = true;
            });
          }
        }

        // 턴 변경 시 효과음 및 타이머 업데이트
        if (previousRoom?.gameState?.turn != room.gameState!.turn) {
          if (room.gameState!.turn == myUid) {
            _soundService.playTurnNotify();
          }
          // 턴 타이머 업데이트
          _updateTurnTimer(room.gameState!);
        } else {
          // 턴이 변경되지 않았어도 타이머 시간 업데이트
          _updateRemainingSeconds(room.gameState!);
        }

        // 특수 이벤트 표시
        if (room.gameState!.lastEvent != SpecialEvent.none &&
            room.gameState!.lastEvent != _lastShownEvent &&
            !_showingEvent) {
          // 보너스 카드 사용 이벤트는 별도 처리 (상대방의 경우)
          if (room.gameState!.lastEvent == SpecialEvent.bonusCardUsed &&
              room.gameState!.lastEventPlayer != myUid &&
              !_showingBonusCardEffect) {
            _showOpponentBonusCardEffect();
          }

          // 흔들기 이벤트: shakeCards가 있으면 양쪽 플레이어 모두에게 표시
          if (room.gameState!.lastEvent == SpecialEvent.shake &&
              room.gameState!.shakeCards.isNotEmpty &&
              !_showingShakeCards) {
            setState(() {
              _shakeCards = room.gameState!.shakeCards;
              _showingShakeCards = true;
            });
          }

          // 총통 이벤트: chongtongCards가 있으면 양쪽 플레이어 모두에게 표시
          if (room.gameState!.lastEvent == SpecialEvent.chongtong &&
              room.gameState!.chongtongCards.isNotEmpty &&
              !_showingChongtongCards) {
            // 승리자 이름 결정
            String? winnerName;
            if (room.gameState!.chongtongPlayer != null) {
              if (room.gameState!.chongtongPlayer == room.host.uid) {
                winnerName = room.host.displayName;
              } else if (room.guest != null &&
                  room.gameState!.chongtongPlayer == room.guest!.uid) {
                winnerName = room.guest!.displayName;
              }
            }
            setState(() {
              _chongtongCards = room.gameState!.chongtongCards;
              _chongtongWinnerName = winnerName;
              _showingChongtongCards = true;
            });
          }

          _showSpecialEvent(
            room.gameState!.lastEvent,
            room.gameState!.lastEventPlayer == myUid,
          );
        }

        // Go/Stop 다이얼로그 표시
        if (room.gameState!.waitingForGoStop &&
            room.gameState!.goStopPlayer == myUid &&
            !_showingGoStop &&
            !_showingResult) {
          _showGoStopDialog();
        }

        // 덱 카드 선택 다이얼로그 표시 (더미 패 2장 매칭)
        if (room.gameState!.waitingForDeckSelection &&
            room.gameState!.deckSelectionPlayer == myUid &&
            !_showingDeckSelection &&
            !_showingResult) {
          _showDeckSelectionDialog(room.gameState!);
        }

        // 게임 종료 결과 표시
        // 일반 게임 종료: 이전 상태가 none이었다가 종료된 경우
        // 총통 종료: 총통 카드 오버레이가 없고, endState가 chongtong인 경우
        final isNormalGameEnd = room.gameState!.endState != GameEndState.none &&
            previousRoom?.gameState?.endState == GameEndState.none;
        final isChongtongEnd = room.gameState!.endState == GameEndState.chongtong &&
            !_showingChongtongCards &&
            room.gameState!.chongtongCards.isNotEmpty;

        if ((isNormalGameEnd || isChongtongEnd) && !_showingResult) {
          // 총통인 경우 오버레이 먼저 표시
          if (room.gameState!.endState == GameEndState.chongtong &&
              !_showingChongtongCards &&
              _chongtongCards.isEmpty) {
            // 첫 진입 시 총통 카드 오버레이 표시
            String? winnerName;
            if (room.gameState!.chongtongPlayer != null) {
              if (room.gameState!.chongtongPlayer == room.host.uid) {
                winnerName = room.host.displayName;
              } else if (room.guest != null &&
                  room.gameState!.chongtongPlayer == room.guest!.uid) {
                winnerName = room.guest!.displayName;
              }
            }
            setState(() {
              _chongtongCards = room.gameState!.chongtongCards;
              _chongtongWinnerName = winnerName;
              _showingChongtongCards = true;
            });
          } else if (!_showingChongtongCards) {
            // 총통 오버레이가 끝났거나 일반 게임 종료인 경우
            _showGameResult();
          }
        }

        // 상태 변화 기반 애니메이션 처리 (시나리오 B, C)
        _processStateChangeAnimations(
          previousRoom?.gameState,
          room.gameState!,
          myUid,
          cachedFloorPositions, // 캐시된 바닥 카드 위치 전달
        );
      }
    });
  }

  void _listenToCoins() {
    final coinService = ref.read(coinServiceProvider);
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    if (myUid == null) return;

    // 내 코인 및 光끼 점수 구독
    _myWalletSubscription = coinService.getUserWalletStream(myUid).listen((wallet) {
      if (mounted) {
        setState(() {
          _myCoinBalance = wallet?.coin;
          _myGwangkkiScore = wallet?.gwangkkiScore ?? 0;
          _canActivateGwangkki = wallet?.canActivateGwangkkiMode ?? false;
        });
      }
    });

    // 상대방 uid는 방 정보에서 가져옴
    // _currentRoom이 설정된 후에 상대방 구독 시작
    _updateOpponentCoinSubscription();
  }

  void _updateOpponentCoinSubscription() {
    if (_currentRoom == null) return;

    final coinService = ref.read(coinServiceProvider);
    final opponentUid = widget.isHost
        ? _currentRoom?.guest?.uid
        : _currentRoom?.host.uid;

    if (opponentUid == null) return;

    _opponentWalletSubscription?.cancel();
    _opponentWalletSubscription = coinService.getUserWalletStream(opponentUid).listen((wallet) {
      if (mounted) {
        setState(() {
          _opponentCoinBalance = wallet?.coin;
        });
      }
    });
  }

  Future<void> _startGame() async {
    if (!widget.isHost || _currentRoom == null) return;

    setState(() => _isGameStarted = true);

    try {
      final matgoLogic = ref.read(matgoLogicServiceProvider);
      await matgoLogic.initializeGame(
        roomId: widget.roomId,
        hostUid: _currentRoom!.host.uid,
        guestUid: _currentRoom!.guest!.uid,
        hostName: _currentRoom!.host.displayName,
        guestName: _currentRoom!.guest!.displayName,
        gameCount: _currentRoom!.gameCount,
        lastWinner: _currentRoom!.lastWinner,
      );
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _startRematch() async {
    _cancelRematchTimer();

    final roomService = ref.read(roomServiceProvider);
    // 재대결 시 이전 승자와 게임 카운트를 전달
    final lastWinner = _currentRoom?.gameState?.winner;
    final currentGameCount = _currentRoom?.gameCount ?? 0;
    await roomService.startRematch(
      roomId: widget.roomId,
      lastWinner: lastWinner,
      currentGameCount: currentGameCount,
    );

    setState(() {
      _isGameStarted = false;
      _showingResult = false;
      _rematchRequested = false;
      _opponentRematchRequested = false;
      _lastShownEvent = SpecialEvent.none;
      _previousGameState = null;
      _coinTransferAmount = null;
      _coinSettlementDone = false;
      _rematchCountdown = 15;
      _opponentLeftDuringRematch = false;
    });

    // 호스트는 재대결 후 즉시 새 게임 시작
    if (widget.isHost && _currentRoom?.isFull == true) {
      // 약간의 지연을 주어 상태가 안정화된 후 게임 시작
      await Future.delayed(const Duration(milliseconds: 100));
      _startGame();
    }
  }

  /// 상태 변화를 감지하여 애니메이션을 트리거합니다 (시나리오 B, C)
  Future<void> _processStateChangeAnimations(
    GameState? previousState,
    GameState currentState,
    String? myUid,
    Map<String, Offset> cachedFloorPositions, // setState 전에 캡처한 바닥 카드 위치
  ) async {
    // 이전 상태가 없거나 애니메이션 처리 중이면 무시
    if (previousState == null || _processingAnimations) {
      _previousGameState = currentState;
      return;
    }

    // 중복 처리 방지
    if (_previousGameState == currentState) return;

    _processingAnimations = true;

    try {
      // 1. 시나리오 B: 덱에서 카드가 뒤집어졌는지 확인
      await _processScenarioB(previousState, currentState, cachedFloorPositions);

      // 개선: 스택 상태 표시를 위한 딜레이 추가
      // 카드들이 바닥에 쌓인 상태를 볼 시간을 확보 (특히 따닥, 뻑 상황에서 중요)
      await Future.delayed(const Duration(milliseconds: 400));

      // 2. 시나리오 C: 카드가 획득되었는지 확인
      await _processScenarioC(previousState, currentState, myUid, cachedFloorPositions);
    } finally {
      _previousGameState = currentState;
      _processingAnimations = false;
    }
  }

  /// 시나리오 B: 덱 → 플립 → 바닥 애니메이션
  Future<void> _processScenarioB(
    GameState previousState,
    GameState currentState,
    Map<String, Offset> cachedFloorPositions,
  ) async {
    // 덱 카드 수가 감소했는지 확인
    if (currentState.deck.length >= previousState.deck.length) {
      debugPrint('[ScenarioB] 덱 변화 없음 (이전: ${previousState.deck.length}, 현재: ${currentState.deck.length})');
      return;
    }

    debugPrint('[ScenarioB] === 시작 ===');
    debugPrint('[ScenarioB] 이전 바닥: ${previousState.floorCards.map((c) => '${c.id}(${c.month}월)').toList()}');
    debugPrint('[ScenarioB] 현재 바닥: ${currentState.floorCards.map((c) => '${c.id}(${c.month}월)').toList()}');
    debugPrint('[ScenarioB] 캐시된 위치: ${cachedFloorPositions.keys.toList()}');

    // 이전 상태에서 존재하던 모든 카드 ID 수집
    final previousFloorIds = previousState.floorCards.map((c) => c.id).toSet();
    final previousHand1Ids = previousState.player1Hand.map((c) => c.id).toSet();
    final previousHand2Ids = previousState.player2Hand.map((c) => c.id).toSet();
    final previousCaptured1Ids = {
      ...previousState.player1Captured.kwang.map((c) => c.id),
      ...previousState.player1Captured.animal.map((c) => c.id),
      ...previousState.player1Captured.ribbon.map((c) => c.id),
      ...previousState.player1Captured.pi.map((c) => c.id),
    };
    final previousCaptured2Ids = {
      ...previousState.player2Captured.kwang.map((c) => c.id),
      ...previousState.player2Captured.animal.map((c) => c.id),
      ...previousState.player2Captured.ribbon.map((c) => c.id),
      ...previousState.player2Captured.pi.map((c) => c.id),
    };

    // 이전에 존재하던 모든 카드 (덱 제외)
    final allPreviousKnownIds = {
      ...previousFloorIds,
      ...previousHand1Ids,
      ...previousHand2Ids,
      ...previousCaptured1Ids,
      ...previousCaptured2Ids,
    };

    // 손패에서 사라진 카드 (플레이된 카드)
    final currentHand1Ids = currentState.player1Hand.map((c) => c.id).toSet();
    final currentHand2Ids = currentState.player2Hand.map((c) => c.id).toSet();
    final playedFromHand1 = previousHand1Ids.difference(currentHand1Ids);
    final playedFromHand2 = previousHand2Ids.difference(currentHand2Ids);
    final playedCardIds = playedFromHand1.union(playedFromHand2);
    debugPrint('[ScenarioB] 손패에서 플레이된 카드: $playedCardIds');

    // 현재 상태에서 새로 나타난 모든 카드 수집 (바닥 + 획득 영역)
    final currentFloorCards = currentState.floorCards;
    final currentCaptured1Cards = [
      ...currentState.player1Captured.kwang,
      ...currentState.player1Captured.animal,
      ...currentState.player1Captured.ribbon,
      ...currentState.player1Captured.pi,
    ];
    final currentCaptured2Cards = [
      ...currentState.player2Captured.kwang,
      ...currentState.player2Captured.animal,
      ...currentState.player2Captured.ribbon,
      ...currentState.player2Captured.pi,
    ];

    // 새로 나타난 카드들 (이전에 없던 카드)
    final allNewCards = <CardData>[];
    for (final card in currentFloorCards) {
      if (!allPreviousKnownIds.contains(card.id)) {
        allNewCards.add(card);
        debugPrint('[ScenarioB] 새 바닥 카드: ${card.id} (${card.month}월)');
      }
    }
    for (final card in currentCaptured1Cards) {
      if (!allPreviousKnownIds.contains(card.id)) {
        allNewCards.add(card);
        debugPrint('[ScenarioB] 새 획득1 카드: ${card.id} (${card.month}월)');
      }
    }
    for (final card in currentCaptured2Cards) {
      if (!allPreviousKnownIds.contains(card.id)) {
        allNewCards.add(card);
        debugPrint('[ScenarioB] 새 획득2 카드: ${card.id} (${card.month}월)');
      }
    }

    // 덱에서 뒤집힌 카드만 필터 (손패에서 나온 것 제외)
    final flippedFromDeck = allNewCards
        .where((c) => !playedCardIds.contains(c.id))
        .toList();

    debugPrint('[ScenarioB] 덱에서 뒤집힌 카드 후보: ${flippedFromDeck.map((c) => '${c.id}(${c.month}월)').toList()}');

    if (flippedFromDeck.isEmpty) {
      debugPrint('[ScenarioB] 덱에서 뒤집힌 카드 없음 - 종료');
      return;
    }

    // 덱 위치 계산
    final deckPosition = _positionTracker.getDeckPosition(_deckKey);
    if (deckPosition == null) {
      debugPrint('[ScenarioB] 덱 위치를 찾을 수 없음 - 종료');
      return;
    }

    // 첫 번째 뒤집힌 카드에 대해 애니메이션 실행
    final flippedCard = flippedFromDeck.first;
    debugPrint('[ScenarioB] 덱에서 뒤집힌 카드 확정: ${flippedCard.id} (${flippedCard.month}월)');

    // 바닥 카드 위치 계산
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    Offset targetPosition;

    // ★ 핵심 로직: 뒤집힌 카드가 현재 바닥에 있는지로 매칭 여부 판단
    // - 바닥에 있음 = 매칭 없음 (바닥에 놓임)
    // - 바닥에 없음 = 매칭됨 (획득됨)
    final flippedCardInFloor = currentState.floorCards.any((c) => c.id == flippedCard.id);
    debugPrint('[ScenarioB] 뒤집힌 카드가 현재 바닥에 있음: $flippedCardInFloor');

    // 현재 바닥에 있는 같은 월 카드 (뒤집힌 카드 제외)
    final currentSameMonthFloor = currentState.floorCards
        .where((c) => c.month == flippedCard.month && c.id != flippedCard.id)
        .toList();
    debugPrint('[ScenarioB] 현재 바닥에 남은 ${flippedCard.month}월 카드: ${currentSameMonthFloor.map((c) => c.id).toList()}');

    // 이전 상태에서 같은 월 카드 (매칭 위치 추적용)
    final previousSameMonthFloor = previousState.floorCards
        .where((c) => c.month == flippedCard.month)
        .toList();
    debugPrint('[ScenarioB] 이전 바닥 ${flippedCard.month}월 카드: ${previousSameMonthFloor.map((c) => c.id).toList()}');

    CardData? matchingFloorCard;
    bool hasNoMatch = false;
    bool isKissScenario = false; // 쪽(Kiss) 상황 감지

    // ★ 쪽(Kiss) 상황 감지 로직:
    // - 손패에서 플레이된 카드가 현재 바닥에 있음 (바닥에 놓임)
    // - 덱에서 뒤집힌 카드가 그 손패 카드와 같은 월
    // - 두 카드가 함께 획득됨 (현재 상태에서 둘 다 바닥에 없음)
    CardData? playedHandCard;
    for (final cardId in playedCardIds) {
      // 플레이된 카드 중 뒤집힌 카드와 같은 월인 카드 찾기
      // 이전 상태의 손패에서 찾아야 함
      for (final card in previousState.player1Hand) {
        if (card.id == cardId && card.month == flippedCard.month) {
          playedHandCard = card;
          break;
        }
      }
      if (playedHandCard == null) {
        for (final card in previousState.player2Hand) {
          if (card.id == cardId && card.month == flippedCard.month) {
            playedHandCard = card;
            break;
          }
        }
      }
      if (playedHandCard != null) break;
    }

    // 쪽 감지: 플레이된 손패 카드가 덱 카드와 같은 월
    if (playedHandCard != null) {
      debugPrint('[ScenarioB] ★ 쪽(Kiss) 감지: 손패 ${playedHandCard.id} + 덱 ${flippedCard.id} (${flippedCard.month}월)');
      isKissScenario = true;
    }

    if (flippedCardInFloor) {
      // 뒤집힌 카드가 바닥에 있음 = 매칭 없음
      hasNoMatch = true;
      debugPrint('[ScenarioB] ★ 매칭 없음 - 뒤집힌 카드가 바닥에 놓임');

      // 빈 공간 위치 계산 (현재 바닥 카드 수 기준)
      final floorCardCount = currentState.floorCards.length;
      final radius = screenSize.width * 0.25;
      final angleStep = (2 * math.pi) / math.max(8, floorCardCount);
      // 뒤집힌 카드의 인덱스 찾기
      final flippedIndex = currentState.floorCards.indexWhere((c) => c.id == flippedCard.id);
      final angle = -math.pi / 2 + (flippedIndex * angleStep);

      targetPosition = Offset(
        screenSize.width / 2 + radius * math.cos(angle),
        safeAreaTop + screenSize.height * 0.4 + radius * math.sin(angle) * 0.6,
      );
      debugPrint('[ScenarioB] 빈 공간 위치: $targetPosition (인덱스: $flippedIndex, 총 $floorCardCount장)');
    } else if (isKissScenario && playedHandCard != null) {
      // ★ 쪽 상황: 덱 카드를 손패 카드 위치로 보냄
      debugPrint('[ScenarioB] ★ 쪽 처리 - 덱 카드를 손패 카드(${playedHandCard.id}) 위치로 이동');

      // 손패 카드의 현재 바닥 위치 찾기
      final playedCardFloorKey = 'floor_${playedHandCard.id}';
      var playedCardPos = cachedFloorPositions[playedCardFloorKey];

      if (playedCardPos == null) {
        playedCardPos = _positionTracker.getCardPosition(playedCardFloorKey);
      }

      if (playedCardPos != null) {
        // 스택 offset 적용
        const stackOffset = Offset(4, -6);
        targetPosition = playedCardPos + stackOffset;
        debugPrint('[ScenarioB] ✓ 쪽 - 손패 카드 위치 확정 (스택 offset 적용): ${playedHandCard.id}');
      } else {
        // 폴백: 화면 중앙
        targetPosition = Offset(
          screenSize.width / 2,
          safeAreaTop + screenSize.height * 0.4,
        );
        debugPrint('[ScenarioB] ⚠ 쪽 - 손패 카드 위치 없음, 폴백 사용');
      }
    } else {
      // 뒤집힌 카드가 바닥에 없음 = 매칭되어 획득됨
      debugPrint('[ScenarioB] ★ 매칭됨 - 뒤집힌 카드가 획득됨');

      // 2장 이상인 경우 어떤 카드와 매칭됐는지 정확히 찾기
      // 방법: 이전 바닥에 있던 카드 중 현재 바닥에 없는 카드가 매칭된 카드
      final currentFloorIds = currentState.floorCards.map((c) => c.id).toSet();

      if (previousSameMonthFloor.isNotEmpty) {
        // 이전 바닥에서 사라진 같은 월 카드 찾기 (실제로 매칭된 카드)
        final matchedCards = previousSameMonthFloor
            .where((c) => !currentFloorIds.contains(c.id))
            .toList();

        if (matchedCards.isNotEmpty) {
          matchingFloorCard = matchedCards.first;
          debugPrint('[ScenarioB] 실제 매칭된 카드 감지: ${matchingFloorCard.id}');
        } else if (previousSameMonthFloor.length >= 2) {
          // 2장 이상이었는데 하나만 사라진 경우 (뻑 등 특수 상황)
          matchingFloorCard = previousSameMonthFloor.first;
          debugPrint('[ScenarioB] 특수 상황 - 첫번째 카드 사용: ${matchingFloorCard.id}');
        } else {
          matchingFloorCard = previousSameMonthFloor.first;
          debugPrint('[ScenarioB] 단일 매칭: ${matchingFloorCard.id}');
        }

        final matchKey = 'floor_${matchingFloorCard.id}';

        // 1. 캐시된 위치 시도
        var matchPos = cachedFloorPositions[matchKey];
        debugPrint('[ScenarioB] 캐시된 위치 조회 ($matchKey): $matchPos');

        // 2. 캐시 없으면 현재 위치 시도
        if (matchPos == null) {
          matchPos = _positionTracker.getCardPosition(matchKey);
          debugPrint('[ScenarioB] 현재 위치 조회 ($matchKey): $matchPos');
        }

        if (matchPos != null) {
          // 스택 offset 적용: 매칭 카드 위에 쌓이는 것처럼 보이도록
          const stackOffset = Offset(4, -6); // 우상향으로 살짝 비켜서 쌓임
          targetPosition = matchPos + stackOffset;
          debugPrint('[ScenarioB] ✓ 매칭 카드 위치 확정 (스택 offset 적용): ${matchingFloorCard.id} (${matchingFloorCard.month}월)');
        } else {
          // 폴백: 화면 중앙
          targetPosition = Offset(
            screenSize.width / 2,
            safeAreaTop + screenSize.height * 0.4,
          );
          debugPrint('[ScenarioB] ⚠ 매칭 카드 위치 없음, 폴백 사용');
        }
      } else {
        // 이전 상태에도 같은 월 카드 없음 (비정상 상황)
        targetPosition = Offset(
          screenSize.width / 2,
          safeAreaTop + screenSize.height * 0.4,
        );
        debugPrint('[ScenarioB] ⚠ 비정상: 이전 상태에 매칭 카드 없음, 폴백 사용');
      }
    }

    // ★ 애니메이션 시작 전: 카드 ID를 숨김 목록에 추가
    // 이렇게 하면 FloorZone에서 해당 카드가 렌더링되지 않음 (중복 표시 방지)
    setState(() {
      _animatingDeckCardIds.add(flippedCard.id);
    });
    debugPrint('[ScenarioB] ★ 카드 ${flippedCard.id} 숨김 목록에 추가');

    // 덱 플립 애니메이션 실행 (시나리오 B)
    // hasNoMatch가 true면 "맞는 바닥패가 없어요" 메시지 표시
    await _cardAnimController.animateFlipFromDeck(
      card: flippedCard,
      deckPosition: deckPosition,
      floorPosition: targetPosition,
      hasNoMatch: hasNoMatch,
    );

    // ★ 애니메이션 완료 후: 카드 ID를 숨김 목록에서 제거
    // 이제 FloorZone에서 해당 카드가 정상적으로 렌더링됨
    setState(() {
      _animatingDeckCardIds.remove(flippedCard.id);
    });
    debugPrint('[ScenarioB] ★ 카드 ${flippedCard.id} 숨김 목록에서 제거');

    debugPrint('[ScenarioB] === 완료 === (매칭 없음: $hasNoMatch)');
  }

  /// 시나리오 C: 바닥 → 획득 영역 애니메이션
  Future<void> _processScenarioC(
    GameState previousState,
    GameState currentState,
    String? myUid,
    Map<String, Offset> cachedFloorPositions, // setState 전에 캡처한 바닥 카드 위치
  ) async {
    final isPlayer1 = widget.isHost;

    // 이전 획득 패와 현재 획득 패 비교
    final prevCaptured = isPlayer1
        ? previousState.player1Captured
        : previousState.player2Captured;
    final currCaptured = isPlayer1
        ? currentState.player1Captured
        : currentState.player2Captured;

    // 새로 획득한 카드 계산
    final prevAllIds = {
      ...prevCaptured.kwang.map((c) => c.id),
      ...prevCaptured.animal.map((c) => c.id),
      ...prevCaptured.ribbon.map((c) => c.id),
      ...prevCaptured.pi.map((c) => c.id),
    };

    final currAllCards = [
      ...currCaptured.kwang,
      ...currCaptured.animal,
      ...currCaptured.ribbon,
      ...currCaptured.pi,
    ];

    // 손패에서 플레이된 카드 식별 (Scenario A에서 이미 처리됨)
    final previousHand1Ids = previousState.player1Hand.map((c) => c.id).toSet();
    final previousHand2Ids = previousState.player2Hand.map((c) => c.id).toSet();
    final currentHand1Ids = currentState.player1Hand.map((c) => c.id).toSet();
    final currentHand2Ids = currentState.player2Hand.map((c) => c.id).toSet();
    final playedFromHand = previousHand1Ids.difference(currentHand1Ids)
        .union(previousHand2Ids.difference(currentHand2Ids));

    debugPrint('[ScenarioC] 손패에서 플레이된 카드 (Scenario A에서 처리됨): $playedFromHand');

    // 새로 획득한 카드 중 손패에서 플레이된 카드는 제외 (Scenario A에서 이미 처리됨)
    final newlyCaptured = currAllCards
        .where((c) => !prevAllIds.contains(c.id))
        .where((c) => !playedFromHand.contains(c.id)) // 손패 카드 제외
        .toList();

    if (newlyCaptured.isEmpty) {
      debugPrint('[ScenarioC] 새로 획득한 바닥 카드 없음 (손패 카드 제외 후)');
      return;
    }

    debugPrint('[ScenarioC] 새로 획득한 바닥 카드 ${newlyCaptured.length}장: ${newlyCaptured.map((c) => c.id).toList()}');

    // 이전 바닥에 있던 카드 위치들 수집 (캐시된 위치 우선 사용)
    final positions = <Offset>[];
    for (final card in newlyCaptured) {
      final floorKey = 'floor_${card.id}';
      final pos = cachedFloorPositions[floorKey] ??
          _positionTracker.getCardPosition(floorKey);
      if (pos != null) {
        positions.add(pos);
        debugPrint('[ScenarioC] 카드 ${card.id} 위치: $pos');
      }
    }

    // 위치를 못 구한 경우 화면 중앙 사용
    if (positions.isEmpty) {
      final screenSize = MediaQuery.of(context).size;
      final safeAreaTop = MediaQuery.of(context).padding.top;
      positions.add(Offset(
        screenSize.width / 2,
        safeAreaTop + screenSize.height * 0.4,
      ));
    }

    // 획득 영역 위치 계산
    final capturePosition = _positionTracker.getCaptureZonePosition(_playerCaptureKey);
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    final targetPosition = capturePosition ?? Offset(
      screenSize.width * 0.2,
      safeAreaTop + screenSize.height * 0.75,
    );

    // 피 보너스 계산
    final prevPiCount = prevCaptured.piCount;
    final currPiCount = currCaptured.piCount;
    final bonusCount = currPiCount > prevPiCount ? currPiCount - prevPiCount : null;

    // 카드 획득 애니메이션 실행 (시나리오 C)
    await _cardAnimController.animateCollectCards(
      cards: newlyCaptured,
      fromPositions: positions,
      toPosition: targetPosition,
      bonusCount: bonusCount,
    );
  }

  void _onHandCardTap(CardData card) {
    final gameState = _currentRoom?.gameState;
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    if (gameState == null || gameState.turn != myUid) return;
    if (_showingGoStop || _showingResult || _showingCardSelection || _showingDeckSelection) return;
    if (_showingBonusCardEffect) return;

    // 보너스 카드인 경우 즉시 사용 처리
    if (card.isBonus) {
      _useBonusCard(card);
      return;
    }

    setState(() {
      if (_selectedHandCard?.id == card.id) {
        _selectedHandCard = null;
      } else {
        _selectedHandCard = card;
      }
    });
  }

  /// 보너스 카드 사용 처리
  Future<void> _useBonusCard(CardData bonusCard) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    // 애니메이션 중이면 무시
    if (_cardAnimController.isAnimating || _showingBonusCardEffect) return;

    // 카드 위치 계산
    final handCardPosition = _positionTracker.getCardPosition('hand_${bonusCard.id}');
    final capturePosition = _positionTracker.getCaptureZonePosition(_playerCaptureKey);

    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    final startPos = handCardPosition ?? Offset(
      screenSize.width / 2,
      safeAreaTop + screenSize.height * 0.8,
    );

    final endPos = capturePosition ?? Offset(
      screenSize.width * 0.2,
      safeAreaTop + screenSize.height * 0.75,
    );

    // 애니메이션 상태 설정
    setState(() {
      _showingBonusCardEffect = true;
      _bonusCardForEffect = bonusCard;
      _bonusCardStartPosition = startPos;
      _bonusCardEndPosition = endPos;
    });

    // 게임 로직 실행 (턴 소비 없이 점수패로 획득)
    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.useBonusCard(
      roomId: widget.roomId,
      myUid: user.uid,
      bonusCard: bonusCard,
      playerNumber: widget.isHost ? 1 : 2,
    );

    // 사운드 효과
    _soundService.playSpecialEvent(SpecialEvent.bonusCardUsed);
  }

  /// 보너스 카드 애니메이션 완료 처리
  void _onBonusCardEffectComplete() {
    setState(() {
      _showingBonusCardEffect = false;
      _bonusCardForEffect = null;
      _bonusCardStartPosition = null;
      _bonusCardEndPosition = null;
    });
  }

  /// 상대방의 보너스 카드 사용 애니메이션 표시
  void _showOpponentBonusCardEffect() {
    // 상대방의 획득 영역에서 사용된 보너스 카드 찾기
    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    // 상대방의 점수패에서 보너스 카드 찾기
    final opponentCaptured = widget.isHost
        ? gameState.player2Captured
        : gameState.player1Captured;

    // 가장 최근에 획득한 보너스 카드 (pi 목록에서)
    final bonusCards = opponentCaptured.pi.where((c) => c.isBonus).toList();
    if (bonusCards.isEmpty) return;

    final bonusCard = bonusCards.last;

    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    // 상대방 손패 영역에서 시작 (화면 상단)
    final startPos = Offset(
      screenSize.width / 2,
      safeAreaTop + screenSize.height * 0.1,
    );

    // 상대방 점수패 영역으로 이동
    final capturePosition = _positionTracker.getCaptureZonePosition(_opponentCaptureKey);
    final endPos = capturePosition ?? Offset(
      screenSize.width * 0.8,
      safeAreaTop + screenSize.height * 0.15,
    );

    setState(() {
      _showingBonusCardEffect = true;
      _bonusCardForEffect = bonusCard;
      _bonusCardStartPosition = startPos;
      _bonusCardEndPosition = endPos;
    });
  }

  void _onFloorCardTap(CardData floorCard) {
    if (_selectedHandCard == null) return;
    _playCard(_selectedHandCard!, floorCard);
  }

  void _onDeckTap() {
    // 손패가 선택된 경우: 일반 카드 내기
    if (_selectedHandCard != null) {
      _playCard(_selectedHandCard!, null);
      return;
    }

    // 손패가 비어있는 경우: 덱만 뒤집기
    _flipDeckOnly();
  }

  /// 손패 없이 덱만 뒤집기 (손패가 소진된 상태에서 턴 진행)
  Future<void> _flipDeckOnly() async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    final gameState = _currentRoom!.gameState;
    if (gameState == null) return;

    // 내 턴인지 확인
    if (gameState.turn != user.uid) {
      debugPrint('[FlipDeckOnly] 내 턴이 아님');
      return;
    }

    // 손패 확인 (비어있어야 함)
    final myHand = widget.isHost
        ? gameState.player1Hand
        : gameState.player2Hand;

    if (myHand.isNotEmpty) {
      debugPrint('[FlipDeckOnly] 손패가 비어있지 않음 - 손패를 선택해서 내야함');
      return;
    }

    // 덱이 비어있는지 확인
    if (gameState.deck.isEmpty) {
      debugPrint('[FlipDeckOnly] 덱이 비어있음');
      return;
    }

    // 애니메이션 중이면 무시
    if (_cardAnimController.isAnimating) return;

    debugPrint('[FlipDeckOnly] 손패 없이 덱 뒤집기 실행');

    final opponentUid = widget.isHost
        ? _currentRoom!.guest?.uid ?? ''
        : _currentRoom!.host.uid;

    final matgoLogic = ref.read(matgoLogicServiceProvider);

    await matgoLogic.flipDeckOnly(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: opponentUid,
      playerNumber: widget.isHost ? 1 : 2,
    );
  }

  Future<void> _playCard(CardData handCard, CardData? floorCard) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    // 애니메이션 중이면 무시
    if (_cardAnimController.isAnimating) return;

    setState(() => _selectedHandCard = null);

    final opponentUid = widget.isHost
        ? _currentRoom!.guest?.uid ?? ''
        : _currentRoom!.host.uid;

    final matgoLogic = ref.read(matgoLogicServiceProvider);

    // 매칭 카드가 2장 이상인 경우 선택 다이얼로그 표시
    final gameState = _currentRoom!.gameState!;
    final matchingCards = gameState.floorCards
        .where((c) => c.month == handCard.month)
        .toList();

    if (matchingCards.length >= 2 && floorCard == null) {
      setState(() {
        _showingCardSelection = true;
        _selectionOptions = matchingCards;
        _playedCardForSelection = handCard;
      });
      return;
    }

    // 실제 카드 위치 가져오기 (GlobalKey 기반)
    final handCardPosition = _positionTracker.getCardPosition('hand_${handCard.id}');

    // 목적지 결정: 매칭 바닥 카드가 있으면 그 위치, 없으면 덱 위치
    // 개선: 카드가 쌓일 때 스택 offset을 주어 여러 장이 쌓인 것이 보이도록 함
    const stackOffset = Offset(4, -6); // 우상향으로 살짝 비켜서 쌓임

    Offset? targetPosition;

    if (floorCard != null) {
      // 매칭 바닥 카드 위치로 이동 (스택 offset 적용)
      targetPosition = _positionTracker.getCardPosition('floor_${floorCard.id}');
      if (targetPosition != null) {
        targetPosition = targetPosition + stackOffset;
      }
    } else if (matchingCards.length == 1) {
      // 매칭 카드가 1장이면 그 위치로 (스택 offset 적용)
      targetPosition = _positionTracker.getCardPosition('floor_${matchingCards.first.id}');
      if (targetPosition != null) {
        targetPosition = targetPosition + stackOffset;
      }
    } else {
      // 매칭 카드가 없으면 덱 근처 빈 공간으로 (스택 offset 없음)
      targetPosition = _positionTracker.getDeckPosition(_deckKey);
    }

    // 위치를 못 가져온 경우 화면 기반 폴백
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    final fromPosition = handCardPosition ?? Offset(
      screenSize.width / 2,
      safeAreaTop + screenSize.height * 0.8,
    );

    final toPosition = targetPosition ?? Offset(
      screenSize.width / 2,
      safeAreaTop + screenSize.height * 0.4,
    );

    // 카드 내기 애니메이션 실행 (시나리오 A)
    await _cardAnimController.animatePlayCard(
      card: handCard,
      from: fromPosition,
      to: toPosition,
    );

    // 게임 로직 실행
    await matgoLogic.playCard(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: opponentUid,
      card: handCard,
      playerNumber: widget.isHost ? 1 : 2,
      selectedFloorCard: floorCard,
    );
  }

  void _onCardSelected(CardData selectedCard) {
    setState(() {
      _showingCardSelection = false;
      _selectionOptions = [];
    });

    if (_playedCardForSelection != null) {
      _playCard(_playedCardForSelection!, selectedCard);
      _playedCardForSelection = null;
    }
  }

  void _onSelectionCancelled() {
    setState(() {
      _showingCardSelection = false;
      _selectionOptions = [];
      _playedCardForSelection = null;
    });
  }

  // 덱 카드 선택 다이얼로그 표시
  void _showDeckSelectionDialog(GameState gameState) {
    if (gameState.deckCard == null || gameState.deckMatchingCards.isEmpty) return;

    setState(() {
      _showingDeckSelection = true;
      _deckSelectionOptions = gameState.deckMatchingCards;
      _deckCardForSelection = gameState.deckCard;
    });
  }

  // 덱 카드 선택 완료
  void _onDeckCardSelected(CardData selectedCard) async {
    setState(() {
      _showingDeckSelection = false;
      _deckSelectionOptions = [];
    });

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    final opponentUid = widget.isHost
        ? _currentRoom!.guest?.uid ?? ''
        : _currentRoom!.host.uid;

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.selectDeckMatchCard(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: opponentUid,
      playerNumber: widget.isHost ? 1 : 2,
      selectedFloorCard: selectedCard,
    );

    _deckCardForSelection = null;
  }

  // 덱 카드 선택 취소 (취소 불가 - 반드시 선택해야 함)
  void _onDeckSelectionCancelled() {
    // 덱 카드 선택은 취소할 수 없음 - 아무것도 하지 않음
  }

  void _showSpecialEvent(SpecialEvent event, bool isMyEvent) {
    _soundService.playSpecialEvent(event);
    setState(() {
      _lastShownEvent = event;
      _showingEvent = true;
    });
  }

  void _dismissSpecialEvent() {
    setState(() => _showingEvent = false);
  }

  void _showGoStopDialog() {
    setState(() => _showingGoStop = true);
  }

  Future<void> _onGo() async {
    _soundService.playGo();
    setState(() => _showingGoStop = false);

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    final opponentUid = widget.isHost
        ? _currentRoom!.guest?.uid ?? ''
        : _currentRoom!.host.uid;

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.declareGo(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: opponentUid,
      playerNumber: widget.isHost ? 1 : 2,
    );
  }

  Future<void> _onStop() async {
    // 光끼 모드에서는 STOP 불가
    if (_gwangkkiModeActive) return;

    _soundService.playStop();
    setState(() => _showingGoStop = false);

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.declareStop(
      roomId: widget.roomId,
      myUid: user.uid,
      playerNumber: widget.isHost ? 1 : 2,
    );
  }

  // ==================== 光끼 모드 ====================

  /// 光끼 모드 알림 표시
  void _showGwangkkiModeAlert() {
    setState(() => _showingGwangkkiAlert = true);
  }

  /// 光끼 모드 알림 닫기
  void _dismissGwangkkiAlert() {
    setState(() => _showingGwangkkiAlert = false);
  }

  /// 光끼 모드 발동
  Future<void> _activateGwangkkiMode() async {
    if (!_canActivateGwangkki || _gwangkkiModeActive) return;

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final roomService = ref.read(roomServiceProvider);
    final coinService = ref.read(coinServiceProvider);

    // 光끼 점수 리셋 및 모드 발동
    await coinService.resetGwangkkiScore(user.uid);
    await roomService.activateGwangkkiMode(
      roomId: widget.roomId,
      activatorUid: user.uid,
    );
  }

  /// 光끼 모드 발동자가 나인지 확인
  bool get _isGwangkkiActivator {
    final authService = ref.read(authServiceProvider);
    return _gwangkkiActivator == authService.currentUser?.uid;
  }

  void _showGameResult() async {
    final gameState = _currentRoom?.gameState;
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    if (gameState?.endState == GameEndState.nagari) {
      _soundService.playNagari();
    } else if (gameState?.winner == myUid) {
      _soundService.playWin();
    } else {
      _soundService.playLose();
    }

    // 나가리가 아니고 승자가 있으면 코인 정산 처리
    if (gameState?.endState != GameEndState.nagari &&
        gameState?.winner != null &&
        !_coinSettlementDone) {
      await _settleGameCoins();
    }

    setState(() => _showingResult = true);
  }

  Future<void> _settleGameCoins() async {
    final gameState = _currentRoom?.gameState;
    if (gameState == null || gameState.winner == null) return;

    final coinService = ref.read(coinServiceProvider);
    final hostUid = _currentRoom!.host.uid;
    final guestUid = _currentRoom!.guest?.uid;

    if (guestUid == null) return;

    final winnerUid = gameState.winner!;
    final loserUid = winnerUid == hostUid ? guestUid : hostUid;
    final finalScore = gameState.finalScore;

    // 패자가 가진 코인 확인
    final loserWallet = await coinService.getUserWallet(loserUid);
    final loserCoins = loserWallet?.coin ?? 0;

    int actualTransfer;

    // 光끼 모드: 승자가 모든 코인 독식
    if (_gwangkkiModeActive) {
      actualTransfer = loserCoins;

      // 호스트만 실제 코인 정산 API 호출 (중복 정산 방지)
      if (widget.isHost) {
        try {
          // 光끼 모드 정산 (All-in)
          await coinService.settleGwangkkiMode(
            winnerUid: winnerUid,
            loserUid: loserUid,
            isDraw: false,
            activatorUid: _gwangkkiActivator ?? winnerUid,
          );

          // 光끼 점수 업데이트 (양쪽 모두)
          await coinService.updateGwangkkiScores(
            winnerUid: winnerUid,
            loserUid: loserUid,
            winnerScore: finalScore,
            isDraw: false,
          );

          // 光끼 모드 비활성화
          final roomService = ref.read(roomServiceProvider);
          await roomService.deactivateGwangkkiMode(widget.roomId);

          debugPrint('[GameScreen] GwangKki mode settlement: $winnerUid wins ALL ($actualTransfer) coins from $loserUid');
        } catch (e) {
          debugPrint('[GameScreen] GwangKki mode settlement failed: $e');
        }
      }
    } else {
      // 일반 모드: 점수와 패자 보유량 중 작은 값
      actualTransfer = finalScore > loserCoins ? loserCoins : finalScore;

      // 호스트만 실제 코인 정산 API 호출 (중복 정산 방지)
      if (widget.isHost) {
        try {
          await coinService.settleGame(
            winnerUid: winnerUid,
            loserUid: loserUid,
            points: actualTransfer,
            multiplier: 1,
          );

          // 光끼 점수 업데이트 (일반 게임에서도)
          await coinService.updateGwangkkiScores(
            winnerUid: winnerUid,
            loserUid: loserUid,
            winnerScore: finalScore,
            isDraw: false,
          );

          debugPrint('[GameScreen] Coin settlement: $winnerUid wins $actualTransfer coins from $loserUid');
        } catch (e) {
          debugPrint('[GameScreen] Coin settlement failed: $e');
        }
      }
    }

    // 양쪽 모두 코인 변동 금액 표시를 위해 설정
    setState(() {
      _coinTransferAmount = actualTransfer;
      _coinSettlementDone = true;
    });
  }

  Future<void> _onRematch() async {
    _soundService.playClick();
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final roomService = ref.read(roomServiceProvider);
    await roomService.voteRematch(
      roomId: widget.roomId,
      isHost: widget.isHost,
      vote: 'agree',
    );

    setState(() {
      _rematchRequested = true;
      _rematchCountdown = 15;
    });

    // 상대방이 이미 재대결을 요청한 상태가 아니면 타이머 시작
    if (!_opponentRematchRequested) {
      _startRematchTimer();
    }
  }

  void _startRematchTimer() {
    _rematchTimer?.cancel();
    _rematchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _rematchCountdown--;
      });

      // 타이머 만료 시 로비로 이동
      if (_rematchCountdown <= 0) {
        timer.cancel();
        _showRematchTimeoutDialog();
      }
    });
  }

  void _cancelRematchTimer() {
    _rematchTimer?.cancel();
    _rematchTimer = null;
  }

  // ============ 턴 타이머 관련 메서드 ============

  /// 턴 타이머 업데이트 (턴이 변경될 때 호출)
  void _updateTurnTimer(GameState gameState) {
    _turnTimer?.cancel();

    // 게임이 종료되었으면 타이머 중지
    if (gameState.endState != GameEndState.none) {
      return;
    }

    // 남은 시간 계산
    _updateRemainingSeconds(gameState);

    // 1초마다 타이머 업데이트
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final currentRoom = _currentRoom;
      if (currentRoom == null || currentRoom.gameState == null) {
        timer.cancel();
        return;
      }

      final currentGameState = currentRoom.gameState!;

      // 게임이 종료되었으면 타이머 중지
      if (currentGameState.endState != GameEndState.none) {
        timer.cancel();
        return;
      }

      // 남은 시간 계산 및 업데이트
      final remaining = MatgoLogicService.getRemainingTurnTime(
        currentGameState,
        turnDuration: _turnDuration,
      );

      setState(() {
        _remainingSeconds = remaining;
      });

      // 타임아웃 시 자동 플레이 실행 (내 턴인 경우에만)
      if (remaining <= 0) {
        timer.cancel();
        _handleTurnTimeout();
      }
    });
  }

  /// 남은 시간 업데이트 (UI 갱신용)
  void _updateRemainingSeconds(GameState gameState) {
    final remaining = MatgoLogicService.getRemainingTurnTime(
      gameState,
      turnDuration: _turnDuration,
    );
    if (_remainingSeconds != remaining) {
      setState(() {
        _remainingSeconds = remaining;
      });
    }
  }

  /// 턴 타임아웃 처리
  Future<void> _handleTurnTimeout() async {
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;
    final room = _currentRoom;

    if (room == null || room.gameState == null || myUid == null) return;

    final gameState = room.gameState!;

    // 내 턴인 경우에만 자동 플레이 실행
    if (gameState.turn != myUid) return;

    print('[GameScreen] Turn timeout - auto playing...');

    final matgoLogicService = ref.read(matgoLogicServiceProvider);
    final opponentUid = widget.isHost ? room.guest?.uid : room.host.uid;
    final playerNumber = widget.isHost ? 1 : 2;

    if (opponentUid == null) return;

    await matgoLogicService.autoPlayOnTimeout(
      roomId: widget.roomId,
      myUid: myUid,
      opponentUid: opponentUid,
      playerNumber: playerNumber,
    );
  }

  // ============ 턴 타이머 관련 메서드 끝 ============

  void _showRematchTimeoutDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          '재대결 시간 초과',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '상대방이 응답하지 않아 게임이 종료됩니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(this.context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LobbyScreen()),
              );
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showOpponentLeftDialog() {
    if (!mounted) return;
    _cancelRematchTimer();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          '상대방 퇴장',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '상대방이 게임을 떠나 게임이 자동 종료됩니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(this.context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LobbyScreen()),
              );
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showRematchAcceptedDialog() {
    if (!mounted) return;
    _cancelRematchTimer();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          '재대결 수락',
          style: TextStyle(color: Colors.amber),
        ),
        content: const Text(
          '상대방이 재대결을 수락하여 게임이 시작됩니다!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _onExitResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LobbyScreen()),
    );
  }

  Future<void> _onShake(int month) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom?.gameState == null) return;

    // 흔들 카드들 저장 (오버레이 표시용)
    final gameState = _currentRoom!.gameState!;
    final myHand = widget.isHost ? gameState.player1Hand : gameState.player2Hand;
    final shakeCards = myHand.where((c) => c.month == month).take(3).toList();

    // 오버레이 표시
    setState(() {
      _shakeCards = shakeCards;
      _showingShakeCards = true;
    });

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.declareShake(
      roomId: widget.roomId,
      myUid: user.uid,
      playerNumber: widget.isHost ? 1 : 2,
      month: month,
    );
  }

  void _onShakeCardsDismiss() {
    if (mounted) {
      setState(() {
        _showingShakeCards = false;
        _shakeCards = [];
      });
    }
  }

  void _onChongtongCardsDismiss() {
    if (mounted) {
      setState(() {
        _showingChongtongCards = false;
      });
      // 총통 오버레이가 끝나면 게임 결과 다이얼로그 표시
      if (_currentRoom?.gameState?.endState == GameEndState.chongtong &&
          !_showingResult) {
        _showGameResult();
      }
    }
  }

  void _onFirstTurnOverlayDismiss() {
    if (mounted) {
      setState(() {
        _showingFirstTurnOverlay = false;
      });
    }
  }

  Future<void> _onBomb(int month) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    final opponentUid = widget.isHost
        ? _currentRoom!.guest?.uid ?? ''
        : _currentRoom!.host.uid;

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.declareBomb(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: opponentUid,
      playerNumber: widget.isHost ? 1 : 2,
      month: month,
    );
  }

  void _showRoomDeletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.woodDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.woodDark.withValues(alpha: 0.5)),
        ),
        title: Text(
          '방이 종료되었습니다',
          style: TextStyle(color: AppColors.text),
        ),
        content: Text(
          '상대방이 나갔거나 방이 삭제되었습니다.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          RetroButton(
            text: '로비로 돌아가기',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LobbyScreen()),
              );
            },
            width: 160,
            height: 48,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.woodDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.woodDark.withValues(alpha: 0.5)),
        ),
        title: Text(
          '게임 나가기',
          style: TextStyle(color: AppColors.text),
        ),
        content: Text(
          '정말 게임을 나가시겠습니까?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          RetroButton(
            text: '취소',
            color: AppColors.woodLight,
            textColor: AppColors.text,
            onPressed: () => Navigator.of(context).pop(false),
            width: 80,
            height: 48,
            fontSize: 16,
          ),
          const SizedBox(width: 8),
          RetroButton(
            text: '나가기',
            color: AppColors.goRed,
            onPressed: () => Navigator.of(context).pop(true),
            width: 80,
            height: 48,
            fontSize: 16,
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user != null) {
        final roomService = ref.read(roomServiceProvider);
        await roomService.leaveRoom(
          roomId: widget.roomId,
          playerId: user.uid,
          isHost: widget.isHost,
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _myWalletSubscription?.cancel();
    _opponentWalletSubscription?.cancel();
    _rematchTimer?.cancel();
    _turnTimer?.cancel();  // 턴 타이머 정리
    _soundService.dispose();
    _pulseController.dispose();
    _cardAnimController.dispose();
    _positionTracker.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;
    final gameState = _currentRoom?.gameState;
    final isMyTurn = gameState?.turn == myUid;

    return ScreenSizeWarningOverlay(
      child: Scaffold(
        body: RetroBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 게임 레이아웃 (3 Zone)
              Column(
                children: [
                  // Top Zone (상대방) - 22%
                  Expanded(
                    flex: 22,
                    child: OpponentZone(
                      opponentName: widget.isHost
                          ? _currentRoom?.guest?.displayName
                          : _currentRoom?.host.displayName,
                      captured: widget.isHost
                          ? gameState?.player2Captured
                          : gameState?.player1Captured,
                      score: widget.isHost
                          ? gameState?.scores.player2Score ?? 0
                          : gameState?.scores.player1Score ?? 0,
                      goCount: widget.isHost
                          ? gameState?.scores.player2GoCount ?? 0
                          : gameState?.scores.player1GoCount ?? 0,
                      handCount: widget.isHost
                          ? gameState?.player2Hand.length ?? 0
                          : gameState?.player1Hand.length ?? 0,
                      isOpponentTurn: gameState != null && !isMyTurn,
                      isShaking: widget.isHost
                          ? gameState?.scores.player2Shaking ?? false
                          : gameState?.scores.player1Shaking ?? false,
                      hasBomb: widget.isHost
                          ? gameState?.scores.player2Bomb ?? false
                          : gameState?.scores.player1Bomb ?? false,
                      coinBalance: _opponentCoinBalance,
                      remainingSeconds: !isMyTurn ? _remainingSeconds : null,
                    ),
                  ),

                  // Center Zone (바닥) - 46% (기존 40%에서 15% 확대)
                  Expanded(
                    flex: 46,
                    child: Stack(
                      children: [
                        FloorZone(
                          floorCards: gameState?.floorCards ?? [],
                          pukCards: gameState?.pukCards ?? [],
                          deckCount: gameState?.deck.length ?? 0,
                          onFloorCardTap: _onFloorCardTap,
                          onDeckTap: _onDeckTap,
                          selectedHandCard: _selectedHandCard,
                          deckKey: _deckKey,
                          getCardKey: (cardId) => _positionTracker.getKey('floor_$cardId'),
                          hiddenCardIds: _animatingDeckCardIds, // 애니메이션 중인 카드 숨김
                          // 손패 비어있음 여부와 내 턴 여부 (덱만 뒤집기 가능 여부 결정)
                          isHandEmpty: (widget.isHost
                              ? gameState?.player1Hand.isEmpty ?? true
                              : gameState?.player2Hand.isEmpty ?? true),
                          isMyTurn: isMyTurn,
                        ),
                        // 光끼 모드 불꽃 테두리 효과
                        if (_gwangkkiModeActive)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  final intensity = 0.5 + (_pulseController.value * 0.5);
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Color.lerp(
                                          const Color(0xFFFF4500),
                                          const Color(0xFFFF6347),
                                          _pulseController.value,
                                        )!.withValues(alpha: intensity),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF4500).withValues(alpha: 0.3 * intensity),
                                          blurRadius: 20 * intensity,
                                          spreadRadius: 5 * intensity,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFFFF6347).withValues(alpha: 0.2 * intensity),
                                          blurRadius: 30 * intensity,
                                          spreadRadius: 10 * intensity,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom Zone (플레이어) - 32%
                  Expanded(
                    flex: 32,
                    child: Stack(
                      children: [
                        PlayerZone(
                          playerName: widget.isHost
                              ? _currentRoom?.host.displayName
                              : _currentRoom?.guest?.displayName,
                          handCards: widget.isHost
                              ? gameState?.player1Hand ?? []
                              : gameState?.player2Hand ?? [],
                          captured: widget.isHost
                              ? gameState?.player1Captured
                              : gameState?.player2Captured,
                          score: widget.isHost
                              ? gameState?.scores.player1Score ?? 0
                              : gameState?.scores.player2Score ?? 0,
                          goCount: widget.isHost
                              ? gameState?.scores.player1GoCount ?? 0
                              : gameState?.scores.player2GoCount ?? 0,
                          isMyTurn: isMyTurn,
                          selectedCard: _selectedHandCard,
                          onCardTap: _onHandCardTap,
                          showGoStopButtons: _showingGoStop,
                          onGoPressed: _onGo,
                          onStopPressed: _onStop,
                          isShaking: widget.isHost
                              ? gameState?.scores.player1Shaking ?? false
                              : gameState?.scores.player2Shaking ?? false,
                          hasBomb: widget.isHost
                              ? gameState?.scores.player1Bomb ?? false
                              : gameState?.scores.player2Bomb ?? false,
                          coinBalance: _myCoinBalance,
                          remainingSeconds: isMyTurn ? _remainingSeconds : null,
                          getCardKey: (cardId) => _positionTracker.getKey('hand_$cardId'),
                          captureZoneKey: _playerCaptureKey,
                        ),
                        if (!isMyTurn)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.5),
                              child: const Center(
                                child: Text(
                                  '상대 턴입니다',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // 상단 컨트롤 (나가기 버튼만)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _leaveRoom,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.goRed.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // 光끼 게이지 및 발동 버튼 (우하단)
              if (gameState != null && !_gwangkkiModeActive)
                Positioned(
                  right: 8,
                  bottom: MediaQuery.of(context).size.height * 0.35,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 光끼 게이지 (컴팩트 모드)
                      GwangkkiGauge(
                        score: _myGwangkkiScore,
                        showWarning: _canActivateGwangkki,
                        compact: true,
                      ),
                      // 발동 버튼 (점수 100 이상일 때)
                      if (_canActivateGwangkki)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildGwangkkiActivateButton(),
                        ),
                    ],
                  ),
                ),

              // 흔들기/폭탄 액션 버튼
              if (gameState != null && isMyTurn)
                Positioned(
                  left: 8,
                  bottom: MediaQuery.of(context).size.height * 0.25,
                  child: ActionButtons(
                    myHand: widget.isHost
                        ? gameState.player1Hand
                        : gameState.player2Hand,
                    floorCards: gameState.floorCards,
                    isMyTurn: isMyTurn,
                    alreadyUsedShake: widget.isHost
                        ? gameState.scores.player1Shaking
                        : gameState.scores.player2Shaking,
                    alreadyUsedBomb: widget.isHost
                        ? gameState.scores.player1Bomb
                        : gameState.scores.player2Bomb,
                    onShake: _onShake,
                    onBomb: _onBomb,
                  ),
                ),

              // 대기 오버레이
              if (_currentRoom != null && !_currentRoom!.isFull)
                _buildWaitingOverlay(),

              // 선 결정 오버레이
              if (_showingFirstTurnOverlay &&
                  _firstTurnReason != null &&
                  _firstTurnPlayerName != null)
                FirstTurnOverlay(
                  reason: _firstTurnReason!,
                  firstPlayerName: _firstTurnPlayerName!,
                  isMe: _firstTurnIsMe,
                  onDismiss: _onFirstTurnOverlayDismiss,
                ),

              // 특수 이벤트 오버레이
              if (_showingEvent && _lastShownEvent != SpecialEvent.none)
                SpecialEventOverlay(
                  event: _lastShownEvent,
                  isMyEvent: gameState?.lastEventPlayer == myUid,
                  onDismiss: _dismissSpecialEvent,
                ),

              // 흔들기 카드 공개 오버레이
              if (_showingShakeCards && _shakeCards.isNotEmpty)
                ShakeCardsOverlay(
                  cards: _shakeCards,
                  onDismiss: _onShakeCardsDismiss,
                ),

              // 총통 카드 공개 오버레이
              if (_showingChongtongCards && _chongtongCards.isNotEmpty)
                ChongtongCardsOverlay(
                  cards: _chongtongCards,
                  winnerName: _chongtongWinnerName,
                  onDismiss: _onChongtongCardsDismiss,
                ),

              // 光끼 모드 발동 알림 (3초간 표시)
              if (_showingGwangkkiAlert)
                GwangkkiModeAlert(
                  activatorName: _gwangkkiActivator == _currentRoom?.host.uid
                      ? _currentRoom?.host.displayName ?? '호스트'
                      : _currentRoom?.guest?.displayName ?? '게스트',
                  isMyActivation: _isGwangkkiActivator,
                  onDismiss: _dismissGwangkkiAlert,
                ),

              // 光끼 모드 배너 (활성화 중 지속 표시)
              if (_gwangkkiModeActive && !_showingGwangkkiAlert)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: GwangkkiModeBanner(
                    activatorName: _gwangkkiActivator == _currentRoom?.host.uid
                        ? _currentRoom?.host.displayName ?? '호스트'
                        : _currentRoom?.guest?.displayName ?? '게스트',
                  ),
                ),

              // Go/Stop 다이얼로그
              if (_showingGoStop && gameState != null)
                _buildGoStopButtons(gameState),

              // 게임 결과 다이얼로그
              if (_showingResult && gameState != null)
                _buildResultDialog(gameState, myUid),

              // 카드 선택 다이얼로그 (손패 2장 매칭)
              if (_showingCardSelection && _selectionOptions.isNotEmpty)
                CardSelectionDialog(
                  matchingCards: _selectionOptions,
                  playedCard: _playedCardForSelection!,
                  onCardSelected: _onCardSelected,
                  onCancel: _onSelectionCancelled,
                ),

              // 덱 카드 선택 다이얼로그 (더미 패 2장 매칭)
              if (_showingDeckSelection && _deckSelectionOptions.isNotEmpty && _deckCardForSelection != null)
                CardSelectionDialog(
                  matchingCards: _deckSelectionOptions,
                  playedCard: _deckCardForSelection!,
                  onCardSelected: _onDeckCardSelected,
                  onCancel: _onDeckSelectionCancelled,
                  title: '뒤집은 카드로 가져갈 패를 선택하세요',
                ),

              // 카드 애니메이션 오버레이
              AnimatedCardOverlay(
                animatingCards: _cardAnimController.animatingCards,
              ),

              // 보너스 카드 사용 애니메이션
              if (_showingBonusCardEffect &&
                  _bonusCardForEffect != null &&
                  _bonusCardStartPosition != null &&
                  _bonusCardEndPosition != null)
                BonusCardUseEffect(
                  card: _bonusCardForEffect!,
                  screenSize: MediaQuery.of(context).size,
                  startPosition: _bonusCardStartPosition!,
                  endPosition: _bonusCardEndPosition!,
                  onComplete: _onBonusCardEffectComplete,
                ),

              // 카드 이펙트 (착지, 쓸어담기)
              ..._buildActiveEffects(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// 光끼 모드 발동 버튼
  Widget _buildGwangkkiActivateButton() {
    return GestureDetector(
      onTap: _activateGwangkkiMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4500), Color(0xFFFF6347)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4500).withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.yellow, Colors.orange, Colors.red],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '光끼 발동!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoStopButtons(GameState gameState) {
    final myScore = widget.isHost
        ? gameState.scores.player1Score
        : gameState.scores.player2Score;
    final goCount = widget.isHost
        ? gameState.scores.player1GoCount
        : gameState.scores.player2GoCount;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 현재 점수 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.woodLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.woodDark.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    '현재 점수: $myScore점',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (goCount > 0)
                    Text(
                      '$goCount고 진행 중',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 光끼 모드 경고
            if (_gwangkkiModeActive)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4500), Color(0xFFFF6347)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4500).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '光끼 모드! GO만 가능',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.local_fire_department, color: Colors.white, size: 20),
                  ],
                ),
              ),
            // GO / STOP 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RetroButton(
                  text: 'GO',
                  color: AppColors.goRed,
                  onPressed: _onGo,
                  width: 120,
                  height: 60,
                  fontSize: 24,
                ),
                const SizedBox(width: 24),
                // 光끼 모드에서는 STOP 비활성화
                Opacity(
                  opacity: _gwangkkiModeActive ? 0.4 : 1.0,
                  child: RetroButton(
                    text: 'STOP',
                    color: _gwangkkiModeActive ? Colors.grey : AppColors.stopBlue,
                    onPressed: _gwangkkiModeActive ? null : _onStop,
                    width: 120,
                    height: 60,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDialog(GameState gameState, String? myUid) {
    final isWinner = gameState.winner == myUid;
    final isPlayer1 = widget.isHost;

    FinalScoreResult? scoreDetail;
    if (gameState.endState == GameEndState.win) {
      // 승자 기준으로 점수 상세 계산 (패자에게도 보여주기 위해)
      final winnerIsPlayer1 = gameState.winner == _currentRoom?.host.uid;

      // 승자의 획득 패와 상대방(패자) 획득 패
      final winnerCaptured = winnerIsPlayer1
          ? gameState.player1Captured
          : gameState.player2Captured;
      final loserCaptured = winnerIsPlayer1
          ? gameState.player2Captured
          : gameState.player1Captured;
      final winnerGoCount = winnerIsPlayer1
          ? gameState.scores.player1GoCount
          : gameState.scores.player2GoCount;
      final winnerMultiplier = winnerIsPlayer1
          ? gameState.scores.player1Multiplier
          : gameState.scores.player2Multiplier;

      scoreDetail = ScoreCalculator.calculateFinalScore(
        myCaptures: winnerCaptured,
        opponentCaptures: loserCaptured,
        goCount: winnerGoCount,
        playerMultiplier: winnerMultiplier,
      );
    }

    return Stack(
      children: [
        GameResultDialog(
          isWinner: isWinner,
          finalScore: gameState.finalScore,
          scoreDetail: scoreDetail,
          endState: gameState.endState,
          onRematch: _rematchRequested ? () {} : _onRematch,
          onExit: _onExitResult,
          coinChange: _coinTransferAmount,
          isGwangkkiMode: _gwangkkiModeActive,
        ),
        if (_rematchRequested || _opponentRematchRequested)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildRematchStatus(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRematchStatus() {
    if (_rematchRequested && !_opponentRematchRequested) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.cardHighlight,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '상대방의 응답을 기다리는 중...',
                style: TextStyle(color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_rematchCountdown초 후에 게임이 종료됩니다.',
            style: TextStyle(
              color: _rematchCountdown <= 5 ? Colors.redAccent : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    if (_opponentRematchRequested && !_rematchRequested) {
      return Text(
        '상대방이 재대결을 원합니다!',
        style: TextStyle(
          color: AppColors.cardHighlight,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.cardHighlight,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '게임을 다시 시작하는 중...',
          style: TextStyle(color: AppColors.text),
        ),
      ],
    );
  }

  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.cardHighlight,
              strokeWidth: 3,
            ),
            SizedBox(height: 32),
            Text(
              '상대방을 기다리는 중...',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.woodLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.woodDark.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    '방 코드',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.roomId,
                    style: TextStyle(
                      color: AppColors.cardHighlight,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 활성화된 이펙트들 렌더링
  List<Widget> _buildActiveEffects() {
    return _cardAnimController.activeEffects.map((effect) {
      switch (effect.type) {
        case CardEffectType.impact:
          return CardImpactEffect(
            key: ValueKey('impact_${effect.id}'),
            position: effect.position,
            onComplete: () {},
            message: effect.message,
          );
        case CardEffectType.sweep:
          return CardSweepEffect(
            key: ValueKey('sweep_${effect.id}'),
            startPosition: effect.position,
            endPosition: effect.endPosition ?? effect.position,
            onComplete: () {},
          );
        case CardEffectType.countPopup:
          return CardCountPopup(
            key: ValueKey('popup_${effect.id}'),
            position: effect.position,
            count: effect.count ?? 0,
            onComplete: () {},
          );
      }
    }).toList();
  }

  /// 덱 GlobalKey getter (FloorZone에서 사용)
  GlobalKey get deckKey => _deckKey;

  /// 플레이어 획득 영역 GlobalKey getter
  GlobalKey get playerCaptureKey => _playerCaptureKey;

  /// 상대방 획득 영역 GlobalKey getter
  GlobalKey get opponentCaptureKey => _opponentCaptureKey;
}
