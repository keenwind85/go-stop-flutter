/// 유저 지갑 정보 (코인 관리)
class UserWallet {
  final int coin;
  final int totalEarned;
  final double gwangkkiScore; // 光끼 점수 (0~100)

  const UserWallet({
    this.coin = 0,
    this.totalEarned = 0,
    this.gwangkkiScore = 0,
  });

  /// 光끼 모드 발동 가능 여부
  bool get canActivateGwangkkiMode => gwangkkiScore >= 100;

  UserWallet copyWith({
    int? coin,
    int? totalEarned,
    double? gwangkkiScore,
  }) {
    return UserWallet(
      coin: coin ?? this.coin,
      totalEarned: totalEarned ?? this.totalEarned,
      gwangkkiScore: gwangkkiScore ?? this.gwangkkiScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coin': coin,
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

  const DailyActions({
    this.lastAttendance,
    this.lastDonation,
    this.rouletteCount = 0,
    this.bonusRouletteCount = 0,
    this.bonusRouletteEarned = 0,
    this.lastRouletteDate,
  });

  DailyActions copyWith({
    String? lastAttendance,
    String? lastDonation,
    int? rouletteCount,
    int? bonusRouletteCount,
    int? bonusRouletteEarned,
    String? lastRouletteDate,
  }) {
    return DailyActions(
      lastAttendance: lastAttendance ?? this.lastAttendance,
      lastDonation: lastDonation ?? this.lastDonation,
      rouletteCount: rouletteCount ?? this.rouletteCount,
      bonusRouletteCount: bonusRouletteCount ?? this.bonusRouletteCount,
      bonusRouletteEarned: bonusRouletteEarned ?? this.bonusRouletteEarned,
      lastRouletteDate: lastRouletteDate ?? this.lastRouletteDate,
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
