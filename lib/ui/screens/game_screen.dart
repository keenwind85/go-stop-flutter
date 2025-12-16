import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../models/card_data.dart';
import '../../models/game_room.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../services/matgo_logic_service.dart';
import '../../services/sound_service.dart';
import '../../game/matgo_game.dart';
import '../../game/systems/score_calculator.dart';
import '../widgets/go_stop_dialog.dart';
import '../widgets/game_result_dialog.dart';
import '../widgets/special_event_overlay.dart';
import '../widgets/action_buttons.dart';
import '../widgets/card_selection_dialog.dart';
import 'lobby_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomId;
  final bool isHost;

  const GameScreen({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late MatgoGame _game;
  StreamSubscription<GameRoom?>? _roomSubscription;
  GameRoom? _currentRoom;
  bool _isGameStarted = false;

  // UI 상태
  SpecialEvent _lastShownEvent = SpecialEvent.none;
  bool _showingEvent = false;
  bool _showingGoStop = false;
  bool _showingResult = false;
  bool _rematchRequested = false;
  bool _opponentRematchRequested = false;

  // 카드 선택 다이얼로그 상태
  bool _showingCardSelection = false;
  List<CardData> _selectionOptions = [];
  CardData? _playedCardForSelection;

  // 사운드 서비스
  late SoundService _soundService;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _game = MatgoGame();
    _soundService = ref.read(soundServiceProvider);
    _soundService.initialize();
    _setupGame();
    _listenToRoom();
  }

  void _setupGame() {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    // 플레이어 번호 설정 (host=1, guest=2)
    _game.setPlayer(user.uid, widget.isHost ? 1 : 2);

    // 카드 플레이 콜백 설정
    _game.onCardPlayed = _onCardPlayed;

    // 카드 선택 필요 시 콜백 (2장 이상 매칭)
    _game.onSelectionNeeded = _onSelectionNeeded;

    // 특수 이벤트 발생 시 콜백
    _game.onSpecialEventTriggered = _onSpecialEventFromGame;
  }

  /// 2장 이상 매칭 시 카드 선택 다이얼로그 표시
  void _onSelectionNeeded(List<CardData> options, CardData playedCard) {
    setState(() {
      _showingCardSelection = true;
      _selectionOptions = options;
      _playedCardForSelection = playedCard;
    });
  }

  /// 카드 선택 완료 시 처리
  void _onCardSelected(CardData selectedCard) {
    setState(() {
      _showingCardSelection = false;
      _selectionOptions = [];
      _playedCardForSelection = null;
    });

    // 게임 엔진에 선택 결과 전달
    _game.selectFloorCard(selectedCard);
  }

  /// 카드 선택 취소 시 처리
  void _onSelectionCancelled() {
    setState(() {
      _showingCardSelection = false;
      _selectionOptions = [];
      _playedCardForSelection = null;
    });

    // TODO: 필요 시 카드 선택 취소 로직 추가
  }

  /// 게임 엔진에서 발생한 특수 이벤트 처리
  void _onSpecialEventFromGame(SpecialEvent event) {
    if (event != SpecialEvent.none) {
      _soundService.playSpecialEvent(event);
    }
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
      setState(() {
        _currentRoom = room;
        // 재대결 요청 상태 업데이트
        _rematchRequested = widget.isHost
            ? room.hostRematchRequest
            : room.guestRematchRequest;
        _opponentRematchRequested = widget.isHost
            ? room.guestRematchRequest
            : room.hostRematchRequest;
      });

      // 양쪽 모두 재대결 요청 시 게임 재시작
      if (room.bothWantRematch && widget.isHost) {
        _startRematch();
      }

      // 호스트이고 방이 가득 찼으면 게임 시작
      if (widget.isHost &&
          room.isFull &&
          room.state == RoomState.waiting &&
          !_isGameStarted) {
        _startGame();
      }

      // 게임 상태가 있으면 Flame 엔진에 전달
      if (room.gameState != null) {
        _game.onGameStateChanged(room.gameState!);

        // 턴 변경 시 효과음
        if (previousRoom?.gameState?.turn != room.gameState!.turn &&
            room.gameState!.turn == myUid) {
          _soundService.playTurnNotify();
        }

        // 특수 이벤트 표시
        if (room.gameState!.lastEvent != SpecialEvent.none &&
            room.gameState!.lastEvent != _lastShownEvent &&
            !_showingEvent) {
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

        // 게임 종료 결과 표시
        if (room.gameState!.endState != GameEndState.none &&
            previousRoom?.gameState?.endState == GameEndState.none &&
            !_showingResult) {
          _showGameResult();
        }
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
      );
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _startRematch() async {
    final roomService = ref.read(roomServiceProvider);
    await roomService.startRematch(roomId: widget.roomId);

    setState(() {
      _isGameStarted = false;
      _showingResult = false;
      _rematchRequested = false;
      _opponentRematchRequested = false;
      _lastShownEvent = SpecialEvent.none;
    });

    // 호스트는 재대결 후 즉시 새 게임 시작
    if (widget.isHost && _currentRoom?.isFull == true) {
      // 약간의 지연을 주어 상태가 안정화된 후 게임 시작
      await Future.delayed(const Duration(milliseconds: 100));
      _startGame();
    }
  }

  Future<void> _onCardPlayed(dynamic cardData, dynamic floorCardData) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null || _currentRoom == null) return;

    // 카드 놓기 효과음
    _soundService.playCardPlace();

    // 상대방 uid 계산
    final opponentUid = widget.isHost
        ? _currentRoom!.guest?.uid ?? ''
        : _currentRoom!.host.uid;

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.playCard(
      roomId: widget.roomId,
      myUid: user.uid,
      opponentUid: opponentUid,
      card: cardData,
      playerNumber: widget.isHost ? 1 : 2,
      selectedFloorCard: floorCardData,
    );
  }

  void _showSpecialEvent(SpecialEvent event, bool isMyEvent) {
    // 특수 이벤트 효과음
    _soundService.playSpecialEvent(event);

    setState(() {
      _lastShownEvent = event;
      _showingEvent = true;
    });
  }

  void _dismissSpecialEvent() {
    setState(() {
      _showingEvent = false;
    });
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

  void _showGameResult() {
    final gameState = _currentRoom?.gameState;
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;

    // 결과에 따른 효과음
    if (gameState?.endState == GameEndState.nagari) {
      _soundService.playNagari();
    } else if (gameState?.winner == myUid) {
      _soundService.playWin();
    } else {
      _soundService.playLose();
    }

    setState(() => _showingResult = true);
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

    setState(() => _rematchRequested = true);
  }

  void _onExitResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LobbyScreen()),
    );
  }

  // 흔들기 선언
  Future<void> _onShake(int month) async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final matgoLogic = ref.read(matgoLogicServiceProvider);
    await matgoLogic.declareShake(
      roomId: widget.roomId,
      myUid: user.uid,
      playerNumber: widget.isHost ? 1 : 2,
      month: month,
    );
  }

  // 폭탄 선언
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
        backgroundColor: AppColors.background,
        title: const Text(
          '방이 종료되었습니다',
          style: TextStyle(color: AppColors.text),
        ),
        content: const Text(
          '상대방이 나갔거나 방이 삭제되었습니다.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LobbyScreen()),
              );
            },
            child: const Text('로비로 돌아가기'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text(
          '게임 나가기',
          style: TextStyle(color: AppColors.text),
        ),
        content: const Text(
          '정말 게임을 나가시겠습니까?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('나가기'),
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

  void _toggleSound() {
    setState(() {
      _soundEnabled = !_soundEnabled;
      _soundService.toggleMute();
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _soundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    final myUid = authService.currentUser?.uid;
    final gameState = _currentRoom?.gameState;
    final isMyTurn = gameState?.turn == myUid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Flame 게임 뷰
            GameWidget(game: _game),

            // 상단 HUD
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _buildHud(),
            ),

            // 점수 표시 (좌측 하단)
            if (gameState != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: _buildScoreDisplay(),
              ),

            // 흔들기/폭탄 버튼 (우측 하단)
            if (gameState != null && !_showingGoStop && !_showingResult)
              Positioned(
                bottom: 8,
                right: 8,
                child: ActionButtons(
                  myHand: widget.isHost
                      ? gameState.player1Hand
                      : gameState.player2Hand,
                  floorCards: gameState.floorCards,
                  isMyTurn: isMyTurn,
                  onShake: _onShake,
                  onBomb: _onBomb,
                ),
              ),

            // 대기 오버레이
            if (_currentRoom != null && !_currentRoom!.isFull)
              _buildWaitingOverlay(),

            // 특수 이벤트 오버레이
            if (_showingEvent && _lastShownEvent != SpecialEvent.none)
              SpecialEventOverlay(
                event: _lastShownEvent,
                isMyEvent: gameState?.lastEventPlayer == myUid,
                onDismiss: _dismissSpecialEvent,
              ),

            // Go/Stop 다이얼로그
            if (_showingGoStop && gameState != null)
              GoStopDialog(
                currentScore: widget.isHost
                    ? gameState.scores.player1Score
                    : gameState.scores.player2Score,
                goCount: widget.isHost
                    ? gameState.scores.player1GoCount
                    : gameState.scores.player2GoCount,
                onGo: _onGo,
                onStop: _onStop,
              ),

            // 게임 결과 다이얼로그
            if (_showingResult && gameState != null)
              _buildResultDialog(gameState, myUid),

            // 카드 선택 다이얼로그 (2장 이상 매칭 시)
            if (_showingCardSelection &&
                _selectionOptions.isNotEmpty &&
                _playedCardForSelection != null)
              CardSelectionDialog(
                matchingCards: _selectionOptions,
                playedCard: _playedCardForSelection!,
                onCardSelected: _onCardSelected,
                onCancel: _onSelectionCancelled,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDialog(GameState gameState, String? myUid) {
    final isWinner = gameState.winner == myUid;
    final isPlayer1 = widget.isHost;
    final player1Uid = widget.isHost ? myUid : widget.room.guestId;

    // 승자의 점수 상세 계산 (모든 승리 상태에서 계산: win, gobak, autoWin, chongtong)
    FinalScoreResult? scoreDetail;
    final hasWinner = gameState.endState == GameEndState.win ||
        gameState.endState == GameEndState.gobak ||
        gameState.endState == GameEndState.autoWin ||
        gameState.endState == GameEndState.chongtong;

    if (hasWinner && gameState.winner != null) {
      // 승자 기준으로 점수 계산 (패자에게도 상대방 점수 내역으로 표시됨)
      final winnerIsPlayer1 = gameState.winner == player1Uid;
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
        isGobak: gameState.isGobak,
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
        ),
        // 재대결 대기 상태 표시
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_rematchRequested && !_opponentRematchRequested)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '상대방의 응답을 기다리는 중...',
                            style: TextStyle(color: AppColors.text),
                          ),
                        ],
                      ),
                    if (_opponentRematchRequested && !_rematchRequested)
                      const Text(
                        '상대방이 재대결을 원합니다!',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (_rematchRequested && _opponentRematchRequested)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '게임을 다시 시작하는 중...',
                            style: TextStyle(color: AppColors.text),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreDisplay() {
    final gameState = _currentRoom?.gameState;
    if (gameState == null) return const SizedBox.shrink();

    final myScore = widget.isHost
        ? gameState.scores.player1Score
        : gameState.scores.player2Score;
    final opponentScore = widget.isHost
        ? gameState.scores.player2Score
        : gameState.scores.player1Score;
    final myGoCount = widget.isHost
        ? gameState.scores.player1GoCount
        : gameState.scores.player2GoCount;
    final myMultiplier = widget.isHost
        ? gameState.scores.player1Multiplier
        : gameState.scores.player2Multiplier;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '내 점수: ',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '$myScore점',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (myGoCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${myGoCount}고',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (myMultiplier > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'x$myMultiplier',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '상대 점수: ',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '$opponentScore점',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHud() {
    final myName = widget.isHost
        ? _currentRoom?.host.displayName
        : _currentRoom?.guest?.displayName;
    final opponentName = widget.isHost
        ? _currentRoom?.guest?.displayName
        : _currentRoom?.host.displayName;

    final gameState = _currentRoom?.gameState;
    final authService = ref.read(authServiceProvider);
    final isMyTurn = gameState?.turn == authService.currentUser?.uid;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 방 정보 + 턴 표시
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '방: ${widget.roomId}',
                style: const TextStyle(color: AppColors.text),
              ),
            ),
            if (gameState != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isMyTurn
                      ? AppColors.accent.withValues(alpha: 0.8)
                      : Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isMyTurn ? '내 턴' : '상대 턴',
                  style: TextStyle(
                    color: isMyTurn ? Colors.black : AppColors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),

        // 플레이어 정보 + 사운드 + 나가기
        Row(
          children: [
            if (opponentName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '상대: $opponentName',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '나: $myName',
                style: const TextStyle(color: AppColors.text),
              ),
            ),
            const SizedBox(width: 8),
            // 사운드 토글 버튼
            IconButton(
              icon: Icon(
                _soundEnabled ? Icons.volume_up : Icons.volume_off,
                color: AppColors.text,
              ),
              onPressed: _toggleSound,
            ),
            // 나가기 버튼
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: AppColors.error),
              onPressed: _leaveRoom,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 24),
            const Text(
              '상대방을 기다리는 중...',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    '방 코드',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    widget.roomId,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 32,
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
}
