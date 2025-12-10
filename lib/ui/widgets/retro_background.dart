import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/constants.dart';

class RetroBackground extends StatelessWidget {
  final Widget? child;
  final Color? baseColor;

  const RetroBackground({
    super.key,
    this.child,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Gradient Layer
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: baseColor != null
                  ? [
                      Color.lerp(baseColor, Colors.white, 0.1)!, // Slightly lighter
                      baseColor!,
                      Color.lerp(baseColor, Colors.black, 0.2)!, // Slightly darker
                    ]
                  : [
                      AppColors.primaryLight, // 중앙은 약간 밝게
                      AppColors.primary,      // 중간은 기본 모포색
                      AppColors.primaryDark,  // 외곽은 어둡게
                    ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // 2. Noise Texture Layer (Custom Painter)
        Opacity(
          opacity: 0.15, // 노이즈 강도 조절
          child: CustomPaint(
            painter: _NoisePainter(),
            size: Size.infinite,
          ),
        ),

        // 3. Vignette Effect (테두리 어둡게)
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
              ],
              stops: const [0.7, 1.0],
            ),
          ),
        ),

        // 4. Content
        if (child != null) child!,
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  final Random _random = Random();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // 픽셀 단위로 노이즈를 그리면 성능 이슈가 있을 수 있으므로,
    // 작은 점들을 무작위로 찍어서 질감을 표현
    for (int i = 0; i < 5000; i++) {
      paint.color = Colors.white.withValues(alpha: _random.nextDouble() * 0.2);
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
      
      paint.color = Colors.black.withValues(alpha: _random.nextDouble() * 0.2);
      final x2 = _random.nextDouble() * size.width;
      final y2 = _random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x2, y2), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
