import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/game_room.dart';
import '../models/player_info.dart';
import 'coin_service.dart';

/// RoomService Provider
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

/// Firebase Realtime Database를 통한 방 관리 서비스
class RoomService {
  final DatabaseReference _roomsRef = FirebaseDatabase.instance.ref('rooms');
  final CoinService _coinService = CoinService();

  /// 방 만료 시간 (1시간)
  static const int roomExpirationMs = 60 * 60 * 1000;

  /// 새 방 생성 (호스트로 입장)
  /// [gameMode]: 게임 모드 (맞고: 2인, 고스톱: 3인)
  Future<GameRoom> createRoom({
    required String hostUid,
    required String hostName,
    GameMode gameMode = GameMode.matgo,
  }) async {
    final roomId = _generateRoomId();
    final now = DateTime.now().millisecondsSinceEpoch;

    final room = GameRoom(
      roomId: roomId,
      gameMode: gameMode,
      host: PlayerInfo(uid: hostUid, displayName: hostName),
      state: RoomState.waiting,
      createdAt: now,
    );

    await _roomsRef.child(roomId).set(room.toJson());
    debugPrint('[RoomService] Created ${gameMode.displayName} room: $roomId');

    return room;
  }

  /// 대기 중인 방 목록 조회 (유효하지 않은 방 자동 정리)
  Future<List<GameRoom>> getWaitingRooms() async {
    final snapshot = await _roomsRef
        .orderByChild('state')
        .equalTo('waiting')
        .get();

    if (!snapshot.exists) return [];

    final rooms = <GameRoom>[];
    final data = snapshot.value as Map<dynamic, dynamic>;
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleRoomIds = <String>[];

    for (final entry in data.entries) {
      try {
        final roomData = Map<String, dynamic>.from(entry.value as Map);
        final room = GameRoom.fromJson(roomData);

        // 유효성 검사: 호스트가 없거나 만료된 방
        final isExpired = (now - room.createdAt) > roomExpirationMs;
        final hasNoHost = room.host.uid.isEmpty;

        if (isExpired || hasNoHost) {
          staleRoomIds.add(room.roomId);
          debugPrint('[RoomService] Stale room detected: ${room.roomId} (expired: $isExpired, noHost: $hasNoHost)');
        } else {
          rooms.add(room);
        }
      } catch (e) {
        debugPrint('[RoomService] Error parsing room: $e');
        // 파싱 에러가 발생한 방도 삭제 대상
        staleRoomIds.add(entry.key.toString());
      }
    }

    // 유효하지 않은 방 삭제 (비동기로 처리)
    if (staleRoomIds.isNotEmpty) {
      _cleanupRooms(staleRoomIds);
    }

    // 최신 순으로 정렬
    rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rooms;
  }

  /// 유효하지 않은 방 일괄 삭제
  Future<void> _cleanupRooms(List<String> roomIds) async {
    for (final roomId in roomIds) {
      try {
        await _roomsRef.child(roomId).remove();
        debugPrint('[RoomService] Cleaned up stale room: $roomId');
      } catch (e) {
        debugPrint('[RoomService] Error cleaning up room $roomId: $e');
      }
    }
  }

  /// 특정 방 조회 (일회성 조회)
  Future<GameRoom?> getRoom(String roomId) async {
    try {
      final snapshot = await _roomsRef.child(roomId).get();
      if (!snapshot.exists) return null;
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return GameRoom.fromJson(data);
    } catch (e) {
      debugPrint('[RoomService] Error getting room $roomId: $e');
      return null;
    }
  }

  /// 모든 만료된 방 정리 (수동 호출용)
  Future<int> cleanupAllStaleRooms() async {
    final snapshot = await _roomsRef.get();
    if (!snapshot.exists) return 0;

    final data = snapshot.value as Map<dynamic, dynamic>;
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleRoomIds = <String>[];

    for (final entry in data.entries) {
      try {
        final roomData = Map<String, dynamic>.from(entry.value as Map);
        final room = GameRoom.fromJson(roomData);

        final isExpired = (now - room.createdAt) > roomExpirationMs;
        final isFinishedLongAgo = room.state == RoomState.finished &&
            (now - room.createdAt) > (10 * 60 * 1000); // 종료 후 10분

        if (isExpired || isFinishedLongAgo) {
          staleRoomIds.add(room.roomId);
        }
      } catch (e) {
        staleRoomIds.add(entry.key.toString());
      }
    }

    await _cleanupRooms(staleRoomIds);
    debugPrint('[RoomService] Cleaned up ${staleRoomIds.length} stale rooms');
    return staleRoomIds.length;
  }

  /// 특정 방에 게스트로 입장
  /// 맞고(2인): guest 슬롯에 입장
  /// 고스톱(3인): guest 슬롯이 비어있으면 guest로, 차 있으면 guest2로 입장
  Future<GameRoom?> joinRoom({
    required String roomId,
    required String guestUid,
    required String guestName,
  }) async {
    final roomRef = _roomsRef.child(roomId);

    try {
      // 먼저 방이 존재하는지 확인
      final snapshot = await roomRef.get();
      if (!snapshot.exists) {
        debugPrint('[RoomService] Room not found: $roomId');
        return null;
      }

      final roomData = Map<String, dynamic>.from(snapshot.value as Map);
      final room = GameRoom.fromJson(roomData);
      debugPrint('[RoomService] Room exists: $roomId, mode: ${room.gameMode.displayName}, state: ${room.state}');

      // 대기 상태가 아니면 실패
      if (room.state != RoomState.waiting) {
        debugPrint('[RoomService] Cannot join: room state is ${room.state}');
        return null;
      }

      // 방이 이미 가득 찼는지 확인
      if (room.isFull) {
        debugPrint('[RoomService] Cannot join: room is full');
        return null;
      }

      // 게스트 정보 생성
      final guestInfo = PlayerInfo(
        uid: guestUid,
        displayName: guestName,
      );

      // 입장 슬롯 결정
      final updates = <String, dynamic>{};

      if (room.guest == null) {
        // guest 슬롯이 비어있으면 guest로 입장
        updates['guest'] = guestInfo.toJson();
        debugPrint('[RoomService] Joining as guest (player2)');
      } else if (room.gameMode == GameMode.gostop && room.guest2 == null) {
        // 고스톱 모드이고 guest2 슬롯이 비어있으면 guest2로 입장
        updates['guest2'] = guestInfo.toJson();
        debugPrint('[RoomService] Joining as guest2 (player3)');
      } else {
        debugPrint('[RoomService] Cannot join: no available slot');
        return null;
      }

      await roomRef.update(updates);
      debugPrint('[RoomService] Joined room: $roomId');

      // 업데이트된 방 정보 반환
      final updatedSnapshot = await roomRef.get();
      final updatedData = Map<String, dynamic>.from(updatedSnapshot.value as Map);
      return GameRoom.fromJson(updatedData);
    } catch (e) {
      debugPrint('[RoomService] Error joining room: $e');
      return null;
    }
  }

  /// 방 상태를 playing으로 변경
  Future<void> startGame(String roomId) async {
    await _roomsRef.child(roomId).update({'state': 'playing'});
    debugPrint('[RoomService] Game started: $roomId');
  }

  /// 게임 상태 업데이트
  Future<void> updateGameState({
    required String roomId,
    required GameState gameState,
  }) async {
    await _roomsRef.child(roomId).child('gameState').set(gameState.toJson());
    debugPrint('[RoomService] Updated game state: $roomId');
  }

  /// 게임 상태를 Transaction으로 안전하게 업데이트
  Future<bool> updateGameStateWithTransaction({
    required String roomId,
    required GameState Function(GameState current) updater,
  }) async {
    final gameStateRef = _roomsRef.child(roomId).child('gameState');

    try {
      final result = await gameStateRef.runTransaction((data) {
        if (data == null) return Transaction.abort();

        try {
          final currentState = GameState.fromJson(
            Map<String, dynamic>.from(data as Map),
          );
          final newState = updater(currentState);

          return Transaction.success(newState.toJson());
        } catch (e) {
          debugPrint('[RoomService] Transaction updater error: $e');
          return Transaction.abort();
        }
      });

      return result.committed;
    } on StateError catch (e) {
      // Flutter Web에서 Firebase Transaction 중 발생하는 StateError 처리
      debugPrint('[RoomService] Transaction StateError (retrying with set): $e');
      
      // Transaction 실패 시 일반 set으로 대체 시도
      try {
        final snapshot = await gameStateRef.get();
        if (!snapshot.exists) return false;
        
        final currentState = GameState.fromJson(
          Map<String, dynamic>.from(snapshot.value as Map),
        );
        final newState = updater(currentState);
        await gameStateRef.set(newState.toJson());
        return true;
      } catch (fallbackError) {
        debugPrint('[RoomService] Fallback set also failed: $fallbackError');
        return false;
      }
    } catch (e) {
      debugPrint('[RoomService] Transaction failed: $e');
      return false;
    }
  }

  /// 방 실시간 구독
  Stream<GameRoom?> watchRoom(String roomId) {
    return _roomsRef.child(roomId).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return GameRoom.fromJson(data);
    });
  }

  /// 대기 중인 방 목록 실시간 구독
  Stream<List<GameRoom>> watchWaitingRooms() {
    return _roomsRef
        .orderByChild('state')
        .equalTo('waiting')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <GameRoom>[];

      final rooms = <GameRoom>[];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final entry in data.entries) {
        try {
          final roomData = Map<String, dynamic>.from(entry.value as Map);
          final room = GameRoom.fromJson(roomData);

          // 유효성 검사: 호스트가 없거나 만료된 방 제외
          final isExpired = (now - room.createdAt) > roomExpirationMs;
          final hasNoHost = room.host.uid.isEmpty;

          if (!isExpired && !hasNoHost) {
            rooms.add(room);
          }
        } catch (e) {
          debugPrint('[RoomService] Error parsing room in stream: $e');
        }
      }

      // 최신 순으로 정렬
      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rooms;
    });
  }

  /// 내가 나간 진행 중인 게임방 찾기 (복귀 가능한 방)
  Future<GameRoom?> findMyLeftGame(String myUid) async {
    try {
      // playing 상태이고 leftPlayer가 나인 방 찾기
      final snapshot = await _roomsRef
          .orderByChild('state')
          .equalTo('playing')
          .get();

      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      for (final entry in data.entries) {
        try {
          final roomData = Map<String, dynamic>.from(entry.value as Map);
          final room = GameRoom.fromJson(roomData);

          // 내가 나간 방이고, 게임이 아직 끝나지 않은 경우
          if (room.leftPlayer == myUid &&
              room.gameState?.endState == GameEndState.none) {
            debugPrint('[RoomService] Found my left game: ${room.roomId}');
            return room;
          }
        } catch (e) {
          debugPrint('[RoomService] Error parsing room: $e');
        }
      }

      return null;
    } catch (e) {
      debugPrint('[RoomService] Error finding left game: $e');
      return null;
    }
  }

  /// 방 나가기
  /// 게임 중인 경우 leftPlayer를 설정하고, 모든 플레이어가 나가면 방 삭제
  /// [playerSlot]: 플레이어 슬롯 (1=host, 2=guest, 3=guest2)
  Future<void> leaveRoom({
    required String roomId,
    required String playerId,
    required bool isHost,
    bool isGuest2 = false,
  }) async {
    // 먼저 현재 방 상태 확인
    final snapshot = await _roomsRef.child(roomId).get();
    if (!snapshot.exists) {
      debugPrint('[RoomService] Room not found: $roomId');
      return;
    }

    final roomData = Map<String, dynamic>.from(snapshot.value as Map);
    final room = GameRoom.fromJson(roomData);
    final state = room.state;
    final leftPlayer = room.leftPlayer;

    // 게임 중인 경우 (playing 상태)
    if (state == RoomState.playing) {
      // 이미 다른 플레이어가 나간 경우
      if (leftPlayer != null && leftPlayer != playerId) {
        // 3인 모드에서 아직 한 명 남아있을 수 있음
        if (room.gameMode == GameMode.gostop) {
          // 남은 플레이어 수 확인 (leftPlayer 제외)
          final remainingCount = room.currentPlayerCount - 1; // 나가려는 사람 제외
          if (remainingCount <= 1) {
            // 마지막 한 명만 남음 → 방 삭제
            await _roomsRef.child(roomId).remove();
            debugPrint('[RoomService] All players left during game, room deleted: $roomId');
            return;
          }
        } else {
          // 2인 모드: 양쪽 모두 나감 → 방 삭제
          await _roomsRef.child(roomId).remove();
          debugPrint('[RoomService] Both players left during game, room deleted: $roomId');
          return;
        }
      }

      // 첫 번째 플레이어가 나감 → leftPlayer 설정
      await _roomsRef.child(roomId).update({
        'leftPlayer': playerId,
        'leftAt': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[RoomService] Player left during game: $playerId (room: $roomId)');
      return;
    }

    // 대기 중이거나 게임 종료된 경우
    if (isHost) {
      // 호스트가 나가면 방 삭제
      await _roomsRef.child(roomId).remove();
      debugPrint('[RoomService] Room deleted: $roomId');
    } else if (isGuest2) {
      // guest2가 나가면 guest2 정보만 삭제
      await _roomsRef.child(roomId).update({
        'guest2': null,
        'state': 'waiting',
        'gameState': null,
        'leftPlayer': null,
        'leftAt': null,
        'guest2RematchRequest': false,
      });
      debugPrint('[RoomService] Guest2 left room: $roomId');
    } else {
      // guest가 나가면 guest 정보만 삭제
      await _roomsRef.child(roomId).update({
        'guest': null,
        'state': 'waiting',
        'gameState': null,
        'leftPlayer': null,
        'leftAt': null,
        'guestRematchRequest': false,
      });
      debugPrint('[RoomService] Guest left room: $roomId');
    }
  }

  /// 게임방으로 복귀 (나갔던 플레이어)
  Future<bool> rejoinRoom({
    required String roomId,
    required String playerId,
  }) async {
    final snapshot = await _roomsRef.child(roomId).get();
    if (!snapshot.exists) {
      debugPrint('[RoomService] Room not found for rejoin: $roomId');
      return false;
    }

    final roomData = Map<String, dynamic>.from(snapshot.value as Map);
    final leftPlayer = roomData['leftPlayer'] as String?;
    final state = roomData['state'] as String?;

    // 게임이 진행 중이고, 나갔던 플레이어가 복귀하는 경우
    if (state == 'playing' && leftPlayer == playerId) {
      await _roomsRef.child(roomId).update({
        'leftPlayer': null,
        'leftAt': null,
      });
      debugPrint('[RoomService] Player rejoined: $playerId (room: $roomId)');
      return true;
    }

    debugPrint('[RoomService] Cannot rejoin - state: $state, leftPlayer: $leftPlayer, playerId: $playerId');
    return false;
  }

  /// 방 삭제
  Future<void> deleteRoom(String roomId) async {
    await _roomsRef.child(roomId).remove();
    debugPrint('[RoomService] Deleted room: $roomId');
  }

  /// 재대결 투표
  /// [playerSlot]: 플레이어 슬롯 (1=host, 2=guest, 3=guest2)
  Future<void> voteRematch({
    required String roomId,
    required bool isHost,
    required String vote, // 'agree' | 'disagree'
    bool isGuest2 = false,
  }) async {
    String field;
    if (isHost) {
      field = 'hostRematchRequest';
    } else if (isGuest2) {
      field = 'guest2RematchRequest';
    } else {
      field = 'guestRematchRequest';
    }

    final value = vote == 'agree';
    await _roomsRef.child(roomId).update({field: value});

    final playerName = isHost ? 'host' : (isGuest2 ? 'guest2' : 'guest');
    debugPrint('[RoomService] Rematch vote: $roomId by $playerName = $vote');
  }

  /// 재대결 투표 상태 확인
  Future<({String? hostVote, String? guestVote})> getRematchVotes(String roomId) async {
    final snapshot = await _roomsRef.child(roomId).child('rematch_vote').get();
    if (!snapshot.exists) {
      return (hostVote: null, guestVote: null);
    }
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return (
      hostVote: data['host'] as String?,
      guestVote: data['guest'] as String?,
    );
  }

  /// 재대결 투표 초기화
  Future<void> clearRematchVotes(String roomId) async {
    await _roomsRef.child(roomId).child('rematch_vote').remove();
    debugPrint('[RoomService] Rematch votes cleared: $roomId');
  }

  /// 재대결 시작 (게임 상태 초기화)
  Future<void> startRematch({
    required String roomId,
    String? lastWinner,
    int? currentGameCount,
  }) async {
    final updates = <String, dynamic>{
      'state': 'waiting',
      'gameState': null,
      'hostRematchRequest': false,
      'guestRematchRequest': false,
      'guest2RematchRequest': false, // 3인 모드 지원
    };

    // lastWinner가 제공되면 저장
    if (lastWinner != null) {
      updates['lastWinner'] = lastWinner;
    }

    // gameCount 증가 (제공되면 +1, 아니면 1로 설정)
    updates['gameCount'] = (currentGameCount ?? 0) + 1;

    await _roomsRef.child(roomId).update(updates);
    debugPrint('[RoomService] Rematch started: $roomId, gameCount: ${updates['gameCount']}, lastWinner: $lastWinner');
  }

  /// 게임 종료 및 코인 정산
  ///
  /// [coinMultiplier]: 코인 정산 배수 (기본 1)
  /// [isGwangBak]: 광박 여부 (패자 광 0장)
  /// [isPiBak]: 피박 여부 (패자 피 7장 이하)
  /// [isGobak]: 고박 여부 (패자가 1고+ 상태에서 역전패)
  Future<({bool success, int transferAmount, String message})> settleGameResult({
    required String roomId,
    required String winnerUid,
    required String loserUid,
    required int points,
    int coinMultiplier = 1,
    bool isGwangBak = false,
    bool isPiBak = false,
    bool isGobak = false,
    bool isAllIn = false,
  }) async {
    try {
      final result = await _coinService.settleGame(
        winnerUid: winnerUid,
        loserUid: loserUid,
        points: points,
        coinMultiplier: coinMultiplier,
        isGwangBak: isGwangBak,
        isPiBak: isPiBak,
        isGobak: isGobak,
        isAllIn: isAllIn,
      );

      final transferAmount = result.actualTransfer;

      // 방 상태 업데이트
      await _roomsRef.child(roomId).update({
        'state': 'finished',
        'settlement': {
          'winner': winnerUid,
          'loser': loserUid,
          'points': points,
          'coinMultiplier': coinMultiplier,
          'isGwangBak': isGwangBak,
          'isPiBak': isPiBak,
          'isGobak': isGobak,
          'transferAmount': transferAmount,
          'isAllIn': isAllIn,
          'settledAt': DateTime.now().millisecondsSinceEpoch,
        },
      });

      debugPrint('[RoomService] Game settled: $winnerUid won $transferAmount coins (박: 광박=$isGwangBak, 피박=$isPiBak, 고박=$isGobak)');
      return (
        success: true,
        transferAmount: transferAmount,
        message: '정산 완료! ${winnerUid == loserUid ? "무승부" : "$transferAmount 코인 이동"}',
      );
    } catch (e) {
      debugPrint('[RoomService] Settlement error: $e');
      return (
        success: false,
        transferAmount: 0,
        message: '정산 중 오류가 발생했습니다.',
      );
    }
  }

  /// 재대결 요청 (기존 호환성 유지)
  @Deprecated('Use voteRematch instead')
  Future<void> requestRematch({
    required String roomId,
    required String playerId,
    required bool isHost,
  }) async {
    await voteRematch(roomId: roomId, isHost: isHost, vote: 'agree');
  }

  // ==================== 光끼 모드 ====================

  /// 光끼 모드 발동
  Future<void> activateGwangkkiMode({
    required String roomId,
    required String activatorUid,
  }) async {
    await _roomsRef.child(roomId).update({
      'gwangkkiModeActive': true,
      'gwangkkiActivator': activatorUid,
    });
    debugPrint('[RoomService] GwangKki mode activated by $activatorUid in room $roomId');
  }

  /// 光끼 모드 비활성화
  Future<void> deactivateGwangkkiMode(String roomId) async {
    await _roomsRef.child(roomId).update({
      'gwangkkiModeActive': false,
      'gwangkkiActivator': null,
    });
    debugPrint('[RoomService] GwangKki mode deactivated in room $roomId');
  }

  /// 4자리 방 ID 생성
  String _generateRoomId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var result = '';
    var seed = random;
    for (var i = 0; i < 4; i++) {
      result += chars[seed % chars.length];
      seed ~/= chars.length;
      seed += DateTime.now().microsecondsSinceEpoch;
    }
    return result;
  }
}
