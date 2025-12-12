import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_wallet.dart';

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
      // 새로운 날이면 카운트 리셋
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
    final currentBonusEarned = isSameDayRoulette ? currentDaily.bonusRouletteEarned : 0;

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

  /// 게임 정산 (승자에게 코인 이전)
  Future<void> settleGame({
    required String winnerUid,
    required String loserUid,
    required int points,
    required int multiplier,
    bool isAllIn = false,
  }) async {
    // 이전할 코인 계산
    int transferAmount = points * multiplier;

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
    print('[CoinService] Game settled: $winnerUid wins $actualTransfer coins from $loserUid');
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

  /// 光끼 점수 업데이트 (게임 완료 시 호출)
  /// - 모든 플레이어: 게임 1판당 +5점
  /// - 승자 (30점 미만 승리): 변동 없음
  /// - 승자 (30점 이상 승리): -5점
  /// - 패자: 승자 점수 * 0.3 획득
  Future<void> updateGwangkkiScores({
    required String winnerUid,
    required String loserUid,
    required int winnerScore,
    required bool isDraw,
  }) async {
    final winnerWalletRef = _db.child('users/$winnerUid/wallet/gwangkki_score');
    final loserWalletRef = _db.child('users/$loserUid/wallet/gwangkki_score');

    // 현재 점수 가져오기
    final winnerSnapshot = await winnerWalletRef.get();
    final loserSnapshot = await loserWalletRef.get();

    double winnerCurrentScore = (winnerSnapshot.value as num?)?.toDouble() ?? 0;
    double loserCurrentScore = (loserSnapshot.value as num?)?.toDouble() ?? 0;

    // 기본: 모든 플레이어 +5점
    winnerCurrentScore += 5;
    loserCurrentScore += 5;

    if (!isDraw) {
      // 승자 점수 조정
      if (winnerScore >= 30) {
        // 30점 이상 승리: -5점 (기본 +5와 상쇄되어 총 0)
        winnerCurrentScore -= 5;
      }
      // 30점 미만 승리: 변동 없음 (이미 +5 적용됨)

      // 패자: 승자 점수 * 0.3 획득
      double loserBonus = winnerScore * 0.3;
      loserCurrentScore += loserBonus;
    }

    // 0~100 범위로 클램프
    winnerCurrentScore = winnerCurrentScore.clamp(0, 100);
    loserCurrentScore = loserCurrentScore.clamp(0, 100);

    // 업데이트
    await winnerWalletRef.set(winnerCurrentScore);
    await loserWalletRef.set(loserCurrentScore);

    print('[CoinService] GwangKki scores updated - Winner: $winnerCurrentScore, Loser: $loserCurrentScore');
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
}
