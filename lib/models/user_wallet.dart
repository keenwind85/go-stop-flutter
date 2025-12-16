/// 유저 지갑 정보 (코인 관리)
class UserWallet {
  final int coin;           // 소유 코인 (게임 입장 시 사용)
  final int storedCoin;     // 보관 코인 (게임 정산에 포함되지 않음)
  final int totalEarned;
  final double gwangkkiScore; // 光끼 점수 (0~100)

  const UserWallet({
    this.coin = 0,
    this.storedCoin = 0,
    this.totalEarned = 0,
    this.gwangkkiScore = 0,
  });

  /// 光끼 모드 발동 가능 여부
  bool get canActivateGwangkkiMode => gwangkkiScore >= 100;

  /// 총 코인 (소유 + 보관)
  int get totalCoin => coin + storedCoin;

  UserWallet copyWith({
    int? coin,
    int? storedCoin,
    int? totalEarned,
    double? gwangkkiScore,
  }) {
    return UserWallet(
      coin: coin ?? this.coin,
      storedCoin: storedCoin ?? this.storedCoin,
      totalEarned: totalEarned ?? this.totalEarned,
      gwangkkiScore: gwangkkiScore ?? this.gwangkkiScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coin': coin,
      'stored_coin': storedCoin,
      'total_earned': totalEarned,
      'gwangkki_score': gwangkkiScore,
    };
  }

  factory UserWallet.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserWallet();
    }
    return UserWallet(
      coin: (json['coin'] as num?)?.toInt() ?? 0,
      storedCoin: (json['stored_coin'] as num?)?.toInt() ?? 0,
      totalEarned: (json['total_earned'] as num?)?.toInt() ?? 0,
      gwangkkiScore: (json['gwangkki_score'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 유저 일일 활동 정보
class DailyActions {
  final String? lastAttendance;
  final String? lastDonation;
  final int rouletteCount;           // 기본 룰렛 사용 횟수 (매일 3회)
  final int bonusRouletteCount;      // 게임 완료로 얻은 보너스 룰렛 사용 횟수
  final int bonusRouletteEarned;     // 게임 완료로 얻은 보너스 룰렛 총 횟수
  final String? lastRouletteDate;
  // 슬롯머신 관련 필드
  final int slotSpinCount;           // 기본 슬롯 사용 횟수 (매일 10회)
  final int bonusSlotCount;          // 게임 완료로 얻은 보너스 슬롯 사용 횟수
  final int bonusSlotEarned;         // 게임 완료로 얻은 보너스 슬롯 총 횟수
  final String? lastSlotDate;

  const DailyActions({
    this.lastAttendance,
    this.lastDonation,
    this.rouletteCount = 0,
    this.bonusRouletteCount = 0,
    this.bonusRouletteEarned = 0,
    this.lastRouletteDate,
    this.slotSpinCount = 0,
    this.bonusSlotCount = 0,
    this.bonusSlotEarned = 0,
    this.lastSlotDate,
  });

  DailyActions copyWith({
    String? lastAttendance,
    String? lastDonation,
    int? rouletteCount,
    int? bonusRouletteCount,
    int? bonusRouletteEarned,
    String? lastRouletteDate,
    int? slotSpinCount,
    int? bonusSlotCount,
    int? bonusSlotEarned,
    String? lastSlotDate,
  }) {
    return DailyActions(
      lastAttendance: lastAttendance ?? this.lastAttendance,
      lastDonation: lastDonation ?? this.lastDonation,
      rouletteCount: rouletteCount ?? this.rouletteCount,
      bonusRouletteCount: bonusRouletteCount ?? this.bonusRouletteCount,
      bonusRouletteEarned: bonusRouletteEarned ?? this.bonusRouletteEarned,
      lastRouletteDate: lastRouletteDate ?? this.lastRouletteDate,
      slotSpinCount: slotSpinCount ?? this.slotSpinCount,
      bonusSlotCount: bonusSlotCount ?? this.bonusSlotCount,
      bonusSlotEarned: bonusSlotEarned ?? this.bonusSlotEarned,
      lastSlotDate: lastSlotDate ?? this.lastSlotDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'last_attendance': lastAttendance,
      'last_donation': lastDonation,
      'roulette_count': rouletteCount,
      'bonus_roulette_count': bonusRouletteCount,
      'bonus_roulette_earned': bonusRouletteEarned,
      'last_roulette_date': lastRouletteDate,
      'slot_spin_count': slotSpinCount,
      'bonus_slot_count': bonusSlotCount,
      'bonus_slot_earned': bonusSlotEarned,
      'last_slot_date': lastSlotDate,
    };
  }

  factory DailyActions.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DailyActions();
    }
    return DailyActions(
      lastAttendance: json['last_attendance'] as String?,
      lastDonation: json['last_donation'] as String?,
      rouletteCount: (json['roulette_count'] as num?)?.toInt() ?? 0,
      bonusRouletteCount: (json['bonus_roulette_count'] as num?)?.toInt() ?? 0,
      bonusRouletteEarned: (json['bonus_roulette_earned'] as num?)?.toInt() ?? 0,
      lastRouletteDate: json['last_roulette_date'] as String?,
      slotSpinCount: (json['slot_spin_count'] as num?)?.toInt() ?? 0,
      bonusSlotCount: (json['bonus_slot_count'] as num?)?.toInt() ?? 0,
      bonusSlotEarned: (json['bonus_slot_earned'] as num?)?.toInt() ?? 0,
      lastSlotDate: json['last_slot_date'] as String?,
    );
  }
}

/// 유저 프로필 정보 (기존 PlayerInfo 확장)
class UserProfile {
  final String uid;
  final String displayName;
  final String? avatar;
  final UserWallet wallet;
  final DailyActions dailyActions;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.avatar,
    this.wallet = const UserWallet(),
    this.dailyActions = const DailyActions(),
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? avatar,
    UserWallet? wallet,
    DailyActions? dailyActions,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      wallet: wallet ?? this.wallet,
      dailyActions: dailyActions ?? this.dailyActions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': {
        'name': displayName,
        'avatar': avatar,
      },
      'wallet': wallet.toJson(),
      'daily_actions': dailyActions.toJson(),
    };
  }

  factory UserProfile.fromJson(String uid, Map<String, dynamic>? json) {
    if (json == null) {
      return UserProfile(uid: uid, displayName: 'Unknown');
    }

    final profile = json['profile'] as Map<String, dynamic>?;
    final walletData = json['wallet'] as Map<String, dynamic>?;
    final dailyData = json['daily_actions'] as Map<String, dynamic>?;

    return UserProfile(
      uid: uid,
      displayName: profile?['name'] as String? ?? 'Unknown',
      avatar: profile?['avatar'] as String?,
      wallet: UserWallet.fromJson(walletData),
      dailyActions: DailyActions.fromJson(dailyData),
    );
  }
}
