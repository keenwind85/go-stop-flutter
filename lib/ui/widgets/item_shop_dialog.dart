import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/item_data.dart';
import '../../services/item_service.dart';
import '../../services/coin_service.dart';
import '../../services/debug_config_service.dart';

/// 아이템 상점 다이얼로그
class ItemShopDialog extends ConsumerStatefulWidget {
  final String uid;
  final DebugConfigService? debugConfig;

  const ItemShopDialog({
    super.key,
    required this.uid,
    this.debugConfig,
  });

  @override
  ConsumerState<ItemShopDialog> createState() => _ItemShopDialogState();
}

class _ItemShopDialogState extends ConsumerState<ItemShopDialog> {
  bool _isLoading = true;
  List<ItemType> _shopItems = [];
  UserInventory _inventory = const UserInventory();
  int _userCoin = 0;
  String? _purchasingItem;
  bool _isDebugProcessing = false;

  /// 디버그 모드 활성화 여부
  bool get _isDebugModeActive =>
      widget.debugConfig?.canUseItemShopDebug ?? false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final itemService = ref.read(itemServiceProvider);
    final coinService = ref.read(coinServiceProvider);

    try {
      print('[ItemShopDialog] Loading data for uid: ${widget.uid}');

      final shopItems = await itemService.getTodayShopItems();
      print('[ItemShopDialog] Shop items loaded: ${shopItems.length} items');

      final inventory = await itemService.getUserInventory(widget.uid);
      print('[ItemShopDialog] Inventory loaded: ${inventory.items}');

      final wallet = await coinService.getUserWallet(widget.uid);
      print('[ItemShopDialog] Wallet loaded: ${wallet?.coin ?? 0} coins');

      if (mounted) {
        setState(() {
          _shopItems = shopItems;
          _inventory = inventory;
          _userCoin = wallet?.coin ?? 0;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('[ItemShopDialog] Error loading data: $e');
      print('[ItemShopDialog] Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _purchaseItem(ItemType type) async {
    if (_purchasingItem != null) return;

    setState(() => _purchasingItem = type.name);

    final itemService = ref.read(itemServiceProvider);
    final result = await itemService.purchaseItem(widget.uid, type);

    if (mounted) {
      setState(() => _purchasingItem = null);

      if (result.success) {
        // 성공 - 데이터 새로고침
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 실패
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 550),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.indigo.shade800,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.amber.shade400,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            _buildHeader(),

            // 콘텐츠
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    )
                  : _buildItemList(),
            ),

            // 푸터 (코인 표시 + 닫기 버튼)
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.amber.shade400.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, color: Colors.amber.shade400, size: 28),
          const SizedBox(width: 10),
          Text(
            '오늘의 아이템',
            style: TextStyle(
              color: Colors.amber.shade400,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.store, color: Colors.amber.shade400, size: 28),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (_shopItems.isEmpty) {
      return const Center(
        child: Text(
          '오늘의 아이템이 없습니다',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      itemCount: _shopItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final itemType = _shopItems[index];
        return _buildItemCard(itemType);
      },
    );
  }

  Widget _buildItemCard(ItemType type) {
    final item = ItemData.getItem(type);
    final today = ref.read(itemServiceProvider).getTodayString();

    final hasItem = _inventory.hasItem(type);
    final purchasedToday = _inventory.hasPurchasedToday(type, today);
    final canAfford = _userCoin >= item.price;
    final isPurchasing = _purchasingItem == type.name;

    // 버튼 상태 결정
    String buttonText;
    bool buttonEnabled;
    Color buttonColor;

    if (hasItem) {
      buttonText = '보유중';
      buttonEnabled = false;
      buttonColor = Colors.grey;
    } else if (purchasedToday) {
      buttonText = '구매완료';
      buttonEnabled = false;
      buttonColor = Colors.grey;
    } else if (!canAfford) {
      buttonText = '코인 부족';
      buttonEnabled = false;
      buttonColor = Colors.red.shade400;
    } else {
      buttonText = '구매';
      buttonEnabled = true;
      buttonColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasItem ? Colors.green.withOpacity(0.5) : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.indigo.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                item.iconEmoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 아이템 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.shortDesc,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${item.price}',
                      style: TextStyle(
                        color: Colors.amber.shade400,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 구매 버튼
          SizedBox(
            width: 70,
            height: 36,
            child: ElevatedButton(
              onPressed: buttonEnabled && !isPurchasing
                  ? () => _purchaseItem(type)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: buttonColor.withOpacity(0.5),
              ),
              child: isPurchasing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(fontSize: 12),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.amber.shade400.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 디버그 버튼들 (디버그 모드 활성화 시에만 표시)
          if (_isDebugModeActive) _buildDebugButtons(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 내 코인
              Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    '내 코인: $_userCoin',
                    style: TextStyle(
                      color: Colors.amber.shade400,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // 닫기 버튼
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 디버그 버튼들 빌드
  Widget _buildDebugButtons() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.deepPurple.shade400,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔧', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                '디버그 모드',
                style: TextStyle(
                  color: Colors.deepPurple.shade200,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 오늘의 아이템 리셋하기
              Expanded(
                child: _buildDebugButton(
                  icon: Icons.refresh,
                  label: '아이템 리셋',
                  onPressed: _isDebugProcessing ? null : _debugResetItems,
                ),
              ),
              const SizedBox(width: 8),
              // 코인 충전하기
              Expanded(
                child: _buildDebugButton(
                  icon: Icons.add_circle,
                  label: '+100 코인',
                  onPressed: _isDebugProcessing ? null : _debugAddCoins,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      icon: _isDebugProcessing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// [DEBUG] 오늘의 아이템 리셋
  Future<void> _debugResetItems() async {
    setState(() => _isDebugProcessing = true);

    try {
      final itemService = ref.read(itemServiceProvider);
      await itemService.debugResetShopItems(widget.uid);

      // 데이터 새로고침
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔧 아이템이 리셋되었습니다!'),
            backgroundColor: Colors.deepPurple,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('리셋 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDebugProcessing = false);
      }
    }
  }

  /// [DEBUG] 코인 100 추가
  Future<void> _debugAddCoins() async {
    setState(() => _isDebugProcessing = true);

    try {
      final itemService = ref.read(itemServiceProvider);
      await itemService.debugAddCoins(widget.uid, amount: 100);

      // 데이터 새로고침
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔧 100 코인이 추가되었습니다!'),
            backgroundColor: Colors.deepPurple,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('코인 추가 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDebugProcessing = false);
      }
    }
  }
}

/// 아이템 상점 다이얼로그 표시
void showItemShopDialog(
  BuildContext context,
  String uid, {
  DebugConfigService? debugConfig,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => ItemShopDialog(
      uid: uid,
      debugConfig: debugConfig,
    ),
  );
}
