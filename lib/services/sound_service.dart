import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/game_room.dart';

/// SoundService Provider
final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService();
});

/// 게임 사운드 효과 서비스
class SoundService {
  AudioPlayer _bgmPlayer = AudioPlayer();
  AudioPlayer _sfxPlayer = AudioPlayer();
  bool _isDisposed = false; // dispose 상태 추적

  bool _isMuted = false; // 기본값: 사운드 켜짐 (사용자 설정 로드 후 덮어씀)
  double _volume = 0.7;

  bool get isMuted => _isMuted;
  double get volume => _volume;

  /// 초기화 (dispose 후 재진입 시 AudioPlayer 재생성)
  Future<void> initialize() async {
    // dispose된 상태면 AudioPlayer 재생성
    if (_isDisposed) {
      _bgmPlayer = AudioPlayer();
      _sfxPlayer = AudioPlayer();
      _isDisposed = false;
    }

    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _sfxPlayer.setReleaseMode(ReleaseMode.release);

    // 현재 음소거 상태에 따라 볼륨 설정
    if (_isMuted) {
      await _bgmPlayer.setVolume(0);
      await _sfxPlayer.setVolume(0);
    } else {
      await _bgmPlayer.setVolume(_volume);
      await _sfxPlayer.setVolume(_volume);
    }
  }

  /// 사용자 설정에 따라 음소거 상태 적용
  void applyUserSetting(bool soundEnabled) {
    _isMuted = !soundEnabled;

    if (_isMuted) {
      _bgmPlayer.setVolume(0);
      _sfxPlayer.setVolume(0);
    } else {
      _bgmPlayer.setVolume(_volume);
      _sfxPlayer.setVolume(_volume);
    }
  }

  /// 음소거 상태 직접 설정
  void setMuted(bool muted) {
    _isMuted = muted;

    if (_isMuted) {
      _bgmPlayer.setVolume(0);
      _sfxPlayer.setVolume(0);
    } else {
      _bgmPlayer.setVolume(_volume);
      _sfxPlayer.setVolume(_volume);
    }
  }

  /// 음소거 토글 (새 상태 반환)
  bool toggleMute() {
    _isMuted = !_isMuted;

    if (_isMuted) {
      _bgmPlayer.setVolume(0);
      _sfxPlayer.setVolume(0);
    } else {
      _bgmPlayer.setVolume(_volume);
      _sfxPlayer.setVolume(_volume);
    }

    return _isMuted;
  }

  /// 볼륨 설정
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (!_isMuted) {
      _bgmPlayer.setVolume(_volume);
      _sfxPlayer.setVolume(_volume);
    }
  }

  // ========================================
  // 내 플레이 시에만 들리는 효과음 (로컬)
  // ========================================

  /// 손패/더미패 매칭 성공 시 효과음
  Future<void> playTakMatch() async {
    await _playSfx('sounds/tak-match.mp3');
  }

  /// 손패/더미패 매칭 실패 시 효과음 (바닥에 놓을 때)
  Future<void> playTakMiss() async {
    await _playSfx('sounds/tak-miss.mp3');
  }

  /// 카드 뒤집기 효과음 (효과음 없음)
  Future<void> playCardFlip() async {
    // 효과음 없음
  }

  /// 카드 놓기 효과음
  Future<void> playCardPlace() async {
    await _playSfx('sounds/tak-miss.mp3');
  }

  /// 카드 매칭 효과음
  Future<void> playCardMatch() async {
    await _playSfx('sounds/tak-match.mp3');
  }

  // ========================================
  // 특수 이벤트 효과음 (양쪽 플레이어 모두 들림)
  // ========================================

  /// 특수 이벤트 효과음
  Future<void> playSpecialEvent(SpecialEvent event) async {
    switch (event) {
      case SpecialEvent.puk:
        await _playSfx('sounds/puk.mp3');
        break;
      case SpecialEvent.jaPuk:
        await _playSfx('sounds/puk.mp3'); // 자뻑도 같은 사운드 사용
        break;
      case SpecialEvent.ttadak:
        await _playSfx('sounds/ttadak.mp3');
        break;
      case SpecialEvent.kiss:
        await _playSfx('sounds/kiss.mp3');
        break;
      case SpecialEvent.sweep:
        await _playSfx('sounds/ssl.mp3.mp3'); // 싹쓸이
        break;
      case SpecialEvent.sulsa:
        await _playSfx('sounds/swiping.mp3'); // 설사
        break;
      case SpecialEvent.shake:
        await _playSfx('sounds/shaking.mp3'); // 흔들기
        break;
      case SpecialEvent.bomb:
        await _playSfx('sounds/bomb.mp3'); // 폭탄
        break;
      case SpecialEvent.chongtong:
        // 총통 효과음 없음
        break;
      case SpecialEvent.bonusCardUsed:
        await _playSfx('sounds/bonus.mp3'); // 보너스패
        break;
      case SpecialEvent.meongTta:
        await _playSfx('sounds/ssl.mp3.mp3'); // 멍따 (경고음)
        break;
      case SpecialEvent.none:
        break;
    }
  }

  // ========================================
  // 플레이어 행동 효과음 (양쪽 플레이어 모두 들림)
  // ========================================

  /// 보너스패 사용 효과음
  Future<void> playBonusCard() async {
    await _playSfx('sounds/bonus.mp3');
  }

  /// 아이템 사용 효과음
  Future<void> playItemUse() async {
    await _playSfx('sounds/item.mp3');
  }

  /// 광끼 모드 발동 효과음
  Future<void> playGwangkki() async {
    await _playSfx('sounds/gang-ggi.mp3');
  }

  // ========================================
  // 게임 시작 효과음
  // ========================================

  /// 게임 시작 효과음 (양쪽 플레이어 모두)
  Future<void> playGameStart() async {
    await _playSfx('sounds/game_start.mp3');
  }

  // ========================================
  // 게임 결과 효과음
  // ========================================

  /// 승리 효과음
  Future<void> playWinner() async {
    await _playSfx('sounds/winner.mp3');
  }

  /// 패배 효과음
  Future<void> playLoser() async {
    await _playSfx('sounds/loser.mp3');
  }

  /// Go 선언 효과음 (효과음 없음)
  Future<void> playGo() async {
    // 효과음 없음
  }

  /// Stop 선언 효과음 (효과음 없음)
  Future<void> playStop() async {
    // 효과음 없음
  }

  /// 승리 효과음 (레거시 - playWinner 사용 권장)
  Future<void> playWin() async {
    await _playSfx('sounds/winner.mp3');
  }

  /// 패배 효과음 (레거시 - playLoser 사용 권장)
  Future<void> playLose() async {
    await _playSfx('sounds/loser.mp3');
  }

  /// 나가리 효과음 (효과음 없음)
  Future<void> playNagari() async {
    // 효과음 없음
  }

  /// 버튼 클릭 효과음 (효과음 없음)
  Future<void> playClick() async {
    // 효과음 없음
  }

  /// 턴 알림 효과음 (효과음 없음)
  Future<void> playTurnNotify() async {
    // 효과음 없음
  }

  /// 배경음악 재생
  Future<void> playBgm() async {
    // BGM 파일이 없으므로 비활성화
    // if (isMuted) return;
    // try {
    //   await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
    //   await _bgmPlayer.setVolume(_volume * 0.5); // BGM은 좀 더 낮게
    // } catch (e) {
    //   // 사운드 파일이 없을 수 있음
    // }
  }

  /// 배경음악 정지
  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
  }

  /// 효과음 재생 (내부용)
  Future<void> _playSfx(String asset) async {
    if (isMuted) return;
    try {
      await _sfxPlayer.play(AssetSource(asset));
    } catch (e) {
      // 사운드 파일이 없을 수 있음 - 웹에서는 무시
      print('[SoundService] Failed to play: $asset - $e');
    }
  }

  /// 리소스 해제
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    _isDisposed = true; // dispose 상태 기록 (다음 initialize에서 재생성 필요)
  }
}
