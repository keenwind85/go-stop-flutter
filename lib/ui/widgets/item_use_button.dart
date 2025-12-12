import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/item_data.dart';
import '../../models/game_room.dart';
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

  const ItemUseButton({
    super.key,
    required this.playerUid,
    required this.opponentUid,
    required this.playerNumber,
    required this.roomId,
    required this.gameState,
    required this.onItemUsed,
    this.enabled = true,
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

        // 이미 이번 게임에서 아이템을 사용했는지 확인
        final effects = widget.playerNumber == 1
            ? widget.gameState.player1ItemEffects
            : widget.gameState.player2ItemEffects;
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
      // 아이템 사용
      final result = await itemService.useItem(
        roomId: widget.roomId,
        playerUid: widget.playerUid,
        opponentUid: widget.opponentUid,
        type: selected,
        playerNumber: widget.playerNumber,
        currentState: widget.gameState,
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
