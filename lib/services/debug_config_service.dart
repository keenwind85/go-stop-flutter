import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug Config Service Provider
final debugConfigServiceProvider = Provider<DebugConfigService>((ref) {
  return DebugConfigService();
});

/// 디버그 설정을 Firebase Remote Config로 관리하는 서비스
///
/// Firebase Remote Config 파라미터:
/// - debug_mode_enabled: 디버그 모드 전체 활성화 여부 (bool)
/// - debug_card_swap_enabled: 게임 내 카드 교체 디버그 (bool)
/// - debug_item_shop_enabled: 아이템 상점 디버그 (bool)
class DebugConfigService {
  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  // 로컬 디버그 상태 (Remote Config 로드 전 또는 실패 시 사용)
  bool _localDebugModeEnabled = false;

  // 세션별 디버그 활성화 상태 (롱프레스로 활성화)
  bool _sessionCardSwapDebugActive = false;
  bool _sessionItemShopDebugActive = false;

  /// Remote Config 초기화
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // FirebaseRemoteConfig.instance 자체가 실패할 수 있음 (특히 웹 플랫폼)
      final remoteConfig = FirebaseRemoteConfig.instance;

      // 기본값 설정
      await remoteConfig.setDefaults({
        'debug_mode_enabled': false,
        'debug_card_swap_enabled': false,
        'debug_item_shop_enabled': false,
      });

      // 설정 가져오기 (5분마다 새로고침)
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(minutes: 5),
      ));

      // 최신 설정 fetch 및 활성화
      await remoteConfig.fetchAndActivate();

      // 모든 작업이 성공한 후에만 _remoteConfig에 할당
      _remoteConfig = remoteConfig;

      // 디버그 빌드에서는 로컬 디버그 모드도 활성화 (Remote Config 값과 OR 연산)
      if (kDebugMode) {
        _localDebugModeEnabled = true;
        print('[DebugConfigService] Debug build detected - enabling local debug mode');
      }

      _initialized = true;
      print('[DebugConfigService] Initialized successfully');
      print('[DebugConfigService] debug_mode_enabled: $isDebugModeEnabled');
    } catch (e) {
      print('[DebugConfigService] Failed to initialize Remote Config: $e');
      // 디버그 모드(개발 중)에서는 로컬 디버그 모드 자동 활성화
      if (kDebugMode) {
        _localDebugModeEnabled = true;
        print('[DebugConfigService] Debug build detected - enabling local debug mode');
      } else {
        print('[DebugConfigService] Using local debug mode (defaults to false)');
      }
      // 실패해도 로컬 기본값 사용 가능 - _remoteConfig는 null 유지
      _initialized = true;
    }
  }

  /// 전체 디버그 모드 활성화 여부
  bool get isDebugModeEnabled {
    if (_remoteConfig == null) return _localDebugModeEnabled;
    return _remoteConfig!.getBool('debug_mode_enabled') || _localDebugModeEnabled;
  }

  /// 카드 교체 디버그 허용 여부
  bool get isCardSwapDebugEnabled {
    if (_remoteConfig == null) return _localDebugModeEnabled;
    return _remoteConfig!.getBool('debug_card_swap_enabled') || isDebugModeEnabled;
  }

  /// 아이템 상점 디버그 허용 여부
  bool get isItemShopDebugEnabled {
    if (_remoteConfig == null) return _localDebugModeEnabled;
    return _remoteConfig!.getBool('debug_item_shop_enabled') || isDebugModeEnabled;
  }

  /// 세션 내 카드 교체 디버그 활성화 여부
  bool get isSessionCardSwapDebugActive => _sessionCardSwapDebugActive;

  /// 세션 내 아이템 상점 디버그 활성화 여부
  bool get isSessionItemShopDebugActive => _sessionItemShopDebugActive;

  /// 카드 교체 디버그 사용 가능 여부 (Remote Config + 세션 활성화)
  bool get canUseCardSwapDebug => isCardSwapDebugEnabled && _sessionCardSwapDebugActive;

  /// 아이템 상점 디버그 사용 가능 여부 (Remote Config + 세션 활성화)
  bool get canUseItemShopDebug => isItemShopDebugEnabled && _sessionItemShopDebugActive;

  /// 세션 내 카드 교체 디버그 활성화 (롱프레스 시 호출)
  void activateSessionCardSwapDebug() {
    if (isCardSwapDebugEnabled) {
      _sessionCardSwapDebugActive = true;
      print('[DebugConfigService] Session card swap debug activated');
    }
  }

  /// 세션 내 아이템 상점 디버그 활성화 (롱프레스 시 호출)
  void activateSessionItemShopDebug() {
    print('[DebugConfigService] activateSessionItemShopDebug called');
    print('[DebugConfigService] isItemShopDebugEnabled: $isItemShopDebugEnabled');
    print('[DebugConfigService] _localDebugModeEnabled: $_localDebugModeEnabled');
    print('[DebugConfigService] _remoteConfig: $_remoteConfig');

    if (isItemShopDebugEnabled) {
      _sessionItemShopDebugActive = true;
      print('[DebugConfigService] Session item shop debug activated');
      print('[DebugConfigService] canUseItemShopDebug: $canUseItemShopDebug');
    } else {
      print('[DebugConfigService] Item shop debug NOT enabled - cannot activate session');
    }
  }

  /// 세션 디버그 상태 리셋 (게임 종료 시 등)
  void resetSessionDebug() {
    _sessionCardSwapDebugActive = false;
    _sessionItemShopDebugActive = false;
  }

  /// 로컬 디버그 모드 설정 (테스트용)
  void setLocalDebugMode(bool enabled) {
    _localDebugModeEnabled = enabled;
  }

  /// Remote Config 새로고침
  Future<void> refresh() async {
    if (_remoteConfig == null) return;

    try {
      await _remoteConfig!.fetchAndActivate();
      print('[DebugConfigService] Config refreshed');
    } catch (e) {
      print('[DebugConfigService] Failed to refresh: $e');
    }
  }
}
