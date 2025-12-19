import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../models/item_data.dart';
import '../../models/game_room.dart';
import '../../models/player_info.dart';
import '../../services/item_service.dart';

/// 게임 화면에서 아이템 사용 버튼
class ItemUseButton extends ConsumerStatefulWidget {
  final String playerUid;
  final String opponentUid;
  final int playerNumber;
  final String roomId;
  final GameState gameState;
  final Function(ItemType) onItemUsed;
  final bool enabled;
  final GameMode gameMode;
  final List<PlayerInfo> opponents; // 고스톱 모드에서 상대 플레이어 목록

  const ItemUseButton({
    super.key,
    required this.playerUid,
    required this.opponentUid,
    required this.playerNumber,
    required this.roomId,
    required this.gameState,
    required this.onItemUsed,
    this.enabled = true,
    this.gameMode = GameMode.matgo,
    this.opponents = const [],
  });

  @override
  ConsumerState<ItemUseButton> createState() => _ItemUseButtonState();
}

class _ItemUseButtonState extends ConsumerState<ItemUseButton> {
  bool _showingMenu = false;

  @override
  Widget build(BuildContext context) {
    final itemService = ref.read(itemServiceProvider);

    return StreamBuilder<UserInventory>(
      stream: itemService.getUserInventoryStream(widget.playerUid),
      builder: (context, snapshot) {
        final inventory = snapshot.data ?? const UserInventory();
        final totalItems = inventory.totalItems;

        // 이미 이번 게임에서 아이템을 사용했는지 확인 (3인 고스톱 지원)
        final effects = switch (widget.playerNumber) {
          1 => widget.gameState.player1ItemEffects,
          2 => widget.gameState.player2ItemEffects,
          3 => widget.gameState.player3ItemEffects,
          _ => widget.gameState.player1ItemEffects,
        };
        final alreadyUsed = effects?.usedItem != null;

        final canUse = widget.enabled && totalItems > 0 && !alreadyUsed;

        return GestureDetector(
          onTap: canUse ? _showItemMenu : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canUse
                    ? [Colors.indigo.shade700, Colors.purple.shade800]
                    : [Colors.grey.shade700, Colors.grey.shade800],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: canUse ? Colors.amber.shade400 : Colors.grey,
                width: 2,
              ),
              boxShadow: canUse
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎁', style: TextStyle(fontSize: 20)),
                if (totalItems > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: alreadyUsed ? Colors.grey : Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      alreadyUsed ? '사용완료' : '$totalItems',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showItemMenu() async {
    if (_showingMenu) return;
    setState(() => _showingMenu = true);

    final itemService = ref.read(itemServiceProvider);
    final inventory = await itemService.getUserInventory(widget.playerUid);

    if (!mounted) return;

    // 보유 중인 아이템 목록
    final ownedItems = inventory.items.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    if (ownedItems.isEmpty) {
      setState(() => _showingMenu = false);
      return;
    }

    // 아이템 선택 다이얼로그
    final selected = await showDialog<ItemType>(
      context: context,
      builder: (context) => _ItemSelectDialog(
        items: ownedItems,
        gameState: widget.gameState,
        playerUid: widget.playerUid,
      ),
    );

    setState(() => _showingMenu = false);

    if (selected != null && mounted) {
      int? targetPlayerNumber;

      // 고스톱 모드에서 대상 선택이 필요한 아이템인 경우
      if (widget.gameMode == GameMode.gostop &&
          ItemData.needsTargetSelection(selected) &&
          widget.opponents.length >= 2) {
        // 대상 선택 다이얼로그 표시
        targetPlayerNumber = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _TargetSelectDialog(
            itemType: selected,
            opponents: widget.opponents,
            myPlayerNumber: widget.playerNumber,
          ),
        );

        // 취소하면 아이템 사용 안 함
        if (targetPlayerNumber == null) return;
      }

      // 아이템 사용
      final result = await itemService.useItem(
        roomId: widget.roomId,
        playerUid: widget.playerUid,
        opponentUid: widget.opponentUid,
        type: selected,
        playerNumber: widget.playerNumber,
        currentState: widget.gameState,
        targetPlayerNumber: targetPlayerNumber,
      );

      if (result.success && mounted) {
        widget.onItemUsed(selected);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 대상 선택 다이얼로그 (고스톱 전용)
class _TargetSelectDialog extends StatelessWidget {
  final ItemType itemType;
  final List<PlayerInfo> opponents;
  final int myPlayerNumber;

  const _TargetSelectDialog({
    required this.itemType,
    required this.opponents,
    required this.myPlayerNumber,
  });

  /// 플레이어 번호에 따른 아바타 이미지 경로 반환
  String _getAvatarPath(int playerNumber) {
    return switch (playerNumber) {
      1 => 'assets/avatar/Host-normal.png',
      2 => 'assets/avatar/Guest-normal.png',
      3 => 'assets/avatar/Guest-normal-2.png',
      _ => 'assets/avatar/Guest-normal.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = ItemData.getItem(itemType);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.indigo.shade800,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.shade400,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${item.iconEmoji} ${item.name}',
                    style: TextStyle(
                      color: Colors.amber.shade400,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '효과를 적용할 대상을 선택하세요',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            // 상대 플레이어 목록
            ...opponents.asMap().entries.map((entry) {
              final index = entry.key;
              final opponent = entry.value;
              // 플레이어 번호 계산 (본인 번호 기준으로 상대 플레이어 번호 결정)
              // opponents 리스트는 순서대로 다른 플레이어들을 담고 있음
              // myPlayerNumber가 1이면 opponents는 [player2, player3]
              // myPlayerNumber가 2이면 opponents는 [player1, player3]
              // myPlayerNumber가 3이면 opponents는 [player1, player2]
              int targetNumber;
              if (myPlayerNumber == 1) {
                targetNumber = index == 0 ? 2 : 3;
              } else if (myPlayerNumber == 2) {
                targetNumber = index == 0 ? 1 : 3;
              } else {
                targetNumber = index == 0 ? 1 : 2;
              }

              return InkWell(
                onTap: () => Navigator.of(context).pop(targetNumber),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 아바타 이미지
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.amber.shade400,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _getAvatarPath(targetNumber),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // 이미지 로드 실패 시 기본 아이콘 표시
                              return Container(
                                color: Colors.purple.shade400,
                                child: Center(
                                  child: Text(
                                    opponent.displayName.isNotEmpty
                                        ? opponent.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opponent.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 선택 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade600,
                              Colors.orange.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '선택',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // 취소 버튼
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white70),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 아이템 선택 다이얼로그
class _ItemSelectDialog extends StatelessWidget {
  final List<ItemType> items;
  final GameState gameState;
  final String playerUid;

  const _ItemSelectDialog({
    required this.items,
    required this.gameState,
    required this.playerUid,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.indigo.shade800,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.shade400,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '아이템 사용',
                style: TextStyle(
                  color: Colors.amber.shade400,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            // 아이템 목록
            ...items.map((type) {
              final item = ItemData.getItem(type);
              final canUse = item.canUse(gameState, playerUid);

              return InkWell(
                onTap: canUse ? () => Navigator.of(context).pop(type) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: canUse ? Colors.transparent : Colors.black26,
                  ),
                  child: Row(
                    children: [
                      Text(item.iconEmoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                color: canUse ? Colors.white : Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              item.shortDesc,
                              style: TextStyle(
                                color: canUse
                                    ? Colors.white70
                                    : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!canUse)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '조건 미충족',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // 닫기 버튼
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white70),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
