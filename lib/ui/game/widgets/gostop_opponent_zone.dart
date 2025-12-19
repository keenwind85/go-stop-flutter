import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../models/captured_cards.dart';
import '../../../models/card_data.dart';
import '../../../config/constants.dart';
import 'game_avatar.dart';

/// 고스톱 3인용 상대방 영역 (화면 상단)
/// 두 명의 상대방을 좌우로 나란히 표시
class GostopOpponentZone extends StatelessWidget {
  // 왼쪽 상대
  final String? opponent1Name;
  final CapturedCards? opponent1Captured;
  final int opponent1Score;
  final int opponent1GoCount;
  final int opponent1HandCount;
  final bool isOpponent1Turn;
  final bool opponent1IsShaking;
  final bool opponent1HasBomb;
  final bool opponent1IsMeongTta;
  final int? opponent1CoinBalance;
  final int? opponent1RemainingSeconds;
  final AvatarState opponent1AvatarState;
  final int opponent1PlayerNumber; // 1=Host, 2=Guest, 3=Guest2

  // 오른쪽 상대
  final String? opponent2Name;
  final CapturedCards? opponent2Captured;
  final int opponent2Score;
  final int opponent2GoCount;
  final int opponent2HandCount;
  final bool isOpponent2Turn;
  final bool opponent2IsShaking;
  final bool opponent2HasBomb;
  final bool opponent2IsMeongTta;
  final int? opponent2CoinBalance;
  final int? opponent2RemainingSeconds;
  final AvatarState opponent2AvatarState;
  final int opponent2PlayerNumber; // 1=Host, 2=Guest, 3=Guest2

  const GostopOpponentZone({
    super.key,
    // 상대1
    this.opponent1Name,
    this.opponent1Captured,
    required this.opponent1Score,
    required this.opponent1GoCount,
    required this.opponent1HandCount,
    required this.isOpponent1Turn,
    this.opponent1IsShaking = false,
    this.opponent1HasBomb = false,
    this.opponent1IsMeongTta = false,
    this.opponent1CoinBalance,
    this.opponent1RemainingSeconds,
    this.opponent1AvatarState = AvatarState.normal,
    this.opponent1PlayerNumber = 2, // 기본값: Guest
    // 상대2
    this.opponent2Name,
    this.opponent2Captured,
    required this.opponent2Score,
    required this.opponent2GoCount,
    required this.opponent2HandCount,
    required this.isOpponent2Turn,
    this.opponent2IsShaking = false,
    this.opponent2HasBomb = false,
    this.opponent2IsMeongTta = false,
    this.opponent2CoinBalance,
    this.opponent2RemainingSeconds,
    this.opponent2AvatarState = AvatarState.normal,
    this.opponent2PlayerNumber = 3, // 기본값: Guest2
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.woodDark.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: AppColors.woodLight, width: 4),
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
      child: Row(
        children: [
          // 왼쪽 상대
          Expanded(
            child: _SingleOpponentCard(
              opponentName: opponent1Name,
              captured: opponent1Captured,
              score: opponent1Score,
              goCount: opponent1GoCount,
              handCount: opponent1HandCount,
              isOpponentTurn: isOpponent1Turn,
              isShaking: opponent1IsShaking,
              hasBomb: opponent1HasBomb,
              isMeongTta: opponent1IsMeongTta,
              coinBalance: opponent1CoinBalance,
              remainingSeconds: opponent1RemainingSeconds,
              avatarState: opponent1AvatarState,
              playerNumber: opponent1PlayerNumber,
              isLeftSide: true,
            ),
          ),
          // 구분선
          Container(
            width: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.woodLight.withValues(alpha: 0.5),
          ),
          // 오른쪽 상대
          Expanded(
            child: _SingleOpponentCard(
              opponentName: opponent2Name,
              captured: opponent2Captured,
              score: opponent2Score,
              goCount: opponent2GoCount,
              handCount: opponent2HandCount,
              isOpponentTurn: isOpponent2Turn,
              isShaking: opponent2IsShaking,
              hasBomb: opponent2HasBomb,
              isMeongTta: opponent2IsMeongTta,
              coinBalance: opponent2CoinBalance,
              remainingSeconds: opponent2RemainingSeconds,
              avatarState: opponent2AvatarState,
              playerNumber: opponent2PlayerNumber,
              isLeftSide: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// 개별 상대방 카드 (압축 레이아웃)
class _SingleOpponentCard extends StatelessWidget {
  final String? opponentName;
  final CapturedCards? captured;
  final int score;
  final int goCount;
  final int handCount;
  final bool isOpponentTurn;
  final bool isShaking;
  final bool hasBomb;
  final bool isMeongTta;
  final int? coinBalance;
  final int? remainingSeconds;
  final AvatarState avatarState;
  final int playerNumber; // 1=Host, 2=Guest, 3=Guest2
  final bool isLeftSide;

  const _SingleOpponentCard({
    this.opponentName,
    this.captured,
    required this.score,
    required this.goCount,
    required this.handCount,
    required this.isOpponentTurn,
    this.isShaking = false,
    this.hasBomb = false,
    this.isMeongTta = false,
    this.coinBalance,
    this.remainingSeconds,
    this.avatarState = AvatarState.normal,
    required this.playerNumber,
    required this.isLeftSide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isOpponentTurn
            ? AppColors.goRed.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // 상단: 아바타 + 닉네임 + 점수
          Expanded(flex: 40, child: _buildHeaderSection()),
          // 하단: 획득 패
          Expanded(flex: 60, child: _buildCapturedCards()),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        // 아바타 (작은 사이즈)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GameAvatar(
            playerNumber: playerNumber,
            state: avatarState,
            size: 32,
          ),
        ),
        // 닉네임 + 정보
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 닉네임 행
              Row(
                children: [
                  // 턴 인디케이터
                  if (isOpponentTurn)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.goRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goRed.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: Text(
                      opponentName ?? '상대방',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // 손패 + 점수 + 코인 행
              Row(
                children: [
                  Text(
                    '$handCount장',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$score점',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 코인 잔액 표시
                  if (coinBalance != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset(
                            'assets/etc/Coin.json',
                            width: 12,
                            height: 12,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$coinBalance',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              // 고 카운트 + 흔들기/폭탄/멍따 태그
              if (goCount > 0 || isShaking || hasBomb || isMeongTta)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (goCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goRed.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '$goCount고',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isShaking) ...[
                        if (goCount > 0) const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '흔들',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (hasBomb) ...[
                        if (goCount > 0 || isShaking) const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '폭탄',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      // 멍따 태그 (열끗 7장 이상)
                      if (isMeongTta) ...[
                        if (goCount > 0 || isShaking || hasBomb) const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '멍따',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 7,
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
        // 타이머 (턴일 때만)
        if (isOpponentTurn && remainingSeconds != null) _buildCompactTimer(),
      ],
    );
  }

  Widget _buildCompactTimer() {
    final isUrgent = remainingSeconds != null && remainingSeconds! <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.red.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.white, size: 10),
          const SizedBox(width: 2),
          Text(
            '$remainingSeconds',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// 획득 패 (압축 버전)
  Widget _buildCapturedCards() {
    final hasCards =
        captured != null &&
        (captured!.kwang.isNotEmpty ||
            captured!.animal.isNotEmpty ||
            captured!.ribbon.isNotEmpty ||
            captured!.pi.isNotEmpty);

    if (!hasCards) {
      return Center(
        child: Text(
          '획득 패 없음',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 9,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 광
            if (captured!.kwang.isNotEmpty)
              _buildCompactCardGroup(
                cards: captured!.kwang,
                label: '광',
                labelColor: AppColors.cardHighlight,
              ),
            // 열끗
            if (captured!.animal.isNotEmpty)
              _buildCompactCardGroup(
                cards: captured!.animal,
                label: '열',
                labelColor: AppColors.goRed,
              ),
            // 띠
            if (captured!.ribbon.isNotEmpty)
              _buildCompactCardGroup(
                cards: captured!.ribbon,
                label: '띠',
                labelColor: AppColors.stopBlue,
              ),
            // 피
            if (captured!.pi.isNotEmpty)
              _buildCompactCardGroup(
                cards: captured!.pi,
                label: '피',
                labelColor: AppColors.primaryLight,
                showCount: captured!.piCount,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCardGroup({
    required List<CardData> cards,
    required String label,
    required Color labelColor,
    int? showCount,
  }) {
    // 3인용이므로 더 작은 카드 크기
    final cardWidth = GameConstants.cardWidth * 0.5;
    final cardHeight = GameConstants.cardHeight * 0.5;
    const overlap = 10.0;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라벨 + 카운트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '$label ${showCount ?? cards.length}',
              style: TextStyle(
                color: labelColor,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 1),
          // 카드 스택
          SizedBox(
            width: cardWidth + (cards.length - 1) * overlap,
            height: cardHeight,
            child: Stack(
              children: List.generate(
                cards.length > 5 ? 5 : cards.length, // 최대 5장만 표시
                (index) {
                  final card = cards[index];
                  return Positioned(
                    left: index * overlap,
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: AppColors.woodDark.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 1,
                            offset: const Offset(0.5, 0.5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
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
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
