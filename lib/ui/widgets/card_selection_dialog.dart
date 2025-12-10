import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../models/card_data.dart';
import 'retro_button.dart';

/// 2장 이상 매칭 시 카드 선택 다이얼로그
class CardSelectionDialog extends StatefulWidget {
  final List<CardData> matchingCards;
  final CardData playedCard;
  final Function(CardData selectedCard) onCardSelected;
  final VoidCallback? onCancel;
  final String title;

  const CardSelectionDialog({
    super.key,
    required this.matchingCards,
    required this.playedCard,
    required this.onCardSelected,
    this.onCancel,
    this.title = '짝을 맞출 카드를 선택하세요',
  });

  @override
  State<CardSelectionDialog> createState() => _CardSelectionDialogState();
}

class _CardSelectionDialogState extends State<CardSelectionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int? _selectedIndex;
  int _hoverIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectCard(int index) {
    setState(() => _selectedIndex = index);

    // 선택 후 약간의 딜레이 후 콜백 호출
    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onCardSelected(widget.matchingCards[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 타이틀
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 내가 낸 카드 표시
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '내 카드: ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 75,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/${widget.playedCard.imagePath}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.primary,
                                  child: Center(
                                    child: Text(
                                      '${widget.playedCard.month}',
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 화살표 표시
                      const Icon(
                        Icons.arrow_downward,
                        color: AppColors.accent,
                        size: 32,
                      ),

                      const SizedBox(height: 16),

                      // 선택 가능한 카드들
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.matchingCards.length,
                          (index) => _buildSelectableCard(index),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 취소 버튼
                      if (widget.onCancel != null)
                        RetroButton(
                          text: '취소',
                          color: AppColors.woodLight,
                          textColor: AppColors.text,
                          onPressed: widget.onCancel,
                          width: 100,
                          height: 44,
                          fontSize: 14,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectableCard(int index) {
    final card = widget.matchingCards[index];
    final isSelected = _selectedIndex == index;
    final isHovered = _hoverIndex == index;

    return GestureDetector(
      onTap: _selectedIndex == null ? () => _selectCard(index) : null,
      child: MouseRegion(
        onEnter: (_) => setState(() {
          _hoverIndex = index;
        }),
        onExit: (_) => setState(() {
          _hoverIndex = -1;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          transform: Matrix4.translationValues(0.0, isHovered || isSelected ? -10.0 : 0.0, 0.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 70,
            height: 105,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : isHovered
                        ? AppColors.cardHighlight
                        : Colors.transparent,
                width: isSelected ? 4 : 3,
              ),
              boxShadow: [
                if (isSelected || isHovered)
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: isSelected ? 0.5 : 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Stack(
              children: [
                // 카드 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/${card.imagePath}',
                    fit: BoxFit.cover,
                    width: 70,
                    height: 105,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${card.month}월',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              card.type.name,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 선택 표시
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.accent,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                // 호버 인디케이터
                if (isHovered && !isSelected)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '선택',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
