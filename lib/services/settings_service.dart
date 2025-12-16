import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SettingsService Provider
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

/// 유저 설정 모델
class UserSettings {
  final String? customNickname; // 사용자 지정 닉네임 (null이면 구글 닉네임 사용)
  final bool soundEnabled;       // 사운드 활성화 여부 (기본값: true)

  const UserSettings({
    this.customNickname,
    this.soundEnabled = true,
  });

  UserSettings copyWith({
    String? customNickname,
    bool? soundEnabled,
  }) {
    return UserSettings(
      customNickname: customNickname ?? this.customNickname,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'custom_nickname': customNickname,
      'sound_enabled': soundEnabled,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserSettings();
    }
    return UserSettings(
      customNickname: json['custom_nickname'] as String?,
      soundEnabled: json['sound_enabled'] as bool? ?? true,
    );
  }
}

/// 사용자 설정 관리 서비스
class SettingsService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// 닉네임 유효성 검사 정규식: 한글, 숫자만 허용, 1~10자
  static final RegExp nicknameRegex = RegExp(r'^[가-힣0-9]{1,10}$');

  /// 닉네임 최대 길이
  static const int maxNicknameLength = 10;

  /// 닉네임 유효성 검사
  static String? validateNickname(String nickname) {
    if (nickname.isEmpty) {
      return '닉네임을 입력해주세요';
    }
    if (nickname.length > maxNicknameLength) {
      return '닉네임은 ${maxNicknameLength}자 이내로 입력해주세요';
    }
    if (!nicknameRegex.hasMatch(nickname)) {
      return '한글과 숫자만 사용할 수 있습니다';
    }
    return null; // 유효함
  }

  /// 사용자 설정 가져오기
  Future<UserSettings> getUserSettings(String uid) async {
    try {
      final snapshot = await _db.child('users/$uid/settings').get();
      if (!snapshot.exists) {
        return const UserSettings();
      }
      return UserSettings.fromJson(
        Map<String, dynamic>.from(snapshot.value as Map),
      );
    } catch (e) {
      print('[SettingsService] Error getting settings: $e');
      return const UserSettings();
    }
  }

  /// 사용자 설정 스트림
  Stream<UserSettings> getUserSettingsStream(String uid) {
    return _db.child('users/$uid/settings').onValue.map((event) {
      if (!event.snapshot.exists) {
        return const UserSettings();
      }
      return UserSettings.fromJson(
        Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  /// 닉네임 변경
  Future<({bool success, String message})> updateNickname(
    String uid,
    String? nickname,
  ) async {
    try {
      // 닉네임 비우기 (구글 닉네임으로 복원)
      if (nickname == null || nickname.trim().isEmpty) {
        await _db.child('users/$uid/settings/custom_nickname').remove();
        // 프로필의 name도 업데이트 (null로 설정하면 안되므로 기존 값 유지)
        return (success: true, message: '기본 닉네임으로 복원되었습니다');
      }

      final trimmed = nickname.trim();

      // 유효성 검사
      final error = validateNickname(trimmed);
      if (error != null) {
        return (success: false, message: error);
      }

      // 설정과 프로필 모두 업데이트
      await _db.child('users/$uid').update({
        'settings/custom_nickname': trimmed,
        'profile/name': trimmed,
      });

      return (success: true, message: '닉네임이 변경되었습니다');
    } catch (e) {
      print('[SettingsService] Error updating nickname: $e');
      return (success: false, message: '닉네임 변경 중 오류가 발생했습니다');
    }
  }

  /// 사운드 설정 변경
  Future<({bool success, String message})> updateSoundEnabled(
    String uid,
    bool enabled,
  ) async {
    try {
      await _db.child('users/$uid/settings/sound_enabled').set(enabled);
      return (
        success: true,
        message: enabled ? '사운드가 켜졌습니다' : '사운드가 꺼졌습니다',
      );
    } catch (e) {
      print('[SettingsService] Error updating sound setting: $e');
      return (success: false, message: '사운드 설정 변경 중 오류가 발생했습니다');
    }
  }

  /// 현재 표시할 닉네임 가져오기 (커스텀 닉네임 또는 구글 닉네임)
  Future<String> getDisplayName(String uid, String defaultName) async {
    final settings = await getUserSettings(uid);
    return settings.customNickname ?? defaultName;
  }
}
