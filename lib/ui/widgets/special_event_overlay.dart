import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../models/game_room.dart';

/// 특수 이벤트 알림 오버레이
class SpecialEventOverlay extends StatefulWidget {
  final SpecialEvent event;
  final bool isMyEvent;
  final VoidCallback onDismiss;

  const SpecialEventOverlay({
    super.key,
    required this.event,
    required this.isMyEvent,
    required this.onDismiss,
  });

  @override
  State<SpecialEventOverlay> createState() => _SpecialEventOverlayState();
}

class _SpecialEventOverlayState extends State<SpecialEventOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
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

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getEventText() {
    switch (widget.event) {
      case SpecialEvent.puk:
        return '뻑!';
      case SpecialEvent.jaPuk:
        return '자뻑!';
      case SpecialEvent.ttadak:
        return '따닥!';
      case SpecialEvent.kiss:
        return '쪽!';
      case SpecialEvent.sweep:
        return '싹쓸이!';
      case SpecialEvent.sulsa:
        return '설사!';
      case SpecialEvent.shake:
        return '흔들기!';
      case SpecialEvent.bomb:
        return '폭탄!';
      case SpecialEvent.chongtong:
        return '총통!';
      case SpecialEvent.bonusCardUsed:
        return '보너스패 사용!';
      case SpecialEvent.none:
        return '';
    }
  }

  String _getEventDescription() {
    switch (widget.event) {
      case SpecialEvent.puk:
        return '카드가 바닥에 쌓입니다';
      case SpecialEvent.jaPuk:
        return '피 2장 뺏기!';
      case SpecialEvent.ttadak:
        return '2쌍 매칭! 피 1장 뺏기';
      case SpecialEvent.kiss:
        return '쪽 맞음! 피 1장 뺏기';
      case SpecialEvent.sweep:
        return '바닥 싹쓸이! 피 1장 뺏기';
      case SpecialEvent.sulsa:
        return '3장 매칭! 피 1장 뺏기';
      case SpecialEvent.shake:
        return '배수 2배 적용!';
      case SpecialEvent.bomb:
        return '4장 한번에! 배수 2배';
      case SpecialEvent.chongtong:
        return '같은 월 4장!';
      case SpecialEvent.bonusCardUsed:
        return '쌍피 효과로 점수 획득!';
      case SpecialEvent.none:
        return '';
    }
  }

  Color _getEventColor() {
    switch (widget.event) {
      case SpecialEvent.puk:
        return Colors.orange;
      case SpecialEvent.jaPuk:
        return Colors.red;
      case SpecialEvent.ttadak:
        return Colors.purple;
      case SpecialEvent.kiss:
        return Colors.pink;
      case SpecialEvent.sweep:
        return Colors.blue;
      case SpecialEvent.sulsa:
        return Colors.green;
      case SpecialEvent.shake:
        return Colors.amber;
      case SpecialEvent.bomb:
        return Colors.deepOrange;
      case SpecialEvent.chongtong:
        return AppColors.accent;
      case SpecialEvent.bonusCardUsed:
        return Colors.teal;
      case SpecialEvent.none:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event == SpecialEvent.none) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                decoration: BoxDecoration(
                  color: _getEventColor().withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getEventColor().withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getEventText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getEventDescription(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.isMyEvent)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '내가 발동!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
