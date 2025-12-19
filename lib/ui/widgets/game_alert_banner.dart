import 'dart:async';
import 'package:flutter/material.dart';

/// 게임 얼럿 메시지 타입
enum GameAlertType {
  gameStart,      // 게임 시작 (10초 후 사라짐)
  persistent,     // 지속 얼럿 (고, 흔들기, 폭탄, 멍따)
  oneTime,        // 1회성 얼럿 (고도리, 단, 광, 피/띠/열끗 달성)
}

/// 지속 얼럿 종류
enum PersistentAlertKind {
  go,             // N고 진행 중
  shake,          // 흔들기 선언
  bomb,           // 폭탄
  meongTta,       // 멍따
}

/// 1회성 얼럿 종류
enum OneTimeAlertKind {
  godori,         // 고도리
  hongdan,        // 홍단
  cheongdan,      // 청단
  chodan,         // 초단
  samgwang,       // 삼광
  bigwangSamgwang,// 비광삼광
  sagwang,        // 사광
  bigwangSagwang, // 비광사광
  ogwang,         // 오광
  pi10,           // 피 10장
  tti5,           // 띠 5장
  animal5,        // 열끗 5장
}

/// 게임 얼럿 메시지 데이터
class GameAlertMessage {
  final String id;
  final GameAlertType type;
  final String playerName;
  final String message;
  final String? suffix;       // 점수 표시 (예: "+3점 획득")
  final PersistentAlertKind? persistentKind;
  final OneTimeAlertKind? oneTimeKind;
  final int? goCount;         // 고 횟수
  final int? month;           // 월 (흔들기/폭탄용)
  final int? score;           // 점수
  final int? multiplier;      // 배수
  final DateTime createdAt;
  final bool isShown;         // 1회성 메시지가 이미 표시되었는지

  GameAlertMessage({
    required this.id,
    required this.type,
    required this.playerName,
    required this.message,
    this.suffix,
    this.persistentKind,
    this.oneTimeKind,
    this.goCount,
    this.month,
    this.score,
    this.multiplier,
    DateTime? createdAt,
    this.isShown = false,
  }) : createdAt = createdAt ?? DateTime.now();

  GameAlertMessage copyWith({
    String? id,
    GameAlertType? type,
    String? playerName,
    String? message,
    String? suffix,
    PersistentAlertKind? persistentKind,
    OneTimeAlertKind? oneTimeKind,
    int? goCount,
    int? month,
    int? score,
    int? multiplier,
    DateTime? createdAt,
    bool? isShown,
  }) {
    return GameAlertMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      playerName: playerName ?? this.playerName,
      message: message ?? this.message,
      suffix: suffix ?? this.suffix,
      persistentKind: persistentKind ?? this.persistentKind,
      oneTimeKind: oneTimeKind ?? this.oneTimeKind,
      goCount: goCount ?? this.goCount,
      month: month ?? this.month,
      score: score ?? this.score,
      multiplier: multiplier ?? this.multiplier,
      createdAt: createdAt ?? this.createdAt,
      isShown: isShown ?? this.isShown,
    );
  }

  /// 고유 키 생성 (중복 체크용)
  String get uniqueKey {
    if (type == GameAlertType.persistent && persistentKind != null) {
      return '${playerName}_${persistentKind!.name}';
    }
    if (type == GameAlertType.oneTime && oneTimeKind != null) {
      return '${playerName}_${oneTimeKind!.name}';
    }
    return id;
  }
}

/// 게임 얼럿 배너 위젯
class GameAlertBanner extends StatefulWidget {
  final List<GameAlertMessage> persistentAlerts;  // 지속 얼럿들
  final GameAlertMessage? currentOneTimeAlert;    // 현재 1회성 얼럿
  final GameAlertMessage? gameStartAlert;         // 게임 시작 얼럿
  final VoidCallback? onGameStartDismiss;
  final Function(String)? onOneTimeAlertDismiss;

  const GameAlertBanner({
    super.key,
    this.persistentAlerts = const [],
    this.currentOneTimeAlert,
    this.gameStartAlert,
    this.onGameStartDismiss,
    this.onOneTimeAlertDismiss,
  });

  @override
  State<GameAlertBanner> createState() => _GameAlertBannerState();
}

class _GameAlertBannerState extends State<GameAlertBanner>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _currentPersistentIndex = 0;
  Timer? _rollingTimer;
  Timer? _gameStartTimer;
  Timer? _oneTimeTimer;

  // 이전 얼럿 개수 추적 (턴 변경과 무관하게 타이머 유지)
  int _lastKnownAlertCount = 0;
  bool _isRollingActive = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _lastKnownAlertCount = widget.persistentAlerts.length;
    _startRollingTimerIfNeeded();
    _startGameStartTimer();
    _startOneTimeTimer();
  }

  @override
  void didUpdateWidget(GameAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentCount = widget.persistentAlerts.length;

    // 얼럿 개수가 실제로 변경된 경우에만 처리
    if (currentCount != _lastKnownAlertCount) {
      final wasRolling = _lastKnownAlertCount > 1;
      final needsRolling = currentCount > 1;

      // 롤링이 필요없던 상태에서 필요한 상태로 변경된 경우에만 타이머 시작
      if (!wasRolling && needsRolling) {
        _startRollingTimerIfNeeded();
      }
      // 롤링이 필요없어진 경우 타이머 정리
      else if (wasRolling && !needsRolling) {
        _rollingTimer?.cancel();
        _rollingTimer = null;
        _isRollingActive = false;
        _currentPersistentIndex = 0;
      }
      // 롤링 중인데 개수만 변경된 경우 - 인덱스만 조정 (타이머 유지)
      else if (needsRolling && _isRollingActive) {
        if (_currentPersistentIndex >= currentCount) {
          _currentPersistentIndex = currentCount - 1;
        }
      }

      _lastKnownAlertCount = currentCount;
    }

    // 게임 시작 얼럿 변경 시 타이머 재시작
    if (widget.gameStartAlert != oldWidget.gameStartAlert && widget.gameStartAlert != null) {
      _startGameStartTimer();
    }

    // 1회성 얼럿 변경 시 타이머 재시작
    if (widget.currentOneTimeAlert != oldWidget.currentOneTimeAlert && widget.currentOneTimeAlert != null) {
      _startOneTimeTimer();
    }
  }

  /// 롤링 타이머 시작 (필요한 경우에만)
  void _startRollingTimerIfNeeded() {
    if (widget.persistentAlerts.length > 1 && !_isRollingActive) {
      _rollingTimer?.cancel();
      _isRollingActive = true;
      _rollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && widget.persistentAlerts.length > 1) {
          setState(() {
            _currentPersistentIndex = (_currentPersistentIndex + 1) % widget.persistentAlerts.length;
          });
        }
      });
    } else if (widget.persistentAlerts.length <= 1) {
      _rollingTimer?.cancel();
      _rollingTimer = null;
      _isRollingActive = false;
      _currentPersistentIndex = 0;
    }
  }

  void _startGameStartTimer() {
    _gameStartTimer?.cancel();
    if (widget.gameStartAlert != null) {
      _gameStartTimer = Timer(const Duration(seconds: 10), () {
        widget.onGameStartDismiss?.call();
      });
    }
  }

  void _startOneTimeTimer() {
    _oneTimeTimer?.cancel();
    if (widget.currentOneTimeAlert != null) {
      _oneTimeTimer = Timer(const Duration(seconds: 5), () {
        widget.onOneTimeAlertDismiss?.call(widget.currentOneTimeAlert!.id);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rollingTimer?.cancel();
    _gameStartTimer?.cancel();
    _oneTimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 우선순위: 1회성 > 게임 시작 > 지속 얼럿
    GameAlertMessage? alertToShow;

    if (widget.currentOneTimeAlert != null) {
      alertToShow = widget.currentOneTimeAlert;
    } else if (widget.gameStartAlert != null) {
      alertToShow = widget.gameStartAlert;
    } else if (widget.persistentAlerts.isNotEmpty) {
      final validIndex = _currentPersistentIndex.clamp(0, widget.persistentAlerts.length - 1);
      alertToShow = widget.persistentAlerts[validIndex];
    }

    if (alertToShow == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return _buildAlertContainer(alertToShow!);
      },
    );
  }

  Widget _buildAlertContainer(GameAlertMessage alert) {
    final colors = _getAlertColors(alert);
    final icon = _getAlertIcon(alert);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.$1.withValues(alpha: 0.9),
            colors.$2.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _pulseAnimation.value > 0.5 ? colors.$3 : colors.$1,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_pulseAnimation.value > 0.5 ? colors.$3 : colors.$1)
                .withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: _pulseAnimation.value > 0.5 ? colors.$3 : Colors.white,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _buildAlertText(alert),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (alert.suffix != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                alert.suffix!,
                style: TextStyle(
                  color: colors.$3,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildAlertText(GameAlertMessage alert) {
    if (alert.type == GameAlertType.gameStart) {
      return alert.message;
    }

    if (alert.type == GameAlertType.persistent) {
      switch (alert.persistentKind) {
        case PersistentAlertKind.go:
          return '🔔 "${alert.playerName}"님이 "${alert.goCount}"고 진행 중입니다-!';
        case PersistentAlertKind.shake:
          return '🔔 "${alert.playerName}"님이 "${alert.month}"월 카드 3장으로 "흔들기"를 선언하였습니다.';
        case PersistentAlertKind.bomb:
          return '🔔 "${alert.playerName}"님이 "${alert.month}"월 카드 4장으로 "폭탄"을 던졌습니다.';
        case PersistentAlertKind.meongTta:
          return '🔔 "${alert.playerName}"님이 "열끗" 카드 7장이상 획득하여 "멍따"상태가 되었습니다.';
        default:
          return alert.message;
      }
    }

    if (alert.type == GameAlertType.oneTime) {
      final name = alert.playerName;
      switch (alert.oneTimeKind) {
        case OneTimeAlertKind.godori:
          return '⚠️ "$name"님 "고도리" 조건 달성!';
        case OneTimeAlertKind.hongdan:
          return '⚠️ "$name"님 "홍단" 조건 달성!';
        case OneTimeAlertKind.cheongdan:
          return '⚠️ "$name"님 "청단" 조건 달성!';
        case OneTimeAlertKind.chodan:
          return '⚠️ "$name"님 "초단" 조건 달성!';
        case OneTimeAlertKind.samgwang:
          return '⚠️ "$name"님 "삼광" 조건 달성!';
        case OneTimeAlertKind.bigwangSamgwang:
          return '⚠️ "$name"님 "비광삼광" 조건 달성!';
        case OneTimeAlertKind.sagwang:
          return '⚠️ "$name"님 "사광" 조건 달성!';
        case OneTimeAlertKind.bigwangSagwang:
          return '⚠️ "$name"님 "비광사광" 조건 달성!';
        case OneTimeAlertKind.ogwang:
          return '⚠️ "$name"님 "오광" 조건 달성!';
        case OneTimeAlertKind.pi10:
          return '⚠️ "$name"님 "피" 10장 달성!';
        case OneTimeAlertKind.tti5:
          return '⚠️ "$name"님 "띠" 5장 달성!';
        case OneTimeAlertKind.animal5:
          return '⚠️ "$name"님 "열끗" 5장 달성!';
        default:
          return alert.message;
      }
    }

    return alert.message;
  }

  /// 얼럿 타입에 따른 색상 반환 (배경1, 배경2, 강조색)
  (Color, Color, Color) _getAlertColors(GameAlertMessage alert) {
    if (alert.type == GameAlertType.gameStart) {
      return (Colors.blue.shade800, Colors.blue.shade600, Colors.cyan);
    }

    if (alert.type == GameAlertType.persistent) {
      switch (alert.persistentKind) {
        case PersistentAlertKind.go:
          return (Colors.purple.shade800, Colors.purple.shade600, Colors.pink);
        case PersistentAlertKind.shake:
          return (Colors.amber.shade800, Colors.amber.shade600, Colors.yellow);
        case PersistentAlertKind.bomb:
          return (Colors.deepOrange.shade800, Colors.deepOrange.shade600, Colors.orange);
        case PersistentAlertKind.meongTta:
          return (Colors.red.shade800, Colors.red.shade600, Colors.yellow);
        default:
          return (Colors.grey.shade800, Colors.grey.shade600, Colors.white);
      }
    }

    if (alert.type == GameAlertType.oneTime) {
      switch (alert.oneTimeKind) {
        case OneTimeAlertKind.godori:
          return (Colors.green.shade800, Colors.green.shade600, Colors.lightGreen);
        case OneTimeAlertKind.hongdan:
          return (Colors.red.shade800, Colors.red.shade600, Colors.pink);
        case OneTimeAlertKind.cheongdan:
          return (Colors.blue.shade800, Colors.blue.shade600, Colors.cyan);
        case OneTimeAlertKind.chodan:
          return (Colors.green.shade800, Colors.green.shade600, Colors.lightGreen);
        case OneTimeAlertKind.samgwang:
        case OneTimeAlertKind.bigwangSamgwang:
        case OneTimeAlertKind.sagwang:
        case OneTimeAlertKind.bigwangSagwang:
        case OneTimeAlertKind.ogwang:
          return (Colors.amber.shade800, Colors.amber.shade600, Colors.yellow);
        case OneTimeAlertKind.pi10:
        case OneTimeAlertKind.tti5:
        case OneTimeAlertKind.animal5:
          return (Colors.teal.shade800, Colors.teal.shade600, Colors.cyan);
        default:
          return (Colors.grey.shade800, Colors.grey.shade600, Colors.white);
      }
    }

    return (Colors.grey.shade800, Colors.grey.shade600, Colors.white);
  }

  IconData _getAlertIcon(GameAlertMessage alert) {
    if (alert.type == GameAlertType.gameStart) {
      return Icons.play_circle_filled;
    }

    if (alert.type == GameAlertType.persistent) {
      switch (alert.persistentKind) {
        case PersistentAlertKind.go:
          return Icons.arrow_upward;
        case PersistentAlertKind.shake:
          return Icons.vibration;
        case PersistentAlertKind.bomb:
          return Icons.local_fire_department;
        case PersistentAlertKind.meongTta:
          return Icons.pets;
        default:
          return Icons.notifications;
      }
    }

    if (alert.type == GameAlertType.oneTime) {
      switch (alert.oneTimeKind) {
        case OneTimeAlertKind.godori:
          return Icons.flutter_dash;
        case OneTimeAlertKind.hongdan:
        case OneTimeAlertKind.cheongdan:
        case OneTimeAlertKind.chodan:
          return Icons.bookmark;
        case OneTimeAlertKind.samgwang:
        case OneTimeAlertKind.bigwangSamgwang:
        case OneTimeAlertKind.sagwang:
        case OneTimeAlertKind.bigwangSagwang:
        case OneTimeAlertKind.ogwang:
          return Icons.star;
        case OneTimeAlertKind.pi10:
        case OneTimeAlertKind.tti5:
        case OneTimeAlertKind.animal5:
          return Icons.emoji_events;
        default:
          return Icons.warning;
      }
    }

    return Icons.notifications;
  }
}
