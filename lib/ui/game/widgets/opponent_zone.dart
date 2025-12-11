import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../models/captured_cards.dart';
import '../../../models/card_data.dart';
import '../../../config/constants.dart';

/// Top Zone: 상대방 영역 (화면 상단 20%)
///
/// 디자인:
/// - 좌측: 상대방 닉네임 + 턴 표시 + 고 카운트
/// - 중앙: 획득 패 (실제 카드 이미지로 종류별 그룹핑)
/// - 우측: 점수 (큰 폰트) + 남은 손패 (카드 뒷면 이미지로 표시)
class OpponentZone extends StatelessWidget {
  final String? opponentName;
  final CapturedCards? captured;
  final int score;
  final int goCount;
  final int handCount;
  final bool isOpponentTurn;
  final bool isShaking;   // 흔들기 사용 여부
  final bool hasBomb;     // 폭탄 사용 여부
  final int? coinBalance; // 코인 잔액

  /// 턴 타이머 관련
  final int? remainingSeconds;  // 남은 시간 (초)

  const OpponentZone({
    super.key,
    this.opponentName,
    this.captured,
    required this.score,
    required this.goCount,
    required this.handCount,
    required this.isOpponentTurn,
    this.isShaking = false,
    this.hasBomb = false,
    this.coinBalance,
    this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.woodDark.withValues(alpha: 0.95), // 진한 나무 색상
        border: Border(
          bottom: BorderSide(
            color: AppColors.woodLight,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 4, right: 4, top: 50, bottom: 4),
      child: Column(
        children: [
          // 상단: 닉네임 + 점수 + 손패
          Expanded(
            flex: 35,
            child: Row(
              children: [
                // 좌측: 닉네임 + 턴/고 표시
                Expanded(
                  flex: 3,
                  child: _buildNameSection(),
                ),
                // 우측: 점수 + 남은 손패 (카드 뒷면 이미지)
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: _buildScoreAndHandSection()),
                      // 상단 우측 버튼(나가기/사운드)과의 겹침 방지용 여백
                      const SizedBox(width: 60),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 하단: 획득 패 (실제 카드 이미지) + 타이머
          Expanded(
            flex: 65,
            child: Stack(
              children: [
                _buildCapturedCards(),
                // 상대방 턴일 때 타이머 표시 (우하단)
                if (isOpponentTurn && remainingSeconds != null)
                  _buildTimerDisplay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return Row(
      children: [
        // 턴 인디케이터
        if (isOpponentTurn)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppColors.goRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.goRed.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                opponentName ?? '상대방',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$handCount장',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // 고 카운트 + 흔들기/폭탄 태그
              if (goCount > 0 || isShaking || hasBomb)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (goCount > 0)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.goRed.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 10,
                                color: AppColors.cardHighlight,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$goCount고',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isShaking) ...[
                        if (goCount > 0) const SizedBox(width: 4),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '흔들기',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (hasBomb) ...[
                        if (goCount > 0 || isShaking) const SizedBox(width: 4),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '폭탄',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreAndHandSection() {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 코인 잔액 표시
          if (coinBalance != null) ...[
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.woodDark, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/etc/Coin.json',
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('🪙', style: TextStyle(fontSize: 12));
                    },
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$coinBalance',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 점수 (큰 폰트)
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.woodDark, width: 2),
            ),
            child: Text(
              '$score점',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 획득 패를 실제 카드 이미지로 그룹별 표시
  Widget _buildCapturedCards() {
    if (captured == null ||
        (captured!.kwang.isEmpty &&
            captured!.animal.isEmpty &&
            captured!.ribbon.isEmpty &&
            captured!.pi.isEmpty)) {
      return Center(
        child: Text(
          '획득 패 없음',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 광
          if (captured!.kwang.isNotEmpty)
            _buildCardGroup(
              cards: captured!.kwang,
              label: '광',
              labelColor: AppColors.cardHighlight,
            ),
          // 열끗 (동물)
          if (captured!.animal.isNotEmpty)
            _buildCardGroup(
              cards: captured!.animal,
              label: '열',
              labelColor: AppColors.goRed,
            ),
          // 띠
          if (captured!.ribbon.isNotEmpty)
            _buildCardGroup(
              cards: captured!.ribbon,
              label: '띠',
              labelColor: AppColors.stopBlue,
            ),
          // 피
          if (captured!.pi.isNotEmpty)
            _buildCardGroup(
              cards: captured!.pi,
              label: '피',
              labelColor: AppColors.primaryLight,
              showCount: captured!.piCount,
            ),
        ],
      ),
    );
  }

  /// 카드 그룹 (종류별로 겹쳐서 표시)
  Widget _buildCardGroup({
    required List<CardData> cards,
    required String label,
    required Color labelColor,
    int? showCount,
  }) {
    final cardWidth = GameConstants.cardWidth * 0.5;
    final cardHeight = GameConstants.cardHeight * 0.5;
    const overlap = 14.0;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라벨 + 카운트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$label ${showCount ?? cards.length}',
              style: TextStyle(
                color: labelColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // 카드 스택
          SizedBox(
            width: cardWidth + (cards.length - 1) * overlap,
            height: cardHeight,
            child: Stack(
              children: List.generate(cards.length, (index) {
                final card = cards[index];
                return Positioned(
                  left: index * overlap,
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border:
                          Border.all(color: AppColors.woodDark.withValues(alpha: 0.5), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.asset(
                        'assets/${card.imagePath}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primaryDark,
                          child: Center(
                            child: Text(
                              '${card.month}',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// 턴 타이머 표시 위젯 (우상단에 위치 - 잘림 방지)
  Widget _buildTimerDisplay() {
    final isUrgent = remainingSeconds != null && remainingSeconds! <= 10;
    final displayText = remainingSeconds != null ? '$remainingSeconds초 남았습니다...' : '';

    return Positioned(
      right: 12,
      top: 4,  // bottom에서 top으로 변경하여 잘림 방지
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isUrgent
              ? Colors.red.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUrgent ? Colors.redAccent : Colors.white24,
            width: 1,
          ),
          boxShadow: isUrgent
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              color: isUrgent ? Colors.white : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              displayText,
              style: TextStyle(
                color: isUrgent ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
