import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/slot_result.dart';

/// SlotMachineService Provider
final slotMachineServiceProvider = Provider<SlotMachineService>((ref) {
  return SlotMachineService();
});

/// 슬롯머신 게임 서비스
///
/// 확률 기반 결과 결정 방식:
/// 1. 먼저 확률 테이블에서 결과 타입 결정
/// 2. 결과 타입에 맞는 릴 심볼 생성
/// 3. 보상 계산 및 지급
class SlotMachineService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final Random _random = Random();

  // ==================== 상수 정의 ====================

  /// 최소 베팅 금액
  static const int minBet = 10;

  /// 최대 베팅 금액
  static const int maxBet = 100;

  /// 일일 스핀 제한
  static const int maxDailySpins = 10;

  /// 베팅 금액 옵션
  static const List<int> betOptions = [10, 50, 100];

  /// 확률 테이블 (1000 기준 누적 확률)
  /// - 잭팟 (특별월 3매치): 0.4%
  /// - 트리플 (일반월 3매치): 2.0%
  /// - 더블 (2매치): 18%
  /// - 꽝: 79.6%
  static const List<({int threshold, SlotResultType type, double multiplier})> _odds = [
    (threshold: 4, type: SlotResultType.jackpot, multiplier: 40.0),      // 0-3: 0.4%
    (threshold: 24, type: SlotResultType.tripleMatch, multiplier: 10.0), // 4-23: 2.0%
    (threshold: 204, type: SlotResultType.doubleMatch, multiplier: 1.5), // 24-203: 18%
    (threshold: 1000, type: SlotResultType.noMatch, multiplier: 0.0),    // 204-999: 79.6%
  ];

  /// 일반월 목록 (특별월 제외)
  static final List<int> _normalMonths = List.generate(12, (i) => i + 1)
      .where((m) => !SlotResult.specialMonths.contains(m))
      .toList();

  // ==================== 헬퍼 함수 ====================

  /// 오늘 날짜 문자열 반환 (yyyy-MM-dd)
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 두 날짜가 같은 날인지 비교
  bool _isSameDay(String? date1, String? date2) {
    if (date1 == null || date2 == null) return false;
    return date1 == date2;
  }

  // ==================== 스핀 가능 여부 확인 ====================

  /// 스핀 가능 여부 및 남은 횟수 확인 (기본 10회 + 게임 완료 보너스)
  Future<({bool canSpin, int remainingBase, int remainingBonus, int totalRemaining, String? message})> canSpin(String uid) async {
    final today = _getTodayString();
    final dailyRef = _db.child('users/$uid/daily_actions');
    final snapshot = await dailyRef.get();

    if (!snapshot.exists) {
      return (canSpin: true, remainingBase: maxDailySpins, remainingBonus: 0, totalRemaining: maxDailySpins, message: null);
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final lastSlotDate = data['last_slot_date'] as String?;
    final slotSpinCount = (data['slot_spin_count'] as num?)?.toInt() ?? 0;
    final bonusSlotCount = (data['bonus_slot_count'] as num?)?.toInt() ?? 0;
    final bonusSlotEarned = (data['bonus_slot_earned'] as num?)?.toInt() ?? 0;

    // 새로운 날이면 기본 횟수 리셋, 미사용 보너스는 유지
    if (!_isSameDay(lastSlotDate, today)) {
      final unusedBonus = (bonusSlotEarned - bonusSlotCount).clamp(0, 999);
      return (canSpin: true, remainingBase: maxDailySpins, remainingBonus: unusedBonus, totalRemaining: maxDailySpins + unusedBonus, message: null);
    }

    final remainingBase = maxDailySpins - slotSpinCount;
    final remainingBonus = bonusSlotEarned - bonusSlotCount;
    final totalRemaining = remainingBase + remainingBonus;

    if (totalRemaining <= 0) {
      return (
        canSpin: false,
        remainingBase: 0,
        remainingBonus: 0,
        totalRemaining: 0,
        message: '오늘의 슬롯머신 기회를 모두 사용하셨습니다.',
      );
    }

    return (canSpin: true, remainingBase: remainingBase.clamp(0, maxDailySpins), remainingBonus: remainingBonus.clamp(0, 999), totalRemaining: totalRemaining, message: null);
  }

  // ==================== 스핀 실행 ====================

  /// 슬롯머신 스핀 실행 (기본 횟수 먼저 소진, 그 후 보너스 횟수 사용)
  ///
  /// 1. 코인 잔액 확인
  /// 2. 일일 횟수 확인 (기본 + 보너스)
  /// 3. 결과 계산
  /// 4. 코인 차감/지급
  /// 5. 스핀 횟수 업데이트
  Future<({bool success, SlotResult? result, int newBalance, int remainingBase, int remainingBonus, String message})> spin(
    String uid,
    int betAmount,
  ) async {
    final today = _getTodayString();

    // 베팅 금액 유효성 검사
    if (betAmount < minBet || betAmount > maxBet) {
      return (
        success: false,
        result: null,
        newBalance: 0,
        remainingBase: 0,
        remainingBonus: 0,
        message: '베팅 금액은 $minBet~$maxBet 코인이어야 합니다.',
      );
    }

    // 현재 사용자 데이터 확인
    final userSnapshot = await _db.child('users/$uid').get();
    if (!userSnapshot.exists) {
      return (
        success: false,
        result: null,
        newBalance: 0,
        remainingBase: 0,
        remainingBonus: 0,
        message: '사용자 정보를 찾을 수 없습니다.',
      );
    }

    final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
    final walletData = userData['wallet'] as Map?;
    final dailyData = userData['daily_actions'] as Map?;

    final currentCoin = (walletData?['coin'] as num?)?.toInt() ?? 0;
    final totalEarned = (walletData?['total_earned'] as num?)?.toInt() ?? 0;
    final lastSlotDate = dailyData?['last_slot_date'] as String?;
    final slotSpinCount = (dailyData?['slot_spin_count'] as num?)?.toInt() ?? 0;
    final bonusSlotCount = (dailyData?['bonus_slot_count'] as num?)?.toInt() ?? 0;
    final bonusSlotEarned = (dailyData?['bonus_slot_earned'] as num?)?.toInt() ?? 0;

    // 코인 잔액 확인
    if (currentCoin < betAmount) {
      return (
        success: false,
        result: null,
        newBalance: currentCoin,
        remainingBase: 0,
        remainingBonus: 0,
        message: '코인이 부족합니다. (보유: $currentCoin, 필요: $betAmount)',
      );
    }

    // 일일 횟수 확인 (기본 + 보너스)
    final isSameDaySlot = _isSameDay(lastSlotDate, today);
    final currentBaseCount = isSameDaySlot ? slotSpinCount : 0;
    final currentBonusCount = isSameDaySlot ? bonusSlotCount : 0;
    // 새로운 날: 전날 미사용 보너스를 새로운 획득량으로 전환
    final currentBonusEarned = isSameDaySlot
        ? bonusSlotEarned
        : (bonusSlotEarned - bonusSlotCount).clamp(0, 999);

    final remainingBase = maxDailySpins - currentBaseCount;
    final remainingBonus = currentBonusEarned - currentBonusCount;
    final totalRemaining = remainingBase + remainingBonus;

    if (totalRemaining <= 0) {
      return (
        success: false,
        result: null,
        newBalance: currentCoin,
        remainingBase: 0,
        remainingBonus: 0,
        message: '오늘의 슬롯머신 기회를 모두 사용하셨습니다.',
      );
    }

    // 결과 계산
    final result = _calculateResult(betAmount);

    // 코인 계산 (베팅 차감 + 보상)
    final netChange = result.reward - betAmount;
    final newCoin = (currentCoin + netChange).clamp(0, currentCoin + (netChange > 0 ? netChange : 0));
    final newTotalEarned = result.reward > 0 ? totalEarned + result.reward : totalEarned;

    // 기본 횟수 먼저 사용, 기본 횟수가 다 떨어지면 보너스 횟수 사용
    int newBaseCount = currentBaseCount;
    int newBonusCount = currentBonusCount;

    if (remainingBase > 0) {
      newBaseCount = currentBaseCount + 1;
    } else {
      newBonusCount = currentBonusCount + 1;
    }

    // 업데이트 데이터 준비
    final updates = <String, dynamic>{
      'users/$uid/wallet/coin': newCoin,
      'users/$uid/wallet/total_earned': newTotalEarned,
      'users/$uid/daily_actions/last_slot_date': today,
      'users/$uid/daily_actions/slot_spin_count': newBaseCount,
      'users/$uid/daily_actions/bonus_slot_count': newBonusCount,
      'users/$uid/daily_actions/bonus_slot_earned': currentBonusEarned,
    };

    try {
      await _db.update(updates);

      final newRemainingBase = maxDailySpins - newBaseCount;
      final newRemainingBonus = currentBonusEarned - newBonusCount;

      print('[SlotMachineService] Spin result for $uid: ${result.type}, bet: $betAmount, reward: ${result.reward}');

      return (
        success: true,
        result: result,
        newBalance: newCoin,
        remainingBase: newRemainingBase.clamp(0, maxDailySpins),
        remainingBonus: newRemainingBonus.clamp(0, 999),
        message: result.resultMessage,
      );
    } catch (e) {
      print('[SlotMachineService] Spin failed: $e');
      return (
        success: false,
        result: null,
        newBalance: currentCoin,
        remainingBase: 0,
        remainingBonus: 0,
        message: '슬롯머신 처리 중 오류가 발생했습니다.',
      );
    }
  }

  // ==================== 결과 계산 ====================

  /// 확률 테이블 기반 결과 계산
  SlotResult _calculateResult(int betAmount) {
    final roll = _random.nextInt(1000);

    SlotResultType resultType = SlotResultType.noMatch;
    double baseMultiplier = 0.0;

    // 확률 테이블에서 결과 타입 결정
    for (final odd in _odds) {
      if (roll < odd.threshold) {
        resultType = odd.type;
        baseMultiplier = odd.multiplier;
        break;
      }
    }

    // 결과에 맞는 릴 생성
    final reels = _generateReelsForResult(resultType);

    // 잭팟인 경우 월별 배당 적용
    double finalMultiplier = baseMultiplier;
    if (resultType == SlotResultType.jackpot) {
      final jackpotMonth = reels.first;
      finalMultiplier = SlotResult.jackpotMultipliers[jackpotMonth] ?? 40.0;
    }

    // 보상 계산
    final reward = (betAmount * finalMultiplier).toInt();

    return SlotResult(
      reels: reels,
      type: resultType,
      multiplier: finalMultiplier,
      reward: reward,
      betAmount: betAmount,
    );
  }

  /// 결과 타입에 맞는 릴 심볼 생성
  List<int> _generateReelsForResult(SlotResultType type) {
    switch (type) {
      case SlotResultType.jackpot:
        // 특별월 중 랜덤 선택 → 3개 동일
        final specialList = SlotResult.specialMonths.toList();
        final month = specialList[_random.nextInt(specialList.length)];
        return [month, month, month];

      case SlotResultType.tripleMatch:
        // 일반월 중 랜덤 선택 → 3개 동일
        final month = _normalMonths[_random.nextInt(_normalMonths.length)];
        return [month, month, month];

      case SlotResultType.doubleMatch:
        // 2개 같고 1개 다름
        final month1 = _random.nextInt(12) + 1;
        int month2;
        do {
          month2 = _random.nextInt(12) + 1;
        } while (month2 == month1);

        // 랜덤 위치에 다른 카드 배치
        final reels = [month1, month1, month2];
        reels.shuffle(_random);
        return reels;

      case SlotResultType.noMatch:
        // 3개 모두 다름
        final months = <int>{};
        while (months.length < 3) {
          months.add(_random.nextInt(12) + 1);
        }
        return months.toList();
    }
  }

  // ==================== 통계 조회 ====================

  /// 오늘 슬롯머신 통계 조회
  Future<({int baseUsed, int baseRemaining, int bonusUsed, int bonusRemaining, int totalRemaining})> getTodayStats(String uid) async {
    final today = _getTodayString();
    final dailyRef = _db.child('users/$uid/daily_actions');
    final snapshot = await dailyRef.get();

    if (!snapshot.exists) {
      return (baseUsed: 0, baseRemaining: maxDailySpins, bonusUsed: 0, bonusRemaining: 0, totalRemaining: maxDailySpins);
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final lastSlotDate = data['last_slot_date'] as String?;
    final slotSpinCount = (data['slot_spin_count'] as num?)?.toInt() ?? 0;
    final bonusSlotCount = (data['bonus_slot_count'] as num?)?.toInt() ?? 0;
    final bonusSlotEarned = (data['bonus_slot_earned'] as num?)?.toInt() ?? 0;

    if (!_isSameDay(lastSlotDate, today)) {
      final unusedBonus = (bonusSlotEarned - bonusSlotCount).clamp(0, 999);
      return (baseUsed: 0, baseRemaining: maxDailySpins, bonusUsed: 0, bonusRemaining: unusedBonus, totalRemaining: maxDailySpins + unusedBonus);
    }

    final baseRemaining = (maxDailySpins - slotSpinCount).clamp(0, maxDailySpins);
    final bonusRemaining = (bonusSlotEarned - bonusSlotCount).clamp(0, 999);

    return (
      baseUsed: slotSpinCount,
      baseRemaining: baseRemaining,
      bonusUsed: bonusSlotCount,
      bonusRemaining: bonusRemaining,
      totalRemaining: baseRemaining + bonusRemaining,
    );
  }
}
