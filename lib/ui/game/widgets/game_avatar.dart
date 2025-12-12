import 'package:flutter/material.dart';

/// 아바타 상태 정의
enum AvatarState {
  normal,   // 기본 (0~3턴)
  turn4,    // 4턴 이후 기본
  winning,  // 이기는 중 (1점 이상 앞서는 경우)
  losing,   // 지는 중 (1점 이상 뒤지는 경우)
  mad,      // 광끼 모드 (최우선)
}

/// 아바타 상태 결정 함수
AvatarState determineAvatarState({
  required bool isGwangkkiMode,
  required int myScore,
  required int opponentScore,
  required int turnCount,
}) {
  // 1. 광끼 모드 최우선
  if (isGwangkkiMode) {
    return AvatarState.mad;
  }

  // 2. 점수 차이에 따른 상태 (점수가 발생한 경우에만)
  final scoreDiff = myScore - opponentScore;
  if (myScore > 0 || opponentScore > 0) {
    if (scoreDiff >= 1) {
      return AvatarState.winning;
    } else if (scoreDiff <= -1) {
      return AvatarState.losing;
    }
  }

  // 3. 4턴 이후 기본 상태
  if (turnCount >= 4) {
    return AvatarState.turn4;
  }

  // 4. 초기 상태
  return AvatarState.normal;
}

/// 턴 카운트 계산 (덱 카드 수 기반)
int calculateTurnCount(int deckCount) {
  // 초기: 24장, 1턴 후: 22장, 2턴 후: 20장...
  return (24 - deckCount) ~/ 2;
}

/// 게임 아바타 위젯
class GameAvatar extends StatefulWidget {
  final bool isHost;
  final AvatarState state;
  final double size;
  final bool showBorderAnimation;

  const GameAvatar({
    super.key,
    required this.isHost,
    required this.state,
    this.size = 40,
    this.showBorderAnimation = true,
  });

  @override
  State<GameAvatar> createState() => _GameAvatarState();
}

class _GameAvatarState extends State<GameAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAnimationIfNeeded();
  }

  @override
  void didUpdateWidget(GameAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _startAnimationIfNeeded();
    }
  }

  void _startAnimationIfNeeded() {
    // 애니메이션이 필요한 상태에서만 반복
    if (_shouldAnimate(widget.state)) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  bool _shouldAnimate(AvatarState state) {
    return state == AvatarState.winning ||
        state == AvatarState.losing ||
        state == AvatarState.mad;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getAvatarAssetPath() {
    final prefix = widget.isHost ? 'Host' : 'Guest';
    final suffix = switch (widget.state) {
      AvatarState.normal => 'normal',
      AvatarState.turn4 => '4turn',
      AvatarState.winning => 'win',
      AvatarState.losing => 'lose',
      AvatarState.mad => 'mad',
    };
    return 'assets/avatar/$prefix-$suffix.png';
  }

  Color _getBorderColor() {
    return switch (widget.state) {
      AvatarState.normal => Colors.grey.shade400,
      AvatarState.turn4 => Colors.blueGrey.shade400,
      AvatarState.winning => Colors.amber,
      AvatarState.losing => Colors.blue.shade400,
      AvatarState.mad => Colors.deepOrange,
    };
  }

  Color _getGlowColor() {
    return switch (widget.state) {
      AvatarState.normal => Colors.transparent,
      AvatarState.turn4 => Colors.transparent,
      AvatarState.winning => Colors.amber.withValues(alpha: 0.6),
      AvatarState.losing => Colors.blue.withValues(alpha: 0.5),
      AvatarState.mad => Colors.deepOrange.withValues(alpha: 0.7),
    };
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();
    final glowColor = _getGlowColor();
    final assetPath = _getAvatarAssetPath();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseValue = _shouldAnimate(widget.state) ? _pulseAnimation.value : 0.0;

        // 광끼 모드는 더 강한 효과
        final isMad = widget.state == AvatarState.mad;
        final borderWidth = isMad ? 3.0 + (pulseValue * 1.5) : 2.0 + (pulseValue * 0.5);
        final glowSpread = isMad ? 4.0 + (pulseValue * 4.0) : 2.0 + (pulseValue * 2.0);
        final glowBlur = isMad ? 8.0 + (pulseValue * 8.0) : 4.0 + (pulseValue * 4.0);

        // 광끼 모드 색상 변화
        Color animatedBorderColor = borderColor;
        if (isMad) {
          animatedBorderColor = Color.lerp(
            Colors.deepOrange,
            Colors.red,
            pulseValue,
          )!;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: animatedBorderColor,
              width: borderWidth,
            ),
            boxShadow: widget.showBorderAnimation && _shouldAnimate(widget.state)
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: glowColor.a * (0.5 + pulseValue * 0.5)),
                      blurRadius: glowBlur,
                      spreadRadius: glowSpread,
                    ),
                    if (isMad) ...[
                      // 광끼 모드 추가 불꽃 효과
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3 * pulseValue),
                        blurRadius: 12 + (pulseValue * 8),
                        spreadRadius: 2 + (pulseValue * 3),
                      ),
                    ],
                  ]
                : null,
          ),
          child: ClipOval(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                assetPath,
                key: ValueKey(assetPath),
                width: widget.size - 4,
                height: widget.size - 4,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade800,
                  child: Icon(
                    Icons.person,
                    size: widget.size * 0.6,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 아바타 프리로딩 유틸리티
class AvatarPreloader {
  static final List<String> _avatarPaths = [
    'assets/avatar/Host-normal.png',
    'assets/avatar/Host-4turn.png',
    'assets/avatar/Host-win.png',
    'assets/avatar/Host-lose.png',
    'assets/avatar/Host-mad.png',
    'assets/avatar/Guest-normal.png',
    'assets/avatar/Guest-4turn.png',
    'assets/avatar/Guest-win.png',
    'assets/avatar/Guest-lose.png',
    'assets/avatar/Guest-mad.png',
  ];

  static bool _preloaded = false;

  /// 모든 아바타 PNG 프리로드
  static Future<void> preloadAll(BuildContext context) async {
    if (_preloaded) return;

    for (final path in _avatarPaths) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (e) {
        debugPrint('[AvatarPreloader] Failed to preload $path: $e');
      }
    }

    _preloaded = true;
    debugPrint('[AvatarPreloader] All avatars preloaded');
  }
}
