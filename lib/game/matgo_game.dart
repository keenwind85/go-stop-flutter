import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/card_data.dart';
import '../models/game_room.dart';
import '../config/constants.dart';
import 'components/card_component.dart';
import 'components/arrow_indicator.dart';
import 'components/shake_bomb_indicator.dart';
import 'components/card_text_overlay.dart';

/// Flame 기반 맞고 게임 엔진 (향상된 애니메이션 시스템)
class MatgoGame extends FlameGame with HasCollisionDetection {
  // UI 컴포넌트들
  final List<CardComponent> _myHandCards = [];
  final List<CardComponent> _opponentHandCards = [];
  final List<CardComponent> _floorCards = [];
  final List<CardComponent> _deckCards = [];
  final List<CardComponent> _pukStackCards = []; // 뻑으로 쌓인 카드들

  // 애니메이션 관리자
  late ArrowIndicatorManager _arrowManager;
  late ShakeBombIndicatorManager _shakeBombManager;

  // 게임 상태
  String? _myUid;
  int _myPlayerNumber = 0;
  bool _isMyTurn = false;
  bool _isLoaded = false;
  bool _isAnimating = false; // 애니메이션 진행 중 여부
  bool _isFirstLoad = true; // 첫 로드 여부 (첫 로드시에는 애니메이션 없음)

  // 선택 상태
  CardComponent? _selectedCard;
  List<CardComponent> _matchingFloorCards = [];

  // 흔들기/폭탄 가능한 월 목록
  List<int> _shakableMonths = [];
  List<int> _bombableMonths = [];

  // 현재 게임 상태 캐시
  GameState? _currentGameState;
  GameState? _previousGameState;

  // 콜백
  Function(CardData, CardData?)? onCardPlayed;
  Function(bool)? onGoStopDecision;
  Function(List<CardData> options, CardData playedCard)? onSelectionNeeded;
  Function(SpecialEvent event)? onSpecialEventTriggered;

  @override
  Color backgroundColor() => AppColors.background;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 애니메이션 관리자 초기화
    _arrowManager = ArrowIndicatorManager();
    _shakeBombManager = ShakeBombIndicatorManager();

    await add(_arrowManager);
    await add(_shakeBombManager);
    // Don't add it yet, let the isVisible setter handle it or add it initially if needed
    // But since we want it on top, maybe we should add it last or use priority
    // TurnOverlay has priority 100, so it should be fine.
    // We'll let onGameStateChanged handle visibility.

    _isLoaded = true;
    print('[MatgoGame] Loaded with enhanced animation system');
  }

  /// 내 uid와 플레이어 번호 설정
  void setPlayer(String uid, int playerNumber) {
    _myUid = uid;
    _myPlayerNumber = playerNumber;
    print('[MatgoGame] Set player: $uid, number: $playerNumber');
  }

  /// 게임 상태 변경 시 호출 (Firebase 리스너에서 호출)
  Future<void> onGameStateChanged(GameState newState) async {
    if (!_isLoaded) return;

    print('[MatgoGame] Game state changed, turn: ${newState.turn}');

    _previousGameState = _currentGameState;
    _currentGameState = newState;

    // 내 턴인지 확인
    final wasMyTurn = _isMyTurn;
    _isMyTurn = newState.turn == _myUid;

    // 턴 변경 시 처리
    if (_isMyTurn != wasMyTurn) {
      _setHandInteractive(_isMyTurn && !_isAnimating);
      print('[MatgoGame] My turn: $_isMyTurn');

      if (_isMyTurn) {
        // 내 턴이 되면 흔들기/폭탄 가능 여부 체크
        _checkShakeBombOptions(newState);
      } else {
        // 내 턴이 아니면 표시기 제거
        _shakeBombManager.clearImmediately();
        _arrowManager.clearArrows();
      }
      
    }

    // 특수 이벤트 처리
    if (newState.lastEvent != SpecialEvent.none &&
        _previousGameState?.lastEvent != newState.lastEvent) {
      await _handleSpecialEvent(newState.lastEvent, newState);
    }

    // 카드 상태 업데이트
    await _updateCards(newState);
  }

  /// 흔들기/폭탄 가능 여부 체크
  void _checkShakeBombOptions(GameState state) {
    final myHand = _myPlayerNumber == 1 ? state.player1Hand : state.player2Hand;

    // 월별 카드 개수 카운트
    final monthCount = <int, List<CardData>>{};
    for (final card in myHand) {
      monthCount.putIfAbsent(card.month, () => []).add(card);
    }

    _shakableMonths = [];
    _bombableMonths = [];

    for (final entry in monthCount.entries) {
      if (entry.value.length >= 3) {
        // 바닥에 같은 월 카드가 있는지 확인
        final floorMatchCount = state.floorCards
            .where((c) => c.month == entry.key)
            .length;

        if (floorMatchCount == 1) {
          // 폭탄 가능 (손에 3장 + 바닥에 1장)
          _bombableMonths.add(entry.key);
        } else {
          // 흔들기만 가능
          _shakableMonths.add(entry.key);
        }
      }
    }

    // 흔들기/폭탄 표시기 업데이트
    _updateShakeBombIndicators();
  }

  /// 흔들기/폭탄 표시기 업데이트
  void _updateShakeBombIndicators() {
    _shakeBombManager.clearImmediately();

    final cardSize = Vector2(GameConstants.cardWidth, GameConstants.cardHeight);

    // 흔들기 가능 카드 표시
    for (final month in _shakableMonths) {
      final matchingCards = _myHandCards
          .where((c) => c.cardData.month == month)
          .map((c) => c.position.clone())
          .toList();

      if (matchingCards.length >= 3) {
        _shakeBombManager.addShakeIndicators(matchingCards, cardSize);
      }
    }

    // 폭탄 가능 카드 표시
    for (final month in _bombableMonths) {
      final matchingCards = _myHandCards
          .where((c) => c.cardData.month == month)
          .map((c) => c.position.clone())
          .toList();

      if (matchingCards.length >= 3) {
        _shakeBombManager.addBombIndicators(matchingCards, cardSize);
      }
    }
  }

  /// 특수 이벤트 처리
  Future<void> _handleSpecialEvent(SpecialEvent event, GameState state) async {
    onSpecialEventTriggered?.call(event);

    switch (event) {
      case SpecialEvent.puk:
        await _showPukAnimation(state);
        break;
      case SpecialEvent.kiss:
        await _showKissAnimation();
        break;
      case SpecialEvent.ttadak:
        await _showTtadakAnimation();
        break;
      case SpecialEvent.sweep:
        await _showSweepAnimation();
        break;
      case SpecialEvent.sulsa:
        await _showSulsaAnimation();
        break;
      default:
        break;
    }
  }

  /// 뻑 애니메이션
  Future<void> _showPukAnimation(GameState state) async {
    if (state.pukCards.isEmpty) return;

    // 상대방 손패 위치 (화면 상단)
    final startY = 80.0;
    final centerX = size.x / 2;

    // 뻑 텍스트 표시
    final textOverlay = PpukTextOverlay(
      position: Vector2(centerX, startY + 60),
    );
    await add(textOverlay);

    // 3초 후 텍스트 제거
    await Future.delayed(const Duration(seconds: 2));
    await textOverlay.fadeOutAndRemove();
  }

  /// 쪽 애니메이션
  Future<void> _showKissAnimation() async {
    final textOverlay = JjokTextOverlay(
      position: Vector2(size.x / 2, size.y / 2 - 60),
    );
    await add(textOverlay);

    await Future.delayed(const Duration(milliseconds: 1500));
    await textOverlay.fadeOutAndRemove();
  }

  /// 따닥 애니메이션
  Future<void> _showTtadakAnimation() async {
    final textOverlay = TtadakTextOverlay(
      position: Vector2(size.x / 2, size.y / 2 - 60),
    );
    await add(textOverlay);

    await Future.delayed(const Duration(milliseconds: 1500));
    await textOverlay.fadeOutAndRemove();
  }

  /// 싹쓸이 애니메이션
  Future<void> _showSweepAnimation() async {
    final textOverlay = SweepTextOverlay(
      position: Vector2(size.x / 2, size.y / 2 - 60),
    );
    await add(textOverlay);

    await Future.delayed(const Duration(milliseconds: 1500));
    await textOverlay.fadeOutAndRemove();
  }

  /// 설사 애니메이션
  Future<void> _showSulsaAnimation() async {
    final textOverlay = SulsaTextOverlay(
      position: Vector2(size.x / 2, size.y / 2 - 60),
    );
    await add(textOverlay);

    await Future.delayed(const Duration(milliseconds: 1500));
    await textOverlay.fadeOutAndRemove();
  }

  /// 카드 상태 업데이트 (애니메이션 포함)
  Future<void> _updateCards(GameState state) async {
    // 내 손패 vs 상대 손패 결정
    final myHand = _myPlayerNumber == 1 ? state.player1Hand : state.player2Hand;
    final opponentHand = _myPlayerNumber == 1 ? state.player2Hand : state.player1Hand;

    // 첫 로드인 경우 모든 카드 새로 배치
    if (_isFirstLoad) {
      _isFirstLoad = false;
      _clearCards();
      await _dealMyHand(myHand);
      await _dealOpponentHand(opponentHand);
      await _dealFloorCards(state.floorCards);
      await _setupDeck(state.deck);
      if (state.pukCards.isNotEmpty) {
        await _setupPukStack(state.pukCards);
      }
      return;
    }

    // 상태 변화 감지 및 애니메이션 처리
    _isAnimating = true;

    try {
      // 1. 이전 상태와 현재 상태 비교하여 변화 감지
      final changes = _detectCardChanges(state, myHand, opponentHand);

      // 2. 카드 이동 애니메이션 실행
      await _animateCardChanges(changes, state, myHand, opponentHand);

    } finally {
      _isAnimating = false;
      _setHandInteractive(_isMyTurn);
    }
  }

  /// 카드 변화 감지
  _CardChanges _detectCardChanges(GameState state, List<CardData> myHand, List<CardData> opponentHand) {
    final changes = _CardChanges();

    // 내 손패에서 사라진 카드 (바닥으로 이동)
    final currentHandIds = myHand.map((c) => c.id).toSet();
    for (final card in _myHandCards) {
      if (!currentHandIds.contains(card.cardData.id)) {
        changes.handToFloor.add(card);
      }
    }

    // 바닥에서 사라진 카드 (획득됨)
    final currentFloorIds = state.floorCards.map((c) => c.id).toSet();
    for (final card in _floorCards) {
      if (!currentFloorIds.contains(card.cardData.id)) {
        changes.floorToCaptured.add(card);
      }
    }

    // 바닥에 새로 추가된 카드
    final existingFloorIds = _floorCards.map((c) => c.cardData.id).toSet();
    for (final cardData in state.floorCards) {
      if (!existingFloorIds.contains(cardData.id)) {
        changes.newFloorCards.add(cardData);
      }
    }

    // 덱에서 카드가 줄었는지 확인
    if (_deckCards.isNotEmpty && state.deck.length < _deckCards.length) {
      changes.deckCardDrawn = _deckCards.isNotEmpty ? _deckCards.last : null;
    }

    return changes;
  }

  /// 카드 변화에 따른 애니메이션 실행
  Future<void> _animateCardChanges(
    _CardChanges changes,
    GameState state,
    List<CardData> myHand,
    List<CardData> opponentHand,
  ) async {
    // 1. 손패에서 바닥으로 이동하는 카드 애니메이션
    if (changes.handToFloor.isNotEmpty) {
      final card = changes.handToFloor.first;
      final floorCenter = Vector2(size.x / 2, size.y / 2);

      // 바닥 중앙으로 이동 애니메이션
      await card.moveTo(floorCenter, duration: 0.3);

      // 손패 목록에서 제거
      _myHandCards.remove(card);
    }

    // 2. 덱 카드 뒤집기 (있다면)
    if (changes.deckCardDrawn != null) {
      final deckCard = changes.deckCardDrawn!;
      final showPosition = Vector2(size.x / 2 + 60, size.y / 2);

      // 덱에서 중앙으로 이동
      await deckCard.moveTo(showPosition, duration: 0.25);

      // 카드 뒤집기
      await deckCard.flip(showFront: true);

      // 잠시 대기
      await Future.delayed(const Duration(milliseconds: 300));

      _deckCards.remove(deckCard);
    }

    // 3. 획득된 카드들 점수패로 이동
    if (changes.floorToCaptured.isNotEmpty) {
      final scorePilePosition = _isMyTurn
          ? Vector2(size.x - 80, size.y - 150)  // 내 점수패
          : Vector2(size.x - 80, 150);           // 상대 점수패

      final futures = <Future>[];
      for (int i = 0; i < changes.floorToCaptured.length; i++) {
        final card = changes.floorToCaptured[i];
        final delay = i * 80; // 순차적 이동

        futures.add(
          Future.delayed(Duration(milliseconds: delay), () async {
            await card.captureAnimation(
              target: scorePilePosition + Vector2(i * 5.0, 0),
            );
            card.removeFromParent();
          }),
        );

        _floorCards.remove(card);
      }

      await Future.wait(futures);
    }

    // 4. 손패에서 나간 카드가 바닥에 남아있으면 처리
    for (final card in changes.handToFloor) {
      // 새 바닥 카드 데이터에 있는지 확인
      final inNewFloor = state.floorCards.any((c) => c.id == card.cardData.id);
      if (inNewFloor) {
        // 바닥 카드 목록으로 이동
        _floorCards.add(card);
      } else {
        // 획득되었으면 점수패로 이동 후 제거
        final scorePilePosition = Vector2(size.x - 80, size.y - 150);
        await card.captureAnimation(target: scorePilePosition);
        card.removeFromParent();
      }
    }

    // 5. 덱 카드가 바닥에 남거나 획득되었으면 처리
    if (changes.deckCardDrawn != null) {
      final deckCard = changes.deckCardDrawn!;
      final inNewFloor = state.floorCards.any((c) => c.id == deckCard.cardData.id);
      if (inNewFloor) {
        _floorCards.add(deckCard);
      } else {
        // 획득됨
        final scorePilePosition = _isMyTurn
            ? Vector2(size.x - 80, size.y - 150)
            : Vector2(size.x - 80, 150);
        await deckCard.captureAnimation(target: scorePilePosition);
        deckCard.removeFromParent();
      }
    }

    // 6. 카드 재배치 (위치 업데이트)
    await _repositionMyHand(myHand);
    await _repositionOpponentHand(opponentHand);
    await _repositionFloorCards(state.floorCards);
    await _repositionDeck(state.deck);

    // 뻑 카드 처리
    if (state.pukCards.isNotEmpty) {
      await _setupPukStack(state.pukCards);
    }
  }

  /// 내 손패 재배치 (애니메이션으로 이동)
  Future<void> _repositionMyHand(List<CardData> cards) async {
    final screenWidth = size.x;
    final screenHeight = size.y;
    final cardWidth = GameConstants.cardWidth;

    final spacing = min(cardWidth + 10, (screenWidth * 0.8) / max(cards.length, 1));
    final startX = (screenWidth - (cards.length - 1) * spacing) / 2;
    final y = screenHeight - 80;

    // 기존 카드 ID 맵
    final existingCards = {for (var c in _myHandCards) c.cardData.id: c};
    final newHandCards = <CardComponent>[];
    final futures = <Future>[];

    for (int i = 0; i < cards.length; i++) {
      final targetPos = Vector2(startX + i * spacing, y);

      if (existingCards.containsKey(cards[i].id)) {
        // 기존 카드 이동
        final card = existingCards[cards[i].id]!;
        if ((card.position - targetPos).length > 5) {
          futures.add(card.moveTo(targetPos, duration: 0.2));
        } else {
          // 이동하지 않아도 originalY 업데이트 (호버 애니메이션 기준점)
          card.updateOriginalY(y);
        }
        newHandCards.add(card);
      } else {
        // 새 카드 생성
        final card = CardComponent(
          cardData: cards[i],
          isFlipped: false,
          isInteractive: _isMyTurn && !_isAnimating,
          onCardTap: _onMyCardTap,
          position: Vector2(startX + i * spacing, screenHeight + 50), // 화면 밖에서 시작
        );
        add(card);
        newHandCards.add(card);
        futures.add(card.moveTo(targetPos, duration: 0.3));
      }
    }

    await Future.wait(futures);

    // 모든 카드의 originalY가 올바른 y 값으로 설정되었는지 확인
    for (final card in newHandCards) {
      card.updateOriginalY(y);
    }

    // 사라진 카드 제거
    for (final card in _myHandCards) {
      if (!newHandCards.contains(card) && card.isMounted) {
        card.removeFromParent();
      }
    }

    _myHandCards
      ..clear()
      ..addAll(newHandCards);
  }

  /// 상대 손패 재배치
  Future<void> _repositionOpponentHand(List<CardData> cards) async {
    final screenWidth = size.x;
    final cardWidth = GameConstants.cardWidth;

    final scale = GameConstants.opponentCardScale;
    final scaledCardWidth = GameConstants.cardWidth * scale;
    
    final spacing = min(scaledCardWidth + 10, (screenWidth * 0.8) / max(cards.length, 1));
    final startX = (screenWidth - (cards.length - 1) * spacing) / 2;
    final y = 150.0; // Moved down to align with captured cards area

    final existingCards = {for (var c in _opponentHandCards) c.cardData.id: c};
    final newHandCards = <CardComponent>[];
    final futures = <Future>[];

    for (int i = 0; i < cards.length; i++) {
      final targetPos = Vector2(startX + i * spacing, y);

      if (existingCards.containsKey(cards[i].id)) {
        final card = existingCards[cards[i].id]!;
        if ((card.position - targetPos).length > 5) {
          futures.add(card.moveTo(targetPos, duration: 0.2));
        }
        newHandCards.add(card);
      } else {
        final card = CardComponent(
          cardData: cards[i],
          isFlipped: true,
          isInteractive: false,
          position: Vector2(startX + i * spacing, -50),
        );
        card.scale = Vector2.all(scale);
        add(card);
        newHandCards.add(card);
        futures.add(card.moveTo(targetPos, duration: 0.3));
      }
    }

    await Future.wait(futures);

    for (final card in _opponentHandCards) {
      if (!newHandCards.contains(card) && card.isMounted) {
        card.removeFromParent();
      }
    }

    _opponentHandCards
      ..clear()
      ..addAll(newHandCards);
  }

  /// 바닥 카드 재배치
  Future<void> _repositionFloorCards(List<CardData> cards) async {
    final screenWidth = size.x;
    final screenHeight = size.y;
    final cardWidth = GameConstants.cardWidth;
    final cardHeight = GameConstants.cardHeight;

    // 월별로 그룹화
    final byMonth = <int, List<CardData>>{};
    for (final card in cards) {
      byMonth.putIfAbsent(card.month, () => []).add(card);
    }

    final months = byMonth.keys.toList()..sort();
    const maxCols = 4;
    final cols = min(months.length, maxCols);
    final rows = (months.length / maxCols).ceil();

    final horizontalSpacing = min(cardWidth + 20, screenWidth * 0.8 / max(cols, 1));
    final verticalSpacing = min(cardHeight + 10, screenHeight * 0.3 / max(rows, 1));

    final startX = (screenWidth - (cols - 1) * horizontalSpacing) / 2;
    final startY = screenHeight / 2 - (rows - 1) * verticalSpacing / 2;

    final existingCards = {for (var c in _floorCards) c.cardData.id: c};
    final newFloorCards = <CardComponent>[];
    final futures = <Future>[];

    for (int i = 0; i < months.length; i++) {
      final month = months[i];
      final monthCards = byMonth[month]!;

      final col = i % maxCols;
      final row = i ~/ maxCols;
      final baseX = startX + col * horizontalSpacing;
      final baseY = startY + row * verticalSpacing;

      for (int j = 0; j < monthCards.length; j++) {
        final cardData = monthCards[j];
        final targetPos = Vector2(baseX + j * 8, baseY + j * 4);

        if (existingCards.containsKey(cardData.id)) {
          final card = existingCards[cardData.id]!;
          if ((card.position - targetPos).length > 5) {
            futures.add(card.moveTo(targetPos, duration: 0.25));
          }
          newFloorCards.add(card);
        } else {
          // 새 바닥 카드
          final card = CardComponent(
            cardData: cardData,
            isFlipped: false,
            isInteractive: true,
            onCardTap: _onFloorCardTap,
            position: targetPos,
          );
          add(card);
          newFloorCards.add(card);
          // 새 카드는 페이드인 효과
          card.opacity = 0;
          futures.add(card.fadeInAnimation(duration: 0.3));
        }
      }
    }

    await Future.wait(futures);

    // 사라진 카드는 이미 _animateCardChanges에서 처리됨
    _floorCards
      ..clear()
      ..addAll(newFloorCards);
  }

  /// 덱 재배치
  Future<void> _repositionDeck(List<CardData> cards) async {
    final screenWidth = size.x;
    final screenHeight = size.y;

    // 기존 덱 카드 제거
    for (final card in _deckCards) {
      if (card.isMounted) {
        card.removeFromParent();
      }
    }
    _deckCards.clear();

    // 새 덱 카드 생성
    for (int i = 0; i < min(cards.length, 5); i++) {
      final card = CardComponent(
        cardData: cards[i],
        isFlipped: true,
        isInteractive: false,
        position: Vector2(screenWidth - 60, screenHeight / 2 + i * 2),
      );
      await add(card);
      _deckCards.add(card);
    }
  }

  /// 내 손패 배치
  Future<void> _dealMyHand(List<CardData> cards) async {
    final screenWidth = size.x;
    final screenHeight = size.y;
    final cardWidth = GameConstants.cardWidth;

    final spacing = min(cardWidth + 10, (screenWidth * 0.8) / max(cards.length, 1));
    final startX = (screenWidth - (cards.length - 1) * spacing) / 2;
    final y = screenHeight - 80;

    for (int i = 0; i < cards.length; i++) {
      final card = CardComponent(
        cardData: cards[i],
        isFlipped: false,
        isInteractive: _isMyTurn && !_isAnimating,
        onCardTap: _onMyCardTap,
        position: Vector2(startX + i * spacing, y),
      );

      // 호버 이벤트 처리를 위한 콜백 설정
      await add(card);
      _myHandCards.add(card);
    }
  }

  /// 상대 손패 배치 (뒷면)
  Future<void> _dealOpponentHand(List<CardData> cards) async {
    final screenWidth = size.x;
    final cardWidth = GameConstants.cardWidth;

    final scale = GameConstants.opponentCardScale;
    final scaledCardWidth = GameConstants.cardWidth * scale;

    final spacing = min(scaledCardWidth + 10, (screenWidth * 0.8) / max(cards.length, 1));
    final startX = (screenWidth - (cards.length - 1) * spacing) / 2;
    final y = 150.0; // Moved down to align with captured cards area

    for (int i = 0; i < cards.length; i++) {
      final card = CardComponent(
        cardData: cards[i],
        isFlipped: true,
        isInteractive: false,
        position: Vector2(startX + i * spacing, y),
      );
      card.scale = Vector2.all(scale);
      await add(card);
      _opponentHandCards.add(card);
    }
  }

  /// 바닥 카드 배치
  Future<void> _dealFloorCards(List<CardData> cards) async {
    final screenWidth = size.x;
    final screenHeight = size.y;
    final cardWidth = GameConstants.cardWidth;
    final cardHeight = GameConstants.cardHeight;

    // 월별로 그룹화
    final byMonth = <int, List<CardData>>{};
    for (final card in cards) {
      byMonth.putIfAbsent(card.month, () => []).add(card);
    }

    final months = byMonth.keys.toList()..sort();
    const maxCols = 4;
    final cols = min(months.length, maxCols);
    final rows = (months.length / maxCols).ceil();

    final horizontalSpacing = min(cardWidth + 20, screenWidth * 0.8 / max(cols, 1));
    final verticalSpacing = min(cardHeight + 10, screenHeight * 0.3 / max(rows, 1));

    final startX = (screenWidth - (cols - 1) * horizontalSpacing) / 2;
    final startY = screenHeight / 2 - (rows - 1) * verticalSpacing / 2;

    for (int i = 0; i < months.length; i++) {
      final month = months[i];
      final monthCards = byMonth[month]!;

      final col = i % maxCols;
      final row = i ~/ maxCols;
      final baseX = startX + col * horizontalSpacing;
      final baseY = startY + row * verticalSpacing;

      for (int j = 0; j < monthCards.length; j++) {
        final card = CardComponent(
          cardData: monthCards[j],
          isFlipped: false,
          isInteractive: true,
          onCardTap: _onFloorCardTap,
          position: Vector2(baseX + j * 8, baseY + j * 4),
        );
        await add(card);
        _floorCards.add(card);
      }
    }
  }

  /// 덱 배치
  Future<void> _setupDeck(List<CardData> cards) async {
    final screenWidth = size.x;
    final screenHeight = size.y;

    for (int i = 0; i < min(cards.length, 5); i++) {
      final card = CardComponent(
        cardData: cards[i],
        isFlipped: true,
        isInteractive: false,
        position: Vector2(screenWidth - 60, screenHeight / 2 + i * 2),
      );
      await add(card);
      _deckCards.add(card);
    }
  }

  /// 뻑 카드 스택 배치
  Future<void> _setupPukStack(List<CardData> pukCards) async {
    final screenWidth = size.x;
    final screenHeight = size.y;

    // 뻑 카드들을 바닥 중앙에 겹쳐서 배치
    final baseX = screenWidth / 2 + 80;
    final baseY = screenHeight / 2;

    for (int i = 0; i < pukCards.length; i++) {
      final card = CardComponent(
        cardData: pukCards[i],
        isFlipped: false,
        isInteractive: false,
        position: Vector2(baseX + i * 4, baseY + i * 4),
      );
      await add(card);
      _pukStackCards.add(card);
    }

    // 뻑 텍스트 오버레이 추가
    if (pukCards.isNotEmpty) {
      final textOverlay = CardTextOverlay(
        text: '뻑',
        position: Vector2(baseX + pukCards.length * 2, baseY - 50),
        backgroundColor: Colors.orange,
        fontSize: 20,
        animate: true,
      );
      await add(textOverlay);
    }
  }

  /// 카드 전부 제거
  void _clearCards() {
    for (final card in _myHandCards) {
      card.removeFromParent();
    }
    for (final card in _opponentHandCards) {
      card.removeFromParent();
    }
    for (final card in _floorCards) {
      card.removeFromParent();
    }
    for (final card in _deckCards) {
      card.removeFromParent();
    }
    for (final card in _pukStackCards) {
      card.removeFromParent();
    }

    _myHandCards.clear();
    _opponentHandCards.clear();
    _floorCards.clear();
    _deckCards.clear();
    _pukStackCards.clear();
    _selectedCard = null;
    _matchingFloorCards.clear();
    _arrowManager.clearArrows();
  }

  /// 손패 인터랙티브 설정
  void _setHandInteractive(bool interactive) {
    for (final card in _myHandCards) {
      card.isInteractive = interactive;
    }
  }

  /// 카드 호버 시 화살표 표시
  void _showMatchingArrows(CardComponent card) {
    _arrowManager.clearArrows();

    final matching = _floorCards
        .where((fc) => fc.cardData.month == card.cardData.month)
        .toList();

    if (matching.isNotEmpty) {
      for (final floorCard in matching) {
        _arrowManager.addArrow(
          card.position,
          floorCard.position,
          color: AppColors.accent,
        );
      }
    }
  }

  /// 내 카드 탭 처리
  void _onMyCardTap(CardComponent card) {
    if (!_isMyTurn || _isAnimating) return;

    // 이미 선택된 카드가 있으면 선택 해제
    if (_selectedCard != null && _selectedCard != card) {
      _selectedCard!.setSelected(false);
      _clearFloorHighlights();
      _arrowManager.clearArrows();
    }

    // 새 카드 선택/해제
    card.setSelected(!card.isSelected);

    if (card.isSelected) {
      _selectedCard = card;

      // 매칭 화살표 표시
      _showMatchingArrows(card);

      // 매칭되는 바닥 카드 찾기
      _matchingFloorCards = _floorCards
          .where((fc) => fc.cardData.month == card.cardData.month)
          .toList();

      if (_matchingFloorCards.isEmpty) {
        // 매칭 없음 -> 바로 카드 플레이
        _playCard(card, null);
      } else if (_matchingFloorCards.length == 1) {
        // 1장 매칭 -> 바로 플레이
        _playCard(card, _matchingFloorCards.first);
      } else {
        // 여러 장 매칭 -> 하이라이트하고 선택 대기
        for (final fc in _matchingFloorCards) {
          fc.setHighlighted(true);
        }

        // 선택 콜백 호출 (UI에서 선택 다이얼로그 표시)
        final options = _matchingFloorCards.map((c) => c.cardData).toList();
        onSelectionNeeded?.call(options, card.cardData);
      }
    } else {
      _selectedCard = null;
      _clearFloorHighlights();
      _arrowManager.clearArrows();
    }
  }

  /// 바닥 카드 탭 처리
  void _onFloorCardTap(CardComponent card) {
    if (!_isMyTurn || _selectedCard == null || _isAnimating) return;

    // 매칭되는 카드인지 확인
    if (_matchingFloorCards.contains(card)) {
      _playCard(_selectedCard!, card);
    }
  }

  /// 외부에서 바닥 카드 선택 시 호출
  void selectFloorCard(CardData selectedFloorCard) {
    if (_selectedCard == null) return;

    final matchingCard = _matchingFloorCards
        .where((c) => c.cardData.id == selectedFloorCard.id)
        .firstOrNull;

    if (matchingCard != null) {
      _playCard(_selectedCard!, matchingCard);
    }
  }

  /// 카드 플레이
  void _playCard(CardComponent handCard, CardComponent? floorCard) {
    _clearFloorHighlights();
    _arrowManager.clearArrows();
    _shakeBombManager.clearImmediately();

    // 콜백 호출 -> GameScreen에서 Firebase 업데이트
    onCardPlayed?.call(
      handCard.cardData,
      floorCard?.cardData,
    );

    _selectedCard = null;
  }

  /// 바닥 카드 하이라이트 해제
  void _clearFloorHighlights() {
    for (final card in _floorCards) {
      card.setHighlighted(false);
    }
    _matchingFloorCards.clear();
  }

  /// 흔들기 가능 여부 확인
  bool canShake(int month) => _shakableMonths.contains(month);

  /// 폭탄 가능 여부 확인
  bool canBomb(int month) => _bombableMonths.contains(month);

  /// 흔들기 가능한 월 목록
  List<int> get shakableMonths => List.unmodifiable(_shakableMonths);

  /// 폭탄 가능한 월 목록
  List<int> get bombableMonths => List.unmodifiable(_bombableMonths);

  /// 게임 리셋 (새 게임 시작 시)
  void resetGame() {
    _isFirstLoad = true;
    _clearCards();
  }
}

/// 카드 상태 변화 추적
class _CardChanges {
  /// 손패에서 바닥으로 이동한 카드
  final List<CardComponent> handToFloor = [];

  /// 바닥에서 획득된 카드
  final List<CardComponent> floorToCaptured = [];

  /// 새로 바닥에 추가된 카드 데이터
  final List<CardData> newFloorCards = [];

  /// 덱에서 뽑힌 카드
  CardComponent? deckCardDrawn;
}
