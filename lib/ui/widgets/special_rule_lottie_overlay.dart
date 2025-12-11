import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../models/game_room.dart';

/// 특수 룰 발생 시 바닥 카드 위에 표시되는 로티 애니메이션 오버레이
///
/// - 따닥: Tap Burst 애니메이션
/// - 뻑/자뻑: Poop 애니메이션
/// - 쪽: Kiss 애니메이션
/// - 싹쓸이: Wind 애니메이션 (바닥판 전체)
/// - 설사: grab 애니메이션 (3장 카드 위)
class SpecialRuleLottieOverlay extends StatefulWidget {
  final SpecialEvent event;
  final List<Offset> positions; // 애니메이션을 표시할 위치들
  final VoidCallback onComplete;
  final double size;

  const SpecialRuleLottieOverlay({
    super.key,
    required this.event,
    required this.positions,
    required this.onComplete,
    this.size = 100,
  });

  @override
  State<SpecialRuleLottieOverlay> createState() => _SpecialRuleLottieOverlayState();
}

class _SpecialRuleLottieOverlayState extends State<SpecialRuleLottieOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _lottieAsset {
    switch (widget.event) {
      case SpecialEvent.ttadak:
        return 'assets/etc/Tap Burst.json';
      case SpecialEvent.puk:
      case SpecialEvent.jaPuk:
        return 'assets/etc/Poop.json';
      case SpecialEvent.kiss:
        return 'assets/etc/Kiss.json';
      case SpecialEvent.sweep:
        return 'assets/etc/Wind.json';
      case SpecialEvent.sulsa:
        return 'assets/etc/grab.json';
      default:
        return null;
    }
  }

  /// 이벤트 타입에 따른 애니메이션 크기
  double get _animationSize {
    switch (widget.event) {
      case SpecialEvent.sweep:
        return 200; // 싹쓸이는 바닥판 전체를 덮는 큰 애니메이션
      default:
        return widget.size;
    }
  }

  void _onAnimationComplete() {
    if (!_animationCompleted) {
      _animationCompleted = true;
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _lottieAsset;
    final size = _animationSize;
    if (asset == null || widget.positions.isEmpty) {
      // 지원하지 않는 이벤트거나 위치가 없으면 즉시 완료
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onAnimationComplete();
      });
      return const SizedBox.shrink();
    }

    return Stack(
      children: widget.positions.map((position) {
        return Positioned(
          left: position.dx - size / 2,
          top: position.dy - size / 2,
          child: SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              asset,
              controller: _controller,
              fit: BoxFit.contain,
              repeat: false,
              onLoaded: (composition) {
                _controller.duration = composition.duration;
                _controller.forward().then((_) {
                  _onAnimationComplete();
                });
              },
              errorBuilder: (context, error, stackTrace) {
                // 로티 로드 실패 시 즉시 완료
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onAnimationComplete();
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 여러 위치에 동일한 애니메이션을 표시하는 멀티 로티 오버레이
/// (뻑 발생 시 3장의 카드 위에 동시에 표시할 때 사용)
class MultiPositionLottieOverlay extends StatefulWidget {
  final String assetPath;
  final List<Offset> positions;
  final VoidCallback onComplete;
  final double size;

  const MultiPositionLottieOverlay({
    super.key,
    required this.assetPath,
    required this.positions,
    required this.onComplete,
    this.size = 100,
  });

  @override
  State<MultiPositionLottieOverlay> createState() => _MultiPositionLottieOverlayState();
}

class _MultiPositionLottieOverlayState extends State<MultiPositionLottieOverlay> {
  int _completedCount = 0;

  void _onSingleComplete() {
    _completedCount++;
    // 모든 애니메이션이 완료되면 콜백 호출
    if (_completedCount >= widget.positions.length) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.positions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete();
      });
      return const SizedBox.shrink();
    }

    return Stack(
      children: widget.positions.map((position) {
        return Positioned(
          left: position.dx - widget.size / 2,
          top: position.dy - widget.size / 2,
          child: _SingleLottieAnimation(
            assetPath: widget.assetPath,
            size: widget.size,
            onComplete: _onSingleComplete,
          ),
        );
      }).toList(),
    );
  }
}

class _SingleLottieAnimation extends StatefulWidget {
  final String assetPath;
  final double size;
  final VoidCallback onComplete;

  const _SingleLottieAnimation({
    required this.assetPath,
    required this.size,
    required this.onComplete,
  });

  @override
  State<_SingleLottieAnimation> createState() => _SingleLottieAnimationState();
}

class _SingleLottieAnimationState extends State<_SingleLottieAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    if (!_completed) {
      _completed = true;
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        widget.assetPath,
        controller: _controller,
        fit: BoxFit.contain,
        repeat: false,
        onLoaded: (composition) {
          _controller.duration = composition.duration;
          _controller.forward().then((_) {
            _complete();
          });
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _complete();
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
