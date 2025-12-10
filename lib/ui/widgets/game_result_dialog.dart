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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
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
            // 결과 타이틀
            Text(
              _getResultTitle(),
              style: TextStyle(
                color: _getResultColor(),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

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
              Container(
                padding: const EdgeInsets.all(16),
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: AppColors.textSecondary),
                    const SizedBox(height: 8),

                    // 기본 점수 상세
                    ...scoreDetail!.baseScore.details.map((detail) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            detail.name,
                            style: const TextStyle(color: AppColors.text),
                          ),
                          Text(
                            '+${detail.points}점',
                            style: const TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    )),

                    const SizedBox(height: 8),
                    const Divider(color: AppColors.textSecondary),
                    const SizedBox(height: 8),

                    // 기본 점수 합계
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '기본 점수',
                          style: TextStyle(color: AppColors.text),
                        ),
                        Text(
                          '${scoreDetail!.baseScore.baseTotal}점',
                          style: const TextStyle(color: AppColors.text),
                        ),
                      ],
                    ),

                    // 배수 적용
                    if (scoreDetail!.goCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${scoreDetail!.goCount}고 배수',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            'x${scoreDetail!.goMultiplier}',
                            style: const TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ],

                    if (scoreDetail!.isPiBak) ...[
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '피박',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            'x2',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ],

                    if (scoreDetail!.isGwangBak) ...[
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '광박',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            'x2',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ],

                    if (scoreDetail!.isMeongTtarigi) ...[
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '멍따리기',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            'x2',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ],

                    if (scoreDetail!.playerMultiplier > 1) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '흔들기/폭탄',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            'x${scoreDetail!.playerMultiplier}',
                            style: const TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 나가리 메시지
            if (endState == GameEndState.nagari)
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
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
                padding: const EdgeInsets.only(bottom: 24),
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
                padding: const EdgeInsets.only(bottom: 24),
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

            // 버튼
            if (isGwangkkiMode) ...[
              // 光끼 모드: 재대결 불가 메시지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
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
                    Text('⚠️', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 8),
                    Text(
                      '光끼 게임은 재대결이 불가능합니다',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // 나가기 버튼만 표시
              SizedBox(
                width: 200,
                child: RetroButton(
                  text: '나가기',
                  color: AppColors.primary,
                  onPressed: onExit,
                  width: null,
                  height: 56,
                  fontSize: 16,
                ),
              ),
            ] else ...[
              // 일반 게임: 나가기 + 재대결 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: RetroButton(
                        text: '나가기',
                        color: AppColors.woodLight,
                        textColor: AppColors.text,
                        onPressed: onExit,
                        width: null,
                        height: 56,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: RetroButton(
                        text: '재대결',
                        color: AppColors.primary,
                        onPressed: onRematch,
                        width: null,
                        height: 56,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
