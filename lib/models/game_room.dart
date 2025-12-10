import 'card_data.dart';
import 'player_info.dart';
import 'captured_cards.dart';

/// 방 상태
enum RoomState {
  waiting,  // 대기 중 (1명만 있음)
  playing,  // 게임 진행 중
  finished, // 게임 종료
}

/// 특수 이벤트 타입
enum SpecialEvent {
  none,           // 없음
  puk,            // 뻑
  jaPuk,          // 자뻑 (자기가 싼 뻑을 먹음)
  ttadak,         // 따닥 (2쌍 매칭)
  kiss,           // 쪽 (내 패 불매칭, 덱 카드가 내 패와 매칭)
  sweep,          // 싹쓸이 (바닥 0장)
  sulsa,          // 설사 (3장 매칭)
  shake,          // 흔들기
  bomb,           // 폭탄
  chongtong,      // 총통
  bonusCardUsed,  // 보너스 카드 사용
}

/// 게임 종료 상태
enum GameEndState {
  none,       // 진행 중
  win,        // 승리 (Stop 선언)
  nagari,     // 나가리 (무승부)
  chongtong,  // 총통 승리
  gobak,      // 고박 (상대가 고 선언 후 내가 7점 이상 도달)
  autoWin,    // 자동 승리 (고 선언 후 덱/손패 소진, 상대 7점 미만)
}

/// 점수 현황
class ScoreInfo {
  final int player1Score;
  final int player2Score;
  final int player1GoCount;
  final int player2GoCount;
  final int player1Multiplier;    // 배수 (흔들기, 폭탄 등)
  final int player2Multiplier;
  final bool player1Shaking;      // 흔들기 사용 여부
  final bool player2Shaking;
  final bool player1Bomb;         // 폭탄 사용 여부
  final bool player2Bomb;

  const ScoreInfo({
    this.player1Score = 0,
    this.player2Score = 0,
    this.player1GoCount = 0,
    this.player2GoCount = 0,
    this.player1Multiplier = 1,
    this.player2Multiplier = 1,
    this.player1Shaking = false,
    this.player2Shaking = false,
    this.player1Bomb = false,
    this.player2Bomb = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'player1Score': player1Score,
      'player2Score': player2Score,
      'player1GoCount': player1GoCount,
      'player2GoCount': player2GoCount,
      'player1Multiplier': player1Multiplier,
      'player2Multiplier': player2Multiplier,
      'player1Shaking': player1Shaking,
      'player2Shaking': player2Shaking,
      'player1Bomb': player1Bomb,
      'player2Bomb': player2Bomb,
    };
  }

  factory ScoreInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScoreInfo();
    return ScoreInfo(
      player1Score: json['player1Score'] as int? ?? 0,
      player2Score: json['player2Score'] as int? ?? 0,
      player1GoCount: json['player1GoCount'] as int? ?? 0,
      player2GoCount: json['player2GoCount'] as int? ?? 0,
      player1Multiplier: json['player1Multiplier'] as int? ?? 1,
      player2Multiplier: json['player2Multiplier'] as int? ?? 1,
      player1Shaking: json['player1Shaking'] as bool? ?? false,
      player2Shaking: json['player2Shaking'] as bool? ?? false,
      player1Bomb: json['player1Bomb'] as bool? ?? false,
      player2Bomb: json['player2Bomb'] as bool? ?? false,
    );
  }

  ScoreInfo copyWith({
    int? player1Score,
    int? player2Score,
    int? player1GoCount,
    int? player2GoCount,
    int? player1Multiplier,
    int? player2Multiplier,
    bool? player1Shaking,
    bool? player2Shaking,
    bool? player1Bomb,
    bool? player2Bomb,
  }) {
    return ScoreInfo(
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      player1GoCount: player1GoCount ?? this.player1GoCount,
      player2GoCount: player2GoCount ?? this.player2GoCount,
      player1Multiplier: player1Multiplier ?? this.player1Multiplier,
      player2Multiplier: player2Multiplier ?? this.player2Multiplier,
      player1Shaking: player1Shaking ?? this.player1Shaking,
      player2Shaking: player2Shaking ?? this.player2Shaking,
      player1Bomb: player1Bomb ?? this.player1Bomb,
      player2Bomb: player2Bomb ?? this.player2Bomb,
    );
  }
}

/// 게임 진행 상태
class GameState {
  final String turn;                    // 현재 턴을 가진 uid
  final List<CardData> deck;            // 남은 덱
  final List<CardData> floorCards;      // 바닥에 깔린 패
  final List<CardData> player1Hand;     // 방장 손패
  final List<CardData> player2Hand;     // 게스트 손패
  final CapturedCards player1Captured;  // 방장 먹은 패
  final CapturedCards player2Captured;  // 게스트 먹은 패
  final ScoreInfo scores;               // 점수 현황

  // 특수 이벤트 관련
  final SpecialEvent lastEvent;         // 마지막 발생 이벤트
  final String? lastEventPlayer;        // 이벤트 발생 플레이어 uid
  final List<CardData> pukCards;        // 뻑으로 바닥에 쌓인 카드들 (뻑 주인 uid별)
  final String? pukOwner;               // 뻑을 싼 플레이어 uid

  // 게임 종료 관련
  final GameEndState endState;          // 게임 종료 상태
  final String? winner;                 // 승자 uid
  final int finalScore;                 // 최종 점수 (배수 적용 후)

  // Go/Stop 선택 대기
  final bool waitingForGoStop;          // Go/Stop 선택 대기 중
  final String? goStopPlayer;           // 선택해야 할 플레이어 uid

  // 흔들기 카드 공개 (양쪽 플레이어 모두에게 표시)
  final List<CardData> shakeCards;      // 흔들기로 공개된 카드들
  final String? shakePlayer;            // 흔들기한 플레이어 uid

  // 총통 카드 공개 (게임 시작 시 같은 월 4장)
  final List<CardData> chongtongCards;  // 총통으로 공개된 카드들
  final String? chongtongPlayer;        // 총통 플레이어 uid

  // 선 결정 관련
  final String? firstTurnPlayer;        // 선 플레이어 uid
  final int? firstTurnDecidingMonth;    // 선 결정에 사용된 월 (표시용)
  final String? firstTurnReason;        // 선 결정 사유 (표시용)

  // 덱 카드 선택 대기 (더미 패 뒤집기 시 2장 매칭)
  final bool waitingForDeckSelection;   // 덱 카드 선택 대기 중
  final String? deckSelectionPlayer;    // 선택해야 할 플레이어 uid
  final CardData? deckCard;             // 뒤집은 덱 카드
  final List<CardData> deckMatchingCards; // 매칭되는 바닥 카드들
  final CardData? pendingHandCard;      // 먼저 낸 손패 카드 (선택 후 처리 위해)
  final CardData? pendingHandMatch;     // 손패로 먹은 바닥 카드 (선택 후 처리 위해)

  // 턴 타이머 관련
  final int? turnStartTime;             // 현재 턴 시작 시간 (밀리초 타임스탬프)

  const GameState({
    required this.turn,
    this.deck = const [],
    this.floorCards = const [],
    this.player1Hand = const [],
    this.player2Hand = const [],
    this.player1Captured = const CapturedCards(),
    this.player2Captured = const CapturedCards(),
    this.scores = const ScoreInfo(),
    this.lastEvent = SpecialEvent.none,
    this.lastEventPlayer,
    this.pukCards = const [],
    this.pukOwner,
    this.endState = GameEndState.none,
    this.winner,
    this.finalScore = 0,
    this.waitingForGoStop = false,
    this.goStopPlayer,
    this.shakeCards = const [],
    this.shakePlayer,
    this.chongtongCards = const [],
    this.chongtongPlayer,
    this.firstTurnPlayer,
    this.firstTurnDecidingMonth,
    this.firstTurnReason,
    this.waitingForDeckSelection = false,
    this.deckSelectionPlayer,
    this.deckCard,
    this.deckMatchingCards = const [],
    this.pendingHandCard,
    this.pendingHandMatch,
    this.turnStartTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'turn': turn,
      'deck': deck.map((c) => c.toJson()).toList(),
      'floorCards': floorCards.map((c) => c.toJson()).toList(),
      'player1Hand': player1Hand.map((c) => c.toJson()).toList(),
      'player2Hand': player2Hand.map((c) => c.toJson()).toList(),
      'player1Captured': player1Captured.toJson(),
      'player2Captured': player2Captured.toJson(),
      'scores': scores.toJson(),
      'lastEvent': lastEvent.name,
      'lastEventPlayer': lastEventPlayer,
      'pukCards': pukCards.map((c) => c.toJson()).toList(),
      'pukOwner': pukOwner,
      'endState': endState.name,
      'winner': winner,
      'finalScore': finalScore,
      'waitingForGoStop': waitingForGoStop,
      'goStopPlayer': goStopPlayer,
      'shakeCards': shakeCards.map((c) => c.toJson()).toList(),
      'shakePlayer': shakePlayer,
      'chongtongCards': chongtongCards.map((c) => c.toJson()).toList(),
      'chongtongPlayer': chongtongPlayer,
      'firstTurnPlayer': firstTurnPlayer,
      'firstTurnDecidingMonth': firstTurnDecidingMonth,
      'firstTurnReason': firstTurnReason,
      'waitingForDeckSelection': waitingForDeckSelection,
      'deckSelectionPlayer': deckSelectionPlayer,
      'deckCard': deckCard?.toJson(),
      'deckMatchingCards': deckMatchingCards.map((c) => c.toJson()).toList(),
      'pendingHandCard': pendingHandCard?.toJson(),
      'pendingHandMatch': pendingHandMatch?.toJson(),
      'turnStartTime': turnStartTime,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      turn: json['turn'] as String? ?? '',
      deck: _parseCardList(json['deck']),
      floorCards: _parseCardList(json['floorCards']),
      player1Hand: _parseCardList(json['player1Hand']),
      player2Hand: _parseCardList(json['player2Hand']),
      player1Captured: CapturedCards.fromJson(
        json['player1Captured'] != null
            ? Map<String, dynamic>.from(json['player1Captured'] as Map)
            : null,
      ),
      player2Captured: CapturedCards.fromJson(
        json['player2Captured'] != null
            ? Map<String, dynamic>.from(json['player2Captured'] as Map)
            : null,
      ),
      scores: ScoreInfo.fromJson(
        json['scores'] != null
            ? Map<String, dynamic>.from(json['scores'] as Map)
            : null,
      ),
      lastEvent: SpecialEvent.values.firstWhere(
        (e) => e.name == json['lastEvent'],
        orElse: () => SpecialEvent.none,
      ),
      lastEventPlayer: json['lastEventPlayer'] as String?,
      pukCards: _parseCardList(json['pukCards']),
      pukOwner: json['pukOwner'] as String?,
      endState: GameEndState.values.firstWhere(
        (e) => e.name == json['endState'],
        orElse: () => GameEndState.none,
      ),
      winner: json['winner'] as String?,
      finalScore: json['finalScore'] as int? ?? 0,
      waitingForGoStop: json['waitingForGoStop'] as bool? ?? false,
      goStopPlayer: json['goStopPlayer'] as String?,
      shakeCards: _parseCardList(json['shakeCards']),
      shakePlayer: json['shakePlayer'] as String?,
      chongtongCards: _parseCardList(json['chongtongCards']),
      chongtongPlayer: json['chongtongPlayer'] as String?,
      firstTurnPlayer: json['firstTurnPlayer'] as String?,
      firstTurnDecidingMonth: json['firstTurnDecidingMonth'] as int?,
      firstTurnReason: json['firstTurnReason'] as String?,
      waitingForDeckSelection: json['waitingForDeckSelection'] as bool? ?? false,
      deckSelectionPlayer: json['deckSelectionPlayer'] as String?,
      deckCard: json['deckCard'] != null
          ? CardData.fromJson(Map<String, dynamic>.from(json['deckCard'] as Map))
          : null,
      deckMatchingCards: _parseCardList(json['deckMatchingCards']),
      pendingHandCard: json['pendingHandCard'] != null
          ? CardData.fromJson(Map<String, dynamic>.from(json['pendingHandCard'] as Map))
          : null,
      pendingHandMatch: json['pendingHandMatch'] != null
          ? CardData.fromJson(Map<String, dynamic>.from(json['pendingHandMatch'] as Map))
          : null,
      turnStartTime: json['turnStartTime'] as int?,
    );
  }

  static List<CardData> _parseCardList(dynamic list) {
    if (list == null) return [];
    return (list as List)
        .map((e) => CardData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  GameState copyWith({
    String? turn,
    List<CardData>? deck,
    List<CardData>? floorCards,
    List<CardData>? player1Hand,
    List<CardData>? player2Hand,
    CapturedCards? player1Captured,
    CapturedCards? player2Captured,
    ScoreInfo? scores,
    SpecialEvent? lastEvent,
    String? lastEventPlayer,
    List<CardData>? pukCards,
    String? pukOwner,
    GameEndState? endState,
    String? winner,
    int? finalScore,
    bool? waitingForGoStop,
    String? goStopPlayer,
    List<CardData>? shakeCards,
    String? shakePlayer,
    List<CardData>? chongtongCards,
    String? chongtongPlayer,
    String? firstTurnPlayer,
    int? firstTurnDecidingMonth,
    String? firstTurnReason,
    bool? waitingForDeckSelection,
    String? deckSelectionPlayer,
    CardData? deckCard,
    List<CardData>? deckMatchingCards,
    CardData? pendingHandCard,
    CardData? pendingHandMatch,
    int? turnStartTime,
    bool clearLastEventPlayer = false,
    bool clearPukOwner = false,
    bool clearWinner = false,
    bool clearGoStopPlayer = false,
    bool clearShakePlayer = false,
    bool clearChongtongPlayer = false,
    bool clearFirstTurnPlayer = false,
    bool clearDeckSelectionPlayer = false,
    bool clearDeckCard = false,
    bool clearPendingHandCard = false,
    bool clearPendingHandMatch = false,
    bool clearTurnStartTime = false,
  }) {
    return GameState(
      turn: turn ?? this.turn,
      deck: deck ?? this.deck,
      floorCards: floorCards ?? this.floorCards,
      player1Hand: player1Hand ?? this.player1Hand,
      player2Hand: player2Hand ?? this.player2Hand,
      player1Captured: player1Captured ?? this.player1Captured,
      player2Captured: player2Captured ?? this.player2Captured,
      scores: scores ?? this.scores,
      lastEvent: lastEvent ?? this.lastEvent,
      lastEventPlayer: clearLastEventPlayer ? null : (lastEventPlayer ?? this.lastEventPlayer),
      pukCards: pukCards ?? this.pukCards,
      pukOwner: clearPukOwner ? null : (pukOwner ?? this.pukOwner),
      endState: endState ?? this.endState,
      winner: clearWinner ? null : (winner ?? this.winner),
      finalScore: finalScore ?? this.finalScore,
      waitingForGoStop: waitingForGoStop ?? this.waitingForGoStop,
      goStopPlayer: clearGoStopPlayer ? null : (goStopPlayer ?? this.goStopPlayer),
      shakeCards: shakeCards ?? this.shakeCards,
      shakePlayer: clearShakePlayer ? null : (shakePlayer ?? this.shakePlayer),
      chongtongCards: chongtongCards ?? this.chongtongCards,
      chongtongPlayer: clearChongtongPlayer ? null : (chongtongPlayer ?? this.chongtongPlayer),
      firstTurnPlayer: clearFirstTurnPlayer ? null : (firstTurnPlayer ?? this.firstTurnPlayer),
      firstTurnDecidingMonth: firstTurnDecidingMonth ?? this.firstTurnDecidingMonth,
      firstTurnReason: firstTurnReason ?? this.firstTurnReason,
      waitingForDeckSelection: waitingForDeckSelection ?? this.waitingForDeckSelection,
      deckSelectionPlayer: clearDeckSelectionPlayer ? null : (deckSelectionPlayer ?? this.deckSelectionPlayer),
      deckCard: clearDeckCard ? null : (deckCard ?? this.deckCard),
      deckMatchingCards: deckMatchingCards ?? this.deckMatchingCards,
      pendingHandCard: clearPendingHandCard ? null : (pendingHandCard ?? this.pendingHandCard),
      pendingHandMatch: clearPendingHandMatch ? null : (pendingHandMatch ?? this.pendingHandMatch),
      turnStartTime: clearTurnStartTime ? null : (turnStartTime ?? this.turnStartTime),
    );
  }
}

/// 게임 방 전체 데이터 모델
class GameRoom {
  final String roomId;
  final PlayerInfo host;        // 방장 (player1)
  final PlayerInfo? guest;      // 게스트 (player2)
  final RoomState state;
  final GameState? gameState;
  final int createdAt;
  final bool hostRematchRequest;    // 방장 재대결 요청
  final bool guestRematchRequest;   // 게스트 재대결 요청
  final bool gwangkkiModeActive;    // 光끼 모드 활성화 여부
  final String? gwangkkiActivator;  // 光끼 모드 발동자 UID
  final int gameCount;              // 게임 횟수 (첫 게임=0, 재대결=1,2,3...)
  final String? lastWinner;         // 마지막 게임 승자 UID (재대결 시 선공 결정용)

  const GameRoom({
    required this.roomId,
    required this.host,
    this.guest,
    this.state = RoomState.waiting,
    this.gameState,
    required this.createdAt,
    this.hostRematchRequest = false,
    this.guestRematchRequest = false,
    this.gwangkkiModeActive = false,
    this.gwangkkiActivator,
    this.gameCount = 0,
    this.lastWinner,
  });

  /// 양쪽 모두 재대결 요청했는지
  bool get bothWantRematch => hostRematchRequest && guestRematchRequest;

  /// 방이 가득 찼는지 (2명)
  bool get isFull => guest != null;

  /// 주어진 uid가 방장인지
  bool isHost(String uid) => host.uid == uid;

  /// 주어진 uid가 게스트인지
  bool isGuest(String uid) => guest?.uid == uid;

  /// 주어진 uid의 플레이어 번호 반환 (1 또는 2)
  int getPlayerNumber(String uid) {
    if (host.uid == uid) return 1;
    if (guest?.uid == uid) return 2;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'host': host.toJson(),
      'guest': guest?.toJson(),
      'state': state.name,
      'gameState': gameState?.toJson(),
      'createdAt': createdAt,
      'hostRematchRequest': hostRematchRequest,
      'guestRematchRequest': guestRematchRequest,
      'gwangkkiModeActive': gwangkkiModeActive,
      'gwangkkiActivator': gwangkkiActivator,
      'gameCount': gameCount,
      'lastWinner': lastWinner,
    };
  }

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      roomId: json['roomId'] as String,
      host: PlayerInfo.fromJson(
        Map<String, dynamic>.from(json['host'] as Map),
      ),
      guest: json['guest'] != null
          ? PlayerInfo.fromJson(
              Map<String, dynamic>.from(json['guest'] as Map),
            )
          : null,
      state: RoomState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => RoomState.waiting,
      ),
      gameState: json['gameState'] != null
          ? GameState.fromJson(
              Map<String, dynamic>.from(json['gameState'] as Map),
            )
          : null,
      createdAt: json['createdAt'] as int? ?? 0,
      hostRematchRequest: json['hostRematchRequest'] as bool? ?? false,
      guestRematchRequest: json['guestRematchRequest'] as bool? ?? false,
      gwangkkiModeActive: json['gwangkkiModeActive'] as bool? ?? false,
      gwangkkiActivator: json['gwangkkiActivator'] as String?,
      gameCount: json['gameCount'] as int? ?? 0,
      lastWinner: json['lastWinner'] as String?,
    );
  }

  GameRoom copyWith({
    String? roomId,
    PlayerInfo? host,
    PlayerInfo? guest,
    RoomState? state,
    GameState? gameState,
    int? createdAt,
    bool? hostRematchRequest,
    bool? guestRematchRequest,
    bool? gwangkkiModeActive,
    String? gwangkkiActivator,
    int? gameCount,
    String? lastWinner,
    bool clearGuest = false,
    bool clearGameState = false,
    bool clearGwangkkiActivator = false,
    bool clearLastWinner = false,
  }) {
    return GameRoom(
      roomId: roomId ?? this.roomId,
      host: host ?? this.host,
      guest: clearGuest ? null : (guest ?? this.guest),
      state: state ?? this.state,
      gameState: clearGameState ? null : (gameState ?? this.gameState),
      createdAt: createdAt ?? this.createdAt,
      hostRematchRequest: hostRematchRequest ?? this.hostRematchRequest,
      guestRematchRequest: guestRematchRequest ?? this.guestRematchRequest,
      gwangkkiModeActive: gwangkkiModeActive ?? this.gwangkkiModeActive,
      gwangkkiActivator: clearGwangkkiActivator ? null : (gwangkkiActivator ?? this.gwangkkiActivator),
      gameCount: gameCount ?? this.gameCount,
      lastWinner: clearLastWinner ? null : (lastWinner ?? this.lastWinner),
    );
  }
}
