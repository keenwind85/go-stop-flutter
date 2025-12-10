import 'package:flutter/material.dart';
import '../../../models/card_data.dart';
import '../../../config/constants.dart';
import '../game_screen_new.dart';

/// 화투 카드 위젯
///
/// 디자인 가이드 기반:
/// - 테두리: 평소 얇은 흰색 투명 테두리
/// - 선택 효과: 형광 노랑 빛나는 테두리 (Glow)
/// - 그림자: 깊은 그림자로 입체감
class GameCardWidget extends StatelessWidget {
  final CardData cardData;
  final double width;
  final double height;
  final bool isSelected;
  final bool isHighlighted;
  final bool isInteractive;
  final bool showBack;
  final double rotation;
  final VoidCallback? onTap;

  const GameCardWidget({
    super.key,
    required this.cardData,
    this.width = GameConstants.cardWidth,
    this.height = GameConstants.cardHeight,
    this.isSelected = false,
    this.isHighlighted = false,
    this.isInteractive = true,
    this.showBack = false,
    this.rotation = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isInteractive ? onTap : null,
      child: Transform.rotate(
        angle: rotation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.cardHighlight
                  : isHighlighted
                      ? AppColors.primaryLight
                      : AppColors.woodDark.withValues(alpha: 0.5),
              width: isSelected ? 3 : isHighlighted ? 2 : 1,
            ),
            boxShadow: [
              // 기본 그림자
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
              // 선택 시 Glow 효과
              if (isSelected)
                BoxShadow(
                  color: AppColors.cardHighlight.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              if (isHighlighted)
                BoxShadow(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              showBack
                  ? 'assets/cards/back_of_card.png'
                  : 'assets/${cardData.imagePath}',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.primaryDark,
                  child: Center(
                    child: Text(
                      showBack ? '?' : '${cardData.month}',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 작은 카드 아이콘 (획득 패 요약용)
class CardTypeIcon extends StatelessWidget {
  final CardType type;
  final int count;
  final double size;

  const CardTypeIcon({
    super.key,
    required this.type,
    required this.count,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.woodLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.woodDark.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          const SizedBox(width: 4),
          Text(
            'x$count',
            style: TextStyle(
              color: AppColors.text,
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case CardType.kwang:
        iconData = Icons.wb_sunny;
        iconColor = AppColors.cardHighlight;
      case CardType.animal:
        iconData = Icons.pets;
        iconColor = AppColors.goRed;
      case CardType.ribbon:
        iconData = Icons.bookmark;
        iconColor = AppColors.stopBlue;
      case CardType.pi:
      case CardType.doublePi:
      case CardType.bonusPi:
        iconData = Icons.grass;
        iconColor = AppColors.primaryLight;
    }

    return Icon(iconData, size: size, color: iconColor);
  }
}

/// 덱 카드 스택 (쌓인 카드 표현)
class DeckStack extends StatelessWidget {
  final int count;
  final double cardWidth;
  final double cardHeight;
  final VoidCallback? onTap;

  const DeckStack({
    super.key,
    required this.count,
    this.cardWidth = GameConstants.cardWidth,
    this.cardHeight = GameConstants.cardHeight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    // 덱 두께 표현 (최대 5장까지 시각화)
    final visibleCards = count.clamp(1, 5);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth + 8,
        height: cardHeight + 8,
        child: Stack(
          children: [
            // 쌓인 카드들 (입체감)
            for (int i = 0; i < visibleCards; i++)
              Positioned(
                left: i * 1.5,
                top: i * 1.5,
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.woodDark.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.asset(
                      'assets/cards/back_of_card.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primaryDark,
                          child: Center(
                            child: Icon(
                              Icons.style,
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            // 남은 카드 수 표시
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.woodDark.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.woodDark.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
