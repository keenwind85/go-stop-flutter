import 'package:flutter/material.dart';
import '../../models/item_data.dart';

/// 아이템 사용 시 화면에 표시되는 오버레이 애니메이션
class ItemUseOverlay extends StatefulWidget {
  final String playerName;
  final ItemType itemType;
  final VoidCallback onComplete;

  const ItemUseOverlay({
    super.key,
    required this.playerName,
    required this.itemType,
    required this.onComplete,
  });

  @override
  State<ItemUseOverlay> createState() => _ItemUseOverlayState();
}

class _ItemUseOverlayState extends State<ItemUseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 페이드 인/아웃
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_controller);

    // 스케일 애니메이션
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.1).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8),
        weight: 20,
      ),
    ]).animate(_controller);

    // 슬라이드 애니메이션
    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: Offset.zero),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -0.3)),
        weight: 20,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = ItemData.getItem(widget.itemType);

    return Material(
      color: Colors.black.withOpacity(0.7),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.indigo.shade800,
                          Colors.purple.shade900,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.shade400,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 플레이어 이름
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '✨',
                              style: TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.playerName}님이',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '✨',
                              style: TextStyle(fontSize: 24),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 아이템 아이콘
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.amber.shade300,
                                Colors.amber.shade700,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              item.iconEmoji,
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 아이템 이름
                        Text(
                          item.name,
                          style: TextStyle(
                            color: Colors.amber.shade400,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 사용 텍스트
                        const Text(
                          '을(를) 사용하였습니다!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 아이템 설명
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.shortDesc,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
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
      ),
    );
  }
}

/// 아이템 사용 오버레이 표시 함수
void showItemUseOverlay({
  required BuildContext context,
  required String playerName,
  required ItemType itemType,
  required VoidCallback onComplete,
}) {
  OverlayEntry? overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => ItemUseOverlay(
      playerName: playerName,
      itemType: itemType,
      onComplete: () {
        overlayEntry?.remove();
        onComplete();
      },
    ),
  );

  Overlay.of(context).insert(overlayEntry);
}
