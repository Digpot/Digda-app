import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';

class QuizComingSoonScreen extends StatelessWidget {
  const QuizComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 하단 탭 진입점이라 뒤로가기 없이 좌측 정렬 타이틀로 통일
            // (그룹 홈·캘린더·일기 탭과 동일 패턴).
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '퀴즈',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz_outlined,
                size: 48,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '준비 중이에요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.21,
                letterSpacing: 0,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '곧 서로를 더 잘 알아가는\n재미있는 퀴즈가 찾아올 거예요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 15,
                height: 1.6,
                letterSpacing: 0,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.21,
                  letterSpacing: 0,
                  color: AppColors.purple,
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }
}
