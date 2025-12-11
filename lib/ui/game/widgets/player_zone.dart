import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../models/captured_cards.dart';
import '../../../models/card_data.dart';
import '../../../config/constants.dart';
import 'game_card_widget.dart';

/// Bottom Zone: 플레이어 영역 (화면 하단 40%)
///
/// 디자인:
/// - Layer 1 (상단): 내 획득 패 (실제 카드 이미지, 종류별 그룹핑)
/// - Layer 2 (중앙): 손패 - 부채꼴(Fan Shape) 배치 (-15° ~ +15°)
/// - Layer 3: 액션 버튼 오버레이 (고/스톱)
class PlayerZone extends StatelessWidget {
  final String? playerName;
  final CapturedCards? captured;
  final List<CardData> handCards;
  final int score;
  final int goCount;
  final bool isMyTurn;
  final CardData? selectedCard;
  final Function(CardData) onCardTap;
  final VoidCallback? onGoPressed;
  final VoidCallback? onStopPressed;
  final bool showGoStopButtons;
  final bool isShaking;   // 흔들기 사용 여부
  final bool hasBomb;     // 폭탄 사용 여부
  final int? coinBalance; // 코인 잔액

  /// 턴 타이머 관련
  final int? remainingSeconds;  // 남은 시간 (초)

  /// 카드 위치 추적을 위한 GlobalKey 콜백
  final GlobalKey Function(String cardId)? getCardKey;

  /// 획득 영역 GlobalKey (카드 획득 애니메이션 목적지)
  final GlobalKey? captureZoneKey;

  /// 디버그 모드 관련
  final bool debugModeActive;
  final void Function(CardData)? onCardLongPress;  // 디버그: 손패 카드 변경
  final VoidCallback? onDebugModeActivate;         // 디버그: 모드 발동

  const PlayerZone({
    super.key,
    this.playerName,
    this.captured,
    required this.handCards,
    required this.score,
    required this.goCount,
    required this.isMyTurn,
    this.selectedCard,
    required this.onCardTap,
    this.onGoPressed,
    this.onStopPressed,
    this.showGoStopButtons = false,
    this.isShaking = false,
    this.hasBomb = false,
    this.coinBalance,
    this.remainingSeconds,
    this.getCardKey,
    this.captureZoneKey,
    this.debugModeActive = false,
    this.onCardLongPress,
    this.onDebugModeActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.woodDark.withValues(alpha: 0.95), // 진한 나무 색상
        border: Border(
          top: BorderSide(
            color: AppColors.woodLight,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 메인 콘텐츠
          Column(
            children: [
              // Layer 1: 획득 패 (실제 카드 이미지)
              Expanded(
                flex: 30,
                child: _buildCapturedSection(),
              ),

              // 점수 및 정보 바
              _buildInfoBar(),

              // Layer 2: 손패 (부채꼴)
              Expanded(
                flex: 70,
                child: _buildHandSection(),
              ),
            ],
          ),

          // Layer 3: 고/스톱 버튼 오버레이
          if (showGoStopButtons) _buildGoStopOverlay(),
        ],
      ),
    );
  }

  /// Layer 1: 획득 패를 실제 카드 이미지로 표시
  Widget _buildCapturedSection() {
    if (captured == null ||
        (captured!.kwang.isEmpty &&
            captured!.animal.isEmpty &&
            captured!.ribbon.isEmpty &&
            captured!.pi.isEmpty)) {
      return Center(
        child: Text(
          '획득 패 없음',
          style: TextStyle(
            color: AppColors.woodLight.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          // 광 (점수가 나는 패 - 강조)
          if (captured!.kwang.isNotEmpty)
            _buildCardGroup(
              cards: captured!.kwang,
              label: '광',
              labelColor: AppColors.cardHighlight,
              isHighlighted: captured!.kwang.length >= 3, // 3광 이상이면 강조
            ),
          // 열끗 (동물) - 고도리 체크
          if (captured!.animal.isNotEmpty)
            _buildCardGroup(
              cards: captured!.animal,
              label: '열',
              labelColor: AppColors.goRed,
              isHighlighted: _hasGodori(), // 고도리면 강조
            ),
          // 띠 - 홍단/청단/초단 체크
          if (captured!.ribbon.isNotEmpty)
            _buildCardGroup(
              cards: captured!.ribbon,
              label: '띠',
              labelColor: AppColors.stopBlue,
              isHighlighted: captured!.ribbon.length >= 5, // 5띠 이상이면 강조
            ),
          // 피
          if (captured!.pi.isNotEmpty)
            _buildCardGroup(
              cards: captured!.pi,
              label: '피',
              labelColor: AppColors.primaryLight,
              showCount: captured!.piCount,
              isHighlighted: captured!.piCount >= 10, // 10피 이상이면 강조
            ),
        ],
      ),
    );
  }

  /// 고도리 체크 (2, 4, 8월 동물)
  bool _hasGodori() {
    if (captured == null) return false;
    final months = captured!.animal.map((c) => c.month).toSet();
    return months.contains(2) && months.contains(4) && months.contains(8);
  }

  /// 카드 그룹 (실제 카드 이미지로 겹쳐서 표시)
  Widget _buildCardGroup({
    required List<CardData> cards,
    required String label,
    required Color labelColor,
    int? showCount,
    bool isHighlighted = false,
  }) {
    final cardWidth = GameConstants.cardWidth * 0.45;
    final cardHeight = GameConstants.cardHeight * 0.45;
    const overlap = 14.0;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라벨 + 카운트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? labelColor.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              border: isHighlighted
                  ? Border.all(color: labelColor, width: 1)
                  : Border.all(color: labelColor.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Text(
              '$label ${showCount ?? cards.length}',
              style: TextStyle(
                color: isHighlighted ? Colors.white : labelColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // 카드 스택
          SizedBox(
            width: cardWidth + (cards.length - 1) * overlap,
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(cards.length, (index) {
                final card = cards[index];
                // 점수 패는 살짝 위로 튀어나옴 (오버플로우 방지를 위해 최소화)
                final isScoring = _isScoringCard(card);
                final yOffset = isScoring ? -2.0 : 0.0;

                return Positioned(
                  left: index * overlap,
                  top: yOffset,
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isScoring
                            ? AppColors.cardHighlight
                            : AppColors.woodDark.withValues(alpha: 0.5),
                        width: isScoring ? 1.5 : 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isScoring
                              ? AppColors.cardHighlight.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.3),
                          blurRadius: isScoring ? 6 : 2,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.asset(
                        'assets/${card.imagePath}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primaryDark,
                          child: Center(
                            child: Text(
                              '${card.month}',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// 점수가 나는 특별 카드인지 체크
  bool _isScoringCard(CardData card) {
    // 광 카드
    if (card.type == CardType.kwang) return true;
    // 고도리 (2, 4, 8월 동물)
    if (card.type == CardType.animal &&
        (card.month == 2 || card.month == 4 || card.month == 8)) {
      return _hasGodori();
    }
    return false;
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.woodLight, // 밝은 나무 색상 (명패 느낌)
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.black.withValues(alpha: 0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 플레이어 이름 + 턴 표시
          Row(
            children: [
              if (isMyTurn)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryLight.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              Text(
                playerName ?? '나',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (goCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.goRed.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$goCount고',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              // 흔들기 태그
              if (isShaking) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    '흔들기',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              // 폭탄 태그
              if (hasBomb) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    '폭탄',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // 점수 + 코인 (우측 정렬)
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 점수
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6), // 디지털 디스플레이 느낌
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.woodDark,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '$score점',
                    style: const TextStyle(
                      color: AppColors.cardHighlight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier', // 디지털 폰트 느낌 (없으면 기본 폰트)
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // 코인 잔액 표시 (점수 옆)
                if (coinBalance != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.woodDark, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset(
                          'assets/etc/Coin.json',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text('🪙', style: TextStyle(fontSize: 14));
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$coinBalance',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandSection() {
    if (handCards.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Text(
              '손패 없음',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          // 타이머 표시 (손패 없어도 표시)
          if (isMyTurn && remainingSeconds != null)
            _buildTimerDisplay(),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            _FanHandLayout(
              cards: handCards,
              selectedCard: selectedCard,
              onCardTap: onCardTap,
              constraints: constraints,
              getCardKey: getCardKey,
              debugModeActive: debugModeActive,
              onCardLongPress: onCardLongPress,
              onDebugModeActivate: onDebugModeActivate,
            ),
            // 타이머 표시 (우하단)
            if (isMyTurn && remainingSeconds != null)
              _buildTimerDisplay(),
          ],
        );
      },
    );
  }

  /// 턴 타이머 표시 위젯 (우하단에 위치)
  Widget _buildTimerDisplay() {
    final isUrgent = remainingSeconds != null && remainingSeconds! <= 10;
    final displayText = remainingSeconds != null ? '$remainingSeconds초 남았습니다...' : '';

    return Positioned(
      right: 12,
      bottom: 8,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isUrgent
              ? Colors.red.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUrgent ? Colors.redAccent : Colors.white24,
            width: 1,
          ),
          boxShadow: isUrgent
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              color: isUrgent ? Colors.white : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              displayText,
              style: TextStyle(
                color: isUrgent ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoStopOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.woodDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardHighlight, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardHighlight.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '점수 달성!',
                  style: TextStyle(
                    color: AppColors.cardHighlight,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$score점',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 고 버튼
                    _GoStopButton(
                      label: '고',
                      color: AppColors.goRed,
                      onPressed: onGoPressed,
                    ),
                    const SizedBox(width: 24),
                    // 스톱 버튼
                    _GoStopButton(
                      label: '스톱',
                      color: AppColors.stopBlue,
                      onPressed: onStopPressed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 부채꼴 손패 레이아웃
class _FanHandLayout extends StatefulWidget {
  final List<CardData> cards;
  final CardData? selectedCard;
  final Function(CardData) onCardTap;
  final BoxConstraints constraints;
  final GlobalKey Function(String cardId)? getCardKey;
  final bool debugModeActive;
  final void Function(CardData)? onCardLongPress;
  final VoidCallback? onDebugModeActivate;

  const _FanHandLayout({
    required this.cards,
    this.selectedCard,
    required this.onCardTap,
    required this.constraints,
    this.getCardKey,
    this.debugModeActive = false,
    this.onCardLongPress,
    this.onDebugModeActivate,
  });

  @override
  State<_FanHandLayout> createState() => _FanHandLayoutState();
}

class _FanHandLayoutState extends State<_FanHandLayout> {
  Timer? _longPressTimer;
  CardData? _longPressCard;
  static const int _debugModeLongPressDuration = 5; // 5초

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onLongPressStart(CardData card) {
    _longPressCard = card;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(
      Duration(seconds: _debugModeLongPressDuration),
      () {
        if (_longPressCard != null) {
          if (widget.debugModeActive) {
            // 디버그 모드 활성화 상태: 카드 변경 다이얼로그 열기
            widget.onCardLongPress?.call(_longPressCard!);
          } else {
            // 디버그 모드 비활성화 상태: 디버그 모드 발동
            widget.onDebugModeActivate?.call();
          }
        }
      },
    );
  }

  void _onLongPressEnd() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressCard = null;
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = GameConstants.cardWidth;
    final cardHeight = GameConstants.cardHeight;

    // 부채꼴 각도 범위: -35° ~ +35° (카드가 더 잘 보이도록 간격 넓힘)
    const maxAngle = 35 * (math.pi / 180); // 35도를 라디안으로
    final totalAngleRange = maxAngle * 2;

    // 카드 수에 따른 각도 간격
    final angleStep =
        widget.cards.length > 1 ? totalAngleRange / (widget.cards.length - 1) : 0.0;

    // 중심점
    final centerX = widget.constraints.maxWidth / 2;
    final centerY = widget.constraints.maxHeight + 100; // 화면 아래쪽에 원 중심

    // 부채꼴 반지름
    final radius = widget.constraints.maxHeight * 0.8 + 50;

    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(widget.cards.length, (index) {
        final card = widget.cards[index];
        final isSelected = widget.selectedCard == card;

        // 각도 계산 (중앙부터 양쪽으로)
        final angle = widget.cards.length > 1
            ? -maxAngle + (index * angleStep)
            : 0.0; // 단일 카드는 중앙

        // 위치 계산 (원호 위의 점)
        final x = centerX + radius * math.sin(angle) - cardWidth / 2;
        final y = centerY - radius * math.cos(angle) - cardHeight;

        // 선택된 카드는 위로 올라감
        final yOffset = isSelected ? -20.0 : 0.0;

        // GlobalKey 가져오기 (위치 추적용)
        final cardKey = widget.getCardKey?.call(card.id);

        return Positioned(
          left: x,
          top: y + yOffset,
          child: GestureDetector(
            onTap: () => widget.onCardTap(card),
            onLongPressStart: (_) => _onLongPressStart(card),
            onLongPressEnd: (_) => _onLongPressEnd(),
            onLongPressCancel: _onLongPressEnd,
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Container(
                  key: cardKey,
                  child: GameCardWidget(
                    cardData: card,
                    width: cardWidth,
                    height: cardHeight,
                    isSelected: isSelected,
                    isInteractive: true,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 고/스톱 버튼
class _GoStopButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _GoStopButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
