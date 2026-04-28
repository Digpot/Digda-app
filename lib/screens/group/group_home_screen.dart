import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/feature_card.dart';

class GroupHomeScreen extends StatelessWidget {
  const GroupHomeScreen({super.key, this.groupName = '대학 친구들'});

  final String groupName;

  static const _memberColors = [
    AppColors.primary,
    AppColors.blue,
    AppColors.green,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    // S3-Group_List에서 전달된 그룹 정보 동적으로 받기
    final args = ModalRoute.of(context)?.settings.arguments;
    final String dynamicName;
    final int memberCount;
    if (args is Map<String, dynamic>) {
      dynamicName = args['name'] as String? ?? groupName;
      memberCount = args['members'] as int? ?? 7;
    } else if (args is String) {
      dynamicName = args;
      memberCount = 7;
    } else {
      dynamicName = groupName;
      memberCount = 7;
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더 - 좌측 뒤로가기 + 그룹명 + 우측 아이콘
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      dynamicName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.gray900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/notifications'),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          size: 22,
                          color: AppColors.gray700,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/my-page'),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // 멤버 아바타
                    _buildMemberSection(memberCount),
                    // 버튼을 아래로 이동 - 여백 증가
                    const SizedBox(height: 60),
                    // 기능 카드들
                    FeatureCard(
                      icon: Icons.calendar_month_outlined,
                      iconBgColor: AppColors.primary.withValues(alpha: 0.15),
                      iconColor: AppColors.primary,
                      cardBgColor: AppColors.primary.withValues(alpha: 0.06),
                      title: '일정 관리',
                      subtitle: '우리 모임 일정을 한눈에',
                      onTap: () =>
                          Navigator.of(context).pushNamed('/schedule'),
                    ),
                    const SizedBox(height: 12),
                    FeatureCard(
                      icon: Icons.book_outlined,
                      iconBgColor: const Color(0xFFFFE88A),
                      iconColor: const Color(0xFFC89A00),
                      cardBgColor: const Color(0xFFFFFBEE),
                      title: '그림일기',
                      subtitle: '오늘의 추억을 기록해요',
                      onTap: () =>
                          Navigator.of(context).pushNamed('/diary'),
                    ),
                    const SizedBox(height: 12),
                    FeatureCard(
                      icon: Icons.sentiment_satisfied_outlined,
                      iconBgColor: AppColors.gray100,
                      iconColor: AppColors.gray400,
                      cardBgColor: AppColors.gray50,
                      title: '퀴즈 게임',
                      subtitle: '준비 중이에요',
                      isDisabled: true,
                      badge: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Coming Soon',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FeatureCard(
                      icon: Icons.check_box_outlined,
                      iconBgColor: AppColors.blue.withValues(alpha: 0.2),
                      iconColor: AppColors.blue,
                      cardBgColor: AppColors.blue.withValues(alpha: 0.06),
                      title: '투두리스트',
                      subtitle: '할 일을 함께 관리해요',
                      badge: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '3개 남음',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                      onTap: () =>
                          Navigator.of(context).pushNamed('/todo'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSection(int totalMembers) {
    final displayCount = totalMembers > 4 ? 4 : totalMembers;
    final extraCount = totalMembers - displayCount;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...List.generate(displayCount, (i) => _buildAvatar(i)),
            if (extraCount > 0) ...[
              const SizedBox(width: 8),
              _buildExtraAvatar(extraCount),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$totalMembers명 참여 중',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(int index) {
    final color = _memberColors[index % _memberColors.length];
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: Icon(Icons.person_outline, size: 22, color: color),
    );
  }

  Widget _buildExtraAvatar(int count) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.gray500,
          ),
        ),
      ),
    );
  }
}
