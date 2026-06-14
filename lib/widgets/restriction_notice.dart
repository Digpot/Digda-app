import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 서비스 이용 제한 계정에 노출하는 안내 화면(본문 대체용).
/// 그룹 리스트·그룹 홈 등에서 동일한 톤으로 "마이페이지만 사용 가능"을 안내하고,
/// 마이페이지로 이동하는 버튼을 제공한다.
class RestrictionNotice extends StatelessWidget {
  const RestrictionNotice({super.key, required this.onGoMyPage});

  /// '마이페이지로 이동' 버튼 콜백.
  final VoidCallback onGoMyPage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              '서비스 이용이 제한된 계정이에요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '회원님의 계정은 현재 서비스 이용이 제한되어\n마이페이지만 사용할 수 있어요.\n자세한 내용은 고객센터로 문의해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onGoMyPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '마이페이지로 이동',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
