import 'game_room.dart';
import 'card_data.dart';

/// 아이템 타입
enum ItemType {
  gwangkkiPotion,   // 光끼의 물약
  forceGo,          // 제발 Go만해!
  forceStop,        // 제발 Stop만해!
  swapHands,        // 우리 패 바꾸자!
  stealFromDeck,    // 밑장 빼기
  replaceHand,      // 손패 교체
  replaceFloor,     // 바닥패 교체
  gwangPriority,    // 光의 기운
}

/// 아이템 데이터 클래스
class ItemData {
  final ItemType type;
  final String name;
  final String shortDesc;
  final String description;
  final int price;
  final String iconEmoji;

  const ItemData({
    required this.type,
    required this.name,
    required this.shortDesc,
    required this.description,
    required this.price,
    required this.iconEmoji,
  });

  /// 모든 아이템 정의
  static const Map<ItemType, ItemData> allItems = {
    ItemType.gwangkkiPotion: ItemData(
      type: ItemType.gwangkkiPotion,
      name: '光끼의 물약',
      shortDesc: '光끼 게이지가 즉시 차오릅니다',
      description: '아이템 사용자의 光끼 게이지가 즉시 100으로 설정됩니다. 단, 光끼 모드가 이미 발동 중이거나 상대방 게이지가 이미 100인 경우 사용 불가합니다.',
      price: 50,
      iconEmoji: '🧪',
    ),
    ItemType.forceGo: ItemData(
      type: ItemType.forceGo,
      name: '제발 Go만해!',
      shortDesc: '상대방은 Go만 가능합니다',
      description: '아이템 공격을 당한 플레이어는 다음 Go/Stop 선택 시 Go만 선택 가능합니다.',
      price: 30,
      iconEmoji: '🏃',
    ),
    ItemType.forceStop: ItemData(
      type: ItemType.forceStop,
      name: '제발 Stop만해!',
      shortDesc: '상대방은 Stop만 가능합니다',
      description: '아이템 공격을 당한 플레이어는 다음 Go/Stop 선택 시 Stop만 선택 가능합니다.',
      price: 30,
      iconEmoji: '🛑',
    ),
    ItemType.swapHands: ItemData(
      type: ItemType.swapHands,
      name: '우리 패 바꾸자!',
      shortDesc: '플레이어의 손패를 교환합니다',
      description: '양 플레이어의 손패 전체를 서로 교환합니다.',
      price: 30,
      iconEmoji: '🔄',
    ),
    ItemType.stealFromDeck: ItemData(
      type: ItemType.stealFromDeck,
      name: '밑장 빼기',
      shortDesc: '더미패 1장을 몰래 가져갑니다',
      description: '아이템 사용자가 더미패에서 랜덤으로 1장을 몰래 자신의 손패에 추가합니다.',
      price: 20,
      iconEmoji: '🃏',
    ),
    ItemType.replaceHand: ItemData(
      type: ItemType.replaceHand,
      name: '손패 교체',
      shortDesc: '손패를 더미패로 교체합니다',
      description: '아이템 사용자의 손패 전체를 더미패의 랜덤 카드로 교체합니다. 더미패가 손패 개수보다 적으면 사용 불가합니다.',
      price: 20,
      iconEmoji: '🎴',
    ),
    ItemType.replaceFloor: ItemData(
      type: ItemType.replaceFloor,
      name: '바닥패 교체',
      shortDesc: '바닥패를 더미패로 교체합니다',
      description: '바닥패 전체를 더미패의 랜덤 카드로 교체합니다. 더미패가 바닥패 개수보다 적으면 사용 불가합니다.',
      price: 20,
      iconEmoji: '🌊',
    ),
    ItemType.gwangPriority: ItemData(
      type: ItemType.gwangPriority,
      name: '光의 기운',
      shortDesc: '광을 뽑을 확률이 증가합니다',
      description: '3턴간 더미패 뒤집기 시 덱에 광 카드가 있으면 광 카드가 최우선으로 나옵니다.',
      price: 20,
      iconEmoji: '✨',
    ),
  };

  /// 아이템 타입으로 아이템 데이터 가져오기
  static ItemData getItem(ItemType type) {
    return allItems[type]!;
  }

  /// 고스톱 모드에서 대상 선택이 필요한 아이템인지 확인
  static bool needsTargetSelection(ItemType type) {
    return type == ItemType.forceGo ||
        type == ItemType.forceStop ||
        type == ItemType.swapHands;
  }

  /// 아이템 사용 가능 여부 검사
  bool canUse(GameState state, String playerUid) {
    switch (type) {
      case ItemType.gwangkkiPotion:
        // 光끼 모드가 이미 발동 중이거나 상대 게이지가 100이면 사용 불가
        // (실제 게이지 값은 CoinService에서 확인해야 함)
        return true; // 기본적으로 사용 가능, 실제 조건은 서비스에서 체크

      case ItemType.forceGo:
      case ItemType.forceStop:
      case ItemType.swapHands:
        // 항상 사용 가능
        return true;

      case ItemType.stealFromDeck:
        // 더미패 1장 이상 필요
        return state.deck.isNotEmpty;

      case ItemType.replaceHand:
        // 더미패가 손패 개수 이상 필요
        final isPlayer1 = state.player1Uid == playerUid;
        final handCount = isPlayer1
            ? state.player1Hand.length
            : state.player2Hand.length;
        return state.deck.length >= handCount;

      case ItemType.replaceFloor:
        // 더미패가 바닥패 개수 이상 필요
        return state.deck.length >= state.floor.length;

      case ItemType.gwangPriority:
        // 더미패에 광 카드가 있어야 함
        return state.deck.any((card) => card.type == CardType.kwang);
    }
  }
}

/// 아이템 효과 상태 (게임 내에서 추적)
class ItemEffects {
  final String? usedItem;           // 이번 게임에 사용한 아이템
  final bool forceGoOnly;           // 상대방 Go만 가능
  final bool forceStopOnly;         // 상대방 Stop만 가능
  final int gwangPriorityTurns;     // 光 우선 남은 턴 수

  const ItemEffects({
    this.usedItem,
    this.forceGoOnly = false,
    this.forceStopOnly = false,
    this.gwangPriorityTurns = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'usedItem': usedItem,
      'forceGoOnly': forceGoOnly,
      'forceStopOnly': forceStopOnly,
      'gwangPriorityTurns': gwangPriorityTurns,
    };
  }

  factory ItemEffects.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ItemEffects();
    return ItemEffects(
      usedItem: json['usedItem'] as String?,
      forceGoOnly: json['forceGoOnly'] as bool? ?? false,
      forceStopOnly: json['forceStopOnly'] as bool? ?? false,
      gwangPriorityTurns: json['gwangPriorityTurns'] as int? ?? 0,
    );
  }

  ItemEffects copyWith({
    String? usedItem,
    bool? forceGoOnly,
    bool? forceStopOnly,
    int? gwangPriorityTurns,
    bool clearUsedItem = false,
  }) {
    return ItemEffects(
      usedItem: clearUsedItem ? null : (usedItem ?? this.usedItem),
      forceGoOnly: forceGoOnly ?? this.forceGoOnly,
      forceStopOnly: forceStopOnly ?? this.forceStopOnly,
      gwangPriorityTurns: gwangPriorityTurns ?? this.gwangPriorityTurns,
    );
  }

  /// 모든 효과 초기화
  ItemEffects reset() {
    return const ItemEffects();
  }

  /// 턴 종료 시 호출 - 턴 기반 효과 감소
  ItemEffects onTurnEnd() {
    return copyWith(
      gwangPriorityTurns: gwangPriorityTurns > 0 ? gwangPriorityTurns - 1 : 0,
      // Go/Stop 강제 효과는 사용 후 즉시 해제 (서비스에서 처리)
    );
  }
}

/// 사용자 아이템 인벤토리
class UserInventory {
  final Map<ItemType, int> items;
  final List<ItemType> dailyPurchases;
  final String lastPurchaseDate;

  const UserInventory({
    this.items = const {},
    this.dailyPurchases = const [],
    this.lastPurchaseDate = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((key, value) => MapEntry(key.name, value)),
      'dailyPurchases': dailyPurchases.map((e) => e.name).toList(),
      'lastPurchaseDate': lastPurchaseDate,
    };
  }

  factory UserInventory.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserInventory();

    // Firebase에서 LinkedMap<Object?, Object?>로 반환될 수 있으므로 안전하게 변환
    final rawItems = json['items'];
    final items = <ItemType, int>{};
    if (rawItems != null && rawItems is Map) {
      final itemsMap = Map<String, dynamic>.from(rawItems);
      for (final entry in itemsMap.entries) {
        try {
          final type = ItemType.values.firstWhere((e) => e.name == entry.key);
          items[type] = (entry.value as num).toInt();
        } catch (_) {
          // 알 수 없는 아이템 타입 무시
        }
      }
    }

    final dailyPurchasesJson = json['dailyPurchases'] as List<dynamic>? ?? [];
    final dailyPurchases = <ItemType>[];
    for (final name in dailyPurchasesJson) {
      try {
        final type = ItemType.values.firstWhere((e) => e.name == name);
        dailyPurchases.add(type);
      } catch (_) {
        // 알 수 없는 아이템 타입 무시
      }
    }

    return UserInventory(
      items: items,
      dailyPurchases: dailyPurchases,
      lastPurchaseDate: json['lastPurchaseDate'] as String? ?? '',
    );
  }

  /// 아이템 보유 여부
  bool hasItem(ItemType type) {
    return (items[type] ?? 0) > 0;
  }

  /// 아이템 개수 가져오기
  int getItemCount(ItemType type) {
    return items[type] ?? 0;
  }

  /// 전체 아이템 개수
  int get totalItems {
    return items.values.fold(0, (sum, count) => sum + count);
  }

  /// 오늘 구매 여부 확인
  bool hasPurchasedToday(ItemType type, String todayStr) {
    if (lastPurchaseDate != todayStr) {
      return false; // 날짜가 다르면 아직 안 샀음
    }
    return dailyPurchases.contains(type);
  }
}

/// 오늘의 상점 아이템
class ShopItems {
  final List<ItemType> todayItems;
  final String lastReset;

  const ShopItems({
    this.todayItems = const [],
    this.lastReset = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'today_items': todayItems.map((e) => e.name).toList(),
      'last_reset': lastReset,
    };
  }

  factory ShopItems.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ShopItems();

    final todayItemsJson = json['today_items'] as List<dynamic>? ?? [];
    final todayItems = <ItemType>[];
    for (final name in todayItemsJson) {
      try {
        final type = ItemType.values.firstWhere((e) => e.name == name);
        todayItems.add(type);
      } catch (_) {
        // 알 수 없는 아이템 타입 무시
      }
    }

    return ShopItems(
      todayItems: todayItems,
      lastReset: json['last_reset'] as String? ?? '',
    );
  }
}
