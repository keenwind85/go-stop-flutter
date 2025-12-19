import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../models/card_data.dart';
import '../../models/captured_cards.dart';
import '../../models/game_room.dart';
import '../../models/item_data.dart';
import '../../models/user_wallet.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/matgo_logic_service.dart';
import '../../services/sound_service.dart';
import '../../services/coin_service.dart';
import '../../services/debug_config_service.dart';
import '../../services/settings_service.dart';
import '../../game/systems/score_calculator.dart';
import '../widgets/game_result_dialog.dart';
import '../widgets/special_event_overlay.dart';
import '../widgets/card_selection_dialog.dart';
import '../widgets/action_buttons.dart';
import '../widgets/shake_cards_overlay.dart';
import '../widgets/bomb_cards_overlay.dart';
import '../widgets/meongtta_cards_overlay.dart';
import '../widgets/chongtong_cards_overlay.dart';
import '../widgets/september_animal_choice_dialog.dart';
import '../widgets/special_rule_lottie_overlay.dart';
import '../screens/lobby_screen.dart';
import 'widgets/opponent_zone.dart';
import 'widgets/gostop_opponent_zone.dart';
import 'widgets/floor_zone.dart';
import 'widgets/player_zone.dart';
import 'widgets/game_avatar.dart';
import 'animations/animations.dart';
import '../widgets/screen_size_warning_overlay.dart';
import '../widgets/retro_background.dart';
import '../widgets/retro_button.dart';
import '../widgets/gwangkki_gauge.dart';
import '../widgets/game_alert_banner.dart';
import '../widgets/first_turn_overlay.dart';
import '../widgets/debug_card_selector_dialog.dart';
import '../widgets/item_use_button.dart';
import '../widgets/item_use_overlay.dart';
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

  const GameScreenNew({super.key, required this.roomId, required this.isHost});

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
  StreamSubscription<UserWallet?>?
  _opponent2WalletSubscription; // 고스톱 모드용 두 번째 상대
  int? _myCoinBalance;
  int? _opponentCoinBalance;
  int? _opponent2CoinBalance; // 고스톱 모드용 두 번째 상대 코인

  // 게임 결과 코인 정산 정보
  int? _coinTransferAmount;
  bool _coinSettlementDone = false;
  GostopSettlementResult? _gostopSettlementResult; // 3인 고스톱 패자별 정산 정보 (승자용)
  LoserSettlementDetail? _myLoserSettlement; // 패자 자신의 정산 정보
  bool _bonusRouletteAdded = false; // 보너스 룰렛 추가 완료 플래그
  bool _bonusSlotAdded = false; // 보너스 슬롯 추가 완료 플래그

  // UI 상태
  SpecialEvent _lastShownEvent = SpecialEvent.none;
  int? _lastShownEventAt; // 마지막으로 표시한 이벤트 타임스탬프 (연속 동일 이벤트 감지용)
  bool _showingEvent = false;
  bool _showingGoStop = false;
  bool _showingResult = false;
  bool _rematchRequested = false;
  bool _opponentRematchRequested = false;
  bool _opponent2RematchRequested = false; // 3인 고스톱 모드용

  // 재대결 타이머 상태
  Timer? _rematchTimer;
  int _rematchCountdown = 15;
  bool _opponentLeftDuringRematch = false;
  bool _rematchInProgress = false; // 재대결 진행 중 플래그 (결과 UI 중복 표시 방지)

  // 카드 선택 상태 (손패 2장 매칭)
  bool _showingCardSelection = false;
  List<CardData> _selectionOptions = [];
  CardData? _playedCardForSelection;
  CardData? _selectedHandCard;

  // 덱 카드 선택 상태 (더미 패 2장 매칭)
  bool _showingDeckSelection = false;
  List<CardData> _deckSelectionOptions = [];
  CardData? _deckCardForSelection;

  // 9월 열끗 선택 상태
  bool _showingSeptemberChoice = false;

  // 보너스 카드 사용 애니메이션 상태
  bool _showingBonusCardEffect = false;
  CardData? _bonusCardForEffect;
  Offset? _bonusCardStartPosition;
  Offset? _bonusCardEndPosition;
  int? _lastShownBonusEventAt; // 마지막으로 표시한 보너스 이벤트 타임스탬프

  // 피 빼앗김 알림 상태
  bool _showingPiStolenNotification = false;
  int _lastPiStolenCount = 0; // 마지막으로 처리한 피 빼앗김 횟수

  // 흔들기 카드 공개 오버레이 상태
  bool _showingShakeCards = false;
  List<CardData> _shakeCards = [];

  // 총통 카드 공개 오버레이 상태
  bool _showingChongtongCards = false;
  List<CardData> _chongtongCards = [];
  String? _chongtongWinnerName;

  // 폭탄 카드 공개 오버레이 상태
  bool _showingBombCards = false;
  List<CardData> _bombCards = [];
  String? _bombPlayerName;

  // 멍따 카드 공개 오버레이 상태
  bool _showingMeongTtaCards = false;
  List<CardData> _meongTtaCards = [];
  String? _meongTtaPlayerName;
  CardData? _bombTargetCard; // 획득할 카드 (애니메이션용)
  bool _showingBombExplosion = false; // 폭발 애니메이션 표시 여부
  Offset? _bombExplosionPosition; // 폭발 애니메이션 위치

  // 특수 룰 로티 애니메이션 상태 (따닥, 뻑, 쪽)
  bool _showingSpecialRuleLottie = false;
  SpecialEvent _specialRuleEvent = SpecialEvent.none;
  List<Offset> _specialRulePositions = [];

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

  // 게임 중 광끼 축적 애니메이션 상태
  bool _showingGwangkkiAnger = false;
  int _gwangkkiAngerPoints = 0;
  
  // 게임 종료 시 패자에게 축적된 광끼 점수
  int? _kwangkkiGained;
  
  // 이전 상태 추적 (광끼 축적 이벤트 감지용)
  int? _prevPiStolenCount;
  SpecialEvent? _prevSpecialEvent;
  int? _prevLastEventAt;
  
  // 카드 획득 실패 감지용 (내 턴 시작 시 획득 카드 수 추적)
  int? _myTurnStartCapturedCount;
  int? _lastCheckedTurnIndex;
  bool _pukOccurredThisTurn = false; // 이번 턴에 뻑이 발생했는지 (중복 광끼 축적 방지)

  // 게임 얼럿 상태
  GameAlertMessage? _gameStartAlert;
  List<GameAlertMessage> _persistentAlerts = [];
  List<GameAlertMessage> _oneTimeAlertQueue = [];
  GameAlertMessage? _currentOneTimeAlert;
  Set<String> _shownOneTimeAlertKeys = {};  // 이미 표시된 1회성 얼럿
  final GlobalKey<State<GameAlertBanner>> _alertBannerKey = GlobalKey();  // 얼럿 배너 상태 유지용
  
  // 이전 상태 추적 (얼럿 트리거용)
  int? _prevPlayer1GoCount;
  int? _prevPlayer2GoCount;
  int? _prevPlayer3GoCount;
  bool? _prevPlayer1Shaking;
  bool? _prevPlayer2Shaking;
  bool? _prevPlayer3Shaking;
  bool? _prevPlayer1Bomb;
  bool? _prevPlayer2Bomb;
  bool? _prevPlayer3Bomb;
  bool? _prevPlayer1MeongTta;
  bool? _prevPlayer2MeongTta;
  bool? _prevPlayer3MeongTta;
  int? _prevPlayer1Kwang;
  int? _prevPlayer2Kwang;
  int? _prevPlayer3Kwang;
  int? _prevPlayer1Animal;
  int? _prevPlayer2Animal;
  int? _prevPlayer3Animal;
  int? _prevPlayer1Ribbon;
  int? _prevPlayer2Ribbon;
  int? _prevPlayer3Ribbon;
  int? _prevPlayer1Pi;
  int? _prevPlayer2Pi;
  int? _prevPlayer3Pi;

  // 아이템 사용 애니메이션 상태 (동기화용)
  int? _lastShownItemUsedAt; // 타임스탬프로 새로운 아이템 사용 감지
  bool _showingItemUseOverlay = false;

  // 턴 타이머 상태
  Timer? _turnTimer;
  int _remainingSeconds = 60;
  static const int _turnDuration = 60; // 60초 턴 제한

  // 상대방 퇴장 자동 플레이 상태
  Timer? _opponentLeftAutoPlayTimer;
  bool _processingAutoPlay = false; // 자동 플레이 중복 실행 방지

  // 디버그 모드 상태
  bool _debugModeActive = false;

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
    _loadUserSoundSetting(); // 사용자 사운드 설정 로드

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
      onMatchSound: () => _soundService.playTakMatch(),
      onMissSound: () => _soundService.playTakMiss(),
    );
    _cardAnimController.addListener(() {
      if (mounted) setState(() {});
    });

    _listenToRoom();
    _listenToCoins();

    // 아바타 및 카드 이미지 프리로딩 (게임 시작 전 미리 로드)
    // 웹 브라우저에서 동시 요청 제한으로 인한 이미지 로드 실패 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AvatarPreloader.preloadAll(context);
      CardPreloader.preloadAll(context);
    });
  }

  /// 게임 중 나갔다가 다시 들어온 경우 복귀 처리
  Future<void> _tryRejoinRoom(RoomService roomService, String? myUid) async {
    if (myUid == null) return;

    try {
      final rejoined = await roomService.rejoinRoom(
        roomId: widget.roomId,
        playerId: myUid,
      );

      if (rejoined) {
        debugPrint('[GameScreen] Successfully rejoined room: ${widget.roomId}');
      }
    } catch (e) {
      debugPrint('[GameScreen] Rejoin attempt failed: $e');
    }
  }

  /// 사용자 사운드 설정 로드 및 적용
  Future<void> _loadUserSoundSetting() async {
    final authService = ref.read(authServiceProvider);
    final uid = authService.currentUser?.uid;
    if (uid == null) return;

    final settingsService = ref.read(settingsServiceProvider);
    final settings = await settingsService.getUserSettings(uid);

    // 사용자 설정에 따라 사운드 상태 적용
    _soundService.applyUserSetting(settings.soundEnabled);

    if (mounted) {
      setState(() {}); // UI 갱신 (사운드 아이콘 상태)
    }
  }

  void _listenToRoom() {
    final roomService = ref.read(roomServiceProvider);
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    // 먼저 복귀 시도 (게임 중 나갔다가 다시 들어온 경우)
    _tryRejoinRoom(roomService, myUid);

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
      final wasRematchRequested = _rematchRequested;

      // 3인 고스톱 모드: 내 플레이어 번호에 따라 상대방 재대결 요청 추적
      final isGostopMode = room.gameMode == GameMode.gostop;
      bool newOpponentRematchRequested;
      bool newOpponent2RematchRequested = false;

      if (isGostopMode) {
        // 3인 모드: 플레이어 번호에 따라 두 상대방 추적
        if (widget.isHost) {
          // 호스트: 게스트1, 게스트2 추적
          newOpponentRematchRequested = room.guestRematchRequest;
          newOpponent2RematchRequested = room.guest2RematchRequest;
        } else if (_myPlayerNumber == 2) {
          // 게스트1: 호스트, 게스트2 추적
          newOpponentRematchRequested = room.hostRematchRequest;
          newOpponent2RematchRequested = room.guest2RematchRequest;
        } else {
          // 게스트2: 호스트, 게스트1 추적
          newOpponentRematchRequested = room.hostRematchRequest;
          newOpponent2RematchRequested = room.guestRematchRequest;
        }
      } else {
        // 2인 맞고 모드
        newOpponentRematchRequested = widget.isHost
            ? room.guestRematchRequest
            : room.hostRematchRequest;
      }

      // 光끼 모드 상태 변경 감지
      final wasGwangkkiActive = _gwangkkiModeActive;
      final newGwangkkiActive = room.gwangkkiModeActive;
      final newGwangkkiActivator = room.gwangkkiActivator;

      setState(() {
        _currentRoom = room;
        // 내 재대결 요청 상태
        if (widget.isHost) {
          _rematchRequested = room.hostRematchRequest;
        } else if (_myPlayerNumber == 2) {
          _rematchRequested = room.guestRematchRequest;
        } else {
          _rematchRequested = room.guest2RematchRequest;
        }
        _opponentRematchRequested = newOpponentRematchRequested;
        _opponent2RematchRequested = newOpponent2RematchRequested;
        _gwangkkiModeActive = newGwangkkiActive;
        _gwangkkiActivator = newGwangkkiActivator;
      });

      // 光끼 모드가 새로 활성화되면 알림 표시
      if (!wasGwangkkiActive && newGwangkkiActive) {
        _showGwangkkiModeAlert();
        _clearAllAlertsForGwangkki(); // 광끼모드 시 모든 게임 얼럿 제거
      }

      // 상대방 코인 구독 업데이트
      // 1. 처음 방 정보를 받을 때 (previousRoom == null)
      // 2. 게스트가 입장했을 때
      // 3. 3인 고스톱: guest2 입장했을 때
      final needsSubscriptionUpdate =
          previousRoom == null || // 초기 로딩
          (previousRoom.guest == null && room.guest != null) || // 게스트1 입장
          (previousRoom.guest2 == null && room.guest2 != null); // 게스트2 입장

      if (needsSubscriptionUpdate) {
        _updateOpponentCoinSubscription();
      }

      // 재대결 대기 중 상대방이 나갔는지 확인
      if (_showingResult &&
          wasRematchRequested &&
          !_opponentLeftDuringRematch) {
        // 게스트가 나갔는지 확인 (이전에 있었는데 없어짐)
        if (previousRoom?.guest != null && room.guest == null) {
          _opponentLeftDuringRematch = true;
          _showOpponentLeftDialog();
          return;
        }
      }

      // 게임 중 상대방이 나갔는지 확인 (leftPlayer 필드)
      if (room.state == RoomState.playing &&
          room.gameState?.endState == GameEndState.none &&
          room.leftPlayer != null &&
          room.leftPlayer != myUid) {
        // 상대방이 나감 → 자동 플레이 트리거
        _handleOpponentLeftDuringGame(room);
      }

      // 상대방이 복귀했는지 확인 (이전에 leftPlayer가 있었는데 없어짐)
      if (previousRoom?.leftPlayer != null && room.leftPlayer == null) {
        _opponentLeftAutoPlayTimer?.cancel();
        _opponentLeftAutoPlayTimer = null;
        debugPrint(
          '[GameScreen] Opponent rejoined, cancelling auto-play timer',
        );
      }

      // 양쪽 모두 재대결 요청 시 게임 재시작
      // 호스트만 startRematch 호출하여 방 상태를 waiting으로 변경
      if (room.bothWantRematch && widget.isHost) {
        _cancelRematchTimer();
        _startRematch();
      }

      // 게스트: 양쪽 모두 재대결 요청 시 즉시 재대결 진행 상태로 전환
      // (호스트가 startRematch를 호출하기 전에 미리 플래그 설정)
      if (!widget.isHost && room.bothWantRematch && !_rematchInProgress) {
        _cancelRematchTimer();
        debugPrint(
          '[GameScreen] Guest: Both want rematch, setting rematchInProgress',
        );
        setState(() {
          _rematchInProgress = true;
          _showingResult = false;
        });
      }

      // 게스트: 재대결로 방 상태가 waiting으로 변경되면 상태 초기화
      // (호스트가 startRematch를 호출하여 방 상태를 waiting으로 변경한 경우)
      if (!widget.isHost &&
          previousRoom?.state == RoomState.finished &&
          room.state == RoomState.waiting) {
        _cancelRematchTimer();
        debugPrint('[GameScreen] Guest: Rematch initiated, resetting state');
        setState(() {
          _isGameStarted = false;
          _showingResult = false;
          _rematchRequested = false;
          _opponentRematchRequested = false;
          _opponent2RematchRequested = false; // 3인 모드용
          _lastShownEvent = SpecialEvent.none;
          _lastShownEventAt = null; // 타임스탬프 초기화
          _coinTransferAmount = null;
          _gostopSettlementResult = null; // 3인 고스톱 정산 정보 초기화
          _myLoserSettlement = null; // 패자 정산 정보 초기화
          // 코인 정산 완료 상태는 유지하여 중복 정산 방지
          _coinSettlementDone = true;
          _rematchCountdown = 15;
          _opponentLeftDuringRematch = false;
          // 재대결 진행 중 플래그 설정 - 새 게임 시작 전까지 결과 UI 표시 차단
          _rematchInProgress = true;
        });
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
        // 새 게임 시작 감지 (게임이 처음 시작된 경우)
        // 재대결 후 새 게임이 시작되면 모든 재대결 관련 상태 완전히 리셋
        if (previousRoom?.gameState == null) {
          // 게임 시작 효과음 재생 (양쪽 플레이어 모두)
          _soundService.playGameStart();
          
          // 새 게임 시작 시 모든 얼럿 리셋
          _resetAllAlertsForNewGame();

          if (_coinSettlementDone ||
              _rematchInProgress ||
              _rematchRequested ||
              _opponentRematchRequested) {
            debugPrint(
              '[GameScreen] New game started, resetting ALL rematch flags',
            );
            _cancelRematchTimer(); // 재대결 타이머 확실히 취소
            setState(() {
              _coinSettlementDone = false;
              _bonusRouletteAdded = false;
              _bonusSlotAdded = false;
              _rematchInProgress = false;
              _rematchRequested = false;
              _opponentRematchRequested = false;
              _opponent2RematchRequested = false; // 3인 모드용
              _rematchCountdown = 15;
              // 광끼 관련 상태 초기화
              _kwangkkiGained = null;
              _showingGwangkkiAnger = false;
              _gwangkkiAngerPoints = 0;
              _prevPiStolenCount = null;
              _prevSpecialEvent = null;
              _prevLastEventAt = null;
              _myTurnStartCapturedCount = null;
              _lastCheckedTurnIndex = null;
            });
          }
        }

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
            
            // 게임 시작 얼럿 표시
            final gameMode = _currentRoom?.gameMode == GameMode.gostop ? '고스톱' : '맞고';
            _showGameStartAlert(gameMode, firstPlayerName);
          }
        }

        // 게임 상태 변경 시 얼럿 체크
        if (room.gameState != null && !_gwangkkiModeActive) {
          _checkAndTriggerAlerts(room.gameState!, previousRoom?.gameState);
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

        // 특수 이벤트 표시 (타임스탬프 기반으로 같은 타입의 연속 이벤트도 감지)
        if (room.gameState!.lastEvent != SpecialEvent.none &&
            (room.gameState!.lastEventAt != _lastShownEventAt ||
                room.gameState!.lastEvent != _lastShownEvent) &&
            !_showingEvent) {
          // 보너스 카드 사용 이벤트는 별도 처리 (상대방의 경우)
          // lastEventAt 타임스탬프로 연속 이벤트 감지
          if (room.gameState!.lastEvent == SpecialEvent.bonusCardUsed &&
              room.gameState!.lastEventPlayer != myUid &&
              !_showingBonusCardEffect &&
              room.gameState!.lastEventAt != _lastShownBonusEventAt) {
            _lastShownBonusEventAt = room.gameState!.lastEventAt;
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
              } else if (room.guest2 != null &&
                  room.gameState!.chongtongPlayer == room.guest2!.uid) {
                winnerName = room.guest2!.displayName;
              }
            }
            setState(() {
              _chongtongCards = room.gameState!.chongtongCards;
              _chongtongWinnerName = winnerName;
              _showingChongtongCards = true;
            });
          }

          // 폭탄 이벤트: bombCards가 있으면 양쪽 플레이어 모두에게 표시
          if (room.gameState!.lastEvent == SpecialEvent.bomb &&
              room.gameState!.bombCards.isNotEmpty &&
              !_showingBombCards) {
            // 폭탄 사용자 이름 결정
            String? playerName;
            if (room.gameState!.bombPlayer != null) {
              if (room.gameState!.bombPlayer == room.host.uid) {
                playerName = room.host.displayName;
              } else if (room.guest != null &&
                  room.gameState!.bombPlayer == room.guest!.uid) {
                playerName = room.guest!.displayName;
              } else if (room.guest2 != null &&
                  room.gameState!.bombPlayer == room.guest2!.uid) {
                playerName = room.guest2!.displayName;
              }
            }
            setState(() {
              _bombCards = room.gameState!.bombCards;
              _bombPlayerName = playerName ?? '상대방';
              _bombTargetCard = room.gameState!.bombTargetCard;
              _showingBombCards = true;
            });
          }

          // 멍따 이벤트: meongTtaCards가 있으면 양쪽 플레이어 모두에게 표시
          if (room.gameState!.lastEvent == SpecialEvent.meongTta &&
              room.gameState!.meongTtaCards.isNotEmpty &&
              !_showingMeongTtaCards) {
            // 멍따 플레이어 이름 결정
            String? playerName;
            if (room.gameState!.meongTtaPlayer != null) {
              if (room.gameState!.meongTtaPlayer == room.host.uid) {
                playerName = room.host.displayName;
              } else if (room.guest != null &&
                  room.gameState!.meongTtaPlayer == room.guest!.uid) {
                playerName = room.guest!.displayName;
              } else if (room.guest2 != null &&
                  room.gameState!.meongTtaPlayer == room.guest2!.uid) {
                playerName = room.guest2!.displayName;
              }
            }
            setState(() {
              _meongTtaCards = room.gameState!.meongTtaCards;
              _meongTtaPlayerName = playerName ?? '상대방';
              _showingMeongTtaCards = true;
            });
          }

          _showSpecialEvent(
            room.gameState!.lastEvent,
            room.gameState!.lastEventPlayer == myUid,
            room.gameState!.lastEventAt,
          );
        }

        // 아이템 사용 애니메이션 동기화: 타임스탬프 기반으로 새로운 사용 감지
        // (lastEvent와 독립적으로 처리)
        final lastItem = room.gameState!.lastItemUsed;
        final lastItemBy = room.gameState!.lastItemUsedBy;
        final lastItemAt = room.gameState!.lastItemUsedAt;
        if (lastItem != null &&
            lastItemBy != null &&
            lastItemAt != null &&
            lastItemAt != _lastShownItemUsedAt &&
            !_showingItemUseOverlay &&
            mounted) {
          // 사용자 이름 결정
          String itemUserName;
          if (lastItemBy == room.host.uid) {
            itemUserName = room.host.displayName;
          } else if (room.guest != null && lastItemBy == room.guest!.uid) {
            itemUserName = room.guest!.displayName;
          } else if (room.guest2 != null && lastItemBy == room.guest2!.uid) {
            itemUserName = room.guest2!.displayName;
          } else {
            itemUserName = '알 수 없음';
          }

          // 아이템 타입 파싱
          try {
            final itemType = ItemType.values.firstWhere(
              (e) => e.name == lastItem,
            );
            setState(() {
              _lastShownItemUsedAt = lastItemAt;
              _showingItemUseOverlay = true;
            });
            // 오버레이 표시 - mounted 체크 완료됨
            _showItemUseAnimation(itemUserName, itemType);
          } catch (_) {
            // 알 수 없는 아이템 타입 무시
          }
        }

        // 피 빼앗김 알림 표시 (내가 피를 빼앗긴 경우)
        if (room.gameState!.piStolenCount > 0 &&
            room.gameState!.piStolenFromPlayers.contains(myUid) &&
            !_showingPiStolenNotification) {
          _showPiStolenNotification(room.gameState!.piStolenCount);
        }
        
        // 광끼 축적 이벤트 감지 (뻑, 피빼앗김, 카드획득실패)
        _checkGwangkkiAccumulationEvents(room.gameState!, previousRoom?.gameState);

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

        // 9월 열끗 선택 다이얼로그 표시
        if (room.gameState!.waitingForSeptemberChoice &&
            room.gameState!.septemberChoicePlayer == myUid &&
            !_showingSeptemberChoice &&
            !_showingResult) {
          _showSeptemberChoiceDialog(room.gameState!);
        }

        // 게임 종료 결과 표시
        // 일반 게임 종료: 이전 상태가 none이었다가 종료된 경우
        // 총통 종료: 총통 카드 오버레이가 없고, endState가 chongtong인 경우
        // 재대결 후 새 게임에서는 결과 다이얼로그를 표시하지 않음 (_coinSettlementDone, _rematchInProgress 체크)
        final isNormalGameEnd =
            room.gameState!.endState != GameEndState.none &&
            previousRoom?.gameState?.endState == GameEndState.none;
        final isChongtongEnd =
            room.gameState!.endState == GameEndState.chongtong &&
            !_showingChongtongCards &&
            room.gameState!.chongtongCards.isNotEmpty;

        // 코인 정산이 이미 완료되었거나 재대결 진행 중인 경우 결과 표시 건너뛰기
        if ((isNormalGameEnd || isChongtongEnd) &&
            !_showingResult &&
            !_coinSettlementDone &&
            !_rematchInProgress) {
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
              } else if (room.guest2 != null &&
                  room.gameState!.chongtongPlayer == room.guest2!.uid) {
                winnerName = room.guest2!.displayName;
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
    _myWalletSubscription = coinService.getUserWalletStream(myUid).listen((
      wallet,
    ) {
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

    // 맞고 모드: 상대 1명
    // 고스톱 모드: 상대 2명
    final isGostopMode = _currentRoom?.gameMode == GameMode.gostop;

    // 첫 번째 상대 (맞고: 유일한 상대, 고스톱: guest1 또는 host)
    String? opponent1Uid;
    if (isGostopMode) {
      // 고스톱: _myPlayerNumber에 따라 결정
      switch (_myPlayerNumber) {
        case 1: // 나는 host → 상대1: guest1
          opponent1Uid = _currentRoom?.guest?.uid;
          break;
        case 2: // 나는 guest1 → 상대1: host
          opponent1Uid = _currentRoom?.host.uid;
          break;
        case 3: // 나는 guest2 → 상대1: host
          opponent1Uid = _currentRoom?.host.uid;
          break;
      }
    } else {
      // 맞고 모드
      opponent1Uid = widget.isHost
          ? _currentRoom?.guest?.uid
          : _currentRoom?.host.uid;
    }

    if (opponent1Uid != null) {
      _opponentWalletSubscription?.cancel();
      _opponentWalletSubscription = coinService
          .getUserWalletStream(opponent1Uid)
          .listen((wallet) {
            if (mounted) {
              setState(() {
                _opponentCoinBalance = wallet?.coin;
              });
            }
          });
    }

    // 고스톱 모드: 두 번째 상대 구독
    if (isGostopMode) {
      String? opponent2Uid;
      switch (_myPlayerNumber) {
        case 1: // 나는 host → 상대2: guest2
          opponent2Uid = _currentRoom?.guest2?.uid;
          break;
        case 2: // 나는 guest1 → 상대2: guest2
          opponent2Uid = _currentRoom?.guest2?.uid;
          break;
        case 3: // 나는 guest2 → 상대2: guest1
          opponent2Uid = _currentRoom?.guest?.uid;
          break;
      }

      if (opponent2Uid != null) {
        _opponent2WalletSubscription?.cancel();
        _opponent2WalletSubscription = coinService
            .getUserWalletStream(opponent2Uid)
            .listen((wallet) {
              if (mounted) {
                setState(() {
                  _opponent2CoinBalance = wallet?.coin;
                });
              }
            });
      }
    }
  }

  Future<void> _startGame() async {
    if (!widget.isHost || _currentRoom == null) return;

    // 게임 시작 시 재대결 타이머 확실히 취소
    _cancelRematchTimer();

    setState(() {
      _isGameStarted = true;
      // 재대결 관련 플래그 모두 리셋
      _rematchRequested = false;
      _opponentRematchRequested = false;
      _opponent2RematchRequested = false; // 3인 모드용
      _rematchCountdown = 15;
    });

    try {
      final matgoLogic = ref.read(matgoLogicServiceProvider);
      await matgoLogic.initializeGame(
        roomId: widget.roomId,
        hostUid: _currentRoom!.host.uid,
        guestUid: _currentRoom!.guest!.uid,
        hostName: _currentRoom!.host.displayName,
        guestName: _currentRoom!.guest!.displayName,
        guest2Uid: _currentRoom!.guest2?.uid,
        guest2Name: _currentRoom!.guest2?.displayName,
        gameCount: _currentRoom!.gameCount,
        lastWinner: _currentRoom!.lastWinner,
        gameMode: _currentRoom!.gameMode,
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
      _opponent2RematchRequested = false; // 3인 모드용
      _lastShownEvent = SpecialEvent.none;
      _lastShownEventAt = null; // 타임스탬프 초기화
      _previousGameState = null;
      _coinTransferAmount = null;
      _gostopSettlementResult = null; // 3인 고스톱 정산 정보 초기화
      _myLoserSettlement = null; // 패자 정산 정보 초기화
      _coinSettlementDone = false;
      _bonusRouletteAdded = false;
      _bonusSlotAdded = false;
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
      await _processScenarioB(
        previousState,
        currentState,
        cachedFloorPositions,
      );

      // 개선: 스택 상태 표시를 위한 딜레이 추가
      // 카드들이 바닥에 쌓인 상태를 볼 시간을 확보 (특히 따닥, 뻑 상황에서 중요)
      await Future.delayed(const Duration(milliseconds: 400));

      // 2. 시나리오 C: 카드가 획득되었는지 확인
      await _processScenarioC(
        previousState,
        currentState,
        myUid,
        cachedFloorPositions,
      );
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
      debugPrint(
        '[ScenarioB] 덱 변화 없음 (이전: ${previousState.deck.length}, 현재: ${currentState.deck.length})',
      );
      return;
    }

    debugPrint('[ScenarioB] === 시작 ===');
    debugPrint(
      '[ScenarioB] 이전 바닥: ${previousState.floorCards.map((c) => '${c.id}(${c.month}월)').toList()}',
    );
    debugPrint(
      '[ScenarioB] 현재 바닥: ${currentState.floorCards.map((c) => '${c.id}(${c.month}월)').toList()}',
    );
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

    debugPrint(
      '[ScenarioB] 덱에서 뒤집힌 카드 후보: ${flippedFromDeck.map((c) => '${c.id}(${c.month}월)').toList()}',
    );

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
    debugPrint(
      '[ScenarioB] 덱에서 뒤집힌 카드 확정: ${flippedCard.id} (${flippedCard.month}월)',
    );

    // 바닥 카드 위치 계산
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    Offset targetPosition;

    // ★ 핵심 로직: 뒤집힌 카드가 현재 바닥에 있는지로 매칭 여부 판단
    // - 바닥에 있음 = 매칭 없음 (바닥에 놓임)
    // - 바닥에 없음 = 매칭됨 (획득됨)
    final flippedCardInFloor = currentState.floorCards.any(
      (c) => c.id == flippedCard.id,
    );
    debugPrint('[ScenarioB] 뒤집힌 카드가 현재 바닥에 있음: $flippedCardInFloor');

    // 현재 바닥에 있는 같은 월 카드 (뒤집힌 카드 제외)
    final currentSameMonthFloor = currentState.floorCards
        .where((c) => c.month == flippedCard.month && c.id != flippedCard.id)
        .toList();
    debugPrint(
      '[ScenarioB] 현재 바닥에 남은 ${flippedCard.month}월 카드: ${currentSameMonthFloor.map((c) => c.id).toList()}',
    );

    // 이전 상태에서 같은 월 카드 (매칭 위치 추적용)
    final previousSameMonthFloor = previousState.floorCards
        .where((c) => c.month == flippedCard.month)
        .toList();
    debugPrint(
      '[ScenarioB] 이전 바닥 ${flippedCard.month}월 카드: ${previousSameMonthFloor.map((c) => c.id).toList()}',
    );

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
      debugPrint(
        '[ScenarioB] ★ 쪽(Kiss) 감지: 손패 ${playedHandCard.id} + 덱 ${flippedCard.id} (${flippedCard.month}월)',
      );
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
      final flippedIndex = currentState.floorCards.indexWhere(
        (c) => c.id == flippedCard.id,
      );
      final angle = -math.pi / 2 + (flippedIndex * angleStep);

      targetPosition = Offset(
        screenSize.width / 2 + radius * math.cos(angle),
        safeAreaTop + screenSize.height * 0.4 + radius * math.sin(angle) * 0.6,
      );
      debugPrint(
        '[ScenarioB] 빈 공간 위치: $targetPosition (인덱스: $flippedIndex, 총 $floorCardCount장)',
      );
    } else if (isKissScenario && playedHandCard != null) {
      // ★ 쪽 상황: 덱 카드를 손패 카드 위치로 보냄
      debugPrint(
        '[ScenarioB] ★ 쪽 처리 - 덱 카드를 손패 카드(${playedHandCard.id}) 위치로 이동',
      );

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
        debugPrint(
          '[ScenarioB] ✓ 쪽 - 손패 카드 위치 확정 (스택 offset 적용): ${playedHandCard.id}',
        );
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
          debugPrint(
            '[ScenarioB] ✓ 매칭 카드 위치 확정 (스택 offset 적용): ${matchingFloorCard.id} (${matchingFloorCard.month}월)',
          );
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
    // 이전 획득 패와 현재 획득 패 비교 (3인 고스톱 지원)
    final prevCaptured = switch (_myPlayerNumber) {
      1 => previousState.player1Captured,
      2 => previousState.player2Captured,
      3 => previousState.player3Captured,
      _ => previousState.player1Captured,
    };
    final currCaptured = switch (_myPlayerNumber) {
      1 => currentState.player1Captured,
      2 => currentState.player2Captured,
      3 => currentState.player3Captured,
      _ => currentState.player1Captured,
    };

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

    // 손패에서 플레이된 카드 식별 (Scenario A에서 이미 처리됨) - 3인 고스톱 지원
    final previousHand1Ids = previousState.player1Hand.map((c) => c.id).toSet();
    final previousHand2Ids = previousState.player2Hand.map((c) => c.id).toSet();
    final previousHand3Ids = previousState.player3Hand.map((c) => c.id).toSet();
    final currentHand1Ids = currentState.player1Hand.map((c) => c.id).toSet();
    final currentHand2Ids = currentState.player2Hand.map((c) => c.id).toSet();
    final currentHand3Ids = currentState.player3Hand.map((c) => c.id).toSet();
    final playedFromHand = previousHand1Ids
        .difference(currentHand1Ids)
        .union(previousHand2Ids.difference(currentHand2Ids))
        .union(previousHand3Ids.difference(currentHand3Ids));

    debugPrint('[ScenarioC] 손패에서 플레이된 카드 (Scenario A에서 처리됨): $playedFromHand');

    // 이번 턴에 새로 획득한 전체 카드 수 (손패 카드 포함)
    final totalNewlyCaptured = currAllCards
        .where((c) => !prevAllIds.contains(c.id))
        .toList();
    final totalCapturedCount = totalNewlyCaptured.length;
    debugPrint('[ScenarioC] 이번 턴 총 획득 카드 수: $totalCapturedCount장');

    // 새로 획득한 카드 중 손패에서 플레이된 카드는 제외 (Scenario A에서 이미 처리됨)
    final newlyCaptured = currAllCards
        .where((c) => !prevAllIds.contains(c.id))
        .where((c) => !playedFromHand.contains(c.id)) // 손패 카드 제외
        .toList();

    if (newlyCaptured.isEmpty) {
      debugPrint('[ScenarioC] 새로 획득한 바닥 카드 없음 (손패 카드 제외 후)');
      return;
    }

    debugPrint(
      '[ScenarioC] 새로 획득한 바닥 카드 ${newlyCaptured.length}장: ${newlyCaptured.map((c) => c.id).toList()}',
    );

    // 이전 바닥에 있던 카드 위치들 수집 (캐시된 위치 우선 사용)
    final positions = <Offset>[];
    for (final card in newlyCaptured) {
      final floorKey = 'floor_${card.id}';
      final pos =
          cachedFloorPositions[floorKey] ??
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
      positions.add(
        Offset(screenSize.width / 2, safeAreaTop + screenSize.height * 0.4),
      );
    }

    // 획득 영역 위치 계산
    final capturePosition = _positionTracker.getCaptureZonePosition(
      _playerCaptureKey,
    );
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    final targetPosition =
        capturePosition ??
        Offset(screenSize.width * 0.2, safeAreaTop + screenSize.height * 0.75);

    // 카드 획득 애니메이션 실행 (시나리오 C)
    // totalCapturedCount: 손패 카드 포함 이번 턴에 획득한 전체 카드 수를 표시
    await _cardAnimController.animateCollectCards(
      cards: newlyCaptured,
      fromPositions: positions,
      toPosition: targetPosition,
      bonusCount: totalCapturedCount > 0 ? totalCapturedCount : null,
    );
  }

  void _onHandCardTap(CardData card) {
    final gameState = _currentRoom?.gameState;
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    if (gameState == null || gameState.turn != myUid) return;
    if (_showingGoStop ||
        _showingResult ||
        _showingCardSelection ||
        _showingDeckSelection)
      return;
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
    final handCardPosition = _positionTracker.getCardPosition(
      'hand_${bonusCard.id}',
    );
    final capturePosition = _positionTracker.getCaptureZonePosition(
      _playerCaptureKey,
    );

    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    final startPos =
        handCardPosition ??
        Offset(screenSize.width / 2, safeAreaTop + screenSize.height * 0.8);

    final endPos =
        capturePosition ??
        Offset(screenSize.width * 0.2, safeAreaTop + screenSize.height * 0.75);

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
      playerNumber: _myPlayerNumber,
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

    // 상대방의 점수패에서 보너스 카드 찾기 (3인 고스톱 지원)
    // lastEventPlayer로 보너스 카드를 사용한 플레이어 식별
    final eventPlayerUid = gameState.lastEventPlayer;
    final int eventPlayerNumber;
    if (eventPlayerUid == _currentRoom?.host.uid) {
      eventPlayerNumber = 1;
    } else if (eventPlayerUid == _currentRoom?.guest?.uid) {
      eventPlayerNumber = 2;
    } else if (eventPlayerUid == _currentRoom?.guest2?.uid) {
      eventPlayerNumber = 3;
    } else {
      eventPlayerNumber = widget.isHost ? 2 : 1; // fallback
    }
    final opponentCaptured = switch (eventPlayerNumber) {
      1 => gameState.player1Captured,
      2 => gameState.player2Captured,
      3 => gameState.player3Captured,
      _ => gameState.player2Captured,
    };

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
    final capturePosition = _positionTracker.getCaptureZonePosition(
      _opponentCaptureKey,
    );
    final endPos =
        capturePosition ??
        Offset(screenSize.width * 0.8, safeAreaTop + screenSize.height * 0.15);

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

    // 손패 확인 (비어있어야 함) - 3인 고스톱 모드 지원
    final myHand = _getMyHand(gameState);

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

    final matgoLogic = ref.read(matgoLogicServiceProvider);

    await matgoLogic.flipDeckOnly(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: _primaryOpponentUid,
      playerNumber: _myPlayerNumber,
    );
  }

  Future<void> _playCard(CardData handCard, CardData? floorCard) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    // 애니메이션 중이면 무시
    if (_cardAnimController.isAnimating) return;

    setState(() => _selectedHandCard = null);

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
    final handCardPosition = _positionTracker.getCardPosition(
      'hand_${handCard.id}',
    );

    // 목적지 결정: 매칭 바닥 카드가 있으면 그 위치, 없으면 덱 위치
    // 개선: 카드가 쌓일 때 스택 offset을 주어 여러 장이 쌓인 것이 보이도록 함
    const stackOffset = Offset(4, -6); // 우상향으로 살짝 비켜서 쌓임

    Offset? targetPosition;

    if (floorCard != null) {
      // 매칭 바닥 카드 위치로 이동 (스택 offset 적용)
      targetPosition = _positionTracker.getCardPosition(
        'floor_${floorCard.id}',
      );
      if (targetPosition != null) {
        targetPosition = targetPosition + stackOffset;
      }
    } else if (matchingCards.length == 1) {
      // 매칭 카드가 1장이면 그 위치로 (스택 offset 적용)
      targetPosition = _positionTracker.getCardPosition(
        'floor_${matchingCards.first.id}',
      );
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

    final fromPosition =
        handCardPosition ??
        Offset(screenSize.width / 2, safeAreaTop + screenSize.height * 0.8);

    final toPosition =
        targetPosition ??
        Offset(screenSize.width / 2, safeAreaTop + screenSize.height * 0.4);

    // 매칭 여부 판단: 바닥에 같은 월 카드가 있으면 매칭
    final hasMatch = matchingCards.isNotEmpty || floorCard != null;

    // 카드 내기 애니메이션 실행 (시나리오 A)
    await _cardAnimController.animatePlayCard(
      card: handCard,
      from: fromPosition,
      to: toPosition,
      hasMatch: hasMatch,
    );

    // 게임 로직 실행
    await matgoLogic.playCard(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: _primaryOpponentUid,
      card: handCard,
      playerNumber: _myPlayerNumber,
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
    if (gameState.deckCard == null || gameState.deckMatchingCards.isEmpty)
      return;

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

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.selectDeckMatchCard(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: _primaryOpponentUid,
      playerNumber: _myPlayerNumber,
      selectedFloorCard: selectedCard,
    );

    _deckCardForSelection = null;
  }

  // 덱 카드 선택 취소 (취소 불가 - 반드시 선택해야 함)
  void _onDeckSelectionCancelled() {
    // 덱 카드 선택은 취소할 수 없음 - 아무것도 하지 않음
  }

  // 9월 열끗 선택 다이얼로그 표시
  void _showSeptemberChoiceDialog(GameState gameState) {
    if (gameState.pendingSeptemberCard == null) return;

    setState(() {
      _showingSeptemberChoice = true;
    });
  }

  // 9월 열끗 선택 완료
  void _onSeptemberChoiceSelected(bool useAsAnimal) async {
    setState(() {
      _showingSeptemberChoice = false;
    });

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.completeSeptemberChoice(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: _primaryOpponentUid,
      playerNumber: _myPlayerNumber,
      useAsAnimal: useAsAnimal,
    );
  }

  void _showSpecialEvent(SpecialEvent event, bool isMyEvent, int? eventAt) {
    _soundService.playSpecialEvent(event);
    setState(() {
      _lastShownEvent = event;
      _lastShownEventAt = eventAt; // 타임스탬프 저장 (연속 동일 이벤트 감지용)
      _showingEvent = true;
    });

    // 특수 룰 로티 애니메이션 트리거 (따닥, 뻑, 쪽)
    _triggerSpecialRuleLottie(event);
  }

  /// 피 빼앗김 알림 표시
  void _showPiStolenNotification(int count) {
    setState(() {
      _showingPiStolenNotification = true;
      _lastPiStolenCount = count;
    });

    // 2초 후 알림 숨김
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _showingPiStolenNotification = false;
        });
      }
    });
  }

  /// 게임 중 광끼 축적 애니메이션 표시 및 점수 업데이트
  /// - 뻑 (puk/jaPuk): +2점
  /// - 피 빼앗김 (piStolen): +2점
  /// - 카드 획득 실패 (noCaptureEvent): +1점
  Future<void> _triggerGwangkkiAnger(int points, String reason) async {
    if (points <= 0 || _gwangkkiModeActive) return;
    
    // 이미 애니메이션 진행 중이면 더 높은 점수만 덮어씀 (중복 방지)
    if (_showingGwangkkiAnger && points <= _gwangkkiAngerPoints) {
      debugPrint('[GwangkkiAnger] ⏭️ 이미 애니메이션 진행 중 (현재: $_gwangkkiAngerPoints점) - $points점 스킵');
      return;
    }
    
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;
    if (myUid == null) return;
    
    // DB에 광끼 점수 추가
    final coinService = ref.read(coinServiceProvider);
    await coinService.addGwangkkiScore(uid: myUid, points: points);
    
    // 애니메이션 표시
    debugPrint('[GwangkkiAnger] 🎯 애니메이션 시작: +$points점 ($reason) - _gwangkkiAngerPoints 설정');
    setState(() {
      _showingGwangkkiAnger = true;
      _gwangkkiAngerPoints = points;
    });
    
    debugPrint('[GwangkkiAnger] ✅ setState 완료: _gwangkkiAngerPoints=$_gwangkkiAngerPoints, _showingGwangkkiAnger=$_showingGwangkkiAnger');
  }
  
  /// 광끼 축적 애니메이션 완료 콜백
  void _onGwangkkiAngerComplete() {
    if (mounted) {
      setState(() {
        _showingGwangkkiAnger = false;
        _gwangkkiAngerPoints = 0;
      });
    }
  }
  
  /// 특수 이벤트로 인한 광끼 축적 감지 (뻑, 피빼앗김, 카드획득실패)
  void _checkGwangkkiAccumulationEvents(GameState gameState, GameState? previousState) {
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;
    if (myUid == null || _gwangkkiModeActive) return;
    
    // 디버그: 이벤트 상태 출력
    if (gameState.lastEvent != SpecialEvent.none) {
      debugPrint('[GwangkkiCheck] lastEvent: ${gameState.lastEvent}, lastEventPlayer: ${gameState.lastEventPlayer}, myUid: $myUid');
      debugPrint('[GwangkkiCheck] pukCards: ${gameState.pukCards.length}, piStolenCount: ${gameState.piStolenCount}, piStolenFromPlayers: ${gameState.piStolenFromPlayers}');
      debugPrint('[GwangkkiCheck] prevLastEventAt: $_prevLastEventAt, currentLastEventAt: ${gameState.lastEventAt}');
    }
    
    // 1. 뻑 생성 이벤트 감지 (내가 뻑을 만들어서 3장을 못 가져가는 경우): +2점
    // - lastEvent가 puk이고 pukCards가 비어있지 않으면 뻑 생성 (나쁜 상황)
    // - lastEvent가 puk이고 pukCards가 비어있으면 타뻑 획득 (좋은 상황 - 제외)
    // - lastEvent가 jaPuk이면 자뻑 획득 (좋은 상황 - 제외)
    // - lastEventPlayer가 나인 경우만 광끼 축적
    final isPukCreation = gameState.lastEvent == SpecialEvent.puk && gameState.pukCards.isNotEmpty;
    final isMyEvent = gameState.lastEventPlayer == myUid;
    final isNewEvent = gameState.lastEventAt != _prevLastEventAt;
    
    if (isPukCreation && isMyEvent && isNewEvent) {
      _prevLastEventAt = gameState.lastEventAt;
      _pukOccurredThisTurn = true; // 이번 턴에 뻑 발생 - 카드 획득 실패 중복 방지
      debugPrint('[GwangkkiAnger] ✅ 뻑 생성 감지! myUid: $myUid, pukCards: ${gameState.pukCards.length}장');
      _triggerGwangkkiAnger(2, '뻑 발생');
    } else if (gameState.lastEvent == SpecialEvent.puk) {
      debugPrint('[GwangkkiAnger] ❌ 뻑 이벤트 있으나 조건 미충족: isPukCreation=$isPukCreation, isMyEvent=$isMyEvent, isNewEvent=$isNewEvent');
    }
    
    // 2. 피 빼앗김 감지 (내가 당한 경우): +2점
    // piStolenFromPlayers에 내가 포함된 경우 광끼 축적 (3인 모드 지원)
    final isPiStolenFromMe = gameState.piStolenCount > 0 && gameState.piStolenFromPlayers.contains(myUid);
    final isNewPiStolen = gameState.piStolenCount != _prevPiStolenCount;
    
    if (isPiStolenFromMe && isNewPiStolen) {
      _prevPiStolenCount = gameState.piStolenCount;
      debugPrint('[GwangkkiAnger] ✅ 피 빼앗김 감지! myUid: $myUid, piStolenCount: ${gameState.piStolenCount}');
      _triggerGwangkkiAnger(2, '피 빼앗김');
    } else if (gameState.piStolenCount > 0) {
      debugPrint('[GwangkkiAnger] ❌ 피 빼앗김 있으나 조건 미충족: isPiStolenFromMe=$isPiStolenFromMe (piStolenFromPlayers=${gameState.piStolenFromPlayers}), isNewPiStolen=$isNewPiStolen');
    }
    
    // 3. 턴에 카드 획득 실패 감지: +1점
    // 내 턴에 손패와 더미패 모두 바닥패와 매칭되지 않아 획득패로 한장도 못 가져간 경우
    if (previousState != null) {
      _checkNoCaptureEvent(gameState, previousState, myUid);
    } else {
      debugPrint('[NoCaptureCheck] ❌ previousState가 null - 스킵');
    }
  }
  
  /// 카드 획득 실패 감지 (내 턴에 한 장도 못 가져간 경우)
  /// 내 턴 시작 시 획득 카드 수를 저장하고, 턴이 끝날 때 비교
  void _checkNoCaptureEvent(GameState current, GameState previous, String myUid) {
    // 내 플레이어 번호 확인
    final myPlayerNumber = current.turnOrder.indexOf(myUid) + 1;
    if (myPlayerNumber < 1 || myPlayerNumber > 3) return;
    
    // 현재 내 획득 카드 수
    final currentCapturedCount = switch (myPlayerNumber) {
      1 => current.player1Captured.allCards.length,
      2 => current.player2Captured.allCards.length,
      3 => current.player3Captured.allCards.length,
      _ => 0,
    };
    
    final isMyTurn = current.currentTurnUid == myUid;
    final turnChanged = current.currentTurnIndex != _lastCheckedTurnIndex;
    
    debugPrint('[NoCaptureCheck] isMyTurn: $isMyTurn, turnChanged: $turnChanged, currentTurnIndex: ${current.currentTurnIndex}, lastChecked: $_lastCheckedTurnIndex');
    debugPrint('[NoCaptureCheck] myTurnStartCapturedCount: $_myTurnStartCapturedCount, currentCapturedCount: $currentCapturedCount, pukOccurredThisTurn: $_pukOccurredThisTurn');
    
    // 턴이 바뀌었고, 이전에 내 턴 시작 카드 수를 기록했다면 체크
    if (turnChanged && _myTurnStartCapturedCount != null && !isMyTurn) {
      // 내 턴이 끝났는지 확인 (이전 턴이 내 턴이었는지)
      final wasMyTurn = previous.currentTurnUid == myUid;
      debugPrint('[NoCaptureCheck] wasMyTurn: $wasMyTurn (previousTurnUid=${previous.currentTurnUid})');
      
      if (wasMyTurn) {
        // 뻑이 발생한 턴이면 카드 획득 실패 중복 축적 방지 (뻑이 +2점으로 더 높음)
        if (_pukOccurredThisTurn) {
          debugPrint('[NoCaptureCheck] ❌ 뻑이 발생한 턴 - 카드 획득 실패 중복 축적 방지');
        } else if (currentCapturedCount <= _myTurnStartCapturedCount!) {
          // 카드 수가 증가하지 않았으면 획득 실패
          debugPrint('[GwangkkiAnger] ✅ 카드 획득 실패 감지! myUid: $myUid, turnStart: $_myTurnStartCapturedCount, current: $currentCapturedCount');
          _triggerGwangkkiAnger(1, '카드 획득 실패');
        } else {
          debugPrint('[NoCaptureCheck] ❌ 카드 획득됨 (${currentCapturedCount - _myTurnStartCapturedCount!}장) - 광끼 축적 안함');
        }
        // 내 턴이 끝났으므로 리셋
        _myTurnStartCapturedCount = null;
        _pukOccurredThisTurn = false; // 뻑 플래그 리셋
      }
    }
    
    // 내 턴이 시작되었으면 현재 획득 카드 수 저장
    if (isMyTurn && _myTurnStartCapturedCount == null) {
      _myTurnStartCapturedCount = currentCapturedCount;
      _pukOccurredThisTurn = false; // 새 턴 시작 시 뻑 플래그 리셋
      debugPrint('[NoCaptureCheck] 내 턴 시작 - 획득 카드 수 저장: $currentCapturedCount');
    }
    
    // 턴 인덱스 업데이트
    _lastCheckedTurnIndex = current.currentTurnIndex;
  }

  /// 아이템 사용 애니메이션 표시 (모든 플레이어에게 동기화)
  void _showItemUseAnimation(String playerName, ItemType itemType) {
    // 아이템 사용 효과음 재생 (양쪽 플레이어 모두 들림)
    _soundService.playItemUse();
    showItemUseOverlay(
      context: context,
      playerName: playerName,
      itemType: itemType,
      onComplete: () {
        if (mounted) {
          setState(() {
            _showingItemUseOverlay = false;
          });
        }
      },
    );
  }

  /// 특수 룰 발생 시 바닥 카드 위치에 로티 애니메이션 표시
  void _triggerSpecialRuleLottie(SpecialEvent event) {
    // 지원하는 이벤트인지 확인
    if (event != SpecialEvent.ttadak &&
        event != SpecialEvent.puk &&
        event != SpecialEvent.jaPuk &&
        event != SpecialEvent.kiss &&
        event != SpecialEvent.sweep &&
        event != SpecialEvent.sulsa) {
      return;
    }

    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    // 바닥 카드에서 관련 카드 위치 찾기
    final positions = <Offset>[];

    // 최근 플레이된 카드와 관련된 바닥 카드들의 위치 찾기
    // 이벤트 발생 시점에서 관련 카드의 월을 찾아서 해당 월의 바닥 카드들 위치를 수집

    // 현재 바닥에 있는 카드들 중에서 같은 월의 카드 위치 수집
    // 이벤트 종류에 따라 다른 처리
    if (event == SpecialEvent.ttadak) {
      // 따닥: 바닥에 2쌍이 매칭된 상황 - 관련 카드 4장 중 최근 착지 위치
      // 가장 최근에 변화가 있었던 카드들의 위치 (현재 바닥의 마지막 몇 장)
      _collectRecentFloorCardPositions(positions, 2);
    } else if (event == SpecialEvent.puk || event == SpecialEvent.jaPuk) {
      // 뻑: 바닥에 같은 월 카드 3장이 쌓인 상황
      _collectStackedFloorCardPositions(positions, 3);
    } else if (event == SpecialEvent.kiss) {
      // 쪽: 바닥에 같은 월 카드 2장이 있고 1장을 내서 가져간 상황
      // 획득 직전의 바닥 카드 위치 (현재 바닥에서 최근 매칭된 카드)
      _collectRecentFloorCardPositions(positions, 1);
    } else if (event == SpecialEvent.sweep) {
      // 싹쓸이: 바닥 전체에 Wind 애니메이션 표시
      // 바닥판 중앙에 큰 애니메이션 1개 표시
      _collectFloorCenterPosition(positions);
    } else if (event == SpecialEvent.sulsa) {
      // 설사: 바닥에 같은 월 카드 3장이 있는 상황
      // 설사 대상 카드들 위치에 grab 애니메이션 표시
      _collectStackedFloorCardPositions(positions, 3);
    }

    if (positions.isNotEmpty) {
      setState(() {
        _showingSpecialRuleLottie = true;
        _specialRuleEvent = event;
        _specialRulePositions = positions;
      });
    }
  }

  /// 바닥판 중앙 위치 수집 (싹쓸이용)
  void _collectFloorCenterPosition(List<Offset> positions) {
    // 화면 레이아웃 기준 (Top: 22%, Center: 46%, Bottom: 32%)
    // 바닥판(Center Zone)의 중앙 위치 계산
    final screenSize = MediaQuery.of(context).size;
    // Top Zone (22%) 아래에서 Center Zone (46%)의 중앙
    // Center Zone 시작: 22%, 끝: 68%, 중앙: 45%
    final floorCenterY = screenSize.height * 0.45;
    final floorCenterX = screenSize.width / 2;
    positions.add(Offset(floorCenterX, floorCenterY));
  }

  /// 최근 바닥 카드들의 위치 수집
  void _collectRecentFloorCardPositions(List<Offset> positions, int count) {
    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    final floorCards = gameState.floorCards;
    final startIndex = (floorCards.length - count).clamp(0, floorCards.length);

    for (var i = startIndex; i < floorCards.length; i++) {
      final card = floorCards[i];
      final pos = _positionTracker.getCardPosition('floor_${card.id}');
      if (pos != null) {
        positions.add(pos);
      }
    }

    // 위치를 찾지 못한 경우 화면 중앙 근처 사용
    if (positions.isEmpty) {
      final screenSize = MediaQuery.of(context).size;
      positions.add(Offset(screenSize.width / 2, screenSize.height * 0.4));
    }
  }

  /// 같은 월로 쌓인 바닥 카드들의 위치 수집 (뻑 상황)
  void _collectStackedFloorCardPositions(List<Offset> positions, int minStack) {
    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    final floorCards = gameState.floorCards;

    // 월별로 카드 그룹화
    final cardsByMonth = <int, List<CardData>>{};
    for (final card in floorCards) {
      cardsByMonth.putIfAbsent(card.month, () => []).add(card);
    }

    // minStack 이상 쌓인 월 찾기
    for (final entry in cardsByMonth.entries) {
      if (entry.value.length >= minStack) {
        for (final card in entry.value) {
          final pos = _positionTracker.getCardPosition('floor_${card.id}');
          if (pos != null) {
            positions.add(pos);
          }
        }
        break; // 첫 번째로 찾은 스택만 처리
      }
    }

    // 위치를 찾지 못한 경우 화면 중앙 근처 사용
    if (positions.isEmpty) {
      final screenSize = MediaQuery.of(context).size;
      positions.add(Offset(screenSize.width / 2, screenSize.height * 0.4));
    }
  }

  /// 특수 룰 로티 애니메이션 완료
  void _onSpecialRuleLottieComplete() {
    setState(() {
      _showingSpecialRuleLottie = false;
      _specialRuleEvent = SpecialEvent.none;
      _specialRulePositions = [];
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

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.declareGo(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: _primaryOpponentUid,
      playerNumber: _myPlayerNumber,
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
      playerNumber: _myPlayerNumber,
    );
  }

  // ==================== 光끼 모드 ====================

  /// 光끼 모드 알림 표시
  void _showGwangkkiModeAlert() {
    setState(() => _showingGwangkkiAlert = true);
    // 광끼 모드 발동 효과음 (양쪽 플레이어 모두 들림)
    _soundService.playGwangkki();
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

  /// 현재 플레이어의 번호 (1: 호스트, 2: 게스트1, 3: 게스트2)
  int get _myPlayerNumber {
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;
    if (myUid == null || _currentRoom == null) {
      return widget.isHost ? 1 : 2; // fallback
    }
    return _currentRoom!.getPlayerNumber(myUid);
  }

  /// 첫 번째 상대방의 UID 가져오기 (2인/3인 모드 모두 지원)
  ///
  /// 맞고(2인): 유일한 상대방
  /// 고스톱(3인): 첫 번째 상대방 (턴 순서상 다음 플레이어)
  String get _primaryOpponentUid {
    if (_currentRoom == null) {
      // fallback: 2인 모드 로직
      return widget.isHost
          ? _currentRoom?.guest?.uid ?? ''
          : _currentRoom?.host.uid ?? '';
    }

    // _myPlayerNumber에 따라 첫 번째 상대방 결정
    switch (_myPlayerNumber) {
      case 1: // 나는 host → 첫 번째 상대: guest1
        return _currentRoom?.guest?.uid ?? '';
      case 2: // 나는 guest1 → 첫 번째 상대: host
        return _currentRoom?.host.uid ?? '';
      case 3: // 나는 guest2 → 첫 번째 상대: host
        return _currentRoom?.host.uid ?? '';
      default:
        return _currentRoom?.guest?.uid ?? '';
    }
  }

  // ==================== 게임 얼럿 ====================

  /// 게임 시작 얼럿 표시
  void _showGameStartAlert(String gameMode, String firstPlayerName) {
    if (_gwangkkiModeActive) return; // 광끼모드에서는 표시 안함
    
    setState(() {
      _gameStartAlert = GameAlertMessage(
        id: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
        type: GameAlertType.gameStart,
        playerName: firstPlayerName,
        message: '[$gameMode] 게임이 시작되었습니다. "$firstPlayerName"님이 선으로 게임을 시작합니다.',
      );
    });
  }

  /// 게임 시작 얼럿 닫기
  void _dismissGameStartAlert() {
    setState(() => _gameStartAlert = null);
  }

  /// 1회성 얼럿 닫기
  void _dismissOneTimeAlert(String alertId) {
    setState(() {
      _currentOneTimeAlert = null;
      // 다음 큐의 얼럿 표시
      if (_oneTimeAlertQueue.isNotEmpty) {
        _currentOneTimeAlert = _oneTimeAlertQueue.removeAt(0);
      }
    });
  }

  /// 지속 얼럿 추가/업데이트
  void _addOrUpdatePersistentAlert(GameAlertMessage alert) {
    if (_gwangkkiModeActive) return; // 광끼모드에서는 표시 안함
    
    setState(() {
      final existingIndex = _persistentAlerts.indexWhere(
        (a) => a.uniqueKey == alert.uniqueKey,
      );
      if (existingIndex >= 0) {
        _persistentAlerts[existingIndex] = alert;
      } else {
        _persistentAlerts.add(alert);
      }
    });
  }

  /// 지속 얼럿 제거
  void _removePersistentAlert(String uniqueKey) {
    setState(() {
      _persistentAlerts.removeWhere((a) => a.uniqueKey == uniqueKey);
    });
  }

  /// 1회성 얼럿 추가 (큐에 추가)
  void _addOneTimeAlert(GameAlertMessage alert) {
    if (_gwangkkiModeActive) return; // 광끼모드에서는 표시 안함
    
    // 이미 표시된 얼럿이면 무시
    if (_shownOneTimeAlertKeys.contains(alert.uniqueKey)) return;
    
    _shownOneTimeAlertKeys.add(alert.uniqueKey);
    
    setState(() {
      if (_currentOneTimeAlert == null) {
        _currentOneTimeAlert = alert;
      } else {
        _oneTimeAlertQueue.add(alert);
      }
    });
  }

  /// 광끼 모드 시 모든 얼럿 제거
  void _clearAllAlertsForGwangkki() {
    setState(() {
      _gameStartAlert = null;
      _persistentAlerts.clear();
      _currentOneTimeAlert = null;
      _oneTimeAlertQueue.clear();
    });
  }

  /// 새 게임 시작 시 모든 얼럿 및 이전 상태 리셋
  void _resetAllAlertsForNewGame() {
    setState(() {
      // 모든 얼럿 제거
      _gameStartAlert = null;
      _persistentAlerts.clear();
      _currentOneTimeAlert = null;
      _oneTimeAlertQueue.clear();
      _shownOneTimeAlertKeys.clear();
      
      // 이전 상태 추적 변수 리셋
      _prevPlayer1GoCount = null;
      _prevPlayer2GoCount = null;
      _prevPlayer3GoCount = null;
      _prevPlayer1Shaking = null;
      _prevPlayer2Shaking = null;
      _prevPlayer3Shaking = null;
      _prevPlayer1Bomb = null;
      _prevPlayer2Bomb = null;
      _prevPlayer3Bomb = null;
      _prevPlayer1MeongTta = null;
      _prevPlayer2MeongTta = null;
      _prevPlayer3MeongTta = null;
      _prevPlayer1Kwang = null;
      _prevPlayer2Kwang = null;
      _prevPlayer3Kwang = null;
      _prevPlayer1Animal = null;
      _prevPlayer2Animal = null;
      _prevPlayer3Animal = null;
      _prevPlayer1Ribbon = null;
      _prevPlayer2Ribbon = null;
      _prevPlayer3Ribbon = null;
      _prevPlayer1Pi = null;
      _prevPlayer2Pi = null;
      _prevPlayer3Pi = null;
    });
  }

  /// 플레이어 이름 가져오기 (playerNumber 기반)
  String _getPlayerNameByNumber(int playerNumber) {
    switch (playerNumber) {
      case 1:
        return _currentRoom?.host.displayName ?? '호스트';
      case 2:
        return _currentRoom?.guest?.displayName ?? '게스트1';
      case 3:
        return _currentRoom?.guest2?.displayName ?? '게스트2';
      default:
        return '플레이어';
    }
  }

  /// 게임 상태 변경 감지 및 얼럿 처리
  void _checkAndTriggerAlerts(GameState gameState, GameState? prevState) {
    if (_gwangkkiModeActive) return; // 광끼모드에서는 처리 안함
    
    final scores = gameState.scores;
    
    // 1, 2, 3번 플레이어의 이름
    final p1Name = _getPlayerNameByNumber(1);
    final p2Name = _getPlayerNameByNumber(2);
    final p3Name = _getPlayerNameByNumber(3);
    
    // === 지속 얼럿: 고 체크 ===
    _checkGoAlert(1, scores.player1GoCount, _prevPlayer1GoCount, p1Name, scores.player1Multiplier);
    _checkGoAlert(2, scores.player2GoCount, _prevPlayer2GoCount, p2Name, scores.player2Multiplier);
    _checkGoAlert(3, scores.player3GoCount, _prevPlayer3GoCount, p3Name, scores.player3Multiplier);
    
    // === 지속 얼럿: 흔들기 체크 ===
    _checkShakeAlert(1, scores.player1Shaking, _prevPlayer1Shaking, p1Name, gameState.shakeCards);
    _checkShakeAlert(2, scores.player2Shaking, _prevPlayer2Shaking, p2Name, gameState.shakeCards);
    _checkShakeAlert(3, scores.player3Shaking, _prevPlayer3Shaking, p3Name, gameState.shakeCards);
    
    // === 지속 얼럿: 폭탄 체크 ===
    _checkBombAlert(1, scores.player1Bomb, _prevPlayer1Bomb, p1Name, gameState.bombCards);
    _checkBombAlert(2, scores.player2Bomb, _prevPlayer2Bomb, p2Name, gameState.bombCards);
    _checkBombAlert(3, scores.player3Bomb, _prevPlayer3Bomb, p3Name, gameState.bombCards);
    
    // === 지속 얼럿: 멍따 체크 ===
    _checkMeongTtaAlert(1, scores.player1MeongTta, _prevPlayer1MeongTta, p1Name);
    _checkMeongTtaAlert(2, scores.player2MeongTta, _prevPlayer2MeongTta, p2Name);
    _checkMeongTtaAlert(3, scores.player3MeongTta, _prevPlayer3MeongTta, p3Name);
    
    // === 1회성 얼럿: 점수 조건 달성 체크 ===
    _checkScoreAchievements(1, gameState.player1Captured, p1Name);
    _checkScoreAchievements(2, gameState.player2Captured, p2Name);
    _checkScoreAchievements(3, gameState.player3Captured, p3Name);
    
    // 이전 상태 업데이트
    _prevPlayer1GoCount = scores.player1GoCount;
    _prevPlayer2GoCount = scores.player2GoCount;
    _prevPlayer3GoCount = scores.player3GoCount;
    _prevPlayer1Shaking = scores.player1Shaking;
    _prevPlayer2Shaking = scores.player2Shaking;
    _prevPlayer3Shaking = scores.player3Shaking;
    _prevPlayer1Bomb = scores.player1Bomb;
    _prevPlayer2Bomb = scores.player2Bomb;
    _prevPlayer3Bomb = scores.player3Bomb;
    _prevPlayer1MeongTta = scores.player1MeongTta;
    _prevPlayer2MeongTta = scores.player2MeongTta;
    _prevPlayer3MeongTta = scores.player3MeongTta;
    _prevPlayer1Kwang = gameState.player1Captured.kwang.length;
    _prevPlayer2Kwang = gameState.player2Captured.kwang.length;
    _prevPlayer3Kwang = gameState.player3Captured.kwang.length;
    _prevPlayer1Animal = gameState.player1Captured.animal.length;
    _prevPlayer2Animal = gameState.player2Captured.animal.length;
    _prevPlayer3Animal = gameState.player3Captured.animal.length;
    _prevPlayer1Ribbon = gameState.player1Captured.ribbon.length;
    _prevPlayer2Ribbon = gameState.player2Captured.ribbon.length;
    _prevPlayer3Ribbon = gameState.player3Captured.ribbon.length;
    _prevPlayer1Pi = gameState.player1Captured.piCount;
    _prevPlayer2Pi = gameState.player2Captured.piCount;
    _prevPlayer3Pi = gameState.player3Captured.piCount;
  }

  /// 고 얼럿 체크
  void _checkGoAlert(int playerNum, int goCount, int? prevGoCount, String playerName, int multiplier) {
    if (goCount > 0 && goCount != prevGoCount) {
      // 고 점수 계산: 1고=+1, 2고=+2, 3고+=배수
      String suffix;
      if (goCount <= 2) {
        suffix = '점수 +$goCount';
      } else {
        final mult = 1 << (goCount - 2); // 2^(goCount-2)
        suffix = '점수 X$mult!';
      }
      
      _addOrUpdatePersistentAlert(GameAlertMessage(
        id: 'go_${playerNum}_$goCount',
        type: GameAlertType.persistent,
        persistentKind: PersistentAlertKind.go,
        playerName: playerName,
        message: '',
        goCount: goCount,
        suffix: suffix,
      ));
    }
  }

  /// 흔들기 얼럿 체크
  void _checkShakeAlert(int playerNum, bool isShaking, bool? wasShaking, String playerName, List<CardData>? shakeCards) {
    if (isShaking && wasShaking != true) {
      final month = shakeCards?.isNotEmpty == true ? shakeCards!.first.month : 0;
      _addOrUpdatePersistentAlert(GameAlertMessage(
        id: 'shake_$playerNum',
        type: GameAlertType.persistent,
        persistentKind: PersistentAlertKind.shake,
        playerName: playerName,
        message: '',
        month: month,
        suffix: '점수 X2!',
      ));
    }
  }

  /// 폭탄 얼럿 체크
  void _checkBombAlert(int playerNum, bool hasBomb, bool? hadBomb, String playerName, List<CardData>? bombCards) {
    if (hasBomb && hadBomb != true) {
      final month = bombCards?.isNotEmpty == true ? bombCards!.first.month : 0;
      _addOrUpdatePersistentAlert(GameAlertMessage(
        id: 'bomb_$playerNum',
        type: GameAlertType.persistent,
        persistentKind: PersistentAlertKind.bomb,
        playerName: playerName,
        message: '',
        month: month,
        suffix: '점수 X2!',
      ));
    }
  }

  /// 멍따 얼럿 체크
  void _checkMeongTtaAlert(int playerNum, bool isMeongTta, bool? wasMeongTta, String playerName) {
    if (isMeongTta && wasMeongTta != true) {
      _addOrUpdatePersistentAlert(GameAlertMessage(
        id: 'meongtta_$playerNum',
        type: GameAlertType.persistent,
        persistentKind: PersistentAlertKind.meongTta,
        playerName: playerName,
        message: '',
        suffix: '점수 X2!',
      ));
    }
  }

  /// 점수 조건 달성 체크 (1회성 얼럿)
  void _checkScoreAchievements(int playerNum, CapturedCards captured, String playerName) {
    final scoreResult = ScoreCalculator.calculateScore(captured);
    
    // 고도리 (새 3장)
    if (scoreResult.godoriBonus > 0) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'godori_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.godori,
        playerName: playerName,
        message: '',
        suffix: '+${scoreResult.godoriBonus}점 획득',
      ));
    }
    
    // 홍단
    if (scoreResult.hongdanBonus > 0) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'hongdan_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.hongdan,
        playerName: playerName,
        message: '',
        suffix: '+${scoreResult.hongdanBonus}점 획득',
      ));
    }
    
    // 청단
    if (scoreResult.cheongdanBonus > 0) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'cheongdan_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.cheongdan,
        playerName: playerName,
        message: '',
        suffix: '+${scoreResult.cheongdanBonus}점 획득',
      ));
    }
    
    // 초단
    if (scoreResult.chodanBonus > 0) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'chodan_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.chodan,
        playerName: playerName,
        message: '',
        suffix: '+${scoreResult.chodanBonus}점 획득',
      ));
    }
    
    // 광 점수 체크
    final kwangCount = captured.kwang.length;
    final hasRainKwang = captured.kwang.any((c) => c.month == 12); // 비광 (12월)
    
    if (kwangCount >= 5) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'ogwang_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.ogwang,
        playerName: playerName,
        message: '',
        suffix: '+${scoreResult.kwangScore}점 획득',
      ));
    } else if (kwangCount >= 4) {
      if (hasRainKwang) {
        _addOneTimeAlert(GameAlertMessage(
          id: 'bigwangsagwang_$playerNum',
          type: GameAlertType.oneTime,
          oneTimeKind: OneTimeAlertKind.bigwangSagwang,
          playerName: playerName,
          message: '',
          suffix: '+${scoreResult.kwangScore}점 획득',
        ));
      } else {
        _addOneTimeAlert(GameAlertMessage(
          id: 'sagwang_$playerNum',
          type: GameAlertType.oneTime,
          oneTimeKind: OneTimeAlertKind.sagwang,
          playerName: playerName,
          message: '',
          suffix: '+${scoreResult.kwangScore}점 획득',
        ));
      }
    } else if (kwangCount >= 3) {
      if (hasRainKwang) {
        _addOneTimeAlert(GameAlertMessage(
          id: 'bigwangsamgwang_$playerNum',
          type: GameAlertType.oneTime,
          oneTimeKind: OneTimeAlertKind.bigwangSamgwang,
          playerName: playerName,
          message: '',
          suffix: '+${scoreResult.kwangScore}점 획득',
        ));
      } else {
        _addOneTimeAlert(GameAlertMessage(
          id: 'samgwang_$playerNum',
          type: GameAlertType.oneTime,
          oneTimeKind: OneTimeAlertKind.samgwang,
          playerName: playerName,
          message: '',
          suffix: '+${scoreResult.kwangScore}점 획득',
        ));
      }
    }
    
    // 피 10장 달성
    final piCount = captured.piCount;
    final prevPi = playerNum == 1 ? _prevPlayer1Pi : (playerNum == 2 ? _prevPlayer2Pi : _prevPlayer3Pi);
    if (piCount >= 10 && (prevPi == null || prevPi < 10)) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'pi10_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.pi10,
        playerName: playerName,
        message: '',
        suffix: '이후 +1점씩 추가됩니다',
      ));
    }
    
    // 띠 5장 달성
    final ribbonCount = captured.ribbon.length;
    final prevRibbon = playerNum == 1 ? _prevPlayer1Ribbon : (playerNum == 2 ? _prevPlayer2Ribbon : _prevPlayer3Ribbon);
    if (ribbonCount >= 5 && (prevRibbon == null || prevRibbon < 5)) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'tti5_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.tti5,
        playerName: playerName,
        message: '',
        suffix: '이후 +1점씩 추가됩니다',
      ));
    }
    
    // 열끗 5장 달성
    final animalCount = captured.animal.length;
    final prevAnimal = playerNum == 1 ? _prevPlayer1Animal : (playerNum == 2 ? _prevPlayer2Animal : _prevPlayer3Animal);
    if (animalCount >= 5 && (prevAnimal == null || prevAnimal < 5)) {
      _addOneTimeAlert(GameAlertMessage(
        id: 'animal5_$playerNum',
        type: GameAlertType.oneTime,
        oneTimeKind: OneTimeAlertKind.animal5,
        playerName: playerName,
        message: '',
        suffix: '이후 +1점씩 추가됩니다',
      ));
    }
  }

  /// 현재 플레이어의 손패 가져오기
  List<CardData> _getMyHand(GameState gameState) {
    switch (_myPlayerNumber) {
      case 1:
        return gameState.player1Hand;
      case 2:
        return gameState.player2Hand;
      case 3:
        return gameState.player3Hand;
      default:
        return gameState.player1Hand;
    }
  }

  /// 현재 플레이어의 획득패 가져오기
  CapturedCards _getMyCaptured(GameState gameState) {
    switch (_myPlayerNumber) {
      case 1:
        return gameState.player1Captured;
      case 2:
        return gameState.player2Captured;
      case 3:
        return gameState.player3Captured;
      default:
        return gameState.player1Captured;
    }
  }

  /// 현재 플레이어의 이름 가져오기
  String _getMyPlayerName() {
    switch (_myPlayerNumber) {
      case 1:
        return _currentRoom?.host.displayName ?? '호스트';
      case 2:
        return _currentRoom?.guest?.displayName ?? '게스트1';
      case 3:
        return _currentRoom?.guest2?.displayName ?? '게스트2';
      default:
        return '플레이어';
    }
  }

  /// 현재 플레이어의 점수 가져오기
  int _getMyScore(GameState? gameState) {
    if (gameState == null) return 0;
    switch (_myPlayerNumber) {
      case 1:
        return gameState.scores.player1Score;
      case 2:
        return gameState.scores.player2Score;
      case 3:
        return gameState.scores.player3Score;
      default:
        return 0;
    }
  }

  /// 현재 플레이어의 고 횟수 가져오기
  int _getMyGoCount(GameState? gameState) {
    if (gameState == null) return 0;
    switch (_myPlayerNumber) {
      case 1:
        return gameState.scores.player1GoCount;
      case 2:
        return gameState.scores.player2GoCount;
      case 3:
        return gameState.scores.player3GoCount;
      default:
        return 0;
    }
  }

  /// 현재 플레이어의 흔들기 상태 가져오기
  bool _getMyShaking(GameState? gameState) {
    if (gameState == null) return false;
    switch (_myPlayerNumber) {
      case 1:
        return gameState.scores.player1Shaking;
      case 2:
        return gameState.scores.player2Shaking;
      case 3:
        return gameState.scores.player3Shaking;
      default:
        return false;
    }
  }

  /// 현재 플레이어의 폭탄 상태 가져오기
  bool _getMyBomb(GameState? gameState) {
    if (gameState == null) return false;
    switch (_myPlayerNumber) {
      case 1:
        return gameState.scores.player1Bomb;
      case 2:
        return gameState.scores.player2Bomb;
      case 3:
        return gameState.scores.player3Bomb;
      default:
        return false;
    }
  }

  /// 현재 플레이어의 멍따 상태 가져오기 (열끗 7장 이상)
  bool _getMyMeongTta(GameState? gameState) {
    if (gameState == null) return false;
    switch (_myPlayerNumber) {
      case 1:
        return gameState.scores.player1MeongTta;
      case 2:
        return gameState.scores.player2MeongTta;
      case 3:
        return gameState.scores.player3MeongTta;
      default:
        return false;
    }
  }

  /// 상대방의 멍따 상태 가져오기 (맞고: 2인 대결용)
  bool _getOpponentMeongTta(GameState? gameState) {
    if (gameState == null) return false;
    // 맞고(2인): 상대방은 나와 반대
    switch (_myPlayerNumber) {
      case 1:
        return gameState.scores.player2MeongTta;
      case 2:
        return gameState.scores.player1MeongTta;
      case 3:
        return gameState.scores.player1MeongTta;
      default:
        return false;
    }
  }

  /// 상대방의 점수 가져오기 (맞고: 2인 대결용)
  int _getOpponentScore(GameState? gameState) {
    if (gameState == null) return 0;
    // 맞고(2인): 상대방은 나와 반대
    // 고스톱(3인): 첫 번째 상대방 점수 반환 (아바타 상태용)
    switch (_myPlayerNumber) {
      case 1:
        return gameState.scores.player2Score;
      case 2:
        return gameState.scores.player1Score;
      case 3:
        return gameState.scores.player1Score;
      default:
        return 0;
    }
  }

  void _showGameResult() async {
    final gameState = _currentRoom?.gameState;
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    if (gameState?.endState == GameEndState.nagari) {
      _soundService.playNagari();
    } else if (gameState?.winner == myUid) {
      _soundService.playWinner();
    } else {
      _soundService.playLoser();
    }

    // 나가리가 아니고 승자가 있으면 코인 정산 처리
    if (gameState?.endState != GameEndState.nagari &&
        gameState?.winner != null &&
        !_coinSettlementDone) {
      await _settleGameCoins();
    }

    // 게임 완료 시 자신에게 보너스 룰렛 +1 추가
    // 나가리 포함 모든 게임 종료 시 적용, 중복 추가 방지
    // 각 플레이어가 자신의 보너스만 추가 (Firebase 권한 제약)
    if (!_bonusRouletteAdded) {
      _bonusRouletteAdded = true;
      final coinService = ref.read(coinServiceProvider);
      final authService = ref.read(authServiceProvider);
      final myUid = authService.currentUser?.uid;
      if (myUid != null) {
        try {
          await coinService.addBonusRoulette(myUid);
          debugPrint('[GameScreen] Bonus roulette added for myself: $myUid');
        } catch (e) {
          debugPrint('[GameScreen] Bonus roulette add failed: $e');
        }
      }
    }

    // 게임 완료 시 자신에게 보너스 슬롯머신 +1 추가
    if (!_bonusSlotAdded) {
      _bonusSlotAdded = true;
      final coinService = ref.read(coinServiceProvider);
      final authService = ref.read(authServiceProvider);
      final myUid = authService.currentUser?.uid;
      if (myUid != null) {
        try {
          await coinService.addBonusSlot(myUid);
          debugPrint('[GameScreen] Bonus slot added for myself: $myUid');
        } catch (e) {
          debugPrint('[GameScreen] Bonus slot add failed: $e');
        }
      }
    }

    setState(() => _showingResult = true);
  }

  Future<void> _settleGameCoins() async {
    final gameState = _currentRoom?.gameState;
    if (gameState == null || gameState.winner == null) return;

    final coinService = ref.read(coinServiceProvider);
    final hostUid = _currentRoom!.host.uid;
    final guestUid = _currentRoom!.guest?.uid;
    final guest2Uid = _currentRoom!.guest2?.uid;

    if (guestUid == null) return;

    final winnerUid = gameState.winner!;
    final finalScore = gameState.finalScore;

    // 고스톱 3인 모드 여부 확인
    final isGostopMode =
        _currentRoom?.gameMode == GameMode.gostop && guest2Uid != null;

    int actualTransfer;

    // 光끼 모드: 발동자가 승리 시에만 모든 코인 독식 (2인 모드 전용)
    if (_gwangkkiModeActive && !isGostopMode) {
      final loserUid = winnerUid == hostUid ? guestUid : hostUid;
      final activatorUid = _gwangkkiActivator ?? winnerUid;
      
      // 발동자가 승자인 경우에만 모든 코인 독식
      if (activatorUid == winnerUid) {
        final loserWallet = await coinService.getUserWallet(loserUid);
        final loserCoins = loserWallet?.coin ?? 0;
        actualTransfer = loserCoins;

        // 호스트만 실제 코인 정산 API 호출 (중복 정산 방지)
        if (widget.isHost) {
          try {
            await coinService.settleGwangkkiMode(
              winnerUid: winnerUid,
              loserUid: loserUid,
              isDraw: false,
              activatorUid: activatorUid,
            );

            await coinService.updateGwangkkiScores(
              winnerUid: winnerUid,
              loserUid: loserUid,
              winnerScore: finalScore,
              isDraw: false,
            );

            final roomService = ref.read(roomServiceProvider);
            await roomService.deactivateGwangkkiMode(widget.roomId);

            debugPrint(
              '[GameScreen] GwangKki mode (activator won): $winnerUid wins ALL ($actualTransfer) coins from $loserUid',
            );
          } catch (e) {
            debugPrint('[GameScreen] GwangKki mode settlement failed: $e');
          }
        }

        setState(() {
          _coinTransferAmount = actualTransfer;
          _coinSettlementDone = true;
        });
        return;
      } else {
        // 발동자가 패배한 경우: 일반 정산 로직 적용 후 광끼 모드 해제
        debugPrint(
          '[GameScreen] GwangKki mode (activator lost): normal settlement applies',
        );
        
        // 호스트만 광끼 모드 해제 및 발동자 점수 리셋
        if (widget.isHost) {
          try {
            await coinService.resetGwangkkiScore(activatorUid);
            final roomService = ref.read(roomServiceProvider);
            await roomService.deactivateGwangkkiMode(widget.roomId);
          } catch (e) {
            debugPrint('[GameScreen] GwangKki mode deactivation failed: $e');
          }
        }
        
        // 일반 정산 로직으로 진행 (아래 코드로 이어짐 - return하지 않음)
      }
    }

    // 고스톱 3인 모드 정산
    if (isGostopMode) {
      // 2명의 패자 결정 (승자가 아닌 나머지 2명)
      // guest2Uid는 isGostopMode 조건에서 이미 null 체크됨
      final allUids = [hostUid, guestUid, guest2Uid];
      final loserUids = allUids.where((uid) => uid != winnerUid).toList();

      if (loserUids.length != 2) {
        debugPrint(
          '[GameScreen] Gostop settlement error: Expected 2 losers, got ${loserUids.length}',
        );
        return;
      }

      final loser1Uid = loserUids[0]!;
      final loser2Uid = loserUids[1]!;

      // 光끼 모드: 발동자가 승리 시에만 모든 코인 독식
      final activatorUid3P = _gwangkkiActivator ?? winnerUid;
      if (_gwangkkiModeActive && activatorUid3P == winnerUid) {
        int loser1Transfer = 0;
        int loser2Transfer = 0;

        // 호스트만 실제 코인 정산 API 호출 (중복 정산 방지)
        if (widget.isHost) {
          try {
            final result = await coinService.settleGwangkkiModeGostop(
              winnerUid: winnerUid,
              loser1Uid: loser1Uid,
              loser2Uid: loser2Uid,
              isDraw: false,
              activatorUid: activatorUid3P,
            );

            loser1Transfer = result.loser1Transfer;
            loser2Transfer = result.loser2Transfer;

            await coinService.updateGwangkkiScores(
              winnerUid: winnerUid,
              loserUid: loser1Uid, // 대표로 첫 번째 패자 기록
              winnerScore: finalScore,
              isDraw: false,
            );

            final roomService = ref.read(roomServiceProvider);
            await roomService.deactivateGwangkkiMode(widget.roomId);

            debugPrint(
              '[GameScreen] GwangKki mode (3P, activator won): $winnerUid wins ALL coins - $loser1Transfer from $loser1Uid, $loser2Transfer from $loser2Uid',
            );
          } catch (e) {
            debugPrint('[GameScreen] GwangKki mode (3P) settlement failed: $e');
          }
        }

        // 패자별 정산 정보 생성 (UI 표시용)
        String getDisplayName(String uid) {
          if (uid == hostUid) return _currentRoom?.host.displayName ?? '호스트';
          if (uid == guestUid)
            return _currentRoom?.guest?.displayName ?? '게스트1';
          if (uid == guest2Uid)
            return _currentRoom?.guest2?.displayName ?? '게스트2';
          return '플레이어';
        }

        int getPlayerNumber(String uid) {
          if (uid == hostUid) return 1;
          if (uid == guestUid) return 2;
          if (uid == guest2Uid) return 3;
          return 0;
        }

        setState(() {
          _coinTransferAmount = loser1Transfer + loser2Transfer;
          _coinSettlementDone = true;
          _gostopSettlementResult = GostopSettlementResult(
            loserDetails: [
              LoserSettlementDetail(
                loserUid: loser1Uid,
                loserDisplayName: getDisplayName(loser1Uid),
                playerNumber: getPlayerNumber(loser1Uid),
                isGwangBak: false,
                isPiBak: false,
                isGobak: false,
                multiplier: 1, // 광끼는 배수 적용 안 함
                baseAmount: loser1Transfer,
                actualTransfer: loser1Transfer,
              ),
              LoserSettlementDetail(
                loserUid: loser2Uid,
                loserDisplayName: getDisplayName(loser2Uid),
                playerNumber: getPlayerNumber(loser2Uid),
                isGwangBak: false,
                isPiBak: false,
                isGobak: false,
                multiplier: 1, // 광끼는 배수 적용 안 함
                baseAmount: loser2Transfer,
                actualTransfer: loser2Transfer,
              ),
            ],
            totalTransfer: loser1Transfer + loser2Transfer,
          );
        });
        return;
      }
      
      // 光끼 모드: 발동자가 패배한 경우 (3인) - 일반 정산 로직 적용
      if (_gwangkkiModeActive && activatorUid3P != winnerUid) {
        debugPrint(
          '[GameScreen] GwangKki mode (3P, activator lost): normal settlement applies',
        );
        
        // 호스트만 광끼 모드 해제 및 발동자 점수 리셋
        if (widget.isHost) {
          try {
            await coinService.resetGwangkkiScore(activatorUid3P);
            final roomService = ref.read(roomServiceProvider);
            await roomService.deactivateGwangkkiMode(widget.roomId);
          } catch (e) {
            debugPrint('[GameScreen] GwangKki mode (3P) deactivation failed: $e');
          }
        }
        // 일반 정산 로직으로 진행 (아래 코드로 이어짐)
      }

      // 일반 고스톱 정산 (광끼 모드가 아닐 때)
      // 각 패자의 획득 패 정보 (광박/피박 판정)
      final loser1Captured = loser1Uid == hostUid
          ? gameState.player1Captured
          : (loser1Uid == guestUid
                ? gameState.player2Captured
                : gameState.player3Captured);
      final loser2Captured = loser2Uid == hostUid
          ? gameState.player1Captured
          : (loser2Uid == guestUid
                ? gameState.player2Captured
                : gameState.player3Captured);

      // 각 패자의 고 카운트 (마지막 고 선언자 판정용)
      final loser1GoCount = loser1Uid == hostUid
          ? gameState.scores.player1GoCount
          : (loser1Uid == guestUid
                ? gameState.scores.player2GoCount
                : gameState.scores.player3GoCount);
      final loser2GoCount = loser2Uid == hostUid
          ? gameState.scores.player1GoCount
          : (loser2Uid == guestUid
                ? gameState.scores.player2GoCount
                : gameState.scores.player3GoCount);

      // 광박: 패자 광 0장
      final loser1GwangBak = loser1Captured.kwang.isEmpty;
      final loser2GwangBak = loser2Captured.kwang.isEmpty;

      // 피박: 고스톱 모드는 피 5장 이하 (piCount 사용 - 쌍피/보너스피는 2장으로 계산)
      final loser1PiBak = loser1Captured.piCount <= 5;
      final loser2PiBak = loser2Captured.piCount <= 5;

      // 고박: 마지막 고 선언자가 패배 (고 카운트 > 0인 패자만)
      // 둘 중 고 카운트가 더 높은 패자가 "마지막 고 선언자"로 판정
      final loser1IsLastGoDeclarer =
          loser1GoCount > 0 && loser1GoCount >= loser2GoCount;
      final loser2IsLastGoDeclarer =
          loser2GoCount > 0 && loser2GoCount >= loser1GoCount;

      // 각 패자별 코인 배수 계산 (UI 표시용)
      int loser1Multiplier = 1;
      int loser2Multiplier = 1;
      if (loser1GwangBak) loser1Multiplier *= 2;
      if (loser1PiBak) loser1Multiplier *= 2;
      if (loser1IsLastGoDeclarer) loser1Multiplier *= 2;
      if (loser2GwangBak) loser2Multiplier *= 2;
      if (loser2PiBak) loser2Multiplier *= 2;
      if (loser2IsLastGoDeclarer) loser2Multiplier *= 2;

      // 각 패자별 예상 정산 금액 (점수 × 배수)
      final loser1ExpectedTransfer = finalScore * loser1Multiplier;
      final loser2ExpectedTransfer = finalScore * loser2Multiplier;

      // 실제 정산 금액 (호스트가 API 호출 후 반환값 사용)
      int loser1ActualTransfer = loser1ExpectedTransfer;
      int loser2ActualTransfer = loser2ExpectedTransfer;

      // 호스트만 실제 코인 정산 API 호출 (중복 정산 방지)
      if (widget.isHost) {
        try {
          final result = await coinService.settleGostopGame(
            winnerUid: winnerUid,
            loser1Uid: loser1Uid,
            loser2Uid: loser2Uid,
            points: finalScore,
            loser1GwangBak: loser1GwangBak,
            loser1PiBak: loser1PiBak,
            loser1IsLastGoDeclarer: loser1IsLastGoDeclarer,
            loser2GwangBak: loser2GwangBak,
            loser2PiBak: loser2PiBak,
            loser2IsLastGoDeclarer: loser2IsLastGoDeclarer,
          );

          // API 반환값으로 실제 이전 금액 업데이트
          loser1ActualTransfer = result.loser1Transfer;
          loser2ActualTransfer = result.loser2Transfer;

          debugPrint(
            '[GameScreen] Gostop coin settlement: $winnerUid wins $loser1ActualTransfer from $loser1Uid, $loser2ActualTransfer from $loser2Uid',
          );
          debugPrint(
            '[GameScreen] Loser1 박: 광박=$loser1GwangBak, 피박=$loser1PiBak, 고박=$loser1IsLastGoDeclarer (x$loser1Multiplier)',
          );
          debugPrint(
            '[GameScreen] Loser2 박: 광박=$loser2GwangBak, 피박=$loser2PiBak, 고박=$loser2IsLastGoDeclarer (x$loser2Multiplier)',
          );
        } catch (e) {
          debugPrint('[GameScreen] Gostop coin settlement failed: $e');
        }
      }

      // 패자별 정산 정보 생성
      String getDisplayName(String uid) {
        if (uid == hostUid) return _currentRoom?.host.displayName ?? '호스트';
        if (uid == guestUid) return _currentRoom?.guest?.displayName ?? '게스트1';
        if (uid == guest2Uid)
          return _currentRoom?.guest2?.displayName ?? '게스트2';
        return '플레이어';
      }

      int getPlayerNumber(String uid) {
        if (uid == hostUid) return 1;
        if (uid == guestUid) return 2;
        if (uid == guest2Uid) return 3;
        return 0;
      }

      final loser1Detail = LoserSettlementDetail(
        loserUid: loser1Uid,
        loserDisplayName: getDisplayName(loser1Uid),
        playerNumber: getPlayerNumber(loser1Uid),
        isGwangBak: loser1GwangBak,
        isPiBak: loser1PiBak,
        isGobak: loser1IsLastGoDeclarer,
        multiplier: loser1Multiplier,
        baseAmount: finalScore,
        actualTransfer: loser1ActualTransfer,
      );

      final loser2Detail = LoserSettlementDetail(
        loserUid: loser2Uid,
        loserDisplayName: getDisplayName(loser2Uid),
        playerNumber: getPlayerNumber(loser2Uid),
        isGwangBak: loser2GwangBak,
        isPiBak: loser2PiBak,
        isGobak: loser2IsLastGoDeclarer,
        multiplier: loser2Multiplier,
        baseAmount: finalScore,
        actualTransfer: loser2ActualTransfer,
      );

      // 현재 플레이어에 따라 표시할 금액 결정 (배수 적용된 금액)
      final authService = ref.read(authServiceProvider);
      final myUid = authService.currentUser?.uid;

      setState(() {
        // 3인 고스톱 정산 정보 저장
        _gostopSettlementResult = GostopSettlementResult(
          loserDetails: [loser1Detail, loser2Detail],
          totalTransfer: loser1ActualTransfer + loser2ActualTransfer,
        );

        if (myUid == winnerUid) {
          // 승자: 두 패자에게서 받은 총합 표시
          _coinTransferAmount = loser1ActualTransfer + loser2ActualTransfer;
          _myLoserSettlement = null; // 승자는 패자 정산 정보 없음
          _kwangkkiGained = null; // 승자는 광끼 축적 없음
        } else if (myUid == loser1Uid) {
          // 패자1: 자신이 잃은 금액 표시 (배수 적용)
          _coinTransferAmount = loser1ActualTransfer;
          _myLoserSettlement = loser1Detail; // 패자1 자신의 정산 정보
          // 패자: 잃은 코인의 50%만큼 광끼 게이지 축적
          _kwangkkiGained = loser1ActualTransfer ~/ 2;
        } else if (myUid == loser2Uid) {
          // 패자2: 자신이 잃은 금액 표시 (배수 적용)
          _coinTransferAmount = loser2ActualTransfer;
          _myLoserSettlement = loser2Detail; // 패자2 자신의 정산 정보
          // 패자: 잃은 코인의 50%만큼 광끼 게이지 축적
          _kwangkkiGained = loser2ActualTransfer ~/ 2;
        } else {
          _coinTransferAmount = 0;
          _myLoserSettlement = null;
          _kwangkkiGained = null;
        }
        _coinSettlementDone = true;
      });
      return;
    }

    // 맞고 2인 모드 정산 (기존 로직)
    final loserUid = winnerUid == hostUid ? guestUid : hostUid;
    final loserWallet = await coinService.getUserWallet(loserUid);
    final loserCoins = loserWallet?.coin ?? 0;
    final baseTransfer = finalScore > loserCoins ? loserCoins : finalScore;

    // 승자/패자의 획득 패 정보 (박 계산용) - UI 표시를 위해 호스트/게스트 모두 계산
    final winnerIsPlayer1 = winnerUid == hostUid;
    final loserCaptured = winnerIsPlayer1
        ? gameState.player2Captured
        : gameState.player1Captured;
    final winnerGoCount = winnerIsPlayer1
        ? gameState.scores.player1GoCount
        : gameState.scores.player2GoCount;
    final loserGoCount = winnerIsPlayer1
        ? gameState.scores.player2GoCount
        : gameState.scores.player1GoCount;

    // 광박: 패자 광 0장
    final isGwangBak = loserCaptured.kwang.isEmpty;

    // 피박: 맞고 모드는 피 7장 이하 (piCount 사용 - 쌍피/보너스피는 2장으로 계산)
    final isPiBak = loserCaptured.piCount <= 7;

    // 고박: 맞고 모드에서 패자가 1고+ 상태에서 승자가 1고+로 승리
    final isGobak =
        gameState.isGobak || (loserGoCount > 0 && winnerGoCount > 0);

    // 코인 배수 계산 (UI 표시용)
    int coinMultiplier = 1;
    if (isGwangBak) coinMultiplier *= 2;
    if (isPiBak) coinMultiplier *= 2;
    if (isGobak) coinMultiplier *= 2;

    // 예상 정산 금액 (배수 적용, 패자 잔액 한도 내)
    final expectedTransfer = (baseTransfer * coinMultiplier) > loserCoins
        ? loserCoins
        : baseTransfer * coinMultiplier;
    actualTransfer = expectedTransfer;

    // 호스트만 실제 코인 정산 API 호출 (중복 정산 방지)
    int kwangkkiGained = 0;
    if (widget.isHost) {
      try {
        await coinService.settleGame(
          winnerUid: winnerUid,
          loserUid: loserUid,
          points: baseTransfer,
          coinMultiplier: 1, // 기본 배수 (박 배수는 서비스에서 개별 처리)
          isGwangBak: isGwangBak,
          isPiBak: isPiBak,
          isGobak: isGobak,
        );

        // 패자: 잃은 코인의 50%만큼 광끼 게이지 축적
        kwangkkiGained = await coinService.updateGwangkkiScores(
          winnerUid: winnerUid,
          loserUid: loserUid,
          winnerScore: finalScore,
          isDraw: false,
          lostCoins: actualTransfer,
        );

        debugPrint(
          '[GameScreen] Coin settlement: $winnerUid wins $actualTransfer coins from $loserUid',
        );
        debugPrint(
          '[GameScreen] 박 정보: 광박=$isGwangBak, 피박=$isPiBak, 고박=$isGobak, 배수=$coinMultiplier',
        );
        debugPrint(
          '[GameScreen] 광끼 축적: 패자 +$kwangkkiGained점 (잃은 코인의 50%)',
        );
      } catch (e) {
        debugPrint('[GameScreen] Coin settlement failed: $e');
      }
    }

    // 현재 플레이어 확인
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    // 패자 정산 정보 생성 (패자만 사용)
    final loserSettlement = LoserSettlementDetail(
      loserUid: loserUid,
      loserDisplayName: loserUid == hostUid
          ? (_currentRoom?.host.displayName ?? '호스트')
          : (_currentRoom?.guest?.displayName ?? '게스트'),
      playerNumber: loserUid == hostUid ? 1 : 2,
      isGwangBak: isGwangBak,
      isPiBak: isPiBak,
      isGobak: isGobak,
      multiplier: coinMultiplier,
      baseAmount: baseTransfer,
      actualTransfer: actualTransfer,
    );

    // 양쪽 모두 코인 변동 금액 표시를 위해 설정 (배수 적용된 금액)
    setState(() {
      _coinTransferAmount = actualTransfer;
      _coinSettlementDone = true;
      // 패자인 경우 자신의 정산 정보와 광끼 축적량 저장
      if (myUid == loserUid) {
        _myLoserSettlement = loserSettlement;
        // 호스트는 API 결과값 사용, 게스트는 직접 계산 (잃은 코인의 50%)
        _kwangkkiGained = widget.isHost ? kwangkkiGained : (actualTransfer ~/ 2);
      } else {
        _myLoserSettlement = null;
        _kwangkkiGained = null;
      }
    });
  }

  Future<void> _onRematch() async {
    _soundService.playClick();
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    // 코인 부족 체크 (최소 10코인 필요)
    final coinService = ref.read(coinServiceProvider);
    final wallet = await coinService.getUserWallet(user.uid);
    if (wallet == null || wallet.coin < CoinService.minEntryCoins) {
      if (mounted) {
        _showInsufficientCoinsDialog();
      }
      return;
    }

    final roomService = ref.read(roomServiceProvider);
    await roomService.voteRematch(
      roomId: widget.roomId,
      isHost: widget.isHost,
      isGuest2: _myPlayerNumber == 3, // 3인 모드에서 게스트2인 경우
      vote: 'agree',
    );

    setState(() {
      _rematchRequested = true;
      _rematchCountdown = 15;
    });

    // 상대방이 이미 재대결을 요청한 상태가 아니면 타이머 시작
    // 3인 모드: 두 상대방 중 아무도 요청하지 않은 경우만 타이머 시작
    final isGostopMode = _currentRoom?.gameMode == GameMode.gostop;
    final noOpponentRequested = isGostopMode
        ? (!_opponentRematchRequested && !_opponent2RematchRequested)
        : !_opponentRematchRequested;

    if (noOpponentRequested) {
      _startRematchTimer();
    }
  }

  /// 코인 부족 시 알림 다이얼로그
  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '코인 부족',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '보유 코인이 부족하여 재대결을 할 수 없습니다.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
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

    await matgoLogicService.autoPlayOnTimeout(
      roomId: widget.roomId,
      myUid: myUid,
      opponentUid: _primaryOpponentUid,
      playerNumber: _myPlayerNumber,
    );
  }

  // ============ 턴 타이머 관련 메서드 끝 ============

  // ============ 상대방 퇴장 자동 플레이 관련 메서드 ============

  /// 게임 중 상대방이 나갔을 때 처리
  void _handleOpponentLeftDuringGame(GameRoom room) {
    if (_processingAutoPlay) return;

    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;
    final gameState = room.gameState;

    if (gameState == null || myUid == null) return;

    // 상대방의 턴인 경우에만 자동 플레이 실행
    // 내 턴이면 내가 플레이하면 되므로 자동 플레이 불필요
    final opponentUid = room.leftPlayer;
    if (gameState.turn != opponentUid) {
      debugPrint(
        '[GameScreen] Opponent left but it\'s my turn, waiting for my play',
      );
      return;
    }

    debugPrint(
      '[GameScreen] Opponent left during game, starting auto-play for opponent',
    );

    // 기존 타이머가 있으면 취소
    _opponentLeftAutoPlayTimer?.cancel();

    // 3초 후 자동 플레이 실행 (상대방이 복귀할 시간을 주기 위해)
    _opponentLeftAutoPlayTimer = Timer(const Duration(seconds: 3), () {
      _executeAutoPlayForLeftOpponent();
    });
  }

  /// 나간 상대방 대신 자동 플레이 실행
  Future<void> _executeAutoPlayForLeftOpponent() async {
    if (_processingAutoPlay) return;

    final room = _currentRoom;
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    if (room == null || room.gameState == null || myUid == null) return;

    final gameState = room.gameState!;
    final opponentUid = room.leftPlayer;

    // 게임이 이미 종료되었거나 상대방이 복귀했으면 무시
    if (gameState.endState != GameEndState.none || opponentUid == null) {
      debugPrint(
        '[GameScreen] Auto-play cancelled - game ended or opponent rejoined',
      );
      return;
    }

    // 상대방의 턴이 아니면 무시
    if (gameState.turn != opponentUid) {
      debugPrint('[GameScreen] Auto-play cancelled - not opponent\'s turn');
      return;
    }

    _processingAutoPlay = true;
    debugPrint(
      '[GameScreen] Executing auto-play for left opponent: $opponentUid',
    );

    try {
      final matgoLogicService = ref.read(matgoLogicServiceProvider);
      final opponentPlayerNumber = widget.isHost ? 2 : 1;

      // 상대방 대신 자동 플레이 실행
      await matgoLogicService.autoPlayOnTimeout(
        roomId: widget.roomId,
        myUid: opponentUid, // 나간 상대방의 UID로 실행
        opponentUid: myUid, // 나는 상대방의 상대
        playerNumber: opponentPlayerNumber,
      );

      // 자동 플레이 후 다시 체크 - 여전히 상대방 턴이면 다시 실행
      // (Go/Stop 선택 등 추가 동작이 필요할 수 있음)
      await Future.delayed(const Duration(milliseconds: 500));

      final updatedRoom = _currentRoom;
      if (updatedRoom?.leftPlayer != null &&
          updatedRoom?.gameState?.turn == opponentUid &&
          updatedRoom?.gameState?.endState == GameEndState.none) {
        debugPrint(
          '[GameScreen] Opponent still needs to play, scheduling next auto-play',
        );
        _opponentLeftAutoPlayTimer = Timer(const Duration(seconds: 2), () {
          _processingAutoPlay = false;
          _executeAutoPlayForLeftOpponent();
        });
      } else {
        _processingAutoPlay = false;
      }
    } catch (e) {
      debugPrint('[GameScreen] Auto-play error: $e');
      _processingAutoPlay = false;
    }
  }

  // ============ 상대방 퇴장 자동 플레이 관련 메서드 끝 ============

  void _showRematchTimeoutDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('재대결 시간 초과', style: TextStyle(color: Colors.white)),
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
        title: const Text('상대방 퇴장', style: TextStyle(color: Colors.white)),
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

  void _onExitResult() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LobbyScreen()));
  }

  Future<void> _onShake(int month) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom?.gameState == null) return;

    // 흔들 카드들 저장 (오버레이 표시용)
    final gameState = _currentRoom!.gameState!;
    final myHand = _getMyHand(gameState);
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
      playerNumber: _myPlayerNumber,
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

  void _onMeongTtaCardsDismiss() {
    if (mounted) {
      setState(() {
        _showingMeongTtaCards = false;
        _meongTtaCards = [];
        _meongTtaPlayerName = null;
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

  /// 폭탄 오버레이 닫힘 시 호출
  /// 오버레이 종료 후 폭발 애니메이션 표시 및 실제 폭탄 실행
  void _onBombCardsDismiss() async {
    if (!mounted) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    // 오버레이 숨기고 폭발 애니메이션 시작
    if (mounted) {
      setState(() {
        _showingBombCards = false;
        _showingBombExplosion = true;
      });
    }

    // 내가 폭탄 사용자인 경우에만 executeBomb 호출
    if (gameState.bombPlayer == user.uid) {
      final matgoLogic = ref.read(matgoLogicServiceProvider);
      await matgoLogic.executeBomb(
        roomId: widget.roomId,
        myUid: user.uid,
        opponentUid: _primaryOpponentUid,
        playerNumber: _myPlayerNumber,
      );
    }

    // 폭발 애니메이션 완료 대기 (3초)
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _showingBombExplosion = false;
        _bombCards = [];
        _bombPlayerName = null;
        _bombTargetCard = null;
      });
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

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.declareBomb(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: _primaryOpponentUid,
      playerNumber: _myPlayerNumber,
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
        title: Text('방이 종료되었습니다', style: TextStyle(color: AppColors.text)),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 디버그 모드 메서드
  // ═══════════════════════════════════════════════════════════════════════════

  /// 디버그 모드 발동 (5초 롱프레스)
  void _activateDebugMode() {
    if (_debugModeActive) return;

    // Remote Config에서 카드 교체 디버그 허용 여부 확인
    final debugConfig = ref.read(debugConfigServiceProvider);
    if (!debugConfig.isCardSwapDebugEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('디버그 모드가 비활성화 상태입니다'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 세션 내 카드 교체 디버그 활성화
    debugConfig.activateSessionCardSwapDebug();
    setState(() => _debugModeActive = true);

    // 디버그 모드 발동 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.white),
            const SizedBox(width: 8),
            const Text('디버그 모드 활성화! 턴 제한 해제, 카드 변경 가능'),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        duration: const Duration(seconds: 3),
      ),
    );

    // 턴 타이머 정지
    _turnTimer?.cancel();
  }

  /// 디버그: 손패 카드 변경
  Future<void> _debugChangeHandCard(CardData currentCard) async {
    if (!_debugModeActive) return;

    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    // 이미 획득된 카드는 선택 불가
    final capturedCardIds = _getCapturedCardIds(gameState);

    final selectedCard = await showDialog<CardData>(
      context: context,
      builder: (context) => DebugCardSelectorDialog(
        currentCard: currentCard,
        usedCardIds: capturedCardIds,
        location: '내 손패',
      ),
    );

    if (selectedCard != null && selectedCard.id != currentCard.id) {
      await _applyDebugCardSwap(
        oldCard: currentCard,
        newCard: selectedCard,
        sourceLocation: 'hand',
      );
    }
  }

  /// 디버그: 바닥 카드 변경
  Future<void> _debugChangeFloorCard(CardData currentCard) async {
    if (!_debugModeActive) return;

    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    // 이미 획득된 카드는 선택 불가
    final capturedCardIds = _getCapturedCardIds(gameState);

    final selectedCard = await showDialog<CardData>(
      context: context,
      builder: (context) => DebugCardSelectorDialog(
        currentCard: currentCard,
        usedCardIds: capturedCardIds,
        location: '바닥패',
      ),
    );

    if (selectedCard != null && selectedCard.id != currentCard.id) {
      await _applyDebugCardSwap(
        oldCard: currentCard,
        newCard: selectedCard,
        sourceLocation: 'floor',
      );
    }
  }

  /// 디버그: 덱 맨 윗장 카드 변경
  Future<void> _debugChangeDeckTopCard() async {
    if (!_debugModeActive) return;

    final gameState = _currentRoom?.gameState;
    if (gameState == null || gameState.deck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('덱이 비어있습니다'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final topCard = gameState.deck.first;

    // 이미 획득된 카드는 선택 불가
    final capturedCardIds = _getCapturedCardIds(gameState);

    final selectedCard = await showDialog<CardData>(
      context: context,
      builder: (context) => DebugCardSelectorDialog(
        currentCard: topCard,
        usedCardIds: capturedCardIds,
        location: '덱 맨 윗장',
      ),
    );

    if (selectedCard != null && selectedCard.id != topCard.id) {
      await _applyDebugCardSwap(
        oldCard: topCard,
        newCard: selectedCard,
        sourceLocation: 'deck',
      );
    }
  }

  /// 이미 획득된 카드 ID 세트를 반환 (디버그 모드에서 교환 불가 카드)
  Set<String> _getCapturedCardIds(GameState gameState) {
    final capturedIds = <String>{};

    // 플레이어1 획득 카드
    for (final card in gameState.player1Captured.allCards) {
      capturedIds.add(card.id);
    }

    // 플레이어2 획득 카드
    for (final card in gameState.player2Captured.allCards) {
      capturedIds.add(card.id);
    }

    // 플레이어3 획득 카드 (3인 고스톱 모드)
    for (final card in gameState.player3Captured.allCards) {
      capturedIds.add(card.id);
    }

    return capturedIds;
  }

  /// 선택한 카드가 어디에 있는지 찾기
  String? _findCardLocation(CardData card, GameState gameState) {
    // 플레이어1 손패
    if (gameState.player1Hand.any((c) => c.id == card.id)) {
      return 'player1Hand';
    }
    // 플레이어2 손패
    if (gameState.player2Hand.any((c) => c.id == card.id)) {
      return 'player2Hand';
    }
    // 플레이어3 손패 (3인 고스톱 모드)
    if (gameState.player3Hand.any((c) => c.id == card.id)) {
      return 'player3Hand';
    }
    // 바닥
    if (gameState.floorCards.any((c) => c.id == card.id)) {
      return 'floor';
    }
    // 덱
    if (gameState.deck.any((c) => c.id == card.id)) {
      return 'deck';
    }
    // 뻑 카드
    if (gameState.pukCards.any((c) => c.id == card.id)) {
      return 'puk';
    }
    // 플레이어1 획득 카드
    if (gameState.player1Captured.allCards.any((c) => c.id == card.id)) {
      return 'player1Captured';
    }
    // 플레이어2 획득 카드
    if (gameState.player2Captured.allCards.any((c) => c.id == card.id)) {
      return 'player2Captured';
    }
    // 플레이어3 획득 카드 (3인 고스톱 모드)
    if (gameState.player3Captured.allCards.any((c) => c.id == card.id)) {
      return 'player3Captured';
    }
    return null;
  }

  /// 디버그 카드 맞교환을 Firebase에 적용
  Future<void> _applyDebugCardSwap({
    required CardData oldCard,
    required CardData newCard,
    required String sourceLocation,
  }) async {
    final gameState = _currentRoom?.gameState;
    if (gameState == null) return;

    final roomService = ref.read(roomServiceProvider);

    try {
      // newCard가 어디에 있는지 찾기
      final targetLocation = _findCardLocation(newCard, gameState);

      if (targetLocation == null) {
        // 게임에 없는 카드면 단순 교체
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('선택한 카드를 찾을 수 없습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 획득 카드와의 교환 불가
      if (targetLocation == 'player1Captured' ||
          targetLocation == 'player2Captured' ||
          targetLocation == 'player3Captured') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 획득한 카드와는 교환할 수 없습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 새 게임 상태 생성 (3인 고스톱 지원)
      List<CardData> newPlayer1Hand = List.from(gameState.player1Hand);
      List<CardData> newPlayer2Hand = List.from(gameState.player2Hand);
      List<CardData> newPlayer3Hand = List.from(gameState.player3Hand);
      List<CardData> newFloorCards = List.from(gameState.floorCards);
      List<CardData> newDeck = List.from(gameState.deck);
      List<CardData> newPukCards = List.from(gameState.pukCards);

      // 먼저 양쪽 인덱스를 찾아둠 (교환 전에 찾아야 함)
      int sourceIdx = -1;
      int targetIdx = -1;

      // sourceLocation에서 oldCard 인덱스 찾기 (3인 고스톱 지원)
      switch (sourceLocation) {
        case 'hand':
          switch (_myPlayerNumber) {
            case 1:
              sourceIdx = newPlayer1Hand.indexWhere((c) => c.id == oldCard.id);
              break;
            case 2:
              sourceIdx = newPlayer2Hand.indexWhere((c) => c.id == oldCard.id);
              break;
            case 3:
              sourceIdx = newPlayer3Hand.indexWhere((c) => c.id == oldCard.id);
              break;
          }
          break;
        case 'floor':
          sourceIdx = newFloorCards.indexWhere((c) => c.id == oldCard.id);
          break;
        case 'deck':
          sourceIdx = newDeck.indexWhere((c) => c.id == oldCard.id);
          break;
      }

      // targetLocation에서 newCard 인덱스 찾기 (3인 고스톱 지원)
      switch (targetLocation) {
        case 'player1Hand':
          targetIdx = newPlayer1Hand.indexWhere((c) => c.id == newCard.id);
          break;
        case 'player2Hand':
          targetIdx = newPlayer2Hand.indexWhere((c) => c.id == newCard.id);
          break;
        case 'player3Hand':
          targetIdx = newPlayer3Hand.indexWhere((c) => c.id == newCard.id);
          break;
        case 'floor':
          targetIdx = newFloorCards.indexWhere((c) => c.id == newCard.id);
          break;
        case 'deck':
          targetIdx = newDeck.indexWhere((c) => c.id == newCard.id);
          break;
        case 'puk':
          targetIdx = newPukCards.indexWhere((c) => c.id == newCard.id);
          break;
      }

      // 인덱스를 찾은 후 동시에 교환 (3인 고스톱 지원)
      if (sourceIdx != -1) {
        switch (sourceLocation) {
          case 'hand':
            switch (_myPlayerNumber) {
              case 1:
                newPlayer1Hand[sourceIdx] = newCard;
                break;
              case 2:
                newPlayer2Hand[sourceIdx] = newCard;
                break;
              case 3:
                newPlayer3Hand[sourceIdx] = newCard;
                break;
            }
            break;
          case 'floor':
            newFloorCards[sourceIdx] = newCard;
            break;
          case 'deck':
            newDeck[sourceIdx] = newCard;
            break;
        }
      }

      if (targetIdx != -1) {
        switch (targetLocation) {
          case 'player1Hand':
            newPlayer1Hand[targetIdx] = oldCard;
            break;
          case 'player2Hand':
            newPlayer2Hand[targetIdx] = oldCard;
            break;
          case 'player3Hand':
            newPlayer3Hand[targetIdx] = oldCard;
            break;
          case 'floor':
            newFloorCards[targetIdx] = oldCard;
            break;
          case 'deck':
            newDeck[targetIdx] = oldCard;
            break;
          case 'puk':
            newPukCards[targetIdx] = oldCard;
            break;
        }
      }

      // 위치 이름 변환 (3인 고스톱 지원)
      String getLocationName(String loc) {
        switch (loc) {
          case 'hand':
            return '내 손패';
          case 'floor':
            return '바닥';
          case 'deck':
            return '덱';
          case 'player1Hand':
            return '플레이어1 손패';
          case 'player2Hand':
            return '플레이어2 손패';
          case 'player3Hand':
            return '플레이어3 손패';
          case 'puk':
            return '뻑 카드';
          default:
            return loc;
        }
      }

      // 업데이트된 게임 상태 (3인 고스톱 모드 완벽 지원)
      final updatedState = GameState(
        turn: gameState.turn,
        player1Hand: newPlayer1Hand,
        player2Hand: newPlayer2Hand,
        player3Hand: newPlayer3Hand,
        floorCards: newFloorCards,
        deck: newDeck,
        pukCards: newPukCards,
        pukOwner: gameState.pukOwner,
        player1Captured: gameState.player1Captured,
        player2Captured: gameState.player2Captured,
        player3Captured: gameState.player3Captured,
        scores: gameState.scores,
        lastEvent: gameState.lastEvent,
        lastEventPlayer: gameState.lastEventPlayer,
        endState: gameState.endState,
        winner: gameState.winner,
        finalScore: gameState.finalScore,
        waitingForGoStop: gameState.waitingForGoStop,
        goStopPlayer: gameState.goStopPlayer,
        shakeCards: gameState.shakeCards,
        shakePlayer: gameState.shakePlayer,
        chongtongCards: gameState.chongtongCards,
        chongtongPlayer: gameState.chongtongPlayer,
        firstTurnPlayer: gameState.firstTurnPlayer,
        firstTurnDecidingMonth: gameState.firstTurnDecidingMonth,
        firstTurnReason: gameState.firstTurnReason,
        waitingForDeckSelection: gameState.waitingForDeckSelection,
        deckSelectionPlayer: gameState.deckSelectionPlayer,
        deckCard: gameState.deckCard,
        deckMatchingCards: gameState.deckMatchingCards,
        pendingHandCard: gameState.pendingHandCard,
        pendingHandMatch: gameState.pendingHandMatch,
        turnStartTime: gameState.turnStartTime,
        // 3인 고스톱 모드 필수 필드
        gameMode: gameState.gameMode,
        turnOrder: gameState.turnOrder,
        currentTurnIndex: gameState.currentTurnIndex,
        // 기타 게임 상태 필드 유지
        isGobak: gameState.isGobak,
        bombCards: gameState.bombCards,
        bombPlayer: gameState.bombPlayer,
        bombTargetCard: gameState.bombTargetCard,
        waitingForSeptemberChoice: gameState.waitingForSeptemberChoice,
        septemberChoicePlayer: gameState.septemberChoicePlayer,
        pendingSeptemberCard: gameState.pendingSeptemberCard,
        piStolenCount: gameState.piStolenCount,
        piStolenFromPlayers: gameState.piStolenFromPlayers,
        // 아이템 효과 필드 유지
        player1ItemEffects: gameState.player1ItemEffects,
        player2ItemEffects: gameState.player2ItemEffects,
        player3ItemEffects: gameState.player3ItemEffects,
        lastItemUsed: gameState.lastItemUsed,
        lastItemUsedBy: gameState.lastItemUsedBy,
        lastItemUsedAt: gameState.lastItemUsedAt,
        player1Uid: gameState.player1Uid,
        player2Uid: gameState.player2Uid,
      );

      await roomService.updateGameState(
        roomId: widget.roomId,
        gameState: updatedState,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '맞교환 완료: ${oldCard.id}(${getLocationName(sourceLocation)}) ↔ ${newCard.id}(${getLocationName(targetLocation)})',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카드 변경 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _leaveRoom() async {
    // 게임 진행 중인지 확인
    final isGameInProgress =
        _currentRoom?.state == RoomState.playing &&
        _currentRoom?.gameState?.endState == GameEndState.none;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.woodDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.woodDark.withValues(alpha: 0.5)),
        ),
        title: Text('게임 나가기', style: TextStyle(color: AppColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말 게임을 나가시겠습니까?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            // 게임 진행 중 경고 메시지
            if (isGameInProgress) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.goRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.goRed.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.goRed,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '현재 게임방에서 나가면 자동 플레이가 적용되어 코인을 잃을 수도 있습니다',
                        style: TextStyle(
                          color: AppColors.goRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.woodLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '취소',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.goRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '나가기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
    _opponent2WalletSubscription?.cancel(); // 고스톱 모드용
    _rematchTimer?.cancel();
    _turnTimer?.cancel(); // 턴 타이머 정리
    _opponentLeftAutoPlayTimer?.cancel(); // 상대방 퇴장 자동 플레이 타이머 정리
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
                      child: _currentRoom?.gameMode == GameMode.gostop
                          ? _buildGostopOpponentZone(gameState, isMyTurn)
                          : OpponentZone(
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
                              isMeongTta: widget.isHost
                                  ? gameState?.scores.player2MeongTta ?? false
                                  : gameState?.scores.player1MeongTta ?? false,
                              coinBalance: _opponentCoinBalance,
                              remainingSeconds: !isMyTurn
                                  ? _remainingSeconds
                                  : null,
                              // 아바타 상태 (상대방)
                              playerNumber: widget.isHost
                                  ? 2
                                  : 1, // 상대방: 내가 호스트면 2, 아니면 1
                              avatarState: determineAvatarState(
                                isGwangkkiMode: _gwangkkiModeActive,
                                myScore: widget.isHost
                                    ? gameState?.scores.player2Score ?? 0
                                    : gameState?.scores.player1Score ?? 0,
                                opponentScore: widget.isHost
                                    ? gameState?.scores.player1Score ?? 0
                                    : gameState?.scores.player2Score ?? 0,
                                turnCount: calculateTurnCount(
                                  gameState?.deck.length ?? 24,
                                ),
                              ),
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
                            getCardKey: (cardId) =>
                                _positionTracker.getKey('floor_$cardId'),
                            hiddenCardIds:
                                _animatingDeckCardIds, // 애니메이션 중인 카드 숨김
                            // 손패 비어있음 여부와 내 턴 여부 (덱만 뒤집기 가능 여부 결정)
                            // 3인 고스톱 모드 지원: _myPlayerNumber에 따라 올바른 손패 확인
                            isHandEmpty: switch (_myPlayerNumber) {
                              1 => gameState?.player1Hand.isEmpty ?? true,
                              2 => gameState?.player2Hand.isEmpty ?? true,
                              3 => gameState?.player3Hand.isEmpty ?? true,
                              _ => true,
                            },
                            isMyTurn: isMyTurn,
                            // 디버그 모드 관련
                            debugModeActive: _debugModeActive,
                            onFloorCardLongPress: _debugChangeFloorCard,
                            onDeckLongPress: _debugChangeDeckTopCard,
                            onDebugModeActivate: _activateDebugMode,
                          ),
                          // 光끼 모드 불꽃 테두리 효과
                          if (_gwangkkiModeActive)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final intensity =
                                        0.5 + (_pulseController.value * 0.5);
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
                                            color: const Color(0xFFFF4500)
                                                .withValues(
                                                  alpha: 0.3 * intensity,
                                                ),
                                            blurRadius: 20 * intensity,
                                            spreadRadius: 5 * intensity,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFFFF6347)
                                                .withValues(
                                                  alpha: 0.2 * intensity,
                                                ),
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
                            playerName: _getMyPlayerName(),
                            handCards: gameState != null
                                ? _getMyHand(gameState)
                                : [],
                            captured: gameState != null
                                ? _getMyCaptured(gameState)
                                : null,
                            score: _getMyScore(gameState),
                            goCount: _getMyGoCount(gameState),
                            isMyTurn: isMyTurn,
                            selectedCard: _selectedHandCard,
                            onCardTap: _onHandCardTap,
                            // showGoStopButtons는 false로 유지 - 전체화면 Go/Stop 다이얼로그(_buildGoStopButtons)만 사용
                            showGoStopButtons: false,
                            onGoPressed: _onGo,
                            onStopPressed: _onStop,
                            isShaking: _getMyShaking(gameState),
                            hasBomb: _getMyBomb(gameState),
                            isMeongTta: _getMyMeongTta(gameState),
                            coinBalance: _myCoinBalance,
                            remainingSeconds: isMyTurn
                                ? _remainingSeconds
                                : null,
                            getCardKey: (cardId) =>
                                _positionTracker.getKey('hand_$cardId'),
                            captureZoneKey: _playerCaptureKey,
                            // 디버그 모드 관련
                            debugModeActive: _debugModeActive,
                            onCardLongPress: _debugChangeHandCard,
                            onDebugModeActivate: _activateDebugMode,
                            // 아바타 상태 (나)
                            playerNumber: _myPlayerNumber,
                            avatarState:
                                _currentRoom?.gameMode == GameMode.gostop
                                ? determineAvatarStateFor3Players(
                                    isGwangkkiMode: _gwangkkiModeActive,
                                    myScore: _getMyScore(gameState),
                                    opponent1Score:
                                        gameState?.scores.player1Score ?? 0,
                                    opponent2Score: _myPlayerNumber == 1
                                        ? gameState?.scores.player3Score ?? 0
                                        : _myPlayerNumber == 2
                                        ? gameState?.scores.player3Score ?? 0
                                        : gameState?.scores.player2Score ?? 0,
                                    turnCount: calculateTurnCount(
                                      gameState?.deck.length ?? 24,
                                    ),
                                  )
                                : determineAvatarState(
                                    isGwangkkiMode: _gwangkkiModeActive,
                                    myScore: _getMyScore(gameState),
                                    opponentScore: _getOpponentScore(gameState),
                                    turnCount: calculateTurnCount(
                                      gameState?.deck.length ?? 24,
                                    ),
                                  ),
                          ),
                          if (!isMyTurn)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '상대 턴입니다',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // 피 빼앗김 알림
                                    if (_showingPiStolenNotification)
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        builder: (context, value, child) {
                                          return Opacity(
                                            opacity: value,
                                            child: Transform.translate(
                                              offset: Offset(
                                                0,
                                                10 * (1 - value),
                                              ),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _lastPiStolenCount > 1
                                                ? '특수룰로 인해 피를 $_lastPiStolenCount장 뺏겼어요 😭'
                                                : '특수룰로 인해 피를 1장 뺏겼어요 😭',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 상단 컨트롤 (사운드 토글 + 나가기 버튼)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 사운드 토글 버튼
                      StatefulBuilder(
                        builder: (context, setLocalState) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _soundService.toggleMute();
                                setLocalState(() {}); // UI 리빌드
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _soundService.isMuted
                                      ? AppColors.woodDark.withValues(
                                          alpha: 0.85,
                                        )
                                      : AppColors.accent.withValues(
                                          alpha: 0.85,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  _soundService.isMuted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      // 나가기 버튼
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _leaveRoom,
                          borderRadius: BorderRadius.circular(6),
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
                    ],
                  ),
                ),

                // 光끼 게이지 및 발동 버튼 (우하단)
                if (gameState != null && !_gwangkkiModeActive)
                  Positioned(
                    right: 4,
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
                            padding: const EdgeInsets.only(top: 4),
                            child: _buildGwangkkiActivateButton(),
                          ),
                      ],
                    ),
                  ),
                
                // 광끼 분노 애니메이션 (게임 중 축적 시 광끼 게이지 위에 표시)
                if (_showingGwangkkiAnger && !_gwangkkiModeActive)
                  Positioned(
                    right: 4,
                    bottom: MediaQuery.of(context).size.height * 0.35 + 60,
                    child: GwangkkiAngerAnimation(
                      points: _gwangkkiAngerPoints,
                      onComplete: _onGwangkkiAngerComplete,
                    ),
                  ),

                // 흔들기/폭탄 액션 버튼 (3인 고스톱 모드 지원)
                if (gameState != null && isMyTurn)
                  Positioned(
                    left: 4,
                    bottom: MediaQuery.of(context).size.height * 0.25,
                    child: ActionButtons(
                      myHand: _getMyHand(gameState),
                      floorCards: gameState.floorCards,
                      isMyTurn: isMyTurn,
                      alreadyUsedShake: _getMyShaking(gameState),
                      alreadyUsedBomb: _getMyBomb(gameState),
                      onShake: _onShake,
                      onBomb: _onBomb,
                    ),
                  ),

                // 아이템 사용 버튼 (좌하단, 바닥패 영역 좌측)
                if (gameState != null &&
                    myUid != null &&
                    _currentRoom?.guest != null)
                  Positioned(
                    left: 8,
                    bottom: MediaQuery.of(context).size.height * 0.32 + 8,
                    child: ItemUseButton(
                      playerUid: myUid,
                      opponentUid: _primaryOpponentUid,
                      playerNumber: _myPlayerNumber,
                      roomId: widget.roomId,
                      gameState: gameState,
                      // 내 턴일 때만 아이템 사용 가능
                      enabled: gameState.turn == myUid,
                      gameMode: _currentRoom!.gameMode,
                      // 고스톱 모드에서 상대 플레이어 목록 (자신 제외)
                      opponents: _currentRoom!.gameMode == GameMode.gostop
                          ? _currentRoom!.allPlayers
                                .where((p) => p.uid != myUid)
                                .toList()
                          : [],
                      onItemUsed: (itemType) {
                        // 애니메이션은 Firebase 동기화를 통해 모든 플레이어에게 동시에 표시됨
                        // onItemUsed는 아이템 사용 성공 알림용으로만 사용
                        debugPrint(
                          '[ItemUseButton] 아이템 사용 완료: ${itemType.name}',
                        );
                      },
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

                // 폭탄 카드 공개 오버레이
                if (_showingBombCards && _bombCards.isNotEmpty)
                  BombCardsOverlay(
                    cards: _bombCards,
                    playerName: _bombPlayerName ?? '상대방',
                    onDismiss: _onBombCardsDismiss,
                  ),

                // 멍따 카드 공개 오버레이 (열끗 7장 이상)
                if (_showingMeongTtaCards && _meongTtaCards.isNotEmpty)
                  MeongTtaCardsOverlay(
                    cards: _meongTtaCards,
                    playerName: _meongTtaPlayerName,
                    onDismiss: _onMeongTtaCardsDismiss,
                  ),

                // 폭탄 폭발 애니메이션 (화면 중앙에 표시)
                if (_showingBombExplosion)
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Lottie.asset(
                        'assets/etc/Bomb.json',
                        fit: BoxFit.contain,
                        repeat: false,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
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
                // right: 68 = 사운드버튼(28) + 간격(4) + 나가기버튼(28) + 여유(8)
                if (_gwangkkiModeActive && !_showingGwangkkiAlert)
                  Positioned(
                    top: 4,
                    left: 4,
                    right: 68,
                    child: GwangkkiModeBanner(
                      activatorName:
                          _gwangkkiActivator == _currentRoom?.host.uid
                          ? _currentRoom?.host.displayName ?? '호스트'
                          : _currentRoom?.guest?.displayName ?? '게스트',
                    ),
                  ),

                // 게임 얼럿 배너 (광끼 모드가 아닐 때만 표시)
                // right: 68 = 사운드버튼(28) + 간격(4) + 나가기버튼(28) + 여유(8)
                if (!_gwangkkiModeActive && !_showingGwangkkiAlert &&
                    (_gameStartAlert != null || _persistentAlerts.isNotEmpty || _currentOneTimeAlert != null))
                  Positioned(
                    top: 4,
                    left: 4,
                    right: 68,
                    child: GameAlertBanner(
                      key: _alertBannerKey,
                      gameStartAlert: _gameStartAlert,
                      persistentAlerts: _persistentAlerts,
                      currentOneTimeAlert: _currentOneTimeAlert,
                      onGameStartDismiss: _dismissGameStartAlert,
                      onOneTimeAlertDismiss: _dismissOneTimeAlert,
                    ),
                  ),

                // Go/Stop 다이얼로그
                if (_showingGoStop && gameState != null)
                  _buildGoStopButtons(gameState),

                // 게임 결과 다이얼로그 (재대결 진행 중에는 표시하지 않음)
                if (_showingResult && gameState != null && !_rematchInProgress)
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
                if (_showingDeckSelection &&
                    _deckSelectionOptions.isNotEmpty &&
                    _deckCardForSelection != null)
                  CardSelectionDialog(
                    matchingCards: _deckSelectionOptions,
                    playedCard: _deckCardForSelection!,
                    onCardSelected: _onDeckCardSelected,
                    onCancel: _onDeckSelectionCancelled,
                    title: '뒤집은 카드로 가져갈 패를 선택하세요',
                  ),

                // 9월 열끗 선택 다이얼로그
                if (_showingSeptemberChoice &&
                    gameState?.pendingSeptemberCard != null)
                  SeptemberAnimalChoiceDialog(
                    card: gameState!.pendingSeptemberCard!,
                    onChoice: _onSeptemberChoiceSelected,
                    playerName: widget.isHost
                        ? _currentRoom?.host.displayName ?? '플레이어'
                        : _currentRoom?.guest?.displayName ?? '플레이어',
                  ),

                // 특수 룰 로티 애니메이션 (따닥, 뻑, 쪽)
                if (_showingSpecialRuleLottie &&
                    _specialRulePositions.isNotEmpty)
                  SpecialRuleLottieOverlay(
                    event: _specialRuleEvent,
                    positions: _specialRulePositions,
                    onComplete: _onSpecialRuleLottieComplete,
                    size: 120,
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

                // 光끼 모드 하단 불꽃 애니메이션 (화면 최하단, 좌-우 풀사이즈)
                if (_gwangkkiModeActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Lottie.asset(
                        'assets/etc/Fire_wall.json',
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.bottomCenter,
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 고스톱 3인 모드용 상대방 영역 빌더
  Widget _buildGostopOpponentZone(GameState? gameState, bool isMyTurn) {
    // 현재 플레이어가 누구인지에 따라 상대방 2명 결정
    // _myPlayerNumber == 1 (host): 상대는 player2 (guest1), player3 (guest2)
    // _myPlayerNumber == 2 (guest1): 상대는 player1 (host), player3 (guest2)
    // _myPlayerNumber == 3 (guest2): 상대는 player1 (host), player2 (guest1)

    final currentTurn = gameState?.turn;
    final myNumber = _myPlayerNumber;

    // 상대1 정보 (왼쪽 상단)
    String? opponent1Name;
    CapturedCards? opponent1Captured;
    int opponent1Score = 0;
    int opponent1GoCount = 0;
    int opponent1HandCount = 0;
    String? opponent1Uid;
    bool opponent1Shaking = false;
    bool opponent1Bomb = false;
    bool opponent1MeongTta = false;
    int opponent1PlayerNumber = 2; // 1=Host, 2=Guest, 3=Guest2

    // 상대2 정보 (오른쪽 상단)
    String? opponent2Name;
    CapturedCards? opponent2Captured;
    int opponent2Score = 0;
    int opponent2GoCount = 0;
    int opponent2HandCount = 0;
    String? opponent2Uid;
    bool opponent2Shaking = false;
    bool opponent2Bomb = false;
    bool opponent2MeongTta = false;
    int opponent2PlayerNumber = 3; // 1=Host, 2=Guest, 3=Guest2

    switch (myNumber) {
      case 1: // 나는 host → 상대1: guest1(player2), 상대2: guest2(player3)
        opponent1Name = _currentRoom?.guest?.displayName ?? '게스트1';
        opponent1Captured = gameState?.player2Captured;
        opponent1Score = gameState?.scores.player2Score ?? 0;
        opponent1GoCount = gameState?.scores.player2GoCount ?? 0;
        opponent1HandCount = gameState?.player2Hand.length ?? 0;
        opponent1Uid = _currentRoom?.guest?.uid;
        opponent1Shaking = gameState?.scores.player2Shaking ?? false;
        opponent1Bomb = gameState?.scores.player2Bomb ?? false;
        opponent1MeongTta = gameState?.scores.player2MeongTta ?? false;
        opponent1PlayerNumber = 2; // Guest

        opponent2Name = _currentRoom?.guest2?.displayName ?? '게스트2';
        opponent2Captured = gameState?.player3Captured;
        opponent2Score = gameState?.scores.player3Score ?? 0;
        opponent2GoCount = gameState?.scores.player3GoCount ?? 0;
        opponent2HandCount = gameState?.player3Hand.length ?? 0;
        opponent2Uid = _currentRoom?.guest2?.uid;
        opponent2Shaking = gameState?.scores.player3Shaking ?? false;
        opponent2Bomb = gameState?.scores.player3Bomb ?? false;
        opponent2MeongTta = gameState?.scores.player3MeongTta ?? false;
        opponent2PlayerNumber = 3; // Guest2
        break;

      case 2: // 나는 guest1 → 상대1: host(player1), 상대2: guest2(player3)
        opponent1Name = _currentRoom?.host.displayName ?? '호스트';
        opponent1Captured = gameState?.player1Captured;
        opponent1Score = gameState?.scores.player1Score ?? 0;
        opponent1GoCount = gameState?.scores.player1GoCount ?? 0;
        opponent1HandCount = gameState?.player1Hand.length ?? 0;
        opponent1Uid = _currentRoom?.host.uid;
        opponent1Shaking = gameState?.scores.player1Shaking ?? false;
        opponent1Bomb = gameState?.scores.player1Bomb ?? false;
        opponent1MeongTta = gameState?.scores.player1MeongTta ?? false;
        opponent1PlayerNumber = 1; // Host

        opponent2Name = _currentRoom?.guest2?.displayName ?? '게스트2';
        opponent2Captured = gameState?.player3Captured;
        opponent2Score = gameState?.scores.player3Score ?? 0;
        opponent2GoCount = gameState?.scores.player3GoCount ?? 0;
        opponent2HandCount = gameState?.player3Hand.length ?? 0;
        opponent2Uid = _currentRoom?.guest2?.uid;
        opponent2Shaking = gameState?.scores.player3Shaking ?? false;
        opponent2Bomb = gameState?.scores.player3Bomb ?? false;
        opponent2MeongTta = gameState?.scores.player3MeongTta ?? false;
        opponent2PlayerNumber = 3; // Guest2
        break;

      case 3: // 나는 guest2 → 상대1: host(player1), 상대2: guest1(player2)
        opponent1Name = _currentRoom?.host.displayName ?? '호스트';
        opponent1Captured = gameState?.player1Captured;
        opponent1Score = gameState?.scores.player1Score ?? 0;
        opponent1GoCount = gameState?.scores.player1GoCount ?? 0;
        opponent1HandCount = gameState?.player1Hand.length ?? 0;
        opponent1Uid = _currentRoom?.host.uid;
        opponent1Shaking = gameState?.scores.player1Shaking ?? false;
        opponent1Bomb = gameState?.scores.player1Bomb ?? false;
        opponent1MeongTta = gameState?.scores.player1MeongTta ?? false;
        opponent1PlayerNumber = 1; // Host

        opponent2Name = _currentRoom?.guest?.displayName ?? '게스트1';
        opponent2Captured = gameState?.player2Captured;
        opponent2Score = gameState?.scores.player2Score ?? 0;
        opponent2GoCount = gameState?.scores.player2GoCount ?? 0;
        opponent2HandCount = gameState?.player2Hand.length ?? 0;
        opponent2Uid = _currentRoom?.guest?.uid;
        opponent2Shaking = gameState?.scores.player2Shaking ?? false;
        opponent2Bomb = gameState?.scores.player2Bomb ?? false;
        opponent2MeongTta = gameState?.scores.player2MeongTta ?? false;
        opponent2PlayerNumber = 2; // Guest
        break;

      default:
        // fallback: host case와 동일하게 처리
        opponent1Name = _currentRoom?.guest?.displayName ?? '게스트1';
        opponent1Uid = _currentRoom?.guest?.uid;
        opponent1PlayerNumber = 2; // Guest
        opponent2Name = _currentRoom?.guest2?.displayName ?? '게스트2';
        opponent2Uid = _currentRoom?.guest2?.uid;
        opponent2PlayerNumber = 3; // Guest2
    }

    final isOpponent1Turn = currentTurn == opponent1Uid;
    final isOpponent2Turn = currentTurn == opponent2Uid;

    // 내 점수와 턴 카운트 계산 (아바타 상태용)
    final myScore = _getMyScore(gameState);
    final turnCount = calculateTurnCount(gameState?.deck.length ?? 24);

    return GostopOpponentZone(
      // 상대1 정보
      opponent1Name: opponent1Name,
      opponent1Captured: opponent1Captured,
      opponent1Score: opponent1Score,
      opponent1GoCount: opponent1GoCount,
      opponent1HandCount: opponent1HandCount,
      isOpponent1Turn: isOpponent1Turn,
      opponent1IsShaking: opponent1Shaking,
      opponent1HasBomb: opponent1Bomb,
      opponent1IsMeongTta: opponent1MeongTta,
      opponent1CoinBalance: _opponentCoinBalance,
      opponent1RemainingSeconds: isOpponent1Turn && !isMyTurn
          ? _remainingSeconds
          : null,
      opponent1AvatarState: determineAvatarStateFor3Players(
        isGwangkkiMode: _gwangkkiModeActive,
        myScore: opponent1Score,
        opponent1Score: myScore,
        opponent2Score: opponent2Score,
        turnCount: turnCount,
      ),
      opponent1PlayerNumber: opponent1PlayerNumber,
      // 상대2 정보
      opponent2Name: opponent2Name,
      opponent2Captured: opponent2Captured,
      opponent2Score: opponent2Score,
      opponent2GoCount: opponent2GoCount,
      opponent2HandCount: opponent2HandCount,
      isOpponent2Turn: isOpponent2Turn,
      opponent2IsShaking: opponent2Shaking,
      opponent2HasBomb: opponent2Bomb,
      opponent2IsMeongTta: opponent2MeongTta,
      opponent2CoinBalance: _opponent2CoinBalance,
      opponent2RemainingSeconds: isOpponent2Turn && !isMyTurn
          ? _remainingSeconds
          : null,
      opponent2AvatarState: determineAvatarStateFor3Players(
        isGwangkkiMode: _gwangkkiModeActive,
        myScore: opponent2Score,
        opponent1Score: myScore,
        opponent2Score: opponent1Score,
        turnCount: turnCount,
      ),
      opponent2PlayerNumber: opponent2PlayerNumber,
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
    // 고스톱 3인 모드에서는 _myPlayerNumber 기준으로 점수 가져오기
    final int myScore;
    final int goCount;
    final ItemEffects? myEffects;

    if (_currentRoom?.gameMode == GameMode.gostop) {
      // 고스톱 3인 모드
      switch (_myPlayerNumber) {
        case 1:
          myScore = gameState.scores.player1Score;
          goCount = gameState.scores.player1GoCount;
          myEffects = gameState.player1ItemEffects;
          break;
        case 2:
          myScore = gameState.scores.player2Score;
          goCount = gameState.scores.player2GoCount;
          myEffects = gameState.player2ItemEffects;
          break;
        case 3:
          myScore = gameState.scores.player3Score;
          goCount = gameState.scores.player3GoCount;
          myEffects = gameState.player3ItemEffects;
          break;
        default:
          myScore = gameState.scores.player1Score;
          goCount = gameState.scores.player1GoCount;
          myEffects = gameState.player1ItemEffects;
      }
    } else {
      // 맞고 2인 모드 (기존 로직)
      myScore = widget.isHost
          ? gameState.scores.player1Score
          : gameState.scores.player2Score;
      goCount = widget.isHost
          ? gameState.scores.player1GoCount
          : gameState.scores.player2GoCount;
      myEffects = widget.isHost
          ? gameState.player1ItemEffects
          : gameState.player2ItemEffects;
    }
    final forceGoOnly = myEffects?.forceGoOnly ?? false;
    final forceStopOnly = myEffects?.forceStopOnly ?? false;

    // 光끼 모드가 최우선! 光끼 모드에서는 아이템 효과 무시하고 GO만 가능
    // GO 버튼 비활성화 조건: forceStopOnly (Stop만 가능 아이템 효과) - 단, 光끼 모드에서는 무시
    final goDisabled = !_gwangkkiModeActive && forceStopOnly;
    // STOP 버튼 비활성화 조건: 光끼 모드 또는 forceGoOnly (Go만 가능 아이템 효과)
    final stopDisabled = _gwangkkiModeActive || forceGoOnly;

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
                border: Border.all(
                  color: AppColors.woodDark.withValues(alpha: 0.5),
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 20,
                    ),
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
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            // 아이템 효과 경고 (forceGoOnly - 상대방이 "제발 Go만해!" 아이템 사용)
            if (forceGoOnly && !_gwangkkiModeActive)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sports_esports, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '아이템 효과! GO만 가능',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.sports_esports, color: Colors.white, size: 20),
                  ],
                ),
              ),
            // 아이템 효과 경고 (forceStopOnly - 상대방이 "제발 Stop만해!" 아이템 사용)
            // 단, 光끼 모드에서는 아이템 효과가 무시되므로 경고도 표시하지 않음
            if (forceStopOnly && !_gwangkkiModeActive)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF03A9F4)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pan_tool, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '아이템 효과! STOP만 가능',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.pan_tool, color: Colors.white, size: 20),
                  ],
                ),
              ),
            // GO / STOP 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // GO 버튼 (forceStopOnly 아이템 효과 시 비활성화)
                Opacity(
                  opacity: goDisabled ? 0.4 : 1.0,
                  child: RetroButton(
                    text: 'GO',
                    color: goDisabled ? Colors.grey : AppColors.goRed,
                    onPressed: goDisabled ? null : _onGo,
                    width: 120,
                    height: 60,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(width: 24),
                // STOP 버튼 (光끼 모드 또는 forceGoOnly 아이템 효과 시 비활성화)
                Opacity(
                  opacity: stopDisabled ? 0.4 : 1.0,
                  child: RetroButton(
                    text: 'STOP',
                    color: stopDisabled ? Colors.grey : AppColors.stopBlue,
                    onPressed: stopDisabled ? null : _onStop,
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

    FinalScoreResult? scoreDetail;
    // 모든 승리 상태에서 점수 상세 계산 (win, gobak, autoWin, chongtong)
    final hasWinner =
        gameState.endState == GameEndState.win ||
        gameState.endState == GameEndState.gobak ||
        gameState.endState == GameEndState.autoWin ||
        gameState.endState == GameEndState.chongtong;

    if (hasWinner && gameState.winner != null) {
      // 승자 기준으로 점수 상세 계산 (패자에게도 보여주기 위해)
      // 3인 고스톱 모드 지원: 승자의 플레이어 번호 결정
      final int winnerPlayerNumber;
      if (gameState.winner == _currentRoom?.host.uid) {
        winnerPlayerNumber = 1;
      } else if (gameState.winner == _currentRoom?.guest?.uid) {
        winnerPlayerNumber = 2;
      } else if (gameState.winner == _currentRoom?.guest2?.uid) {
        winnerPlayerNumber = 3;
      } else {
        winnerPlayerNumber = 1; // fallback
      }

      // 승자의 획득 패와 상대방(패자) 획득 패 (3인 고스톱 지원)
      final winnerCaptured = switch (winnerPlayerNumber) {
        1 => gameState.player1Captured,
        2 => gameState.player2Captured,
        3 => gameState.player3Captured,
        _ => gameState.player1Captured,
      };
      // 패자 획득패: 3인 모드에서는 첫 번째 상대의 획득패 사용 (피박/광박 체크용)
      final loserCaptured = switch (winnerPlayerNumber) {
        1 => gameState.player2Captured,
        2 => gameState.player1Captured,
        3 => gameState.player1Captured,
        _ => gameState.player2Captured,
      };
      final winnerGoCount = switch (winnerPlayerNumber) {
        1 => gameState.scores.player1GoCount,
        2 => gameState.scores.player2GoCount,
        3 => gameState.scores.player3GoCount,
        _ => gameState.scores.player1GoCount,
      };
      final winnerMultiplier = switch (winnerPlayerNumber) {
        1 => gameState.scores.player1Multiplier,
        2 => gameState.scores.player2Multiplier,
        3 => gameState.scores.player3Multiplier,
        _ => gameState.scores.player1Multiplier,
      };

      scoreDetail = ScoreCalculator.calculateFinalScore(
        myCaptures: winnerCaptured,
        opponentCaptures: loserCaptured,
        goCount: winnerGoCount,
        playerMultiplier: winnerMultiplier,
        isGobak: gameState.isGobak,
        gameMode: _currentRoom?.gameMode ?? GameMode.matgo,
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
          gostopSettlement: _gostopSettlementResult, // 3인 고스톱 정산 정보
          loserSettlement: _myLoserSettlement, // 패자 본인의 정산 정보
          kwangkkiGained: _kwangkkiGained, // 패배로 인한 광끼 축적량
        ),
        if (_rematchRequested ||
            _opponentRematchRequested ||
            _opponent2RematchRequested)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
    final isGostopMode = _currentRoom?.gameMode == GameMode.gostop;

    // 3인 모드: 모든 상대방이 동의했는지 체크
    final allOpponentsAgreed = isGostopMode
        ? (_opponentRematchRequested && _opponent2RematchRequested)
        : _opponentRematchRequested;
    final anyOpponentAgreed =
        _opponentRematchRequested || _opponent2RematchRequested;

    // 내가 요청했고, 아직 모든 상대방이 동의하지 않은 경우
    if (_rematchRequested && !allOpponentsAgreed) {
      // 3인 모드에서 일부 상대방만 동의한 경우
      String waitingText;
      if (isGostopMode) {
        final agreedCount =
            (_opponentRematchRequested ? 1 : 0) +
            (_opponent2RematchRequested ? 1 : 0);
        waitingText = '다른 플레이어 응답 대기 중... ($agreedCount/2)';
      } else {
        waitingText = '상대방의 응답을 기다리는 중...';
      }

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
              Text(waitingText, style: TextStyle(color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_rematchCountdown초 후에 게임이 종료됩니다.',
            style: TextStyle(
              color: _rematchCountdown <= 5
                  ? Colors.redAccent
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    // 상대방이 요청했고, 내가 아직 동의하지 않은 경우
    if (anyOpponentAgreed && !_rematchRequested) {
      String requestText;
      if (isGostopMode) {
        final agreedCount =
            (_opponentRematchRequested ? 1 : 0) +
            (_opponent2RematchRequested ? 1 : 0);
        requestText = agreedCount == 2
            ? '모든 상대방이 재대결을 원합니다!'
            : '상대방 $agreedCount명이 재대결을 원합니다!';
      } else {
        requestText = '상대방이 재대결을 원합니다!';
      }

      return Text(
        requestText,
        style: TextStyle(
          color: AppColors.cardHighlight,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // 모두 동의한 경우 - 게임 재시작 중
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
        Text('게임을 다시 시작하는 중...', style: TextStyle(color: AppColors.text)),
      ],
    );
  }

  Widget _buildWaitingOverlay() {
    final isGostopMode = _currentRoom?.gameMode == GameMode.gostop;
    final currentPlayers = _currentRoom?.currentPlayerCount ?? 1;
    final requiredPlayers = isGostopMode ? 3 : 2;
    final waitingCount = currentPlayers - 1; // 호스트 제외한 입장한 플레이어 수
    final neededCount = requiredPlayers - 1; // 필요한 상대 플레이어 수

    // 대기 상태 메시지 결정
    String waitingMessage;
    bool showReadyMessage = false;

    if (isGostopMode) {
      if (currentPlayers >= requiredPlayers) {
        waitingMessage = '모든 플레이어가 입장했습니다!';
        showReadyMessage = true;
      } else {
        waitingMessage = '다른 플레이어 입장 대기 중... ($waitingCount/$neededCount)';
      }
    } else {
      waitingMessage = '상대방을 기다리는 중...';
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!showReadyMessage)
              CircularProgressIndicator(
                color: AppColors.cardHighlight,
                strokeWidth: 3,
              )
            else
              Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 32),
            Text(
              waitingMessage,
              style: TextStyle(
                color: showReadyMessage ? Colors.green : AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showReadyMessage) ...[
              const SizedBox(height: 8),
              Text(
                '곧 대결이 시작됩니다!',
                style: TextStyle(color: AppColors.cardHighlight, fontSize: 16),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.woodLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.woodDark.withValues(alpha: 0.5),
                ),
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
                  // 3인 모드: 현재 입장한 플레이어 수 표시
                  if (isGostopMode) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < requiredPlayers; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.person,
                              color: i < currentPlayers
                                  ? AppColors.cardHighlight
                                  : AppColors.textSecondary.withValues(
                                      alpha: 0.3,
                                    ),
                              size: 28,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currentPlayers / $requiredPlayers 명',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
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
