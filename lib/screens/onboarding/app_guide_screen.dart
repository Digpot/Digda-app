import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class AppGuideScreen extends StatefulWidget {
  /// true면 마이페이지에서 다시 보기로 진입 (뒤로가기만)
  /// false면 최초 로그인 후 진입 (/home으로 이동)
  final bool isFromMyPage;

  const AppGuideScreen({super.key, this.isFromMyPage = false});

  @override
  State<AppGuideScreen> createState() => _AppGuideScreenState();
}

class _AppGuideScreenState extends State<AppGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_GuidePageData> _pages = const [
    _GuidePageData(
      gradient: [Color(0xFFFF9A9E), Color(0xFFFF6B6B)],
      icon: Icons.auto_stories_rounded,
      title: '함께 쓰는 그룹 다이어리',
      subtitle: '친구, 가족, 연인과 함께\n하루를 기록하고 공유하세요',
      features: [
        _FeatureItem(Icons.group_add_outlined, '초대 코드로 간편 참여'),
        _FeatureItem(Icons.photo_camera_outlined, '사진과 함께 일기 작성'),
        _FeatureItem(Icons.favorite_outline, '서로의 일상을 한눈에'),
      ],
    ),
    _GuidePageData(
      gradient: [Color(0xFF93C5FD), Color(0xFF60A5FA)],
      icon: Icons.calendar_month_rounded,
      title: '일정을 함께 관리해요',
      subtitle: '그룹 일정을 한 캘린더에서\n쉽게 확인하고 공유하세요',
      features: [
        _FeatureItem(Icons.event_outlined, '그룹 일정 등록 & 공유'),
        _FeatureItem(Icons.palette_outlined, '카테고리별 색상 구분'),
        _FeatureItem(Icons.people_outline, '참가자 초대 & 관리'),
      ],
    ),
    _GuidePageData(
      gradient: [Color(0xFF86EFAC), Color(0xFF34D399)],
      icon: Icons.checklist_rounded,
      title: '할 일을 놓치지 마세요',
      subtitle: '그룹 투두리스트로\n해야 할 일을 함께 체크해요',
      features: [
        _FeatureItem(Icons.add_task_outlined, '할 일 추가 & 완료 체크'),
        _FeatureItem(Icons.insights_outlined, '진행률 한눈에 확인'),
        _FeatureItem(Icons.notifications_active_outlined, '알림으로 리마인드'),
      ],
    ),
    _GuidePageData(
      gradient: [Color(0xFFC4B5FD), Color(0xFFA78BFA)],
      icon: Icons.rocket_launch_rounded,
      title: '지금 바로 시작하세요!',
      subtitle: '다이어리를 만들거나\n초대 코드로 참여해보세요',
      features: [
        _FeatureItem(Icons.edit_note_outlined, '다이어리 만들기'),
        _FeatureItem(Icons.qr_code_outlined, '초대 코드로 참여'),
        _FeatureItem(Icons.emoji_emotions_outlined, '소중한 순간을 함께'),
      ],
    ),
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    if (widget.isFromMyPage) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 건너뛰기
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isLastPage)
                    GestureDetector(
                      onTap: _finish,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '건너뛰기',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppColors.gray500,
                          ),
                        ),
                      ),
                    ),
                  if (isLastPage) const SizedBox(height: 36),
                ],
              ),
            ),
            // 페이지 콘텐츠
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _buildGuidePage(_pages[index]);
                },
              ),
            ),
            // 인디케이터 + 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  // 도트 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _pages[_currentPage].gradient[1]
                              : AppColors.gray200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  // 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].gradient[1],
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isLastPage ? '시작하기' : '다음',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidePage(_GuidePageData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // 아이콘 영역
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: data.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: data.gradient[1].withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              data.icon,
              size: 64,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 36),
          // 타이틀
          Text(
            data.title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 26,
              height: 1.3,
              color: AppColors.gray900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // 서브타이틀
          Text(
            data.subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 15,
              height: 1.6,
              color: AppColors.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          // 기능 리스트
          ...data.features.map((feature) => _buildFeatureRow(feature, data.gradient[1])),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(_FeatureItem feature, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                feature.icon,
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              feature.label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: AppColors.gray800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePageData {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_FeatureItem> features;

  const _GuidePageData({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
  });
}

class _FeatureItem {
  final IconData icon;
  final String label;

  const _FeatureItem(this.icon, this.label);
}
