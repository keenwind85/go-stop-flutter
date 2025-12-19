import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../game/systems/score_calculator.dart';
import '../../models/game_room.dart';
import 'retro_button.dart';

/// 게임 결과 다이얼로그
class GameResultDialog extends StatelessWidget {
  final bool isWinner;
  final int finalScore;
  final FinalScoreResult? scoreDetail;
  final GameEndState endState;
  final VoidCallback onRematch;
  final VoidCallback onExit;
  final int? coinChange; // 코인 획득/손실량 (null이면 표시 안함)
  final bool isGwangkkiMode; // 光끼 모드 여부
  final GostopSettlementResult? gostopSettlement;  // 3인 고스톱 패자별 정산 정보 (승자용)
  final LoserSettlementDetail? loserSettlement;    // 패자 본인의 정산 정보
  final int? kwangkkiGained; // 패배로 인해 축적된 광끼 게이지 (패자용)

  const GameResultDialog({
    super.key,
    required this.isWinner,
    required this.finalScore,
    this.scoreDetail,
    required this.endState,
    required this.onRematch,
    required this.onExit,
    this.coinChange,
    this.isGwangkkiMode = false,
    this.gostopSettlement,
    this.loserSettlement,
    this.kwangkkiGained,
  });

  String _getResultTitle() {
    // 光끼 모드 특별 타이틀
    if (isGwangkkiMode) {
      return isWinner ? '光끼 승리!' : '光끼 패배';
    }

    switch (endState) {
      case GameEndState.win:
        return isWinner ? '승리!' : '패배';
      case GameEndState.nagari:
        return '나가리';
      case GameEndState.chongtong:
        return isWinner ? '총통 승리!' : '총통 패배';
      case GameEndState.gobak:
        return isWinner ? '고박 승리!' : '고박 패배';
      case GameEndState.autoWin:
        return isWinner ? '자동 승리!' : '자동 패배';
      case GameEndState.none:
        return '';
    }
  }

  Color _getResultColor() {
    // 光끼 모드 특별 색상 (불꽃색)
    if (isGwangkkiMode) {
      return isWinner ? const Color(0xFFFF6347) : const Color(0xFF8B0000);
    }

    switch (endState) {
      case GameEndState.win:
      case GameEndState.chongtong:
      case GameEndState.gobak:
      case GameEndState.autoWin:
        return isWinner ? AppColors.accent : AppColors.error;
      case GameEndState.nagari:
        return AppColors.textSecondary;
      case GameEndState.none:
        return AppColors.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // 다이얼로그 최대 높이를 화면의 85%로 제한
    final maxDialogHeight = screenHeight * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: maxDialogHeight,
        ),
        decoration: BoxDecoration(
          color: AppColors.woodDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.woodLight,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 0,
              offset: const Offset(8, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 결과 타이틀 (고정)
            Text(
              _getResultTitle(),
              style: TextStyle(
                color: _getResultColor(),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 스크롤 가능한 컨텐츠 영역
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 최종 점수
                    if (endState != GameEndState.nagari) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: _getResultColor().withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$finalScore점',
                          style: TextStyle(
                            color: _getResultColor(),
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 코인 획득/손실 표시
                      if (coinChange != null && coinChange! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isWinner
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isWinner
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : Colors.red.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                isWinner ? '+$coinChange' : '-$coinChange',
                                style: TextStyle(
                                  color: isWinner ? Colors.amber : Colors.redAccent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isWinner ? '획득' : '잃음',
                                style: TextStyle(
                                  color: isWinner
                                      ? Colors.amber.withValues(alpha: 0.8)
                                      : Colors.redAccent.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 光끼 모드 Winner takes ALL 메시지
                      if (isGwangkkiMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4500), Color(0xFFFF6347)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4500).withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                isWinner ? 'Winner takes ALL!' : '모든 코인을 잃었습니다!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('🔥', style: TextStyle(fontSize: 18)),
                            ],
                          ),
                        ),
                      if (isGwangkkiMode) const SizedBox(height: 16),
                    ],

                    // 점수 상세 내역 (승자/패자 모두 표시)
                    if (scoreDetail != null) ...[
                      _buildScoreDetailSection(),
                      const SizedBox(height: 16),
                    ],

                    // 나가리 메시지
                    if (endState == GameEndState.nagari)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          '양측 모두 7점 미만으로\n게임이 무승부 처리되었습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),

                    // 고박 메시지
                    if (endState == GameEndState.gobak)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          isWinner
                              ? '상대방이 고를 선언한 상태에서\n7점에 도달하여 고박 승리!'
                              : '고를 선언한 상태에서\n상대방이 7점에 도달하여 고박 패배',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),

                    // 자동 승리 메시지
                    if (endState == GameEndState.autoWin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          isWinner
                              ? '고를 선언한 상태에서 덱이 소진되어\n자동 승리!'
                              : '상대방이 고를 선언한 상태에서\n덱이 소진되어 자동 패배',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 버튼 영역 (항상 고정)
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// 점수 상세 내역 섹션
  Widget _buildScoreDetailSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.woodLight.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isWinner ? '점수 내역' : '상대방 점수 내역',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: AppColors.textSecondary, height: 1),
          const SizedBox(height: 6),

          // 기본 점수 상세 (컴팩트)
          ...scoreDetail!.baseScore.details.map((detail) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  detail.name,
                  style: const TextStyle(color: AppColors.text, fontSize: 12),
                ),
                Text(
                  '+${detail.points}점',
                  style: const TextStyle(color: AppColors.accent, fontSize: 12),
                ),
              ],
            ),
          )),

          const SizedBox(height: 6),
          const Divider(color: AppColors.textSecondary, height: 1),
          const SizedBox(height: 6),

          // 기본 점수 합계
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '기본 점수',
                style: TextStyle(color: AppColors.text, fontSize: 12),
              ),
              Text(
                '${scoreDetail!.baseScore.baseTotal}점',
                style: const TextStyle(color: AppColors.text, fontSize: 12),
              ),
            ],
          ),

          // 점수 배수 섹션
          if (scoreDetail!.goCount > 0 || scoreDetail!.playerMultiplier > 1 || scoreDetail!.isMeongTta) ...[
            const SizedBox(height: 8),
            const Text(
              '── 점수 배수 ──',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // 고 점수 보너스
          if (scoreDetail!.goCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${scoreDetail!.goCount}고',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  scoreDetail!.goAdditive > 0
                      ? '+${scoreDetail!.goAdditive}점'
                      : 'x${scoreDetail!.goMultiplier}',
                  style: const TextStyle(color: AppColors.accent, fontSize: 11),
                ),
              ],
            ),
          ],

          // 흔들기/폭탄 배수
          if (scoreDetail!.playerMultiplier > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '흔들기/폭탄',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  'x${scoreDetail!.playerMultiplier}',
                  style: const TextStyle(color: AppColors.accent, fontSize: 11),
                ),
              ],
            ),
          ],

          // 멍따
          if (scoreDetail!.isMeongTta) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '멍따 (열끗 7장+)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  'x2',
                  style: TextStyle(color: AppColors.accent, fontSize: 11),
                ),
              ],
            ),
          ],

          // 코인 정산 내역
          if (isWinner) ...[
            // 승자: 3인 고스톱 정산 또는 2인 맞고 코인 정산
            if (gostopSettlement != null) ...[
              const SizedBox(height: 8),
              _buildGostopSettlementSection(),
            ] else if (scoreDetail!.isPiBak || scoreDetail!.isGwangBak || scoreDetail!.isGobak) ...[
              const SizedBox(height: 8),
              _buildBakPenaltySection(),
            ] else if (coinChange != null && coinChange! > 0) ...[
              // 박이 없는 맞고 승자의 기본 코인 정산 내역
              const SizedBox(height: 8),
              _buildMatgoWinnerSettlement(),
            ],
          ] else ...[
            // 패자: 내가 지불한 코인 정산 내역
            const SizedBox(height: 8),
            _buildLoserSettlementSection(),
            // 패배로 인한 광끼 게이지 축적 메시지
            if (kwangkkiGained != null && kwangkkiGained! > 0 && !isGwangkkiMode)
              _buildKwangkkiGainedMessage(),
          ],
        ],
      ),
    );
  }

  /// 패배로 인한 광끼 게이지 축적 메시지
  Widget _buildKwangkkiGainedMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade900.withValues(alpha: 0.3),
              Colors.red.shade900.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '패배로 +$kwangkkiGained점의 광끼게이지가 축적되었습니다.',
                style: TextStyle(
                  color: Colors.orange.shade300,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3인 고스톱 코인 정산 내역
  Widget _buildGostopSettlementSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🪙', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '코인 정산 내역',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 패자별 정산 내역
          ...gostopSettlement!.loserDetails.map((loser) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loser.loserDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (loser.hasPenalty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          loser.penaltyDescriptions.join(' + '),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${loser.multiplier}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    '박 없음',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loser.baseAmount}점 x ${loser.multiplier}배',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '+${loser.actualTransfer} 코인',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (gostopSettlement!.loserDetails.indexOf(loser) <
                    gostopSettlement!.loserDetails.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
              ],
            ),
          )),
          // 총 정산액
          const Divider(color: Colors.white38, height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '총 획득',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '+${gostopSettlement!.totalTransfer} 코인',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2인 모드 박 패널티 섹션 (승자용)
  Widget _buildBakPenaltySection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🪙', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '코인 정산 배수',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (scoreDetail!.isGwangBak) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '광박 (광 0장)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  'x2 코인',
                  style: TextStyle(color: AppColors.error, fontSize: 11),
                ),
              ],
            ),
          ],
          if (scoreDetail!.isPiBak) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '피박',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  'x2 코인',
                  style: TextStyle(color: AppColors.error, fontSize: 11),
                ),
              ],
            ),
          ],
          if (scoreDetail!.isGobak) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '고박',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                Text(
                  'x2 코인',
                  style: TextStyle(color: AppColors.error, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 2인 맞고 승자 기본 코인 정산 (박이 없을 때)
  Widget _buildMatgoWinnerSettlement() {
    final multiplier = scoreDetail?.playerMultiplier ?? 1;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🪙', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '코인 정산 내역',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 기본 점수
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '점수',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '$finalScore점',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          // 흔들기/폭탄 배수
          if (multiplier > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '흔들기/폭탄',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'x$multiplier',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],

          const Divider(color: Colors.white38, height: 8),

          // 총 획득 코인
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '총 획득',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '+$coinChange 코인',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 패자 코인 정산 내역 섹션
  Widget _buildLoserSettlementSection() {
    // loserSettlement가 있으면 상세 정보 표시, 없으면 scoreDetail 기반 표시
    if (loserSettlement != null) {
      return _buildDetailedLoserSettlement();
    } else if (scoreDetail != null && coinChange != null && coinChange! > 0) {
      return _buildSimpleLoserSettlement();
    }
    return const SizedBox.shrink();
  }

  /// 상세 패자 정산 내역 (LoserSettlementDetail 기반)
  Widget _buildDetailedLoserSettlement() {
    final settlement = loserSettlement!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🪙', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '내 코인 정산 내역',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 박 패널티 표시
          if (settlement.hasPenalty) ...[
            ...settlement.penaltyDescriptions.map((penalty) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    penalty,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const Text(
                    'x2 코인',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )),
            const Divider(color: Colors.white24, height: 8),
          ],

          // 정산 계산 내역
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '기본 점수',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '${settlement.baseAmount}점',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (settlement.multiplier > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '배수 적용',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'x${settlement.multiplier}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          const Divider(color: Colors.white38, height: 8),

          // 최종 지불 금액
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '승자에게 지급',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '-${settlement.actualTransfer} 코인',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 간단한 패자 정산 내역 (scoreDetail + coinChange 기반)
  Widget _buildSimpleLoserSettlement() {
    final hasPenalty = scoreDetail!.isPiBak || scoreDetail!.isGwangBak || scoreDetail!.isGobak;
    final multiplier = scoreDetail!.coinSettlementMultiplier;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🪙', style: TextStyle(fontSize: 11)),
              SizedBox(width: 4),
              Text(
                '내 코인 정산 내역',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 박 패널티 표시
          if (hasPenalty) ...[
            if (scoreDetail!.isGwangBak)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '광박 (광 0장)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  Text(
                    'x2 코인',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ],
              ),
            if (scoreDetail!.isPiBak)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '피박',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  Text(
                    'x2 코인',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ],
              ),
            if (scoreDetail!.isGobak)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '고박',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  Text(
                    'x2 코인',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ],
              ),
            const Divider(color: Colors.white24, height: 8),
          ],

          // 정산 계산 내역
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '상대방 점수',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '$finalScore점',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (multiplier > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '배수 적용',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'x$multiplier',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          const Divider(color: Colors.white38, height: 8),

          // 최종 지불 금액
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '승자에게 지급',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '-$coinChange 코인',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 액션 버튼 섹션
  Widget _buildActionButtons() {
    if (isGwangkkiMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 光끼 모드: 재대결 불가 메시지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF4500).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⚠️', style: TextStyle(fontSize: 12)),
                SizedBox(width: 6),
                Text(
                  '光끼 게임은 재대결이 불가능합니다',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // 나가기 버튼만 표시
          SizedBox(
            width: 180,
            child: RetroButton(
              text: '나가기',
              color: AppColors.primary,
              onPressed: onExit,
              width: null,
              height: 48,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else {
      // 일반 게임: 나가기 + 재대결 버튼
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: RetroButton(
                text: '나가기',
                color: AppColors.woodLight,
                textColor: AppColors.text,
                onPressed: onExit,
                width: null,
                height: 48,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: RetroButton(
                text: '재대결',
                color: AppColors.primary,
                onPressed: onRematch,
                width: null,
                height: 48,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }
  }
}
