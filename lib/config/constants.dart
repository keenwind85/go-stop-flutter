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

/// 게임 관련 상수
class GameConstants {
  // 카드 크기 (모바일 최적화: 기존 대비 80%)
  static const double cardWidth = 52.0;
  static const double cardHeight = 78.0;
  static const double cardSpacing = 6.0;

  static const int cardsPerPlayer = 10;   // 손패 10장
  static const int fieldCardCount = 8;     // 바닥 8장
  static const int totalCards = 50;        // 48장 + 보너스 2장

  // 점수 관련
  static const int goStopThreshold = 7;    // Go/Stop 선언 가능 점수
  static const int chongtongScore = 10;    // 총통 승리 점수
}
