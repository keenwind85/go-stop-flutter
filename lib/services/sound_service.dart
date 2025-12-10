import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/game_room.dart';

/// SoundService Provider
final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService();
});

/// 게임 사운드 효과 서비스
class SoundService {
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _isMuted = true; // 사운드 파일 없음 - 기본 음소거
  double _volume = 0.7;

  bool get isMuted => _isMuted;
  double get volume => _volume;

  /// 초기화
  Future<void> initialize() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _sfxPlayer.setReleaseMode(ReleaseMode.release);
  }

  /// 음소거 토글
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _bgmPlayer.setVolume(0);
      _sfxPlayer.setVolume(0);
    } else {
      _bgmPlayer.setVolume(_volume);
      _sfxPlayer.setVolume(_volume);
    }
  }

  /// 볼륨 설정
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (!_isMuted) {
      _bgmPlayer.setVolume(_volume);
      _sfxPlayer.setVolume(_volume);
    }
  }

  /// 카드 뒤집기 효과음
  Future<void> playCardFlip() async {
    await _playSfx('sounds/card_flip.mp3');
  }

  /// 카드 놓기 효과음
  Future<void> playCardPlace() async {
    await _playSfx('sounds/card_place.mp3');
  }

  /// 카드 매칭 효과음
  Future<void> playCardMatch() async {
    await _playSfx('sounds/card_match.mp3');
  }

  /// 특수 이벤트 효과음
  Future<void> playSpecialEvent(SpecialEvent event) async {
    switch (event) {
      case SpecialEvent.puk:
        await _playSfx('sounds/puk.mp3');
        break;
      case SpecialEvent.jaPuk:
        await _playSfx('sounds/japuk.mp3');
        break;
      case SpecialEvent.ttadak:
        await _playSfx('sounds/ttadak.mp3');
        break;
      case SpecialEvent.kiss:
        await _playSfx('sounds/kiss.mp3');
        break;
      case SpecialEvent.sweep:
        await _playSfx('sounds/sweep.mp3');
        break;
      case SpecialEvent.sulsa:
        await _playSfx('sounds/sulsa.mp3');
        break;
      case SpecialEvent.shake:
        await _playSfx('sounds/shake.mp3');
        break;
      case SpecialEvent.bomb:
        await _playSfx('sounds/bomb.mp3');
        break;
      case SpecialEvent.chongtong:
        await _playSfx('sounds/chongtong.mp3');
        break;
      case SpecialEvent.bonusCardUsed:
        await _playSfx('sounds/bonus.mp3');
        break;
      case SpecialEvent.none:
        break;
    }
  }

  /// Go 선언 효과음
  Future<void> playGo() async {
    await _playSfx('sounds/go.mp3');
  }

  /// Stop 선언 효과음
  Future<void> playStop() async {
    await _playSfx('sounds/stop.mp3');
  }

  /// 승리 효과음
  Future<void> playWin() async {
    await _playSfx('sounds/win.mp3');
  }

  /// 패배 효과음
  Future<void> playLose() async {
    await _playSfx('sounds/lose.mp3');
  }

  /// 나가리 효과음
  Future<void> playNagari() async {
    await _playSfx('sounds/nagari.mp3');
  }

  /// 버튼 클릭 효과음
  Future<void> playClick() async {
    await _playSfx('sounds/click.mp3');
  }

  /// 턴 알림 효과음
  Future<void> playTurnNotify() async {
    await _playSfx('sounds/turn.mp3');
  }

  /// 배경음악 재생
  Future<void> playBgm() async {
    if (_isMuted) return;
    try {
      await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
      await _bgmPlayer.setVolume(_volume * 0.5); // BGM은 좀 더 낮게
    } catch (e) {
      // 사운드 파일이 없을 수 있음
    }
  }

  /// 배경음악 정지
  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
  }

  /// 효과음 재생 (내부용)
  Future<void> _playSfx(String asset) async {
    if (_isMuted) return;
    try {
      await _sfxPlayer.play(AssetSource(asset));
    } catch (e) {
      // 사운드 파일이 없을 수 있음 - 웹에서는 무시
    }
  }

  /// 리소스 해제
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
