import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_wallet.dart';
import 'slot_machine_service.dart';

/// CoinService 인스턴스 Provider
final coinServiceProvider = Provider<CoinService>((ref) {
  return CoinService();
});

/// 코인 경제 시스템을 처리하는 서비스 클래스
class CoinService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final Random _random = Random();

  // ==================== 상수 정의 ====================

  /// 출석 체크 보상 코인
  static const int attendanceReward = 10;

  /// 기부 코인 수량
  static const int donationAmount = 10;

  /// 일일 룰렛 최대 횟수
  static const int maxDailyRoulette = 3;

  /// 게임 입장 최소 코인
  static const int minEntryCoins = 10;

  /// 룰렛 확률 분포 (누적 확률)
  /// 3% +100, 7% +50, 20% +10, 60% 0, 10% -10
  static const List<({int threshold, int reward})> rouletteOdds = [
    (threshold: 3, reward: 100),   // 0-2: +100 (3%)
    (threshold: 10, reward: 50),   // 3-9: +50 (7%)
    (threshold: 30, reward: 10),   // 10-29: +10 (20%)
    (threshold: 90, reward: 0),    // 30-89: 0 (60%)
    (threshold: 100, reward: -10), // 90-99: -10 (10%)
  ];

  // ==================== 헬퍼 함수 ====================

  /// 두 날짜가 같은 날인지 비교 (yyyy-MM-dd 형식)
  bool isSameDay(String? date1, String? date2) {
    if (date1 == null || date2 == null) return false;
    return date1 == date2;
  }

  /// Firebase에서 반환된 중첩 맵을 안전하게 Map<String, dynamic>으로 변환
  static Map<String, dynamic>? _toStringDynamicMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// 오늘 날짜 문자열 반환 (yyyy-MM-dd)
  String getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 날짜 문자열에서 DateTime 파싱
  DateTime? parseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  // ==================== 코인 조작 ====================

  /// 코인 추가 (트랜잭션)
  Future<int> addCoins(String uid, int amount) async {
    final walletRef = _db.child('users/$uid/wallet');

    final result = await walletRef.runTransaction((data) {
      if (data == null) {
        return Transaction.abort();
      }

      final wallet = UserWallet.fromJson(Map<String, dynamic>.from(data as Map));
      final newCoin = wallet.coin + amount;
      final newTotalEarned = amount > 0
          ? wallet.totalEarned + amount
          : wallet.totalEarned;

      return Transaction.success(
        wallet.copyWith(coin: newCoin, totalEarned: newTotalEarned).toJson(),
      );
    });

    if (result.committed && result.snapshot.value != null) {
      final updatedWallet = UserWallet.fromJson(
        Map<String, dynamic>.from(result.snapshot.value as Map),
      );
      print('[CoinService] Added $amount coins to $uid. New balance: ${updatedWallet.coin}');
      return updatedWallet.coin;
    }

    throw Exception('Failed to add coins');
  }

  /// 코인 차감 (트랜잭션, 음수 방지)
  Future<int> deductCoins(String uid, int amount) async {
    final walletRef = _db.child('users/$uid/wallet');

    final result = await walletRef.runTransaction((data) {
      if (data == null) {
        return Transaction.abort();
      }

      final wallet = UserWallet.fromJson(Map<String, dynamic>.from(data as Map));
      // 음수 방지: max(0, current - amount)
      final newCoin = (wallet.coin - amount).clamp(0, wallet.coin);

      return Transaction.success(
        wallet.copyWith(coin: newCoin).toJson(),
      );
    });

    if (result.committed && result.snapshot.value != null) {
      final updatedWallet = UserWallet.fromJson(
        Map<String, dynamic>.from(result.snapshot.value as Map),
      );
      print('[CoinService] Deducted $amount coins from $uid. New balance: ${updatedWallet.coin}');
      return updatedWallet.coin;
    }

    throw Exception('Failed to deduct coins');
  }

  // ==================== 출석 체크 ====================

  /// 출석 체크 가능 여부 확인
  Future<bool> canCheckAttendance(String uid) async {
    final dailyRef = _db.child('users/$uid/daily_actions');
    final snapshot = await dailyRef.get();

    if (!snapshot.exists) return true;

    final dailyActions = DailyActions.fromJson(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    return !isSameDay(dailyActions.lastAttendance, getTodayString());
  }

  /// 출석 체크 실행 (+10 코인)
  Future<({bool success, int newBalance, String message})> checkAttendance(String uid) async {
    final today = getTodayString();
    final userRef = _db.child('users/$uid');

    // 먼저 현재 상태 확인
    final currentSnapshot = await userRef.get();
    if (!currentSnapshot.exists) {
      print('[CoinService] User data not found for $uid');
      return (
        success: false,
        newBalance: 0,
        message: '사용자 정보를 찾을 수 없습니다.',
      );
    }

    final currentData = Map<String, dynamic>.from(currentSnapshot.value as Map);
    final currentDaily = DailyActions.fromJson(
      _toStringDynamicMap(currentData['daily_actions']),
    );

    // 이미 출석 체크했는지 확인
    if (isSameDay(currentDaily.lastAttendance, today)) {
      print('[CoinService] Already checked attendance today for $uid');
      return (
        success: false,
        newBalance: 0,
        message: '오늘은 이미 출석 체크를 하셨습니다.',
      );
    }

    // 출석 체크와 코인 지급을 업데이트로 처리
    try {
      final currentWallet = UserWallet.fromJson(
        _toStringDynamicMap(currentData['wallet']),
      );

      final newDailyActions = currentDaily.copyWith(lastAttendance: today);
      final newWallet = currentWallet.copyWith(
        coin: currentWallet.coin + attendanceReward,
        totalEarned: currentWallet.totalEarned + attendanceReward,
      );

      final updates = <String, dynamic>{
        'users/$uid/daily_actions': newDailyActions.toJson(),
        'users/$uid/wallet': newWallet.toJson(),
      };

      await _db.update(updates);

      print('[CoinService] Attendance checked for $uid. Reward: +$attendanceReward');
      return (
        success: true,
        newBalance: newWallet.coin,
        message: '출석 체크 완료! +$attendanceReward 코인',
      );
    } catch (e) {
      print('[CoinService] Attendance update failed: $e');
      return (
        success: false,
        newBalance: 0,
        message: '출석 체크 처리 중 오류가 발생했습니다. 다시 시도해주세요.',
      );
    }
  }

  // ==================== 코인 룰렛 ====================

  /// 룰렛 돌리기 가능 여부 확인 (기본 3회 + 게임 완료 보너스)
  Future<({bool canSpin, int remainingBase, int remainingBonus, int totalRemaining})> canSpinRoulette(String uid) async {
    final dailyRef = _db.child('users/$uid/daily_actions');
    final snapshot = await dailyRef.get();

    if (!snapshot.exists) {
      return (canSpin: true, remainingBase: maxDailyRoulette, remainingBonus: 0, totalRemaining: maxDailyRoulette);
    }

    final dailyActions = DailyActions.fromJson(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    final today = getTodayString();
    final isSameDayRoulette = isSameDay(dailyActions.lastRouletteDate, today);

    if (!isSameDayRoulette) {
      // 새로운 날: 기본 횟수와 보너스 횟수 모두 리셋
      return (canSpin: true, remainingBase: maxDailyRoulette, remainingBonus: 0, totalRemaining: maxDailyRoulette);
    }

    final remainingBase = maxDailyRoulette - dailyActions.rouletteCount;
    final remainingBonus = dailyActions.bonusRouletteEarned - dailyActions.bonusRouletteCount;
    final totalRemaining = remainingBase + remainingBonus;
    return (canSpin: totalRemaining > 0, remainingBase: remainingBase.clamp(0, maxDailyRoulette), remainingBonus: remainingBonus.clamp(0, 999), totalRemaining: totalRemaining);
  }

  /// 게임 완료 시 보너스 룰렛 +1 추가
  Future<void> addBonusRoulette(String uid) async {
    final today = getTodayString();
    final dailyRef = _db.child('users/$uid/daily_actions');

    // 트랜잭션으로 안전하게 업데이트
    await dailyRef.runTransaction((Object? currentData) {
      DailyActions currentDaily;
      if (currentData == null) {
        currentDaily = const DailyActions();
      } else {
        currentDaily = DailyActions.fromJson(
          Map<String, dynamic>.from(currentData as Map),
        );
      }

      final isSameDay_ = isSameDay(currentDaily.lastRouletteDate, today);

      // 새로운 날이면 보너스 리셋
      final newBonusEarned = isSameDay_ ? currentDaily.bonusRouletteEarned + 1 : 1;
      final newBonusCount = isSameDay_ ? currentDaily.bonusRouletteCount : 0;

      final newDailyActions = currentDaily.copyWith(
        bonusRouletteEarned: newBonusEarned,
        bonusRouletteCount: newBonusCount,
        lastRouletteDate: today,
      );

      return Transaction.success(newDailyActions.toJson());
    });

    print('[CoinService] Bonus roulette added for $uid');
  }

  /// 게임 완료 시 보너스 슬롯머신 추가 (게임당 10회)
  Future<void> addBonusSlot(String uid) async {
    final today = getTodayString();
    final dailyRef = _db.child('users/$uid/daily_actions');
    final bonusAmount = SlotMachineService.bonusSpinsPerGame;

    // 트랜잭션으로 안전하게 업데이트
    await dailyRef.runTransaction((Object? currentData) {
      DailyActions currentDaily;
      if (currentData == null) {
        currentDaily = const DailyActions();
      } else {
        currentDaily = DailyActions.fromJson(
          Map<String, dynamic>.from(currentData as Map),
        );
      }

      final isSameDay_ = isSameDay(currentDaily.lastSlotDate, today);

      // 새로운 날이면 보너스 리셋
      final newBonusEarned = isSameDay_ ? currentDaily.bonusSlotEarned + bonusAmount : bonusAmount;
      final newBonusCount = isSameDay_ ? currentDaily.bonusSlotCount : 0;

      final newDailyActions = currentDaily.copyWith(
        bonusSlotEarned: newBonusEarned,
        bonusSlotCount: newBonusCount,
        lastSlotDate: today,
      );

      return Transaction.success(newDailyActions.toJson());
    });

    print('[CoinService] Bonus slot added for $uid');
  }

  /// 룰렛 결과 계산
  int _calculateRouletteReward() {
    final roll = _random.nextInt(100);
    for (final odds in rouletteOdds) {
      if (roll < odds.threshold) {
        return odds.reward;
      }
    }
    return 0;
  }

  /// 룰렛 돌리기 실행 (기본 횟수 먼저 소진, 그 후 보너스 횟수 사용)
  Future<({bool success, int reward, int newBalance, int remainingBase, int remainingBonus, String message})> spinRoulette(String uid) async {
    final today = getTodayString();
    final userRef = _db.child('users/$uid');

    // 먼저 현재 상태 확인
    final currentSnapshot = await userRef.get();
    if (!currentSnapshot.exists) {
      print('[CoinService] User data not found for roulette: $uid');
      return (
        success: false,
        reward: 0,
        newBalance: 0,
        remainingBase: 0,
        remainingBonus: 0,
        message: '사용자 정보를 찾을 수 없습니다.',
      );
    }

    final currentData = Map<String, dynamic>.from(currentSnapshot.value as Map);
    final currentDaily = DailyActions.fromJson(
      _toStringDynamicMap(currentData['daily_actions']),
    );

    // 오늘 룰렛 횟수 체크
    final isSameDayRoulette = isSameDay(currentDaily.lastRouletteDate, today);
    final currentBaseCount = isSameDayRoulette ? currentDaily.rouletteCount : 0;
    final currentBonusCount = isSameDayRoulette ? currentDaily.bonusRouletteCount : 0;
    // 새로운 날: 보너스 횟수 0으로 리셋
    // 같은 날: 기존 획득량 유지
    final currentBonusEarned = isSameDayRoulette
        ? currentDaily.bonusRouletteEarned
        : 0;

    final remainingBase = maxDailyRoulette - currentBaseCount;
    final remainingBonus = currentBonusEarned - currentBonusCount;
    final totalRemaining = remainingBase + remainingBonus;

    if (totalRemaining <= 0) {
      print('[CoinService] Roulette limit reached for $uid');
      return (
        success: false,
        reward: 0,
        newBalance: 0,
        remainingBase: 0,
        remainingBonus: 0,
        message: '오늘의 룰렛 기회를 모두 사용하셨습니다.',
      );
    }

    // 룰렛 결과 미리 계산
    final reward = _calculateRouletteReward();

    // 룰렛 처리를 업데이트로 처리
    try {
      final currentWallet = UserWallet.fromJson(
        _toStringDynamicMap(currentData['wallet']),
      );

      // 코인 업데이트 (음수 방지)
      final newCoin = (currentWallet.coin + reward).clamp(0, currentWallet.coin + (reward > 0 ? reward : 0));
      final newTotalEarned = reward > 0
          ? currentWallet.totalEarned + reward
          : currentWallet.totalEarned;

      // 기본 횟수 먼저 사용, 기본 횟수가 다 떨어지면 보너스 횟수 사용
      int newBaseCount = currentBaseCount;
      int newBonusCount = currentBonusCount;
      
      if (remainingBase > 0) {
        newBaseCount = currentBaseCount + 1;
      } else {
        newBonusCount = currentBonusCount + 1;
      }

      final newDailyActions = currentDaily.copyWith(
        rouletteCount: newBaseCount,
        bonusRouletteCount: newBonusCount,
        bonusRouletteEarned: currentBonusEarned,
        lastRouletteDate: today,
      );
      final newWallet = currentWallet.copyWith(
        coin: newCoin,
        totalEarned: newTotalEarned,
      );

      final updates = <String, dynamic>{
        'users/$uid/daily_actions': newDailyActions.toJson(),
        'users/$uid/wallet': newWallet.toJson(),
      };

      await _db.update(updates);

      final newRemainingBase = maxDailyRoulette - newDailyActions.rouletteCount;
      final newRemainingBonus = newDailyActions.bonusRouletteEarned - newDailyActions.bonusRouletteCount;
      final rewardText = reward > 0 ? '+$reward' : (reward < 0 ? '$reward' : '0');

      print('[CoinService] Roulette spun for $uid. Reward: $rewardText');
      return (
        success: true,
        reward: reward,
        newBalance: newWallet.coin,
        remainingBase: newRemainingBase.clamp(0, maxDailyRoulette),
        remainingBonus: newRemainingBonus.clamp(0, 999),
        message: '룰렛 결과: $rewardText 코인!',
      );
    } catch (e) {
      print('[CoinService] Roulette update failed: $e');
      return (
        success: false,
        reward: 0,
        newBalance: 0,
        remainingBase: 0,
        remainingBonus: 0,
        message: '룰렛 처리 중 오류가 발생했습니다. 다시 시도해주세요.',
      );
    }
  }

  // ==================== 코인 기부 ====================

  /// 기부 가능 여부 확인 (횟수 제한 없음 - 코인만 있으면 가능)
  Future<bool> canDonate(String uid) async {
    final walletRef = _db.child('users/$uid/wallet');
    final snapshot = await walletRef.get();

    if (!snapshot.exists) return false;

    final wallet = UserWallet.fromJson(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    return wallet.coin > 0;
  }

  /// 코인 기부 실행 (트랜잭션)
  Future<({bool success, int senderBalance, String message})> donateCoins(
    String senderUid,
    String receiverUid,
  ) async {
    if (senderUid == receiverUid) {
      return (
        success: false,
        senderBalance: 0,
        message: '자기 자신에게는 기부할 수 없습니다.',
      );
    }

    final today = getTodayString();

    // 두 유저의 데이터를 원자적으로 업데이트
    final updates = <String, dynamic>{};
    var senderNewBalance = 0;

    // 먼저 현재 상태 읽기
    final senderSnapshot = await _db.child('users/$senderUid').get();
    final receiverSnapshot = await _db.child('users/$receiverUid').get();

    if (!senderSnapshot.exists) {
      return (success: false, senderBalance: 0, message: '보내는 사람 정보를 찾을 수 없습니다.');
    }
    if (!receiverSnapshot.exists) {
      return (success: false, senderBalance: 0, message: '받는 사람 정보를 찾을 수 없습니다.');
    }

    final senderData = Map<String, dynamic>.from(senderSnapshot.value as Map);
    final receiverData = Map<String, dynamic>.from(receiverSnapshot.value as Map);

    final senderDaily = DailyActions.fromJson(
      _toStringDynamicMap(senderData['daily_actions']),
    );
    final senderWallet = UserWallet.fromJson(
      _toStringDynamicMap(senderData['wallet']),
    );
    final receiverWallet = UserWallet.fromJson(
      _toStringDynamicMap(receiverData['wallet']),
    );

    // 오늘 이미 기부했는지 확인
    if (isSameDay(senderDaily.lastDonation, today)) {
      return (
        success: false,
        senderBalance: senderWallet.coin,
        message: '오늘은 이미 기부를 하셨습니다.',
      );
    }

    // 코인 부족 확인
    if (senderWallet.coin < donationAmount) {
      return (
        success: false,
        senderBalance: senderWallet.coin,
        message: '코인이 부족합니다. (필요: $donationAmount, 보유: ${senderWallet.coin})',
      );
    }

    // 업데이트 데이터 준비
    final newSenderDaily = senderDaily.copyWith(lastDonation: today);
    final newSenderWallet = senderWallet.copyWith(
      coin: senderWallet.coin - donationAmount,
    );
    final newReceiverWallet = receiverWallet.copyWith(
      coin: receiverWallet.coin + donationAmount,
      totalEarned: receiverWallet.totalEarned + donationAmount,
    );

    updates['users/$senderUid/daily_actions'] = newSenderDaily.toJson();
    updates['users/$senderUid/wallet'] = newSenderWallet.toJson();
    updates['users/$receiverUid/wallet'] = newReceiverWallet.toJson();

    try {
      await _db.update(updates);
      senderNewBalance = newSenderWallet.coin;
      print('[CoinService] Donation completed: $senderUid -> $receiverUid ($donationAmount coins)');
      return (
        success: true,
        senderBalance: senderNewBalance,
        message: '기부 완료! -$donationAmount 코인',
      );
    } catch (e) {
      print('[CoinService] Donation failed: $e');
      return (
        success: false,
        senderBalance: senderWallet.coin,
        message: '기부 중 오류가 발생했습니다.',
      );
    }
  }

  /// 사용자 지정 금액 코인 기부 실행 (횟수 제한 없음)
  Future<({bool success, int senderBalance, String message})> donateCoinsWithAmount(
    String senderUid,
    String receiverUid,
    int amount,
  ) async {
    if (senderUid == receiverUid) {
      return (
        success: false,
        senderBalance: 0,
        message: '자기 자신에게는 기부할 수 없습니다.',
      );
    }

    if (amount <= 0) {
      return (
        success: false,
        senderBalance: 0,
        message: '기부 금액은 1 코인 이상이어야 합니다.',
      );
    }

    // 두 유저의 데이터를 원자적으로 업데이트
    final updates = <String, dynamic>{};
    var senderNewBalance = 0;

    // 먼저 현재 상태 읽기
    final senderSnapshot = await _db.child('users/$senderUid').get();
    final receiverSnapshot = await _db.child('users/$receiverUid').get();

    if (!senderSnapshot.exists) {
      return (success: false, senderBalance: 0, message: '보내는 사람 정보를 찾을 수 없습니다.');
    }
    if (!receiverSnapshot.exists) {
      return (success: false, senderBalance: 0, message: '받는 사람 정보를 찾을 수 없습니다.');
    }

    final senderData = Map<String, dynamic>.from(senderSnapshot.value as Map);
    final receiverData = Map<String, dynamic>.from(receiverSnapshot.value as Map);

    final senderWallet = UserWallet.fromJson(
      _toStringDynamicMap(senderData['wallet']),
    );
    final receiverWallet = UserWallet.fromJson(
      _toStringDynamicMap(receiverData['wallet']),
    );

    // 코인 부족 확인
    if (senderWallet.coin < amount) {
      return (
        success: false,
        senderBalance: senderWallet.coin,
        message: '코인이 부족합니다. (필요: $amount, 보유: ${senderWallet.coin})',
      );
    }

    // 업데이트 데이터 준비 (일일 제한 없음 - lastDonation 업데이트 하지 않음)
    final newSenderWallet = senderWallet.copyWith(
      coin: senderWallet.coin - amount,
    );
    final newReceiverWallet = receiverWallet.copyWith(
      coin: receiverWallet.coin + amount,
      totalEarned: receiverWallet.totalEarned + amount,
    );

    updates['users/$senderUid/wallet'] = newSenderWallet.toJson();
    updates['users/$receiverUid/wallet'] = newReceiverWallet.toJson();

    try {
      await _db.update(updates);
      senderNewBalance = newSenderWallet.coin;
      print('[CoinService] Donation completed: $senderUid -> $receiverUid ($amount coins)');
      return (
        success: true,
        senderBalance: senderNewBalance,
        message: '기부 완료! -$amount 코인',
      );
    } catch (e) {
      print('[CoinService] Donation failed: $e');
      return (
        success: false,
        senderBalance: senderWallet.coin,
        message: '기부 중 오류가 발생했습니다.',
      );
    }
  }

  // ==================== 랭킹 ====================

  /// 상위 100명 랭킹 조회
  Future<List<({String uid, String displayName, String? avatar, int coin, int rank})>> getLeaderboard({int limit = 100}) async {
    try {
      final usersRef = _db.child('users');

      // coin 기준 내림차순 정렬, 상위 limit명
      final query = usersRef.orderByChild('wallet/coin').limitToLast(limit);
      print('[CoinService] Fetching leaderboard...');
      final snapshot = await query.get();

      if (!snapshot.exists) {
        print('[CoinService] No users found for leaderboard');
        return [];
      }
      print('[CoinService] Leaderboard data fetched successfully');

    final List<({String uid, String displayName, String? avatar, int coin, int rank})> leaderboard = [];

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final entries = data.entries.toList();

    // coin 기준 내림차순 정렬
    entries.sort((a, b) {
      final aWallet = (a.value as Map)['wallet'] as Map?;
      final bWallet = (b.value as Map)['wallet'] as Map?;
      final aCoin = (aWallet?['coin'] as num?)?.toInt() ?? 0;
      final bCoin = (bWallet?['coin'] as num?)?.toInt() ?? 0;
      return bCoin.compareTo(aCoin);
    });

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final userData = Map<String, dynamic>.from(entry.value as Map);
      final profile = _toStringDynamicMap(userData['profile']);
      final wallet = UserWallet.fromJson(
        _toStringDynamicMap(userData['wallet']),
      );

      leaderboard.add((
        uid: entry.key,
        displayName: profile?['name'] as String? ?? 'Unknown',
        avatar: profile?['avatar'] as String?,
        coin: wallet.coin,
        rank: i + 1,
      ));
    }

    print('[CoinService] Leaderboard loaded: ${leaderboard.length} users');
    return leaderboard;
    } catch (e) {
      print('[CoinService] Error fetching leaderboard: $e');
      return [];
    }
  }

  // ==================== 게임 관련 ====================

  /// 게임 입장 가능 여부 확인
  Future<bool> canEnterGame(String uid) async {
    final walletRef = _db.child('users/$uid/wallet');
    final snapshot = await walletRef.get();

    if (!snapshot.exists) return false;

    final wallet = UserWallet.fromJson(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    return wallet.coin >= minEntryCoins;
  }

  /// 맞고 2인 게임 정산 (승자에게 코인 이전)
  /// 
  /// 코인 정산 배수 (박 규칙):
  /// - 광박(상대 광 0장): ×2
  /// - 피박(상대 피 7장 이하): ×2
  /// - 고박(패자가 1고+ 상태에서 승자가 1고+로 승리): ×2
  /// 
  /// [points]: 승자의 최종 점수 (이미 점수 배수 적용된 값)
  /// [coinMultiplier]: 코인 정산 배수 (광박/피박/고박 배수 곱)
  Future<({int actualTransfer, String details})> settleGame({
    required String winnerUid,
    required String loserUid,
    required int points,
    required int coinMultiplier,
    bool isGwangBak = false,
    bool isPiBak = false,
    bool isGobak = false,
    bool isAllIn = false,
  }) async {
    // 이전할 코인 계산: 점수 × 코인 배수
    int transferAmount = points * coinMultiplier;

    // 올인일 경우 패자의 모든 코인 이전
    if (isAllIn) {
      final loserWalletRef = _db.child('users/$loserUid/wallet');
      final loserSnapshot = await loserWalletRef.get();

      if (loserSnapshot.exists) {
        final loserWallet = UserWallet.fromJson(
          Map<String, dynamic>.from(loserSnapshot.value as Map),
        );
        transferAmount = loserWallet.coin;
      }
    }

    // 트랜잭션으로 코인 이전
    final updates = <String, dynamic>{};

    final winnerSnapshot = await _db.child('users/$winnerUid/wallet').get();
    final loserSnapshot = await _db.child('users/$loserUid/wallet').get();

    if (!winnerSnapshot.exists || !loserSnapshot.exists) {
      throw Exception('Player wallet not found');
    }

    final winnerWallet = UserWallet.fromJson(
      Map<String, dynamic>.from(winnerSnapshot.value as Map),
    );
    final loserWallet = UserWallet.fromJson(
      Map<String, dynamic>.from(loserSnapshot.value as Map),
    );

    // 패자 코인 부족 시 가진 만큼만 이전
    final actualTransfer = loserWallet.coin < transferAmount
        ? loserWallet.coin
        : transferAmount;

    final newWinnerWallet = winnerWallet.copyWith(
      coin: winnerWallet.coin + actualTransfer,
      totalEarned: winnerWallet.totalEarned + actualTransfer,
    );
    final newLoserWallet = loserWallet.copyWith(
      coin: (loserWallet.coin - actualTransfer).clamp(0, loserWallet.coin),
    );

    updates['users/$winnerUid/wallet'] = newWinnerWallet.toJson();
    updates['users/$loserUid/wallet'] = newLoserWallet.toJson();

    await _db.update(updates);
    
    // 정산 상세 내역 생성
    final List<String> bakDetails = [];
    if (isGwangBak) bakDetails.add('광박');
    if (isPiBak) bakDetails.add('피박');
    if (isGobak) bakDetails.add('고박');
    final bakStr = bakDetails.isNotEmpty ? ' (${bakDetails.join(', ')})' : '';
    
    print('[CoinService] Game settled: $winnerUid wins $actualTransfer coins from $loserUid$bakStr');
    
    return (actualTransfer: actualTransfer, details: bakStr);
  }

  /// 고스톱 3인 게임 정산 (승자가 2명의 패자에게서 코인 수령)
  /// 
  /// 코인 정산 배수 (박 규칙):
  /// - 광박(상대 광 0장): 해당 패자에게 ×2
  /// - 피박(상대 피 5장 이하): 해당 패자에게 ×2
  /// - 고박(고스톱): 마지막 고 선언자가 패배 시 해당 플레이어만 ×2
  /// 
  /// [points]: 승자의 최종 점수 (이미 점수 배수 적용된 값)
  /// [loser1CoinMultiplier], [loser2CoinMultiplier]: 각 패자별 코인 배수
  /// [loser1IsLastGoDeclarer], [loser2IsLastGoDeclarer]: 마지막 고 선언자 여부 (고박 판정용)
  /// 
  /// 반환값: 각 패자별 실제 이전 금액 및 상세 내역
  Future<({int loser1Transfer, int loser2Transfer, String loser1Details, String loser2Details})> settleGostopGame({
    required String winnerUid,
    required String loser1Uid,
    required String loser2Uid,
    required int points,
    bool loser1GwangBak = false,
    bool loser1PiBak = false,
    bool loser1IsLastGoDeclarer = false,
    bool loser2GwangBak = false,
    bool loser2PiBak = false,
    bool loser2IsLastGoDeclarer = false,
  }) async {
    // 각 패자별 코인 배수 계산
    int loser1Multiplier = 1;
    int loser2Multiplier = 1;
    
    // 패자1 배수 계산
    if (loser1GwangBak) loser1Multiplier *= 2;
    if (loser1PiBak) loser1Multiplier *= 2;
    if (loser1IsLastGoDeclarer) loser1Multiplier *= 2;  // 고스톱 고박: 마지막 고 선언자만
    
    // 패자2 배수 계산
    if (loser2GwangBak) loser2Multiplier *= 2;
    if (loser2PiBak) loser2Multiplier *= 2;
    if (loser2IsLastGoDeclarer) loser2Multiplier *= 2;  // 고스톱 고박: 마지막 고 선언자만

    // 이전할 코인 계산 (각 패자별로 다른 배수 적용)
    int loser1TransferAmount = points * loser1Multiplier;
    int loser2TransferAmount = points * loser2Multiplier;

    // 각 패자의 지갑 정보 가져오기
    final winnerSnapshot = await _db.child('users/$winnerUid/wallet').get();
    final loser1Snapshot = await _db.child('users/$loser1Uid/wallet').get();
    final loser2Snapshot = await _db.child('users/$loser2Uid/wallet').get();

    if (!winnerSnapshot.exists) {
      throw Exception('Winner wallet not found');
    }

    final winnerWallet = UserWallet.fromJson(
      Map<String, dynamic>.from(winnerSnapshot.value as Map),
    );

    // 패자1 정산
    int loser1Transfer = 0;
    UserWallet? newLoser1Wallet;
    if (loser1Snapshot.exists) {
      final loser1Wallet = UserWallet.fromJson(
        Map<String, dynamic>.from(loser1Snapshot.value as Map),
      );
      // 패자 코인 부족 시 가진 만큼만 이전
      loser1Transfer = loser1Wallet.coin < loser1TransferAmount
          ? loser1Wallet.coin
          : loser1TransferAmount;
      newLoser1Wallet = loser1Wallet.copyWith(
        coin: (loser1Wallet.coin - loser1Transfer).clamp(0, loser1Wallet.coin),
      );
    }

    // 패자2 정산
    int loser2Transfer = 0;
    UserWallet? newLoser2Wallet;
    if (loser2Snapshot.exists) {
      final loser2Wallet = UserWallet.fromJson(
        Map<String, dynamic>.from(loser2Snapshot.value as Map),
      );
      // 패자 코인 부족 시 가진 만큼만 이전
      loser2Transfer = loser2Wallet.coin < loser2TransferAmount
          ? loser2Wallet.coin
          : loser2TransferAmount;
      newLoser2Wallet = loser2Wallet.copyWith(
        coin: (loser2Wallet.coin - loser2Transfer).clamp(0, loser2Wallet.coin),
      );
    }

    // 승자는 두 패자에게서 받은 금액의 합계를 수령
    final totalTransfer = loser1Transfer + loser2Transfer;
    final newWinnerWallet = winnerWallet.copyWith(
      coin: winnerWallet.coin + totalTransfer,
      totalEarned: winnerWallet.totalEarned + totalTransfer,
    );

    // 트랜잭션으로 코인 이전
    final updates = <String, dynamic>{};
    updates['users/$winnerUid/wallet'] = newWinnerWallet.toJson();
    if (newLoser1Wallet != null) {
      updates['users/$loser1Uid/wallet'] = newLoser1Wallet.toJson();
    }
    if (newLoser2Wallet != null) {
      updates['users/$loser2Uid/wallet'] = newLoser2Wallet.toJson();
    }

    await _db.update(updates);
    
    // 정산 상세 내역 생성
    String makeDetails(bool gwangBak, bool piBak, bool isLastGo) {
      final List<String> details = [];
      if (gwangBak) details.add('광박');
      if (piBak) details.add('피박');
      if (isLastGo) details.add('고박');
      return details.isNotEmpty ? '(${details.join(', ')})' : '';
    }
    
    final loser1Details = makeDetails(loser1GwangBak, loser1PiBak, loser1IsLastGoDeclarer);
    final loser2Details = makeDetails(loser2GwangBak, loser2PiBak, loser2IsLastGoDeclarer);
    
    print('[CoinService] Gostop game settled: $winnerUid wins $loser1Transfer$loser1Details from $loser1Uid, $loser2Transfer$loser2Details from $loser2Uid (total: $totalTransfer)');

    return (
      loser1Transfer: loser1Transfer, 
      loser2Transfer: loser2Transfer,
      loser1Details: loser1Details,
      loser2Details: loser2Details,
    );
  }

  // ==================== 유저 정보 ====================

  /// 유저 지갑 정보 가져오기
  Future<UserWallet?> getUserWallet(String uid) async {
    final walletRef = _db.child('users/$uid/wallet');
    final snapshot = await walletRef.get();

    if (!snapshot.exists) return null;

    return UserWallet.fromJson(
      Map<String, dynamic>.from(snapshot.value as Map),
    );
  }

  /// 유저 지갑 스트림
  Stream<UserWallet?> getUserWalletStream(String uid) {
    return _db.child('users/$uid/wallet').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return UserWallet.fromJson(
        Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  // ==================== 光끼 점수 시스템 ====================

  /// 게임 중 광끼 점수 추가 (특수룰 발동 시)
  /// - 뻑 발생 (내가 3장 못 가져감): +2점
  /// - 피 빼앗김 (특수룰로 피 잃음): +2점
  /// - 턴에 카드 획득 실패: +1점
  ///
  /// 반환값: 추가된 점수 (UI 애니메이션용)
  Future<int> addGwangkkiScore({
    required String uid,
    required int points,
  }) async {
    if (points <= 0) return 0;

    final walletRef = _db.child('users/$uid/wallet/gwangkki_score');

    final result = await walletRef.runTransaction((data) {
      double currentScore = (data as num?)?.toDouble() ?? 0;
      double newScore = (currentScore + points).clamp(0, 100);
      return Transaction.success(newScore);
    });

    if (result.committed) {
      print('[CoinService] GwangKki score added for $uid: +$points (total: ${result.snapshot.value})');
      return points;
    }

    return 0;
  }

  /// 光끼 점수 업데이트 (게임 완료 시 호출)
  /// - 승자: 광끼 게이지 변동 없음
  /// - 패자: 잃은 코인 수의 50%만큼 광끼게이지 축적
  ///
  /// 반환값: 패자에게 추가된 광끼 점수 (UI 표시용)
  Future<int> updateGwangkkiScores({
    required String winnerUid,
    required String loserUid,
    required int winnerScore,
    required bool isDraw,
    int lostCoins = 0,  // 패자가 잃은 코인 수
  }) async {
    // 무승부 시 변동 없음
    if (isDraw) {
      print('[CoinService] GwangKki scores unchanged - Draw');
      return 0;
    }

    // 패자: 잃은 코인 수의 50%만큼 광끼게이지 축적
    int loserBonus = (lostCoins * 0.5).round();

    if (loserBonus > 0) {
      final loserWalletRef = _db.child('users/$loserUid/wallet/gwangkki_score');

      await loserWalletRef.runTransaction((data) {
        double currentScore = (data as num?)?.toDouble() ?? 0;
        double newScore = (currentScore + loserBonus).clamp(0, 100);
        return Transaction.success(newScore);
      });

      print('[CoinService] GwangKki scores updated - Winner: no change, Loser: +$loserBonus (lost $lostCoins coins)');
    } else {
      print('[CoinService] GwangKki scores unchanged - No coins lost');
    }

    return loserBonus;
  }

  /// 光끼 점수 리셋 (光끼 모드 종료 후)
  Future<void> resetGwangkkiScore(String uid) async {
    await _db.child('users/$uid/wallet/gwangkki_score').set(0);
    print('[CoinService] GwangKki score reset for $uid');
  }

  /// 光끼 모드 정산 (승자가 패자의 모든 코인 획득)
  Future<void> settleGwangkkiMode({
    required String winnerUid,
    required String loserUid,
    required bool isDraw,
    required String activatorUid,
  }) async {
    if (isDraw) {
      // 무승부: 코인 변동 없음, 발동자 점수만 리셋
      await resetGwangkkiScore(activatorUid);
      print('[CoinService] GwangKki mode ended in draw - no coin transfer');
      return;
    }

    // 패자의 모든 코인 가져오기
    final loserWallet = await getUserWallet(loserUid);
    final loserCoins = loserWallet?.coin ?? 0;

    if (loserCoins > 0) {
      // 패자 → 승자 코인 이동
      await _db.child('users/$loserUid/wallet/coin').set(0);
      await _db.child('users/$winnerUid/wallet/coin').runTransaction((value) {
        final current = (value as num?)?.toInt() ?? 0;
        return Transaction.success(current + loserCoins);
      });
    }

    // 발동자 光끼 점수 리셋
    await resetGwangkkiScore(activatorUid);

    print('[CoinService] GwangKki mode settled - $winnerUid took $loserCoins coins from $loserUid');
  }

  /// 光끼 모드 정산 (3인 고스톱용)
  /// - 승자가 패자 2명의 모든 코인(보관 코인 제외) 독식
  Future<({int loser1Transfer, int loser2Transfer})> settleGwangkkiModeGostop({
    required String winnerUid,
    required String loser1Uid,
    required String loser2Uid,
    required bool isDraw,
    required String activatorUid,
  }) async {
    if (isDraw) {
      // 무승부: 코인 변동 없음, 발동자 점수만 리셋
      await resetGwangkkiScore(activatorUid);
      print('[CoinService] GwangKki mode (3P) ended in draw - no coin transfer');
      return (loser1Transfer: 0, loser2Transfer: 0);
    }

    // 패자1의 모든 코인 가져오기 (보관 코인 제외)
    final loser1Wallet = await getUserWallet(loser1Uid);
    final loser1Coins = loser1Wallet?.coin ?? 0;

    // 패자2의 모든 코인 가져오기 (보관 코인 제외)
    final loser2Wallet = await getUserWallet(loser2Uid);
    final loser2Coins = loser2Wallet?.coin ?? 0;

    final totalTransfer = loser1Coins + loser2Coins;

    if (totalTransfer > 0) {
      // 패자1 코인 0으로
      if (loser1Coins > 0) {
        await _db.child('users/$loser1Uid/wallet/coin').set(0);
      }
      // 패자2 코인 0으로
      if (loser2Coins > 0) {
        await _db.child('users/$loser2Uid/wallet/coin').set(0);
      }
      // 승자에게 전체 코인 추가
      await _db.child('users/$winnerUid/wallet/coin').runTransaction((value) {
        final current = (value as num?)?.toInt() ?? 0;
        return Transaction.success(current + totalTransfer);
      });
    }

    // 발동자 光끼 점수 리셋
    await resetGwangkkiScore(activatorUid);

    print('[CoinService] GwangKki mode (3P) settled - $winnerUid took $loser1Coins from $loser1Uid, $loser2Coins from $loser2Uid (total: $totalTransfer)');
    
    return (loser1Transfer: loser1Coins, loser2Transfer: loser2Coins);
  }

  // ==================== 코인 보관/출금 시스템 ====================

  /// 보관 수수료 (출금 시 적용)
  static const double withdrawFeeRate = 0.15; // 15%

  /// 보관 시 최소 보유 코인
  static const int minCoinAfterDeposit = 10;

  /// 코인 보관 (소유 코인 → 보관 코인)
  /// - 보관 후 최소 10코인은 소유해야 함
  Future<({bool success, int newCoin, int newStoredCoin, String message})> depositCoins(
    String uid,
    int amount,
  ) async {
    if (amount <= 0) {
      return (
        success: false,
        newCoin: 0,
        newStoredCoin: 0,
        message: '보관할 금액을 입력해주세요.',
      );
    }

    final walletRef = _db.child('users/$uid/wallet');
    final snapshot = await walletRef.get();

    if (!snapshot.exists) {
      return (
        success: false,
        newCoin: 0,
        newStoredCoin: 0,
        message: '지갑 정보를 찾을 수 없습니다.',
      );
    }

    final wallet = UserWallet.fromJson(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    // 보관 후 최소 10코인 유지 체크
    final maxDepositable = wallet.coin - minCoinAfterDeposit;
    if (maxDepositable < 0) {
      return (
        success: false,
        newCoin: wallet.coin,
        newStoredCoin: wallet.storedCoin,
        message: '보유 코인이 부족합니다. (최소 ${minCoinAfterDeposit}코인 유지 필요)',
      );
    }

    if (amount > maxDepositable) {
      return (
        success: false,
        newCoin: wallet.coin,
        newStoredCoin: wallet.storedCoin,
        message: '최대 ${maxDepositable}코인까지 보관 가능합니다.',
      );
    }

    // 트랜잭션으로 안전하게 이동
    final result = await walletRef.runTransaction((data) {
      if (data == null) return Transaction.abort();

      final currentWallet = UserWallet.fromJson(Map<String, dynamic>.from(data as Map));
      final newCoin = currentWallet.coin - amount;
      final newStoredCoin = currentWallet.storedCoin + amount;

      if (newCoin < minCoinAfterDeposit) {
        return Transaction.abort();
      }

      return Transaction.success(
        currentWallet.copyWith(coin: newCoin, storedCoin: newStoredCoin).toJson(),
      );
    });

    if (result.committed && result.snapshot.value != null) {
      final updatedWallet = UserWallet.fromJson(
        Map<String, dynamic>.from(result.snapshot.value as Map),
      );
      print('[CoinService] Deposited $amount coins for $uid. Coin: ${updatedWallet.coin}, Stored: ${updatedWallet.storedCoin}');
      return (
        success: true,
        newCoin: updatedWallet.coin,
        newStoredCoin: updatedWallet.storedCoin,
        message: '$amount 코인이 보관되었습니다.',
      );
    }

    return (
      success: false,
      newCoin: wallet.coin,
      newStoredCoin: wallet.storedCoin,
      message: '보관 처리 중 오류가 발생했습니다.',
    );
  }

  /// 코인 출금 (보관 코인 → 소유 코인, 15% 수수료)
  Future<({bool success, int newCoin, int newStoredCoin, int fee, String message})> withdrawCoins(
    String uid,
    int amount,
  ) async {
    if (amount <= 0) {
      return (
        success: false,
        newCoin: 0,
        newStoredCoin: 0,
        fee: 0,
        message: '출금할 금액을 입력해주세요.',
      );
    }

    final walletRef = _db.child('users/$uid/wallet');
    final snapshot = await walletRef.get();

    if (!snapshot.exists) {
      return (
        success: false,
        newCoin: 0,
        newStoredCoin: 0,
        fee: 0,
        message: '지갑 정보를 찾을 수 없습니다.',
      );
    }

    final wallet = UserWallet.fromJson(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    if (amount > wallet.storedCoin) {
      return (
        success: false,
        newCoin: wallet.coin,
        newStoredCoin: wallet.storedCoin,
        fee: 0,
        message: '보관 코인이 부족합니다. (보유: ${wallet.storedCoin}코인)',
      );
    }

    // 15% 수수료 계산
    final fee = (amount * withdrawFeeRate).ceil();
    final netAmount = amount - fee;

    // 트랜잭션으로 안전하게 이동
    final result = await walletRef.runTransaction((data) {
      if (data == null) return Transaction.abort();

      final currentWallet = UserWallet.fromJson(Map<String, dynamic>.from(data as Map));

      if (amount > currentWallet.storedCoin) {
        return Transaction.abort();
      }

      final newStoredCoin = currentWallet.storedCoin - amount;
      final newCoin = currentWallet.coin + netAmount;

      return Transaction.success(
        currentWallet.copyWith(coin: newCoin, storedCoin: newStoredCoin).toJson(),
      );
    });

    if (result.committed && result.snapshot.value != null) {
      final updatedWallet = UserWallet.fromJson(
        Map<String, dynamic>.from(result.snapshot.value as Map),
      );
      print('[CoinService] Withdrew $amount coins (fee: $fee) for $uid. Coin: ${updatedWallet.coin}, Stored: ${updatedWallet.storedCoin}');
      return (
        success: true,
        newCoin: updatedWallet.coin,
        newStoredCoin: updatedWallet.storedCoin,
        fee: fee,
        message: '$netAmount 코인이 출금되었습니다. (수수료: $fee)',
      );
    }

    return (
      success: false,
      newCoin: wallet.coin,
      newStoredCoin: wallet.storedCoin,
      fee: 0,
      message: '출금 처리 중 오류가 발생했습니다.',
    );
  }

  /// 보관 가능한 최대 금액 계산
  int getMaxDepositableAmount(int currentCoin) {
    return (currentCoin - minCoinAfterDeposit).clamp(0, currentCoin);
  }

  /// 출금 시 수수료 미리보기
  ({int fee, int netAmount}) previewWithdrawFee(int amount) {
    final fee = (amount * withdrawFeeRate).ceil();
    final netAmount = amount - fee;
    return (fee: fee, netAmount: netAmount);
  }
}
