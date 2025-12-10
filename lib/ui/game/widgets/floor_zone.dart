import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/card_data.dart';
import '../../../config/constants.dart';
import '../game_screen_new.dart';
import 'game_card_widget.dart';

/// Center Zone: 경기장/바닥 (화면 중앙 40%)
///
/// 디자인:
/// - 중앙 덱: 쌓여있는 패 (입체감 있는 그림자)
/// - 바닥 패: 8~12장 자연스럽게 배치 (아치형 또는 흩뿌려진 느낌)
/// - 이펙트 레이어: 쪽, 뻑, 따닥 텍스트 표시 영역
class FloorZone extends StatelessWidget {
  final List<CardData> floorCards;
  final List<CardData> pukCards; // 뻑으로 쌓인 카드들
  final int deckCount;
  final Function(CardData) onFloorCardTap;
  final VoidCallback onDeckTap;
  final CardData? selectedHandCard;
  final GlobalKey? deckKey;

  /// 바닥 카드 위치 추적을 위한 GlobalKey 콜백
  final GlobalKey Function(String cardId)? getCardKey;

  /// 애니메이션 중이라 숨겨야 할 카드 ID들
  /// 덱에서 뒤집힌 카드가 바닥으로 던져지는 애니메이션 중에는
  /// 바닥에서 해당 카드를 숨겨서 중복 표시를 방지
  final Set<String> hiddenCardIds;

  /// 손패가 비어있는지 여부 (덱만 뒤집기 가능 여부 결정)
  final bool isHandEmpty;

  /// 내 턴인지 여부
  final bool isMyTurn;

  const FloorZone({
    super.key,
    required this.floorCards,
    this.pukCards = const [],
    required this.deckCount,
    required this.onFloorCardTap,
    required this.onDeckTap,
    this.selectedHandCard,
    this.deckKey,
    this.getCardKey,
    this.hiddenCardIds = const {},
    this.isHandEmpty = false,
    this.isMyTurn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.6),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AppColors.woodDark.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 바닥 패턴 (미묘한 질감)
              _buildFloorPattern(constraints),

              // 중앙 덱
              Positioned(
                left: constraints.maxWidth / 2 - 30,
                top: constraints.maxHeight / 2 - 45,
                child: DeckStack(
                  key: deckKey,
                  count: deckCount,
                  cardWidth: GameConstants.cardWidth,
                  cardHeight: GameConstants.cardHeight,
                  // 덱 탭 가능 조건:
                  // 1. 손패가 선택되어 있음 (일반 카드 내기)
                  // 2. 손패가 비어있고 내 턴임 (덱만 뒤집기)
                  onTap: (selectedHandCard != null || (isHandEmpty && isMyTurn))
                      ? onDeckTap
                      : null,
                ),
              ),

              // 바닥 패들 (아치형 배치)
              ..._buildFloorCards(constraints),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFloorPattern(BoxConstraints constraints) {
    return Opacity(
      opacity: 0.1,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/cards/back_of_card.png'),
            fit: BoxFit.none,
            repeat: ImageRepeat.repeat,
            scale: 8,
            opacity: 0.3,
          ),
        ),
      ),
    );
  }

  /// 월별로 카드 그룹화 (설사 대상 판별용)
  Map<int, List<CardData>> _groupCardsByMonth(List<CardData> cards) {
    final groups = <int, List<CardData>>{};
    for (final card in cards) {
      groups.putIfAbsent(card.month, () => []).add(card);
    }
    return groups;
  }

  /// 카드 수에 따른 동적 레이아웃 계산
  ///
  /// - 1~8장: 단일 링, 기본 크기
  /// - 9~14장: 단일 링, 축소 크기
  /// - 15~20장: 2중 링 (내부 8장, 외부 나머지)
  /// - 21장 이상: 3중 링 또는 추가 축소
  /// - 같은 월 3장 이상: 겹쳐서 표시 (설사 대상)
  List<Widget> _buildFloorCards(BoxConstraints constraints) {
    if (floorCards.isEmpty) return [];

    // ★ 애니메이션 중인 카드는 제외 (중복 표시 방지)
    final visibleFloorCards = floorCards
        .where((card) => !hiddenCardIds.contains(card.id))
        .toList();

    if (visibleFloorCards.isEmpty) return [];

    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;

    // 월별 그룹화 (visible 카드만)
    final cardsByMonth = _groupCardsByMonth(visibleFloorCards);

    // 뻑 그룹, 설사 그룹 (3장 이상), 일반 카드 분리
    final pukGroup = <int, List<CardData>>{}; // 뻑 카드 그룹
    final sulsaGroups = <int, List<CardData>>{}; // 설사 그룹
    final normalCards = <CardData>[];

    // pukCards ID 세트 생성
    final pukCardIds = pukCards.map((c) => c.id).toSet();

    for (final entry in cardsByMonth.entries) {
      if (entry.value.length >= 3) {
        // 3장 이상인 경우 뻑인지 설사인지 구분
        final isPukStack = pukCards.isNotEmpty &&
            entry.value.every((card) => pukCardIds.contains(card.id));
        if (isPukStack) {
          pukGroup[entry.key] = entry.value;
        } else {
          sulsaGroups[entry.key] = entry.value;
        }
      } else {
        normalCards.addAll(entry.value);
      }
    }

    // 배치할 슬롯 수 계산 (뻑/설사 그룹은 1슬롯, 일반 카드는 각각 1슬롯)
    final slotCount = pukGroup.length + sulsaGroups.length + normalCards.length;

    // 카드 수에 따른 동적 크기 계산
    final cardDimensions = _calculateCardDimensions(slotCount, constraints);
    final cardWidth = cardDimensions.width;
    final cardHeight = cardDimensions.height;

    // 링 배치 계산
    final ringLayout = _calculateRingLayout(slotCount, constraints);

    final widgets = <Widget>[];
    int slotIndex = 0;

    // 배치할 항목들 (뻑 그룹 먼저, 설사 그룹, 그 다음 일반 카드)
    // 뻑 그룹 키를 추적하기 위한 Set
    final pukGroupKeys = pukGroup.keys.toSet();
    final List<dynamic> itemsToPlace = [
      ...pukGroup.entries,
      ...sulsaGroups.entries,
      ...normalCards,
    ];

    for (int ringIndex = 0; ringIndex < ringLayout.rings.length; ringIndex++) {
      final ring = ringLayout.rings[ringIndex];
      final slotsInRing = ring.cardCount;
      final radius = ring.radius;
      final angleStep = (2 * math.pi) / math.max(slotsInRing, 6);
      final startAngle = -math.pi / 2 + (ringIndex * math.pi / 12);

      for (int i = 0; i < slotsInRing && slotIndex < itemsToPlace.length; i++) {
        final item = itemsToPlace[slotIndex];
        final angle = startAngle + (i * angleStep);
        final x = centerX + radius * math.cos(angle) - cardWidth / 2;
        final y = centerY + radius * math.sin(angle) - cardHeight / 2;
        final rotation = (angle + math.pi / 2) * 0.12;

        if (item is MapEntry<int, List<CardData>>) {
          // 뻑 또는 설사 그룹 (3장 이상 겹쳐서 표시)
          final stackCards = item.value;
          final isPukStack = pukGroupKeys.contains(item.key);
          final isMatchable = selectedHandCard != null &&
              stackCards.first.month == selectedHandCard!.month;

          widgets.add(
            Positioned(
              left: x,
              top: y,
              child: AnimatedScale(
                scale: isMatchable ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: isPukStack
                    ? _buildPukStack(
                        cards: stackCards,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        rotation: rotation,
                        isMatchable: isMatchable,
                      )
                    : _buildSulsaStack(
                        cards: stackCards,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        rotation: rotation,
                        isMatchable: isMatchable,
                      ),
              ),
            ),
          );
        } else {
          // 일반 카드
          final card = item as CardData;
          final isMatchable = selectedHandCard != null &&
              card.month == selectedHandCard!.month;
          final cardKey = getCardKey?.call(card.id);

          widgets.add(
            Positioned(
              left: x,
              top: y,
              child: AnimatedScale(
                scale: isMatchable ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: cardKey,
                  child: GameCardWidget(
                    cardData: card,
                    width: cardWidth,
                    height: cardHeight,
                    rotation: rotation,
                    isHighlighted: isMatchable,
                    isInteractive: isMatchable,
                    onTap: isMatchable ? () => onFloorCardTap(card) : null,
                  ),
                ),
              ),
            ),
          );
        }
        slotIndex++;
      }
    }

    return widgets;
  }

  /// 설사 그룹 스택 위젯 (3장 이상 겹쳐서 표시)
  Widget _buildSulsaStack({
    required List<CardData> cards,
    required double cardWidth,
    required double cardHeight,
    required double rotation,
    required bool isMatchable,
  }) {
    const stackOffset = 6.0; // 카드 간 오프셋

    return GestureDetector(
      onTap: isMatchable ? () => onFloorCardTap(cards.first) : null,
      child: SizedBox(
        width: cardWidth + (cards.length - 1) * stackOffset,
        height: cardHeight + (cards.length - 1) * stackOffset,
        child: Stack(
          children: [
            // 설사 표시 라벨
            Positioned(
              top: -16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    '설사 ${cards.length}장',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // 겹쳐진 카드들
            ...cards.asMap().entries.map((entry) {
              final index = entry.key;
              final card = entry.value;
              final cardKey = getCardKey?.call(card.id);

              return Positioned(
                left: index * stackOffset,
                top: index * stackOffset,
                child: Container(
                  key: cardKey,
                  decoration: isMatchable
                      ? BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: GameCardWidget(
                    cardData: card,
                    width: cardWidth,
                    height: cardHeight,
                    rotation: rotation,
                    isHighlighted: isMatchable,
                    isInteractive: false, // 스택 전체가 탭 처리
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 뻑 그룹 스택 위젯 (뻑으로 쌓인 3장 표시)
  Widget _buildPukStack({
    required List<CardData> cards,
    required double cardWidth,
    required double cardHeight,
    required double rotation,
    required bool isMatchable,
  }) {
    const stackOffset = 6.0; // 카드 간 오프셋

    return GestureDetector(
      onTap: isMatchable ? () => onFloorCardTap(cards.first) : null,
      child: SizedBox(
        width: cardWidth + (cards.length - 1) * stackOffset,
        height: cardHeight + (cards.length - 1) * stackOffset,
        child: Stack(
          children: [
            // 뻑 표시 라벨 (빨간색)
            Positioned(
              top: -16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.goRed.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goRed.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    '뻑 ${cards.length}장',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // 겹쳐진 카드들
            ...cards.asMap().entries.map((entry) {
              final index = entry.key;
              final card = entry.value;
              final cardKey = getCardKey?.call(card.id);

              return Positioned(
                left: index * stackOffset,
                top: index * stackOffset,
                child: Container(
                  key: cardKey,
                  decoration: isMatchable
                      ? BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goRed.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: GameCardWidget(
                    cardData: card,
                    width: cardWidth,
                    height: cardHeight,
                    rotation: rotation,
                    isHighlighted: isMatchable,
                    isInteractive: false, // 스택 전체가 탭 처리
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 카드 수에 따른 크기 계산
  _CardDimensions _calculateCardDimensions(int cardCount, BoxConstraints constraints) {
    // 기본 크기
    double baseWidth = GameConstants.cardWidth;
    double baseHeight = GameConstants.cardHeight;

    // 카드 수에 따른 축소 비율
    double scale;
    if (cardCount <= 8) {
      scale = 1.0; // 기본 크기
    } else if (cardCount <= 12) {
      scale = 0.9; // 10% 축소
    } else if (cardCount <= 16) {
      scale = 0.8; // 20% 축소
    } else if (cardCount <= 20) {
      scale = 0.75; // 25% 축소
    } else {
      scale = 0.65; // 35% 축소 (20장 이상)
    }

    return _CardDimensions(
      width: baseWidth * scale,
      height: baseHeight * scale,
    );
  }

  /// 링 배치 계산
  _RingLayout _calculateRingLayout(int cardCount, BoxConstraints constraints) {
    final maxRadius = math.min(constraints.maxWidth, constraints.maxHeight) * 0.42;
    final minRadius = math.min(constraints.maxWidth, constraints.maxHeight) * 0.22;

    final rings = <_RingInfo>[];

    if (cardCount <= 8) {
      // 단일 링: 8장 이하
      rings.add(_RingInfo(
        radius: maxRadius * 0.85,
        cardCount: cardCount,
      ));
    } else if (cardCount <= 14) {
      // 단일 링 확장: 9~14장
      rings.add(_RingInfo(
        radius: maxRadius * 0.9,
        cardCount: cardCount,
      ));
    } else if (cardCount <= 20) {
      // 2중 링: 15~20장
      // 내부 링: 6장, 외부 링: 나머지
      final innerCount = 6;
      final outerCount = cardCount - innerCount;
      rings.add(_RingInfo(
        radius: minRadius,
        cardCount: innerCount,
      ));
      rings.add(_RingInfo(
        radius: maxRadius,
        cardCount: outerCount,
      ));
    } else {
      // 3중 링: 21장 이상
      // 내부: 5장, 중간: 8장, 외부: 나머지
      final innerCount = 5;
      final middleCount = 8;
      final outerCount = cardCount - innerCount - middleCount;
      rings.add(_RingInfo(
        radius: minRadius * 0.9,
        cardCount: innerCount,
      ));
      rings.add(_RingInfo(
        radius: (minRadius + maxRadius) / 2,
        cardCount: middleCount,
      ));
      rings.add(_RingInfo(
        radius: maxRadius,
        cardCount: outerCount,
      ));
    }

    return _RingLayout(rings: rings);
  }
}

/// 바닥 패 그리드 레이아웃 (대안적 배치)
class FloorCardGrid extends StatelessWidget {
  final List<CardData> cards;
  final Function(CardData) onCardTap;
  final CardData? selectedHandCard;

  const FloorCardGrid({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.selectedHandCard,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Text(
          '바닥 패 없음',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      );
    }

    // 4열 그리드 배치
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: GameConstants.cardWidth / GameConstants.cardHeight,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final isMatchable = selectedHandCard != null &&
            card.month == selectedHandCard!.month;

        return GameCardWidget(
          cardData: card,
          isHighlighted: isMatchable,
          isInteractive: isMatchable,
          onTap: isMatchable ? () => onCardTap(card) : null,
        );
      },
    );
  }
}

/// 카드 크기 정보
class _CardDimensions {
  final double width;
  final double height;

  const _CardDimensions({
    required this.width,
    required this.height,
  });
}

/// 개별 링 정보
class _RingInfo {
  final double radius;
  final int cardCount;

  const _RingInfo({
    required this.radius,
    required this.cardCount,
  });
}

/// 링 레이아웃 정보
class _RingLayout {
  final List<_RingInfo> rings;

  const _RingLayout({
    required this.rings,
  });
}
