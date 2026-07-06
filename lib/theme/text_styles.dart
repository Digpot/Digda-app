import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Inter';

  // Heading
  static const TextStyle heading1 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle heading5 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle heading6 = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle bodyLargeBold = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle bodyMediumBold = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray500,
  );

  static const TextStyle bodySmallBold = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray700,
  );

  // Caption
  static const TextStyle captionLarge = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray500,
  );

  static const TextStyle captionLargeBold = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  static const TextStyle captionSmall = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray500,
  );

  static const TextStyle captionSmallBold = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  // Tiny
  static const TextStyle tiny = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 10,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray500,
  );

  static const TextStyle tinyBold = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 10,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  // StatusBar
  static const TextStyle statusBar = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );

  // Calendar specific
  static const TextStyle calendarDay = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray700,
  );

  static const TextStyle calendarDaySelected = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.white,
  );

  static const TextStyle calendarWeekday = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray700,
  );

  static const TextStyle calendarEvent = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 9,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.primary,
  );

  static const TextStyle calendarEventSmall = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 8,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.purple,
  );

  // Code display
  static const TextStyle codeDisplay = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 34,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.primary,
  );

  // Percentage
  static const TextStyle percentage = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.blue,
  );

  // Counter
  static const TextStyle counterLarge = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.21,
    letterSpacing: 0,
    color: AppColors.gray900,
  );
}
