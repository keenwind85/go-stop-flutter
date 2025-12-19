import 'package:flutter/material.dart';

/// 앱 전체에서 사용하는 색상 상수
class AppColors {
  // Main Theme (Retro Green)
  static const Color primary = Color(0xFF005000);      // 깊은 모포색 (Main)
  static const Color primaryLight = Color(0xFF2E7D32); // 밝은 모포색 (Highlight)
  static const Color primaryDark = Color(0xFF003300);  // 어두운 모포색 (Shadow)
  
  // Wood Accents
  static const Color woodLight = Color(0xFFD7CCC8);    // 밝은 나무
  static const Color woodMedium = Color(0xFF8D6E63);   // 중간 나무
  static const Color woodDark = Color(0xFF5D4037);     // 어두운 나무 (Border)
  static const Color woodDarkBlue = Color(0xFF3E2723); // 아주 어두운 나무 (Gathering Effect)
  
  // UI Elements
  static const Color accent = Color(0xFFFFD700);       // Gold (승리/강조)
  static const Color background = Color(0xFF003300);   // Dark Green Background
  static const Color text = Color(0xFFFFF9C4);         // Cream White (종이 질감 텍스트)
  static const Color textSecondary = Color(0xFFB0BEC5);// Light Grey Text
  
  // Game Specific
  static const Color goRed = Color(0xFFD32F2F);        // Crimson Red
  static const Color stopBlue = Color(0xFF1976D2);     // Ocean Blue
  static const Color cardHighlight = Color(0xFFFFD700);// Gold Highlight
  static const Color error = Color(0xFFE57373);
}

/// 게임 모드
enum GameMode {
  matgo,    // 맞고 (2인)
  gostop,   // 고스톱 (3인)
}

/// GameMode 확장
extension GameModeExtension on GameMode {
  /// 표시 이름
  String get displayName {
    switch (this) {
      case GameMode.matgo:
        return '맞고';
      case GameMode.gostop:
        return '고스톱';
    }
  }

  /// 플레이어 수
  int get playerCount {
    switch (this) {
      case GameMode.matgo:
        return 2;
      case GameMode.gostop:
        return 3;
    }
  }

  /// 손패 장수
  int get cardsPerPlayer {
    switch (this) {
      case GameMode.matgo:
        return 10;
      case GameMode.gostop:
        return 7;
    }
  }

  /// 바닥패 장수
  int get fieldCardCount {
    switch (this) {
      case GameMode.matgo:
        return 8;
      case GameMode.gostop:
        return 6;
    }
  }

  /// 승리 점수 기준
  int get winThreshold {
    switch (this) {
      case GameMode.matgo:
        return 7;
      case GameMode.gostop:
        return 3;
    }
  }

  /// 피박 기준 (이 장수 이하면 피박)
  int get piBakThreshold {
    switch (this) {
      case GameMode.matgo:
        return 7;
      case GameMode.gostop:
        return 5;
    }
  }
}

/// 게임 관련 상수
class GameConstants {
  // 카드 크기 (모바일 최적화: 기존 대비 80%)
  static const double cardWidth = 52.0;
  static const double cardHeight = 78.0;
  static const double cardSpacing = 6.0;

  // 기본 상수 (맞고 기준, 레거시 호환용)
  static const int cardsPerPlayer = 10;   // 손패 10장
  static const int fieldCardCount = 8;     // 바닥 8장
  static const int totalCards = 50;        // 48장 + 보너스 2장

  // 점수 관련 (맞고 기준, 레거시 호환용)
  static const int goStopThreshold = 7;    // Go/Stop 선언 가능 점수
  static const int chongtongScore = 10;    // 총통 승리 점수

  /// 모드별 손패 장수
  static int getCardsPerPlayer(GameMode mode) => mode.cardsPerPlayer;

  /// 모드별 바닥패 장수
  static int getFieldCardCount(GameMode mode) => mode.fieldCardCount;

  /// 모드별 승리 점수 기준
  static int getWinThreshold(GameMode mode) => mode.winThreshold;

  /// 모드별 피박 기준
  static int getPiBakThreshold(GameMode mode) => mode.piBakThreshold;
}
