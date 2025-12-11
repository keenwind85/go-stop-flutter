import 'package:flutter/material.dart';
import '../../models/card_data.dart';
import '../../config/constants.dart';
import '../../game/systems/deck_generator.dart';

/// 디버그 모드에서 카드를 선택하는 다이얼로그
///
/// 전체 화투 카드 목록에서 하나를 선택할 수 있습니다.
/// 이미 사용 중인 카드는 선택할 수 없습니다.
class DebugCardSelectorDialog extends StatefulWidget {
  /// 현재 변경하려는 카드
  final CardData currentCard;

  /// 이미 사용 중인 카드 ID 목록 (중복 방지)
  final Set<String> usedCardIds;

  /// 카드 변경 위치 설명
  final String location;

  const DebugCardSelectorDialog({
    super.key,
    required this.currentCard,
    required this.usedCardIds,
    required this.location,
  });

  @override
  State<DebugCardSelectorDialog> createState() => _DebugCardSelectorDialogState();
}

class _DebugCardSelectorDialogState extends State<DebugCardSelectorDialog> {
  late List<CardData> _allCards;
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _allCards = DeckGenerator.generateDeck();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1810),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '디버그: 카드 변경',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.location,
                          style: TextStyle(
                            color: AppColors.text.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.text),
                  ),
                ],
              ),
            ),

            // 현재 카드 표시
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    '현재 카드: ',
                    style: TextStyle(color: AppColors.text.withValues(alpha: 0.7)),
                  ),
                  _buildCardPreview(widget.currentCard, isSmall: true),
                  const SizedBox(width: 8),
                  Text(
                    _getCardName(widget.currentCard),
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.woodDark, height: 1),

            // 월 선택 탭
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  _buildMonthTab(null, '전체'),
                  for (int month = 1; month <= 12; month++)
                    _buildMonthTab(month, '$month월'),
                  _buildMonthTab(0, '보너스'),
                ],
              ),
            ),

            // 카드 그리드
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _filteredCards.length,
                itemBuilder: (context, index) {
                  final card = _filteredCards[index];
                  final isUsed = widget.usedCardIds.contains(card.id) &&
                                 card.id != widget.currentCard.id;
                  final isCurrent = card.id == widget.currentCard.id;

                  return _buildCardItem(card, isUsed: isUsed, isCurrent: isCurrent);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CardData> get _filteredCards {
    if (_selectedMonth == null) {
      return _allCards;
    }
    return _allCards.where((c) => c.month == _selectedMonth).toList();
  }

  Widget _buildMonthTab(int? month, String label) {
    final isSelected = _selectedMonth == month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMonth = month),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.woodDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : AppColors.text,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(CardData card, {required bool isUsed, required bool isCurrent}) {
    return GestureDetector(
      onTap: isUsed ? null : () => Navigator.pop(context, card),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? AppColors.accent
                : isUsed
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // 카드 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ColorFiltered(
                colorFilter: isUsed
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                child: Image.asset(
                  'assets/${card.imagePath}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.woodDark,
                    child: Center(
                      child: Text(
                        '${card.month}월\n${card.index}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.text, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 사용 중 표시
            if (isUsed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(Icons.block, color: Colors.red, size: 24),
                  ),
                ),
              ),
            // 현재 카드 표시
            if (isCurrent)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.black, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPreview(CardData card, {bool isSmall = false}) {
    final size = isSmall ? 30.0 : 50.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        'assets/${card.imagePath}',
        width: size,
        height: size * 1.5,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size * 1.5,
          color: AppColors.woodDark,
          child: Center(
            child: Text(
              '${card.month}',
              style: const TextStyle(color: AppColors.text, fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }

  String _getCardName(CardData card) {
    if (card.month == 0) return '보너스 ${card.index}';

    final monthNames = ['', '송학', '매조', '벚꽃', '흑싸리', '난초', '모란', '홍싸리', '공산', '국화', '단풍', '오동', '비'];
    final typeName = switch (card.type) {
      CardType.kwang => '광',
      CardType.animal => '열끗',
      CardType.ribbon => '띠',
      CardType.pi => '피',
      CardType.doublePi => '쌍피',
      CardType.bonusPi => '보너스피',
    };

    return '${monthNames[card.month]} $typeName';
  }
}
