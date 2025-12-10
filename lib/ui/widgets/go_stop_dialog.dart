import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// Go/Stop 선택 다이얼로그
class GoStopDialog extends StatelessWidget {
  final int currentScore;
  final int goCount;
  final VoidCallback onGo;
  final VoidCallback onStop;

  const GoStopDialog({
    super.key,
    required this.currentScore,
    required this.goCount,
    required this.onGo,
    required this.onStop,
  });

  String _getGoMultiplierText() {
    if (goCount == 0) return '(다음 고: 2배)';
    if (goCount == 1) return '(다음 고: 4배)';
    if (goCount == 2) return '(다음 고: 5배)';
    return '(다음 고: ${4 + goCount - 1}배)';
  }

  String _getCurrentMultiplierText() {
    if (goCount == 0) return '';
    if (goCount == 1) return '현재 2배';
    if (goCount == 2) return '현재 4배';
    return '현재 ${4 + goCount - 2}배';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 타이틀
            const Text(
              '7점 이상!',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 현재 점수
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '$currentScore점',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (goCount > 0)
                    Text(
                      _getCurrentMultiplierText(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 선택 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Go 버튼
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ElevatedButton(
                      onPressed: onGo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'GO',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getGoMultiplierText(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stop 버튼
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ElevatedButton(
                      onPressed: onStop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'STOP',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '승리 확정',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
