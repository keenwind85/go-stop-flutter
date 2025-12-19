import 'card_data.dart';
import 'player_info.dart';
import 'captured_cards.dart';
import 'item_data.dart';
import '../config/constants.dart';

/// 방 상태
enum RoomState {
  waiting,  // 대기 중 (플레이어 모집 중)
  ready,    // 준비 완료 (필요 인원 충족)
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
  meongTta,       // 멍따 (열끗 7장 이상 보유)
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

/// 패자별 정산 상세 정보 (3인 고스톱 전용)
class LoserSettlementDetail {
  final String loserUid;           // 패자 UID
  final String loserDisplayName;   // 패자 표시 이름
  final int playerNumber;          // 플레이어 번호 (1, 2, 3)
  final bool isGwangBak;           // 광박 (광 0장)
  final bool isPiBak;              // 피박 (피 5장 이하)
  final bool isGobak;              // 고박 (고 선언 후 패배)
  final int multiplier;            // 코인 배수 (박 규칙 적용)
  final int baseAmount;            // 기본 정산액 (점수)
  final int actualTransfer;        // 실제 정산액 (배수 적용)

  const LoserSettlementDetail({
    required this.loserUid,
    required this.loserDisplayName,
    required this.playerNumber,
    this.isGwangBak = false,
    this.isPiBak = false,
    this.isGobak = false,
    this.multiplier = 1,
    this.baseAmount = 0,
    this.actualTransfer = 0,
  });

  /// 박 규칙 적용 여부
  bool get hasPenalty => isGwangBak || isPiBak || isGobak;

  /// 박 규칙 설명 목록
  List<String> get penaltyDescriptions {
    final descriptions = <String>[];
    if (isGwangBak) descriptions.add('광박');
    if (isPiBak) descriptions.add('피박');
    if (isGobak) descriptions.add('고박');
    return descriptions;
  }
}

/// 고스톱 3인 정산 결과
class GostopSettlementResult {
  final List<LoserSettlementDetail> loserDetails;
  final int totalTransfer;  // 승자가 받은 총 코인

  const GostopSettlementResult({
    required this.loserDetails,
    required this.totalTransfer,
  });
}

/// 점수 현황
class ScoreInfo {
  final int player1Score;
  final int player2Score;
  final int player3Score;         // 게스트2 점수 (고스톱 전용)
  final int player1GoCount;
  final int player2GoCount;
  final int player3GoCount;       // 게스트2 고 횟수 (고스톱 전용)
  final int player1Multiplier;    // 배수 (흔들기, 폭탄 등)
  final int player2Multiplier;
  final int player3Multiplier;    // 게스트2 배수 (고스톱 전용)
  final bool player1Shaking;      // 흔들기 사용 여부
  final bool player2Shaking;
  final bool player3Shaking;      // 게스트2 흔들기 (고스톱 전용)
  final bool player1Bomb;         // 폭탄 사용 여부
  final bool player2Bomb;
  final bool player3Bomb;         // 게스트2 폭탄 (고스톱 전용)
  final bool player1MeongTta;     // 멍따 (열끗 7장 이상)
  final bool player2MeongTta;
  final bool player3MeongTta;     // 게스트2 멍따 (고스톱 전용)

  const ScoreInfo({
    this.player1Score = 0,
    this.player2Score = 0,
    this.player3Score = 0,
    this.player1GoCount = 0,
    this.player2GoCount = 0,
    this.player3GoCount = 0,
    this.player1Multiplier = 1,
    this.player2Multiplier = 1,
    this.player3Multiplier = 1,
    this.player1Shaking = false,
    this.player2Shaking = false,
    this.player3Shaking = false,
    this.player1Bomb = false,
    this.player2Bomb = false,
    this.player3Bomb = false,
    this.player1MeongTta = false,
    this.player2MeongTta = false,
    this.player3MeongTta = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'player1Score': player1Score,
      'player2Score': player2Score,
      'player3Score': player3Score,
      'player1GoCount': player1GoCount,
      'player2GoCount': player2GoCount,
      'player3GoCount': player3GoCount,
      'player1Multiplier': player1Multiplier,
      'player2Multiplier': player2Multiplier,
      'player3Multiplier': player3Multiplier,
      'player1Shaking': player1Shaking,
      'player2Shaking': player2Shaking,
      'player3Shaking': player3Shaking,
      'player1Bomb': player1Bomb,
      'player2Bomb': player2Bomb,
      'player3Bomb': player3Bomb,
      'player1MeongTta': player1MeongTta,
      'player2MeongTta': player2MeongTta,
      'player3MeongTta': player3MeongTta,
    };
  }

  factory ScoreInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScoreInfo();
    return ScoreInfo(
      player1Score: json['player1Score'] as int? ?? 0,
      player2Score: json['player2Score'] as int? ?? 0,
      player3Score: json['player3Score'] as int? ?? 0,
      player1GoCount: json['player1GoCount'] as int? ?? 0,
      player2GoCount: json['player2GoCount'] as int? ?? 0,
      player3GoCount: json['player3GoCount'] as int? ?? 0,
      player1Multiplier: json['player1Multiplier'] as int? ?? 1,
      player2Multiplier: json['player2Multiplier'] as int? ?? 1,
      player3Multiplier: json['player3Multiplier'] as int? ?? 1,
      player1Shaking: json['player1Shaking'] as bool? ?? false,
      player2Shaking: json['player2Shaking'] as bool? ?? false,
      player3Shaking: json['player3Shaking'] as bool? ?? false,
      player1Bomb: json['player1Bomb'] as bool? ?? false,
      player2Bomb: json['player2Bomb'] as bool? ?? false,
      player3Bomb: json['player3Bomb'] as bool? ?? false,
      player1MeongTta: json['player1MeongTta'] as bool? ?? false,
      player2MeongTta: json['player2MeongTta'] as bool? ?? false,
      player3MeongTta: json['player3MeongTta'] as bool? ?? false,
    );
  }

  ScoreInfo copyWith({
    int? player1Score,
    int? player2Score,
    int? player3Score,
    int? player1GoCount,
    int? player2GoCount,
    int? player3GoCount,
    int? player1Multiplier,
    int? player2Multiplier,
    int? player3Multiplier,
    bool? player1Shaking,
    bool? player2Shaking,
    bool? player3Shaking,
    bool? player1Bomb,
    bool? player2Bomb,
    bool? player3Bomb,
    bool? player1MeongTta,
    bool? player2MeongTta,
    bool? player3MeongTta,
  }) {
    return ScoreInfo(
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      player3Score: player3Score ?? this.player3Score,
      player1GoCount: player1GoCount ?? this.player1GoCount,
      player2GoCount: player2GoCount ?? this.player2GoCount,
      player3GoCount: player3GoCount ?? this.player3GoCount,
      player1Multiplier: player1Multiplier ?? this.player1Multiplier,
      player2Multiplier: player2Multiplier ?? this.player2Multiplier,
      player3Multiplier: player3Multiplier ?? this.player3Multiplier,
      player1Shaking: player1Shaking ?? this.player1Shaking,
      player2Shaking: player2Shaking ?? this.player2Shaking,
      player3Shaking: player3Shaking ?? this.player3Shaking,
      player1Bomb: player1Bomb ?? this.player1Bomb,
      player2Bomb: player2Bomb ?? this.player2Bomb,
      player3Bomb: player3Bomb ?? this.player3Bomb,
      player1MeongTta: player1MeongTta ?? this.player1MeongTta,
      player2MeongTta: player2MeongTta ?? this.player2MeongTta,
      player3MeongTta: player3MeongTta ?? this.player3MeongTta,
    );
  }
}

/// 게임 진행 상태
class GameState {
  final String turn;                    // 현재 턴을 가진 uid
  final List<CardData> deck;            // 남은 덱
  final List<CardData> floorCards;      // 바닥에 깔린 패
  final List<CardData> player1Hand;     // 방장 손패
  final List<CardData> player2Hand;     // 게스트1 손패
  final List<CardData> player3Hand;     // 게스트2 손패 (고스톱 전용)
  final CapturedCards player1Captured;  // 방장 먹은 패
  final CapturedCards player2Captured;  // 게스트1 먹은 패
  final CapturedCards player3Captured;  // 게스트2 먹은 패 (고스톱 전용)
  final ScoreInfo scores;               // 점수 현황

  // 게임 모드 및 턴 순서 (3인 지원)
  final GameMode gameMode;              // 게임 모드
  final List<String> turnOrder;         // 턴 순서 (uid 리스트)
  final int currentTurnIndex;           // 현재 턴 인덱스

  // 특수 이벤트 관련
  final SpecialEvent lastEvent;         // 마지막 발생 이벤트
  final String? lastEventPlayer;        // 이벤트 발생 플레이어 uid
  final int? lastEventAt;               // 이벤트 발생 시간 (타임스탬프, 연속 이벤트 감지용)
  final List<CardData> pukCards;        // 뻑으로 바닥에 쌓인 카드들 (뻑 주인 uid별)
  final String? pukOwner;               // 뻑을 싼 플레이어 uid

  // 게임 종료 관련
  final GameEndState endState;          // 게임 종료 상태
  final String? winner;                 // 승자 uid
  final int finalScore;                 // 최종 점수 (배수 적용 후)
  final bool isGobak;                   // 고박 여부 (상대가 고 선언 후 역전 승리)

  // Go/Stop 선택 대기
  final bool waitingForGoStop;          // Go/Stop 선택 대기 중
  final String? goStopPlayer;           // 선택해야 할 플레이어 uid

  // 흔들기 카드 공개 (양쪽 플레이어 모두에게 표시)
  final List<CardData> shakeCards;      // 흔들기로 공개된 카드들
  final String? shakePlayer;            // 흔들기한 플레이어 uid

  // 폭탄 카드 공개 (손패에서 같은 월 3장 + 바닥에 1장)
  final List<CardData> bombCards;       // 폭탄으로 공개된 카드들 (손패 3장)
  final String? bombPlayer;             // 폭탄 사용 플레이어 uid
  final CardData? bombTargetCard;       // 폭탄 대상 바닥 카드 (1장)

  // 멍따 카드 공개 (열끗 7장 이상 보유 시)
  final List<CardData> meongTtaCards;   // 멍따 달성 시 열끗 카드들
  final String? meongTtaPlayer;         // 멍따 플레이어 uid

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

  // 9월 열끗(쌍피) 선택 대기
  final bool waitingForSeptemberChoice;   // 9월 열끗 선택 대기 중
  final String? septemberChoicePlayer;    // 선택해야 할 플레이어 uid
  final CardData? pendingSeptemberCard;   // 선택 대기 중인 9월 열끗 카드

  // 피 뺏김 알림 (특수룰로 인한 피 뺏김)
  final int piStolenCount;                // 뺏긴 피 개수
  final List<String> piStolenFromPlayers; // 피를 뺏긴 플레이어들 uid (3인 모드 지원)

  // 아이템 효과 관련
  final ItemEffects? player1ItemEffects;  // 플레이어1 아이템 효과
  final ItemEffects? player2ItemEffects;  // 플레이어2 아이템 효과
  final ItemEffects? player3ItemEffects;  // 플레이어3 아이템 효과 (고스톱 전용)
  final String? lastItemUsed;             // 마지막 사용된 아이템 이름
  final String? lastItemUsedBy;           // 마지막 아이템 사용자 uid
  final int? lastItemUsedAt;              // 마지막 아이템 사용 시간 (타임스탬프, 동기화용)
  final String? player1Uid;               // 플레이어1 uid (아이템 사용 조건 체크용)
  final String? player2Uid;               // 플레이어2 uid (아이템 사용 조건 체크용)

  const GameState({
    required this.turn,
    this.deck = const [],
    this.floorCards = const [],
    this.player1Hand = const [],
    this.player2Hand = const [],
    this.player3Hand = const [],
    this.player1Captured = const CapturedCards(),
    this.player2Captured = const CapturedCards(),
    this.player3Captured = const CapturedCards(),
    this.scores = const ScoreInfo(),
    this.gameMode = GameMode.matgo,
    this.turnOrder = const [],
    this.currentTurnIndex = 0,
    this.lastEvent = SpecialEvent.none,
    this.lastEventPlayer,
    this.lastEventAt,
    this.pukCards = const [],
    this.pukOwner,
    this.endState = GameEndState.none,
    this.winner,
    this.finalScore = 0,
    this.isGobak = false,
    this.waitingForGoStop = false,
    this.goStopPlayer,
    this.shakeCards = const [],
    this.shakePlayer,
    this.bombCards = const [],
    this.bombPlayer,
    this.bombTargetCard,
    this.meongTtaCards = const [],
    this.meongTtaPlayer,
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
    this.waitingForSeptemberChoice = false,
    this.septemberChoicePlayer,
    this.pendingSeptemberCard,
    this.piStolenCount = 0,
    this.piStolenFromPlayers = const [],
    this.player1ItemEffects,
    this.player2ItemEffects,
    this.player3ItemEffects,
    this.lastItemUsed,
    this.lastItemUsedBy,
    this.lastItemUsedAt,
    this.player1Uid,
    this.player2Uid,
  });

  /// 다음 턴 인덱스 계산
  int get nextTurnIndex => (currentTurnIndex + 1) % turnOrder.length;

  /// 현재 턴 플레이어 UID (turnOrder 기반)
  String get currentTurnUid => turnOrder.isNotEmpty ? turnOrder[currentTurnIndex] : turn;

  Map<String, dynamic> toJson() {
    return {
      'turn': turn,
      'deck': deck.map((c) => c.toJson()).toList(),
      'floorCards': floorCards.map((c) => c.toJson()).toList(),
      'player1Hand': player1Hand.map((c) => c.toJson()).toList(),
      'player2Hand': player2Hand.map((c) => c.toJson()).toList(),
      'player3Hand': player3Hand.map((c) => c.toJson()).toList(),
      'player1Captured': player1Captured.toJson(),
      'player2Captured': player2Captured.toJson(),
      'player3Captured': player3Captured.toJson(),
      'scores': scores.toJson(),
      'gameMode': gameMode.name,
      'turnOrder': turnOrder,
      'currentTurnIndex': currentTurnIndex,
      'lastEvent': lastEvent.name,
      'lastEventPlayer': lastEventPlayer,
      'lastEventAt': lastEventAt,
      'pukCards': pukCards.map((c) => c.toJson()).toList(),
      'pukOwner': pukOwner,
      'endState': endState.name,
      'winner': winner,
      'finalScore': finalScore,
      'isGobak': isGobak,
      'waitingForGoStop': waitingForGoStop,
      'goStopPlayer': goStopPlayer,
      'shakeCards': shakeCards.map((c) => c.toJson()).toList(),
      'shakePlayer': shakePlayer,
      'bombCards': bombCards.map((c) => c.toJson()).toList(),
      'bombPlayer': bombPlayer,
      'bombTargetCard': bombTargetCard?.toJson(),
      'meongTtaCards': meongTtaCards.map((c) => c.toJson()).toList(),
      'meongTtaPlayer': meongTtaPlayer,
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
      'waitingForSeptemberChoice': waitingForSeptemberChoice,
      'septemberChoicePlayer': septemberChoicePlayer,
      'pendingSeptemberCard': pendingSeptemberCard?.toJson(),
      'piStolenCount': piStolenCount,
      'piStolenFromPlayers': piStolenFromPlayers,
      'player1ItemEffects': player1ItemEffects?.toJson(),
      'player2ItemEffects': player2ItemEffects?.toJson(),
      'player3ItemEffects': player3ItemEffects?.toJson(),
      'lastItemUsed': lastItemUsed,
      'lastItemUsedBy': lastItemUsedBy,
      'lastItemUsedAt': lastItemUsedAt,
      'player1Uid': player1Uid,
      'player2Uid': player2Uid,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      turn: json['turn'] as String? ?? '',
      deck: _parseCardList(json['deck']),
      floorCards: _parseCardList(json['floorCards']),
      player1Hand: _parseCardList(json['player1Hand']),
      player2Hand: _parseCardList(json['player2Hand']),
      player3Hand: _parseCardList(json['player3Hand']),
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
      player3Captured: CapturedCards.fromJson(
        json['player3Captured'] != null
            ? Map<String, dynamic>.from(json['player3Captured'] as Map)
            : null,
      ),
      scores: ScoreInfo.fromJson(
        json['scores'] != null
            ? Map<String, dynamic>.from(json['scores'] as Map)
            : null,
      ),
      gameMode: GameMode.values.firstWhere(
        (e) => e.name == json['gameMode'],
        orElse: () => GameMode.matgo,
      ),
      turnOrder: (json['turnOrder'] as List?)?.cast<String>() ?? [],
      currentTurnIndex: json['currentTurnIndex'] as int? ?? 0,
      lastEvent: SpecialEvent.values.firstWhere(
        (e) => e.name == json['lastEvent'],
        orElse: () => SpecialEvent.none,
      ),
      lastEventPlayer: json['lastEventPlayer'] as String?,
      lastEventAt: json['lastEventAt'] as int?,
      pukCards: _parseCardList(json['pukCards']),
      pukOwner: json['pukOwner'] as String?,
      endState: GameEndState.values.firstWhere(
        (e) => e.name == json['endState'],
        orElse: () => GameEndState.none,
      ),
      winner: json['winner'] as String?,
      finalScore: json['finalScore'] as int? ?? 0,
      isGobak: json['isGobak'] as bool? ?? false,
      waitingForGoStop: json['waitingForGoStop'] as bool? ?? false,
      goStopPlayer: json['goStopPlayer'] as String?,
      shakeCards: _parseCardList(json['shakeCards']),
      shakePlayer: json['shakePlayer'] as String?,
      bombCards: _parseCardList(json['bombCards']),
      bombPlayer: json['bombPlayer'] as String?,
      bombTargetCard: json['bombTargetCard'] != null
          ? CardData.fromJson(Map<String, dynamic>.from(json['bombTargetCard'] as Map))
          : null,
      meongTtaCards: _parseCardList(json['meongTtaCards']),
      meongTtaPlayer: json['meongTtaPlayer'] as String?,
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
      waitingForSeptemberChoice: json['waitingForSeptemberChoice'] as bool? ?? false,
      septemberChoicePlayer: json['septemberChoicePlayer'] as String?,
      pendingSeptemberCard: json['pendingSeptemberCard'] != null
          ? CardData.fromJson(Map<String, dynamic>.from(json['pendingSeptemberCard'] as Map))
          : null,
      piStolenCount: json['piStolenCount'] as int? ?? 0,
      piStolenFromPlayers: _parsePiStolenFromPlayers(json),
      player1ItemEffects: json['player1ItemEffects'] != null
          ? ItemEffects.fromJson(Map<String, dynamic>.from(json['player1ItemEffects'] as Map))
          : null,
      player2ItemEffects: json['player2ItemEffects'] != null
          ? ItemEffects.fromJson(Map<String, dynamic>.from(json['player2ItemEffects'] as Map))
          : null,
      player3ItemEffects: json['player3ItemEffects'] != null
          ? ItemEffects.fromJson(Map<String, dynamic>.from(json['player3ItemEffects'] as Map))
          : null,
      lastItemUsed: json['lastItemUsed'] as String?,
      lastItemUsedBy: json['lastItemUsedBy'] as String?,
      lastItemUsedAt: json['lastItemUsedAt'] as int?,
      player1Uid: json['player1Uid'] as String?,
      player2Uid: json['player2Uid'] as String?,
    );
  }

  static List<CardData> _parseCardList(dynamic list) {
    if (list == null) return [];
    return (list as List)
        .map((e) => CardData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 피를 뺏긴 플레이어 목록 파싱 (하위 호환성 지원)
  static List<String> _parsePiStolenFromPlayers(Map<String, dynamic> json) {
    // 새 형식: piStolenFromPlayers (List<String>)
    if (json['piStolenFromPlayers'] != null) {
      return List<String>.from(json['piStolenFromPlayers'] as List);
    }
    // 하위 호환: piStolenFromPlayer (String?) → 리스트로 변환
    final oldValue = json['piStolenFromPlayer'] as String?;
    if (oldValue != null) {
      return [oldValue];
    }
    return [];
  }

  GameState copyWith({
    String? turn,
    List<CardData>? deck,
    List<CardData>? floorCards,
    List<CardData>? player1Hand,
    List<CardData>? player2Hand,
    List<CardData>? player3Hand,
    CapturedCards? player1Captured,
    CapturedCards? player2Captured,
    CapturedCards? player3Captured,
    ScoreInfo? scores,
    GameMode? gameMode,
    List<String>? turnOrder,
    int? currentTurnIndex,
    SpecialEvent? lastEvent,
    String? lastEventPlayer,
    int? lastEventAt,
    List<CardData>? pukCards,
    String? pukOwner,
    GameEndState? endState,
    String? winner,
    int? finalScore,
    bool? isGobak,
    bool? waitingForGoStop,
    String? goStopPlayer,
    List<CardData>? shakeCards,
    String? shakePlayer,
    List<CardData>? bombCards,
    String? bombPlayer,
    CardData? bombTargetCard,
    List<CardData>? meongTtaCards,
    String? meongTtaPlayer,
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
    bool? waitingForSeptemberChoice,
    String? septemberChoicePlayer,
    CardData? pendingSeptemberCard,
    int? piStolenCount,
    List<String>? piStolenFromPlayers,
    ItemEffects? player1ItemEffects,
    ItemEffects? player2ItemEffects,
    ItemEffects? player3ItemEffects,
    String? lastItemUsed,
    String? lastItemUsedBy,
    int? lastItemUsedAt,
    String? player1Uid,
    String? player2Uid,
    bool clearLastEventPlayer = false,
    bool clearPiStolenFromPlayers = false,
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
    bool clearBombPlayer = false,
    bool clearBombTargetCard = false,
    bool clearMeongTtaPlayer = false,
    bool clearSeptemberChoicePlayer = false,
    bool clearPendingSeptemberCard = false,
    bool clearLastItemUsed = false,
    bool clearLastItemUsedBy = false,
  }) {
    return GameState(
      turn: turn ?? this.turn,
      deck: deck ?? this.deck,
      floorCards: floorCards ?? this.floorCards,
      player1Hand: player1Hand ?? this.player1Hand,
      player2Hand: player2Hand ?? this.player2Hand,
      player3Hand: player3Hand ?? this.player3Hand,
      player1Captured: player1Captured ?? this.player1Captured,
      player2Captured: player2Captured ?? this.player2Captured,
      player3Captured: player3Captured ?? this.player3Captured,
      scores: scores ?? this.scores,
      gameMode: gameMode ?? this.gameMode,
      turnOrder: turnOrder ?? this.turnOrder,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      lastEvent: lastEvent ?? this.lastEvent,
      lastEventPlayer: clearLastEventPlayer ? null : (lastEventPlayer ?? this.lastEventPlayer),
      lastEventAt: lastEventAt ?? this.lastEventAt,
      pukCards: pukCards ?? this.pukCards,
      pukOwner: clearPukOwner ? null : (pukOwner ?? this.pukOwner),
      endState: endState ?? this.endState,
      winner: clearWinner ? null : (winner ?? this.winner),
      finalScore: finalScore ?? this.finalScore,
      isGobak: isGobak ?? this.isGobak,
      waitingForGoStop: waitingForGoStop ?? this.waitingForGoStop,
      goStopPlayer: clearGoStopPlayer ? null : (goStopPlayer ?? this.goStopPlayer),
      shakeCards: shakeCards ?? this.shakeCards,
      shakePlayer: clearShakePlayer ? null : (shakePlayer ?? this.shakePlayer),
      bombCards: bombCards ?? this.bombCards,
      bombPlayer: clearBombPlayer ? null : (bombPlayer ?? this.bombPlayer),
      bombTargetCard: clearBombTargetCard ? null : (bombTargetCard ?? this.bombTargetCard),
      meongTtaCards: meongTtaCards ?? this.meongTtaCards,
      meongTtaPlayer: clearMeongTtaPlayer ? null : (meongTtaPlayer ?? this.meongTtaPlayer),
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
      waitingForSeptemberChoice: waitingForSeptemberChoice ?? this.waitingForSeptemberChoice,
      septemberChoicePlayer: clearSeptemberChoicePlayer ? null : (septemberChoicePlayer ?? this.septemberChoicePlayer),
      pendingSeptemberCard: clearPendingSeptemberCard ? null : (pendingSeptemberCard ?? this.pendingSeptemberCard),
      piStolenCount: piStolenCount ?? this.piStolenCount,
      piStolenFromPlayers: clearPiStolenFromPlayers ? const [] : (piStolenFromPlayers ?? this.piStolenFromPlayers),
      player1ItemEffects: player1ItemEffects ?? this.player1ItemEffects,
      player2ItemEffects: player2ItemEffects ?? this.player2ItemEffects,
      player3ItemEffects: player3ItemEffects ?? this.player3ItemEffects,
      lastItemUsed: clearLastItemUsed ? null : (lastItemUsed ?? this.lastItemUsed),
      lastItemUsedBy: clearLastItemUsedBy ? null : (lastItemUsedBy ?? this.lastItemUsedBy),
      lastItemUsedAt: clearLastItemUsed ? null : (lastItemUsedAt ?? this.lastItemUsedAt),
      player1Uid: player1Uid ?? this.player1Uid,
      player2Uid: player2Uid ?? this.player2Uid,
    );
  }

  /// 바닥 카드 가져오기 (getter)
  List<CardData> get floor => floorCards;
}

/// 게임 방 전체 데이터 모델
class GameRoom {
  final String roomId;
  final GameMode gameMode;      // 게임 모드 (맞고/고스톱)
  final PlayerInfo host;        // 방장 (player1)
  final PlayerInfo? guest;      // 게스트1 (player2) - 맞고/고스톱 공용
  final PlayerInfo? guest2;     // 게스트2 (player3) - 고스톱 전용
  final RoomState state;
  final GameState? gameState;
  final int createdAt;
  final bool hostRematchRequest;    // 방장 재대결 요청
  final bool guestRematchRequest;   // 게스트1 재대결 요청
  final bool guest2RematchRequest;  // 게스트2 재대결 요청 (고스톱)
  final bool gwangkkiModeActive;    // 光끼 모드 활성화 여부
  final String? gwangkkiActivator;  // 光끼 모드 발동자 UID
  final int gameCount;              // 게임 횟수 (첫 게임=0, 재대결=1,2,3...)
  final String? lastWinner;         // 마지막 게임 승자 UID (재대결 시 선공 결정용)
  final String? leftPlayer;         // 게임 중 나간 플레이어 UID
  final int? leftAt;                // 나간 시간 (timestamp)
  final int? betAmount;             // 판돈

  const GameRoom({
    required this.roomId,
    this.gameMode = GameMode.matgo,
    required this.host,
    this.guest,
    this.guest2,
    this.state = RoomState.waiting,
    this.gameState,
    required this.createdAt,
    this.hostRematchRequest = false,
    this.guestRematchRequest = false,
    this.guest2RematchRequest = false,
    this.gwangkkiModeActive = false,
    this.gwangkkiActivator,
    this.gameCount = 0,
    this.lastWinner,
    this.leftPlayer,
    this.leftAt,
    this.betAmount,
  });

  /// 현재 입장한 플레이어 수
  int get currentPlayerCount {
    int count = 1; // 호스트
    if (guest != null) count++;
    if (guest2 != null) count++;
    return count;
  }

  /// 게임 시작 가능 여부 (필요 인원 충족)
  bool get canStartGame => currentPlayerCount >= gameMode.playerCount;

  /// 양쪽 모두 재대결 요청했는지
  bool get bothWantRematch {
    if (gameMode == GameMode.matgo) {
      return hostRematchRequest && guestRematchRequest;
    } else {
      // 고스톱: 3명 모두 동의
      return hostRematchRequest && guestRematchRequest && guest2RematchRequest;
    }
  }

  /// 방이 가득 찼는지
  bool get isFull => currentPlayerCount >= gameMode.playerCount;

  /// 주어진 uid가 방장인지
  bool isHost(String uid) => host.uid == uid;

  /// 주어진 uid가 게스트1인지
  bool isGuest(String uid) => guest?.uid == uid;

  /// 주어진 uid가 게스트2인지
  bool isGuest2(String uid) => guest2?.uid == uid;

  /// 주어진 uid의 플레이어 번호 반환 (1, 2, 3)
  int getPlayerNumber(String uid) {
    if (host.uid == uid) return 1;
    if (guest?.uid == uid) return 2;
    if (guest2?.uid == uid) return 3;
    return 0;
  }

  /// 플레이어 UID 목록 반환 (턴 순환에 사용)
  List<String> get playerUids {
    final uids = <String>[host.uid];
    if (guest != null) uids.add(guest!.uid);
    if (guest2 != null) uids.add(guest2!.uid);
    return uids;
  }

  /// 플레이어 정보 목록 반환
  List<PlayerInfo> get allPlayers {
    final players = <PlayerInfo>[host];
    if (guest != null) players.add(guest!);
    if (guest2 != null) players.add(guest2!);
    return players;
  }

  /// uid로 플레이어 정보 가져오기
  PlayerInfo? getPlayerByUid(String uid) {
    if (host.uid == uid) return host;
    if (guest?.uid == uid) return guest;
    if (guest2?.uid == uid) return guest2;
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'gameMode': gameMode.name,
      'host': host.toJson(),
      'guest': guest?.toJson(),
      'guest2': guest2?.toJson(),
      'state': state.name,
      'gameState': gameState?.toJson(),
      'createdAt': createdAt,
      'hostRematchRequest': hostRematchRequest,
      'guestRematchRequest': guestRematchRequest,
      'guest2RematchRequest': guest2RematchRequest,
      'gwangkkiModeActive': gwangkkiModeActive,
      'gwangkkiActivator': gwangkkiActivator,
      'gameCount': gameCount,
      'lastWinner': lastWinner,
      'leftPlayer': leftPlayer,
      'leftAt': leftAt,
      'betAmount': betAmount,
    };
  }

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      roomId: json['roomId'] as String,
      gameMode: GameMode.values.firstWhere(
        (e) => e.name == json['gameMode'],
        orElse: () => GameMode.matgo,
      ),
      host: PlayerInfo.fromJson(
        Map<String, dynamic>.from(json['host'] as Map),
      ),
      guest: json['guest'] != null
          ? PlayerInfo.fromJson(
              Map<String, dynamic>.from(json['guest'] as Map),
            )
          : null,
      guest2: json['guest2'] != null
          ? PlayerInfo.fromJson(
              Map<String, dynamic>.from(json['guest2'] as Map),
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
      guest2RematchRequest: json['guest2RematchRequest'] as bool? ?? false,
      gwangkkiModeActive: json['gwangkkiModeActive'] as bool? ?? false,
      gwangkkiActivator: json['gwangkkiActivator'] as String?,
      gameCount: json['gameCount'] as int? ?? 0,
      lastWinner: json['lastWinner'] as String?,
      leftPlayer: json['leftPlayer'] as String?,
      leftAt: json['leftAt'] as int?,
      betAmount: json['betAmount'] as int?,
    );
  }

  GameRoom copyWith({
    String? roomId,
    GameMode? gameMode,
    PlayerInfo? host,
    PlayerInfo? guest,
    PlayerInfo? guest2,
    RoomState? state,
    GameState? gameState,
    int? createdAt,
    bool? hostRematchRequest,
    bool? guestRematchRequest,
    bool? guest2RematchRequest,
    bool? gwangkkiModeActive,
    String? gwangkkiActivator,
    int? gameCount,
    String? lastWinner,
    String? leftPlayer,
    int? leftAt,
    int? betAmount,
    bool clearGuest = false,
    bool clearGuest2 = false,
    bool clearGameState = false,
    bool clearGwangkkiActivator = false,
    bool clearLastWinner = false,
    bool clearLeftPlayer = false,
  }) {
    return GameRoom(
      roomId: roomId ?? this.roomId,
      gameMode: gameMode ?? this.gameMode,
      host: host ?? this.host,
      guest: clearGuest ? null : (guest ?? this.guest),
      guest2: clearGuest2 ? null : (guest2 ?? this.guest2),
      state: state ?? this.state,
      gameState: clearGameState ? null : (gameState ?? this.gameState),
      createdAt: createdAt ?? this.createdAt,
      hostRematchRequest: hostRematchRequest ?? this.hostRematchRequest,
      guestRematchRequest: guestRematchRequest ?? this.guestRematchRequest,
      guest2RematchRequest: guest2RematchRequest ?? this.guest2RematchRequest,
      gwangkkiModeActive: gwangkkiModeActive ?? this.gwangkkiModeActive,
      gwangkkiActivator: clearGwangkkiActivator ? null : (gwangkkiActivator ?? this.gwangkkiActivator),
      gameCount: gameCount ?? this.gameCount,
      lastWinner: clearLastWinner ? null : (lastWinner ?? this.lastWinner),
      leftPlayer: clearLeftPlayer ? null : (leftPlayer ?? this.leftPlayer),
      leftAt: clearLeftPlayer ? null : (leftAt ?? this.leftAt),
      betAmount: betAmount ?? this.betAmount,
    );
  }
}
