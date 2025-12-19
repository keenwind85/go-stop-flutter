import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/card_data.dart';
import 'card_animator.dart';

/// 카드 애니메이션 컨트롤러
///
/// GameScreenNew에서 사용하는 고수준 애니메이션 API를 제공합니다.
/// 내부적으로 CardAnimator를 사용하여 실제 애니메이션을 처리합니다.
class CardAnimationController extends ChangeNotifier {
  CardAnimator? _animator;
  final List<CardEffectData> _activeEffects = [];
  bool _isDisposed = false;

  // 사운드 콜백들
  VoidCallback? _onMatchSound;
  VoidCallback? _onMissSound;

  /// 초기화 (TickerProvider 필요)
  void initialize(
    TickerProvider vsync, {
    VoidCallback? onImpactSound,
    VoidCallback? onSweepSound,
    VoidCallback? onMatchSound,
    VoidCallback? onMissSound,
  }) {
    _onMatchSound = onMatchSound;
    _onMissSound = onMissSound;
    _animator = CardAnimator(
      vsync: vsync,
      onUpdate: _onAnimationUpdate,
      onImpact: onImpactSound,
      onSweep: onSweepSound,
    );
  }

  /// 현재 애니메이션 중인 카드 목록
  List<CardAnimationState> get animatingCards =>
      _animator?.animatingCards ?? [];

  /// 활성 이펙트 목록
  List<CardEffectData> get activeEffects => List.unmodifiable(_activeEffects);

  /// 애니메이션 진행 중 여부
  bool get isAnimating => _animator?.isAnimating ?? false;

  /// ========================================
  /// 시나리오 A: 손패 → 바닥 (패 내기)
  /// ========================================
  ///
  /// 내 손에서 카드를 바닥으로 내려놓는 애니메이션
  /// - 카드가 손에서 살짝 들어올려짐
  /// - 포물선 궤적으로 바닥까지 이동
  /// - 바닥에 닿을 때 탄성 있는 착지
  Future<void> animatePlayCard({
    required CardData card,
    required Offset from,
    required Offset to,
    bool hasMatch = true, // 바닥에 매칭되는 패가 있는지 여부
  }) async {
    if (_animator == null || _isDisposed) return;

    await _animator!.playHandToFloor(
      card: card,
      startPosition: from,
      endPosition: to,
    );

    // 매칭 여부에 따라 사운드 재생 (내 플레이 시에만)
    if (hasMatch) {
      _onMatchSound?.call();
    } else {
      _onMissSound?.call();
    }

    // 착지 이펙트 추가
    _addImpactEffect(to);
  }

  /// ========================================
  /// 시나리오 B: 덱 → 뒤집기 → 바닥
  /// ========================================
  ///
  /// 중앙 덱에서 카드를 뒤집어 바닥에 놓는 애니메이션
  /// - 덱 위로 카드가 올라옴
  /// - 3D 플립으로 앞면 공개
  /// - 잠시 멈춤 후 바닥으로 이동
  Future<void> animateFlipFromDeck({
    required CardData card,
    required Offset deckPosition,
    required Offset floorPosition,
    bool hasNoMatch = false, // 맞는 바닥패가 없는 경우
  }) async {
    if (_animator == null || _isDisposed) return;

    await _animator!.playDeckFlipToFloor(
      card: card,
      deckPosition: deckPosition,
      endPosition: floorPosition,
    );

    // 매칭 여부에 따라 사운드 재생 (내 플레이 시에만)
    if (hasNoMatch) {
      _onMissSound?.call();
    } else {
      _onMatchSound?.call();
    }

    // 착지 이펙트 추가 (매칭 결과에 따라 다른 메시지 표시)
    String? message;
    if (hasNoMatch) {
      message = '맞는 바닥패가 없어요 😭';
    } else {
      message = '잘 붙었어요 😍';
    }
    _addImpactEffect(floorPosition, message: message);
  }

  /// ========================================
  /// 시나리오 C: 바닥 → 획득 영역 (패 가져오기)
  /// ========================================
  ///
  /// 매칭된 카드들을 획득 영역으로 가져오는 애니메이션
  /// - 흩어진 카드들이 한 점으로 모임
  /// - 빠른 속도로 플레이어 쪽으로 쓸어담김
  /// - 획득 영역에서 작아지며 사라짐
  Future<void> animateCollectCards({
    required List<CardData> cards,
    required List<Offset> fromPositions,
    required Offset toPosition,
    int? bonusCount, // 피 보너스 카운트 등
  }) async {
    if (_animator == null || _isDisposed) return;
    if (cards.isEmpty) return;

    // 중심점 계산 (쓸어담기 시작점)
    final centerX =
        fromPositions.map((p) => p.dx).reduce((a, b) => a + b) /
        fromPositions.length;
    final centerY =
        fromPositions.map((p) => p.dy).reduce((a, b) => a + b) /
        fromPositions.length;
    final gatherPoint = Offset(centerX, centerY);

    await _animator!.playFloorToCapture(
      cards: cards,
      startPositions: fromPositions,
      endPosition: toPosition,
    );

    // 쓸어담기 이펙트
    _addSweepEffect(gatherPoint, toPosition);

    // 카운트 팝업 (보너스가 있으면)
    if (bonusCount != null && bonusCount > 0) {
      _addCountPopup(toPosition, bonusCount);
    }
  }

  /// ========================================
  /// 상대방 카드 내기 애니메이션
  /// ========================================
  Future<void> animateOpponentPlayCard({
    required CardData card,
    required Offset from,
    required Offset to,
  }) async {
    if (_animator == null || _isDisposed) return;

    await _animator!.playOpponentToFloor(
      card: card,
      startPosition: from,
      endPosition: to,
    );

    _addImpactEffect(to);
  }

  /// ========================================
  /// 상대방 카드 획득 애니메이션
  /// ========================================
  Future<void> animateOpponentCollect({
    required List<CardData> cards,
    required List<Offset> fromPositions,
    required Offset toPosition,
  }) async {
    if (_animator == null || _isDisposed) return;
    if (cards.isEmpty) return;

    await _animator!.playFloorToCapture(
      cards: cards,
      startPositions: fromPositions,
      endPosition: toPosition,
    );
  }

  /// 이펙트 추가 헬퍼
  void _addImpactEffect(Offset position, {String? message}) {
    final effect = CardEffectData(
      type: CardEffectType.impact,
      position: position,
      id: DateTime.now().millisecondsSinceEpoch,
      message: message,
    );
    _activeEffects.add(effect);
    notifyListeners();

    // 메시지가 있으면 더 오래 표시 (800ms), 없으면 기본 (300ms)
    final duration = message != null ? 800 : 300;
    Future.delayed(Duration(milliseconds: duration), () {
      _activeEffects.remove(effect);
      if (!_isDisposed) notifyListeners();
    });
  }

  void _addSweepEffect(Offset start, Offset end) {
    final effect = CardEffectData(
      type: CardEffectType.sweep,
      position: start,
      endPosition: end,
      id: DateTime.now().millisecondsSinceEpoch,
    );
    _activeEffects.add(effect);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 400), () {
      _activeEffects.remove(effect);
      if (!_isDisposed) notifyListeners();
    });
  }

  void _addCountPopup(Offset position, int count) {
    final effect = CardEffectData(
      type: CardEffectType.countPopup,
      position: position,
      count: count,
      id: DateTime.now().millisecondsSinceEpoch,
    );
    _activeEffects.add(effect);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 800), () {
      _activeEffects.remove(effect);
      if (!_isDisposed) notifyListeners();
    });
  }

  void _onAnimationUpdate() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// 모든 애니메이션 취소
  void cancelAll() {
    _animator?.cancelAll();
    _activeEffects.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _animator?.dispose();
    _activeEffects.clear();
    super.dispose();
  }
}

/// 이펙트 타입
enum CardEffectType { impact, sweep, countPopup }

/// 이펙트 데이터
class CardEffectData {
  final CardEffectType type;
  final Offset position;
  final Offset? endPosition;
  final int? count;
  final int id;
  final String? message; // 추가 메시지 (예: "맞는 바닥패가 없어요 ㅠ")

  const CardEffectData({
    required this.type,
    required this.position,
    required this.id,
    this.endPosition,
    this.count,
    this.message,
  });
}

/// 위치 키 생성기 (GlobalKey 기반 위치 추적)
class CardPositionTracker {
  final Map<String, GlobalKey> _cardKeys = {};
  final Map<String, Offset> _cachedPositions = {};

  /// 카드 키 가져오기 또는 생성
  GlobalKey getKey(String cardId) {
    return _cardKeys.putIfAbsent(cardId, () => GlobalKey());
  }

  /// 카드의 현재 화면 위치 계산
  Offset? getCardPosition(String cardId) {
    final key = _cardKeys[cardId];
    if (key == null) return _cachedPositions[cardId];

    final context = key.currentContext;
    if (context == null) return _cachedPositions[cardId];

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return _cachedPositions[cardId];

    final position = box.localToGlobal(
      Offset(box.size.width / 2, box.size.height / 2),
    );

    _cachedPositions[cardId] = position;
    return position;
  }

  /// 여러 카드의 위치 계산
  List<Offset> getCardPositions(List<String> cardIds) {
    return cardIds
        .map((id) => getCardPosition(id))
        .whereType<Offset>()
        .toList();
  }

  /// 특정 영역의 중심 위치 계산
  Offset? getZoneCenter(GlobalKey zoneKey) {
    final context = zoneKey.currentContext;
    if (context == null) return null;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;

    return box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
  }

  /// 덱 위치 계산 (덱 중앙 상단)
  Offset? getDeckPosition(GlobalKey deckKey) {
    final context = deckKey.currentContext;
    if (context == null) return null;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;

    return box.localToGlobal(Offset(box.size.width / 2, box.size.height * 0.3));
  }

  /// 획득 영역 위치 계산 (플레이어 기준)
  Offset? getCaptureZonePosition(GlobalKey captureKey) {
    final context = captureKey.currentContext;
    if (context == null) return null;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;

    return box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
  }

  /// 키 정리
  void clear() {
    _cardKeys.clear();
    _cachedPositions.clear();
  }
}
