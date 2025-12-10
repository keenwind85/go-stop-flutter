import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../models/card_data.dart';
import 'retro_button.dart';

/// 흔들기/폭탄 선언 버튼 위젯
class ActionButtons extends StatelessWidget {
  final List<CardData> myHand;
  final List<CardData> floorCards;
  final bool isMyTurn;
  final bool alreadyUsedShake;  // 이미 흔들기 사용했는지
  final bool alreadyUsedBomb;   // 이미 폭탄 사용했는지
  final Function(int month)? onShake;
  final Function(int month)? onBomb;

  const ActionButtons({
    super.key,
    required this.myHand,
    required this.floorCards,
    required this.isMyTurn,
    this.alreadyUsedShake = false,
    this.alreadyUsedBomb = false,
    this.onShake,
    this.onBomb,
  });

  /// 흔들기 가능한 월 찾기 (손에 같은 월 3장 이상)
  List<int> _getShakableMonths() {
    final monthCounts = <int, int>{};
    for (final card in myHand) {
      monthCounts[card.month] = (monthCounts[card.month] ?? 0) + 1;
    }
    return monthCounts.entries
        .where((e) => e.value >= 3)
        .map((e) => e.key)
        .toList();
  }

  /// 폭탄 가능한 월 찾기 (손에 3장 + 바닥에 1장)
  List<int> _getBombableMonths() {
    final handMonthCounts = <int, int>{};
    for (final card in myHand) {
      handMonthCounts[card.month] = (handMonthCounts[card.month] ?? 0) + 1;
    }

    final floorMonths = <int, int>{};
    for (final card in floorCards) {
      floorMonths[card.month] = (floorMonths[card.month] ?? 0) + 1;
    }

    return handMonthCounts.entries
        .where((e) => e.value == 3 && floorMonths[e.key] == 1)
        .map((e) => e.key)
        .toList();
  }

  String _getMonthName(int month) {
    const monthNames = [
      '', '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월',
    ];
    if (month >= 1 && month <= 12) return monthNames[month];
    return '$month월';
  }

  @override
  Widget build(BuildContext context) {
    if (!isMyTurn) return const SizedBox.shrink();

    // 이미 사용한 액션은 제외
    final shakableMonths = alreadyUsedShake ? <int>[] : _getShakableMonths();
    final bombableMonths = alreadyUsedBomb ? <int>[] : _getBombableMonths();

    if (shakableMonths.isEmpty && bombableMonths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '특수 액션',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 흔들기 버튼들
              for (final month in shakableMonths)
                _ActionButton(
                  label: '흔들기',
                  subLabel: _getMonthName(month),
                  color: Colors.amber,
                  icon: Icons.vibration,
                  onTap: () => onShake?.call(month),
                ),
              // 폭탄 버튼들
              for (final month in bombableMonths)
                _ActionButton(
                  label: '폭탄',
                  subLabel: _getMonthName(month),
                  color: Colors.deepOrange,
                  icon: Icons.flash_on,
                  onTap: () => onBomb?.call(month),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String subLabel;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.subLabel,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RetroButton(
      onPressed: onTap,
      color: color,
      width: null, // Auto width
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
