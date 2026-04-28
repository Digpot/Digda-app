import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFFFF6B6B);       // 메인 빨강
  static const Color primaryDark = Color(0xFFFF4D4D);    // 삭제/위험 빨강

  // Accent
  static const Color blue = Color(0xFF60A5FA);           // 투두리스트 파랑
  static const Color green = Color(0xFF34D399);          // 참가자 뱃지 초록
  static const Color purple = Color(0xFFA78BFA);         // 일정 카테고리 보라
  static const Color saturdayBlue = Color(0xFF4A90D9);   // 토요일 파랑
  static const Color kakaoYellow = Color(0xFFFEE500);    // 카카오 배경
  static const Color naverGreen = Color(0xFF03C75A);     // 네이버 배경
  static const Color appleBlack = Color(0xFF000000);     // 애플 배경

  // Grayscale - Text
  static const Color gray900 = Color(0xFF191F28);        // 기본 텍스트
  static const Color gray800 = Color(0xFF333333);        // 본문 텍스트
  static const Color gray700 = Color(0xFF4E5968);        // 보조 텍스트
  static const Color gray500 = Color(0xFF8B95A1);        // 서브 텍스트/비활성
  static const Color gray400 = Color(0xFFB0B8C1);        // 플레이스홀더/비활성버튼
  static const Color gray300 = Color(0xFFC8C8C0);        // 입력 플레이스홀더
  static const Color gray200 = Color(0xFFD1D6DB);        // 화면 라벨/구분선
  static const Color gray100 = Color(0xFFE5E8EB);        // 배경 장식
  static const Color gray50 = Color(0xFFF2F4F6);         // 배경 밝은회색

  // Semantic
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color kakaoText = Color(0xFF3C1E1E);      // 카카오 텍스트
  static const Color inputHint = Color(0xFF888888);       // 일기 입력 힌트
  static const Color sundayRed = Color(0xFFFF6B6B);       // 일요일 빨강 = primary

  // Background
  static const Color scaffoldBg = Color(0xFFFFFFFF);      // 기본 배경 흰색
  static const Color bottomSheetBg = Color(0xFFFFFFFF);   // 바텀시트 배경
  static const Color overlayBg = Color(0x80000000);       // 오버레이 50% 검정

  // Schedule Event Colors
  static const Color eventRed = Color(0xFFFF6B6B);        // 빨강 일정
  static const Color eventPurple = Color(0xFFA78BFA);     // 보라 일정
  static const Color eventHoliday = Color(0xFF8B0000);    // 공휴일 찐빨강 (pill bg)

  // Schedule Category Colors (연한 파스텔)
  static const Color categoryRed = Color(0xFFFFB3B3);     // 연한 빨강
  static const Color categoryPurple = Color(0xFFD4C4FF);  // 연한 보라
  static const Color categoryBlue = Color(0xFFB3D9FF);    // 연한 파랑
  static const Color categoryGreen = Color(0xFFA8EDCE);   // 연한 초록
  static const Color categoryYellow = Color(0xFFFFE6A0);  // 연한 노랑
}
