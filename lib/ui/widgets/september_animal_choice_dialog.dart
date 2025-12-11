import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../models/card_data.dart';

/// 9월 열끗(쌍피) 선택 다이얼로그
///
/// 9월 열끗 카드(09month_1.png)를 획득할 때
/// 열끗(동물)으로 사용할지 쌍피로 사용할지 선택하는 다이얼로그
class SeptemberAnimalChoiceDialog extends StatefulWidget {
  final CardData card;
  final Function(bool useAsAnimal) onChoice;
  final String playerName;

  const SeptemberAnimalChoiceDialog({
    super.key,
    required this.card,
    required this.onChoice,
    required this.playerName,
  });

  @override
  State<SeptemberAnimalChoiceDialog> createState() => _SeptemberAnimalChoiceDialogState();
}

class _SeptemberAnimalChoiceDialogState extends State<SeptemberAnimalChoiceDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool? _selected;

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

  void _selectChoice(bool useAsAnimal) {
    if (_selected != null) return;

    setState(() => _selected = useAsAnimal);

    // 선택 후 약간의 딜레이 후 콜백 호출
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onChoice(useAsAnimal);
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
                      color: Colors.amber,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.4),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 타이틀
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz,
                              color: Colors.amber,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '9월 열끗 선택',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.swap_horiz,
                              color: Colors.amber,
                              size: 24,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 설명
                      Text(
                        '${widget.playerName}님, 이 카드를 어떻게 사용하시겠습니까?',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 카드 이미지
                      Container(
                        width: 80,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/${widget.card.imagePath}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '9월',
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '열끗',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 선택 버튼들
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 열끗(동물) 선택
                          _buildChoiceButton(
                            title: '열끗 (동물)',
                            subtitle: '10점 열끗으로 사용',
                            icon: Icons.pets,
                            color: AppColors.goRed,
                            isSelected: _selected == true,
                            onTap: () => _selectChoice(true),
                          ),

                          const SizedBox(width: 16),

                          // 쌍피 선택
                          _buildChoiceButton(
                            title: '쌍피',
                            subtitle: '피 2장으로 계산',
                            icon: Icons.filter_2,
                            color: AppColors.primaryLight,
                            isSelected: _selected == false,
                            onTap: () => _selectChoice(false),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 안내 문구
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '이 선택은 게임 종료 시 점수 계산에 적용됩니다',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _buildChoiceButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool isDisabled = _selected != null && !isSelected;

    return GestureDetector(
      onTap: _selected == null ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.3)
              : isDisabled
                  ? Colors.grey.withValues(alpha: 0.1)
                  : AppColors.woodDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : isDisabled ? Colors.grey : AppColors.woodLight,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // 아이콘
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.3)
                    : isDisabled
                        ? Colors.grey.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.check : icon,
                color: isSelected ? color : isDisabled ? Colors.grey : color,
                size: 28,
              ),
            ),

            const SizedBox(height: 10),

            // 타이틀
            Text(
              title,
              style: TextStyle(
                color: isDisabled ? Colors.grey : AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // 서브타이틀
            Text(
              subtitle,
              style: TextStyle(
                color: isDisabled ? Colors.grey.withValues(alpha: 0.7) : AppColors.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
