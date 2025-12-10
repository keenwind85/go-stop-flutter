import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// 화면 크기가 최적화 기준보다 작을 경우 경고 오버레이를 표시하는 위젯
class ScreenSizeWarningOverlay extends StatelessWidget {
  final Widget child;
  final double minWidth;
  final double minHeight;

  const ScreenSizeWarningOverlay({
    super.key,
    required this.child,
    this.minWidth = 360.0,
    this.minHeight = 700.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isTooSmall = width < minWidth || height < minHeight;

        return Stack(
          children: [
            // 메인 콘텐츠
            child,

            // 경고 오버레이
            if (isTooSmall)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.screen_rotation,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '화면 크기 최적화 필요',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '원활한 게임 진행을 위해\n브라우저의 가로, 세로 사이즈를 늘려주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildSizeRow('현재 크기', width, height),
                                const SizedBox(height: 4),
                                _buildSizeRow('최소 크기', minWidth, minHeight),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSizeRow(String label, double w, double h) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        Text(
          '${w.toInt()} x ${h.toInt()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
