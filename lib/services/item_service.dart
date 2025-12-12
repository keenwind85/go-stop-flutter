import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_data.dart';
import '../models/game_room.dart';
import '../models/card_data.dart';
import '../models/captured_cards.dart';

/// ItemService 인스턴스 Provider
final itemServiceProvider = Provider<ItemService>((ref) {
  return ItemService();
});

/// 아이템 시스템을 처리하는 서비스 클래스
class ItemService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final Random _random = Random();

  // ==================== 상수 정의 ====================

  /// 하루에 상점에 표시되는 아이템 수
  static const int dailyShopItemCount = 3;

  // ==================== 헬퍼 함수 ====================

  /// 오늘 날짜 문자열 반환 (yyyy-MM-dd)
  String getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Firebase에서 반환된 중첩 맵을 안전하게 Map<String, dynamic>으로 변환
  static Map<String, dynamic>? _toStringDynamicMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  // ==================== 상점 관련 ====================

  /// 오늘의 상점 아이템 가져오기 (필요시 리셋)
  Future<List<ItemType>> getTodayShopItems() async {
    print('[ItemService] getTodayShopItems called');
    await resetShopIfNeeded();

    final snapshot = await _db.child('global/item_shop').get();
    print('[ItemService] global/item_shop snapshot exists: ${snapshot.exists}');

    if (!snapshot.exists) {
      // 상점 데이터가 없으면 새로 생성
      print('[ItemService] Creating new shop items...');
      return await _createNewShopItems();
    }

    final data = _toStringDynamicMap(snapshot.value);
    print('[ItemService] Shop data: $data');
    final shopItems = ShopItems.fromJson(data);
    print('[ItemService] Parsed shop items: ${shopItems.todayItems}');
    return shopItems.todayItems;
  }

  /// 상점 리셋 필요 여부 확인 및 리셋
  Future<void> resetShopIfNeeded() async {
    final snapshot = await _db.child('global/item_shop').get();
    final today = getTodayString();

    if (!snapshot.exists) {
      await _createNewShopItems();
      return;
    }

    final data = _toStringDynamicMap(snapshot.value);
    final shopItems = ShopItems.fromJson(data);

    // 날짜가 다르면 리셋
    if (!shopItems.lastReset.startsWith(today)) {
      await _createNewShopItems();
    }
  }

  /// 새 상점 아이템 생성
  Future<List<ItemType>> _createNewShopItems() async {
    final allItems = ItemType.values.toList()..shuffle(_random);
    final todayItems = allItems.take(dailyShopItemCount).toList();

    final shopItems = ShopItems(
      todayItems: todayItems,
      lastReset: DateTime.now().toIso8601String(),
    );

    await _db.child('global/item_shop').set(shopItems.toJson());
    return todayItems;
  }

  /// 상점 아이템 스트림
  Stream<List<ItemType>> getShopItemsStream() {
    return _db.child('global/item_shop').onValue.map((event) {
      if (!event.snapshot.exists) return <ItemType>[];
      final data = _toStringDynamicMap(event.snapshot.value);
      final shopItems = ShopItems.fromJson(data);
      return shopItems.todayItems;
    });
  }

  // ==================== 인벤토리 관련 ====================

  /// 사용자 인벤토리 가져오기
  Future<UserInventory> getUserInventory(String uid) async {
    print('[ItemService] getUserInventory called for uid: $uid');
    final snapshot = await _db.child('users/$uid/items').get();
    print('[ItemService] users/$uid/items snapshot exists: ${snapshot.exists}');
    if (!snapshot.exists) {
      print('[ItemService] No inventory found, returning empty');
      return const UserInventory();
    }
    final data = _toStringDynamicMap(snapshot.value);
    print('[ItemService] Inventory data: $data');
    return UserInventory.fromJson(data);
  }

  /// 사용자 인벤토리 스트림
  Stream<UserInventory> getUserInventoryStream(String uid) {
    return _db.child('users/$uid/items').onValue.map((event) {
      if (!event.snapshot.exists) return const UserInventory();
      final data = _toStringDynamicMap(event.snapshot.value);
      return UserInventory.fromJson(data);
    });
  }

  /// 아이템 보유 여부 확인
  Future<bool> hasItem(String uid, ItemType type) async {
    final inventory = await getUserInventory(uid);
    return inventory.hasItem(type);
  }

  // ==================== 구매 관련 ====================

  /// 아이템 구매 가능 여부 확인
  Future<({bool canPurchase, String reason})> canPurchaseItem(
    String uid,
    ItemType type,
  ) async {
    final itemData = ItemData.getItem(type);
    final today = getTodayString();

    // 1. 코인 확인
    final walletSnapshot = await _db.child('users/$uid/wallet/coin').get();
    final coin = (walletSnapshot.value as int?) ?? 0;
    if (coin < itemData.price) {
      return (canPurchase: false, reason: '코인이 부족합니다');
    }

    // 2. 인벤토리 확인
    final inventory = await getUserInventory(uid);

    // 이미 보유 중인지 확인
    if (inventory.hasItem(type)) {
      return (canPurchase: false, reason: '이미 보유 중인 아이템입니다');
    }

    // 오늘 이미 구매했는지 확인
    if (inventory.hasPurchasedToday(type, today)) {
      return (canPurchase: false, reason: '오늘 이미 구매한 아이템입니다');
    }

    return (canPurchase: true, reason: '');
  }

  /// 아이템 구매
  Future<({bool success, String message})> purchaseItem(
    String uid,
    ItemType type,
  ) async {
    final checkResult = await canPurchaseItem(uid, type);
    if (!checkResult.canPurchase) {
      return (success: false, message: checkResult.reason);
    }

    final itemData = ItemData.getItem(type);
    final today = getTodayString();

    try {
      // 개별 업데이트로 처리 (트랜잭션 대신)
      // 1. 코인 차감
      final walletRef = _db.child('users/$uid/wallet');
      final walletSnapshot = await walletRef.get();
      final walletData = _toStringDynamicMap(walletSnapshot.value) ?? {};
      final currentCoin = (walletData['coin'] as int?) ?? 0;

      if (currentCoin < itemData.price) {
        return (success: false, message: '코인이 부족합니다');
      }

      // 2. 인벤토리 확인
      final itemsRef = _db.child('users/$uid/items');
      final itemsSnapshot = await itemsRef.get();
      final itemsData = _toStringDynamicMap(itemsSnapshot.value) ?? {};
      final itemsInventory = _toStringDynamicMap(itemsData['items']) ?? {};
      final currentCount = (itemsInventory[type.name] as int?) ?? 0;

      if (currentCount >= 1) {
        return (success: false, message: '이미 보유 중인 아이템입니다');
      }

      // 3. 코인 차감
      await walletRef.update({'coin': currentCoin - itemData.price});

      // 4. 아이템 추가
      await _db.child('users/$uid/items/items/${type.name}').set(1);

      // 5. 일일 구매 기록 업데이트
      final lastPurchaseDate = itemsData['lastPurchaseDate'] as String? ?? '';
      List<String> dailyPurchases;

      if (lastPurchaseDate == today) {
        final existingPurchases = itemsData['dailyPurchases'] as List<dynamic>? ?? [];
        dailyPurchases = existingPurchases.map((e) => e.toString()).toList();
      } else {
        dailyPurchases = [];
      }
      dailyPurchases.add(type.name);

      await itemsRef.update({
        'dailyPurchases': dailyPurchases,
        'lastPurchaseDate': today,
      });

      return (success: true, message: '${itemData.name}을(를) 구매했습니다!');
    } catch (e) {
      return (success: false, message: '구매 중 오류가 발생했습니다: $e');
    }
  }

  // ==================== 아이템 사용 관련 ====================

  /// 아이템 사용
  Future<({bool success, String message, GameState? newState})> useItem({
    required String roomId,
    required String playerUid,
    required String opponentUid,
    required ItemType type,
    required int playerNumber,
    required GameState currentState,
  }) async {
    final itemData = ItemData.getItem(type);

    // 1. 아이템 보유 확인
    final hasItemResult = await hasItem(playerUid, type);
    if (!hasItemResult) {
      return (
        success: false,
        message: '해당 아이템을 보유하고 있지 않습니다',
        newState: null,
      );
    }

    // 2. 이미 사용했는지 확인
    final effects = playerNumber == 1
        ? currentState.player1ItemEffects
        : currentState.player2ItemEffects;
    if (effects?.usedItem != null) {
      return (
        success: false,
        message: '이번 게임에서 이미 아이템을 사용했습니다',
        newState: null,
      );
    }

    // 3. 사용 조건 확인
    if (!itemData.canUse(currentState, playerUid)) {
      return (
        success: false,
        message: '현재 상황에서 사용할 수 없는 아이템입니다',
        newState: null,
      );
    }

    // 4. 아이템 효과 적용
    final newState = _applyItemEffect(
      type: type,
      state: currentState,
      playerUid: playerUid,
      opponentUid: opponentUid,
      playerNumber: playerNumber,
    );

    // 4-1. 光끼의 물약인 경우 게이지 즉시 100으로 설정
    if (type == ItemType.gwangkkiPotion) {
      await setGwangkkiGaugeFull(playerUid);
    }

    // 5. 인벤토리에서 아이템 제거
    await _removeItemFromInventory(playerUid, type);

    // 6. GameState를 Firebase에 저장
    await _db.child('rooms/$roomId/gameState').set(newState.toJson());

    return (
      success: true,
      message: '${itemData.name}을(를) 사용했습니다!',
      newState: newState,
    );
  }

  /// 아이템 효과 적용
  GameState _applyItemEffect({
    required ItemType type,
    required GameState state,
    required String playerUid,
    required String opponentUid,
    required int playerNumber,
  }) {
    final isPlayer1 = playerNumber == 1;

    // 현재 플레이어의 효과 상태 가져오기
    final myEffects = isPlayer1
        ? (state.player1ItemEffects ?? const ItemEffects())
        : (state.player2ItemEffects ?? const ItemEffects());

    // 상대방 효과 상태 가져오기
    final opponentEffects = isPlayer1
        ? (state.player2ItemEffects ?? const ItemEffects())
        : (state.player1ItemEffects ?? const ItemEffects());

    GameState newState = state;

    switch (type) {
      case ItemType.gwangkkiPotion:
        // 光끼 게이지를 100으로 설정하는 것은 CoinService에서 별도 처리 필요
        // 여기서는 사용 기록만 남김
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(usedItem: type.name),
        );
        break;

      case ItemType.forceGo:
        // 상대방 Go만 가능하도록 설정
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(usedItem: type.name),
        );
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: isPlayer1 ? 2 : 1,
          effects: opponentEffects.copyWith(forceGoOnly: true),
        );
        break;

      case ItemType.forceStop:
        // 상대방 Stop만 가능하도록 설정
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(usedItem: type.name),
        );
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: isPlayer1 ? 2 : 1,
          effects: opponentEffects.copyWith(forceStopOnly: true),
        );
        break;

      case ItemType.swapHands:
        // 손패 교환
        newState = newState.copyWith(
          player1Hand: state.player2Hand,
          player2Hand: state.player1Hand,
        );
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(usedItem: type.name),
        );
        break;

      case ItemType.stealFromDeck:
        // 더미패에서 1장 몰래 가져오기
        if (state.deck.isNotEmpty) {
          final randomIndex = _random.nextInt(state.deck.length);
          final stolenCard = state.deck[randomIndex];
          final newDeck = List<CardData>.from(state.deck)..removeAt(randomIndex);

          if (isPlayer1) {
            final newHand = List<CardData>.from(state.player1Hand)..add(stolenCard);
            newState = newState.copyWith(
              deck: newDeck,
              player1Hand: newHand,
            );
          } else {
            final newHand = List<CardData>.from(state.player2Hand)..add(stolenCard);
            newState = newState.copyWith(
              deck: newDeck,
              player2Hand: newHand,
            );
          }
        }
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(usedItem: type.name),
        );
        break;

      case ItemType.replaceHand:
        // 손패 전체를 더미패 랜덤 카드로 교체
        final handCount = isPlayer1
            ? state.player1Hand.length
            : state.player2Hand.length;
        final currentHand = isPlayer1 ? state.player1Hand : state.player2Hand;

        if (state.deck.length >= handCount) {
          final deckCopy = List<CardData>.from(state.deck)..shuffle(_random);
          final newHand = deckCopy.take(handCount).toList();
          final newDeck = deckCopy.skip(handCount).toList()..addAll(currentHand);
          newDeck.shuffle(_random);

          if (isPlayer1) {
            newState = newState.copyWith(
              deck: newDeck,
              player1Hand: newHand,
            );
          } else {
            newState = newState.copyWith(
              deck: newDeck,
              player2Hand: newHand,
            );
          }
        }
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(usedItem: type.name),
        );
        break;

      case ItemType.replaceFloor:
        // 바닥패 전체를 더미패 랜덤 카드로 교체
        final floorCount = state.floor.length;
        if (state.deck.length >= floorCount) {
          final deckCopy = List<CardData>.from(state.deck)..shuffle(_random);
          final newFloorCards = deckCopy.take(floorCount).toList();
          final newDeck = deckCopy.skip(floorCount).toList()..addAll(state.floor);
          newDeck.shuffle(_random);

          // 새 바닥패에서 보너스 카드 분리 (아이템 사용자가 자동 획득)
          final bonusCards = newFloorCards.where((c) => c.isBonus).toList();
          final normalFloorCards = newFloorCards.where((c) => !c.isBonus).toList();

          // 보너스 카드가 있으면 아이템 사용자의 획득 패에 추가
          CapturedCards updatedCaptured;
          if (isPlayer1) {
            updatedCaptured = state.player1Captured.addCards(bonusCards);
            newState = newState.copyWith(
              deck: newDeck,
              floorCards: normalFloorCards,
              player1Captured: updatedCaptured,
            );
          } else {
            updatedCaptured = state.player2Captured.addCards(bonusCards);
            newState = newState.copyWith(
              deck: newDeck,
              floorCards: normalFloorCards,
              player2Captured: updatedCaptured,
            );
          }
        }
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(usedItem: type.name),
        );
        break;

      case ItemType.gwangPriority:
        // 3턴간 광 우선 출현
        newState = _updatePlayerEffects(
          state: newState,
          playerNumber: playerNumber,
          effects: myEffects.copyWith(
            usedItem: type.name,
            gwangPriorityTurns: 3,
          ),
        );
        break;
    }

    // 아이템 사용 이벤트 기록 (타임스탬프 포함으로 동기화 보장)
    newState = newState.copyWith(
      lastItemUsed: type.name,
      lastItemUsedBy: playerUid,
      lastItemUsedAt: DateTime.now().millisecondsSinceEpoch,
    );

    return newState;
  }

  /// 플레이어 효과 업데이트 헬퍼
  GameState _updatePlayerEffects({
    required GameState state,
    required int playerNumber,
    required ItemEffects effects,
  }) {
    if (playerNumber == 1) {
      return state.copyWith(player1ItemEffects: effects);
    } else {
      return state.copyWith(player2ItemEffects: effects);
    }
  }

  /// 인벤토리에서 아이템 제거
  Future<void> _removeItemFromInventory(String uid, ItemType type) async {
    final itemRef = _db.child('users/$uid/items/items/${type.name}');
    await itemRef.remove();
  }

  /// Go/Stop 강제 효과 해제 (Go/Stop 선택 후 호출)
  Future<void> clearForceGoStop({
    required String roomId,
    required int playerNumber,
    required GameState currentState,
  }) async {
    final effects = playerNumber == 1
        ? currentState.player1ItemEffects
        : currentState.player2ItemEffects;

    if (effects == null) return;

    final newEffects = effects.copyWith(
      forceGoOnly: false,
      forceStopOnly: false,
    );

    GameState newState;
    if (playerNumber == 1) {
      newState = currentState.copyWith(player1ItemEffects: newEffects);
    } else {
      newState = currentState.copyWith(player2ItemEffects: newEffects);
    }

    await _db.child('rooms/$roomId/gameState').set(newState.toJson());
  }

  /// 턴 종료 시 효과 감소 처리
  Future<GameState> onTurnEnd({
    required String roomId,
    required int playerNumber,
    required GameState currentState,
  }) async {
    final effects = playerNumber == 1
        ? currentState.player1ItemEffects
        : currentState.player2ItemEffects;

    if (effects == null) return currentState;

    final newEffects = effects.onTurnEnd();

    GameState newState;
    if (playerNumber == 1) {
      newState = currentState.copyWith(player1ItemEffects: newEffects);
    } else {
      newState = currentState.copyWith(player2ItemEffects: newEffects);
    }

    await _db.child('rooms/$roomId/gameState').set(newState.toJson());
    return newState;
  }

  /// 光의 기운 효과가 활성화된 경우 덱에서 광 카드 우선 선택
  CardData? getNextDeckCard(List<CardData> deck, int gwangPriorityTurns) {
    if (deck.isEmpty) return null;

    if (gwangPriorityTurns > 0) {
      // 덱에서 광 카드 찾기
      final gwangCardIndex = deck.indexWhere(
        (card) => card.type == CardType.kwang,
      );
      if (gwangCardIndex >= 0) {
        return deck[gwangCardIndex];
      }
    }
    return deck.first;
  }

  /// 光끼 게이지 즉시 100 설정 (CoinService와 연동)
  Future<void> setGwangkkiGaugeFull(String uid) async {
    await _db.child('users/$uid/wallet/gwangkki_score').set(100);
    debugPrint('[ItemService] 光끼 게이지 100으로 설정: $uid');
  }

  // ==================== 디버그 기능 ====================

  /// [DEBUG] 오늘의 아이템 강제 리셋 + 구매 내역 초기화
  Future<void> debugResetShopItems(String uid) async {
    // 1. 상점 아이템 새로 생성
    await _createNewShopItems();

    // 2. 해당 유저의 오늘 구매 내역 초기화
    await _db.child('users/$uid/items/dailyPurchases').remove();
    await _db.child('users/$uid/items/lastPurchaseDate').remove();

    print('[ItemService] DEBUG: Shop items reset and purchase history cleared for $uid');
  }

  /// [DEBUG] 코인 추가 (100코인 단위)
  Future<void> debugAddCoins(String uid, {int amount = 100}) async {
    final walletRef = _db.child('users/$uid/wallet');
    final walletSnapshot = await walletRef.get();
    final walletData = _toStringDynamicMap(walletSnapshot.value) ?? {};
    final currentCoin = (walletData['coin'] as int?) ?? 0;

    await walletRef.update({'coin': currentCoin + amount});

    print('[ItemService] DEBUG: Added $amount coins to $uid (new balance: ${currentCoin + amount})');
  }
}
