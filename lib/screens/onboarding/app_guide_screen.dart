import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';

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
      gradient: [Color(0xFFFFB3B8), Color(0xFFFF6B6B)],
      skinHex: '#FF6B6B',
      stage: CharacterStage.sprout,
      speech: '안녕! 난 모찌야 🌸\n디그팟을 같이 둘러볼까?',
      title: '함께 쓰는 그룹 다이어리',
      subtitle: '친구, 가족, 연인과 함께\n하루를 기록하고 공유해요',
      features: [
        _FeatureItem(Icons.group_add_outlined, '초대 코드로 간편 참여'),
        _FeatureItem(Icons.photo_camera_outlined, '사진과 함께 일기 작성'),
        _FeatureItem(Icons.favorite_outline, '서로의 일상을 한눈에'),
      ],
    ),
    _GuidePageData(
      gradient: [Color(0xFF93C5FD), Color(0xFF60A5FA)],
      skinHex: '#60A5FA',
      stage: CharacterStage.bloom,
      speech: '일정도 나랑 같이\n관리할 수 있어!',
      title: '일정을 함께 관리해요',
      subtitle: '그룹 일정을 한 캘린더에서\n쉽게 확인하고 공유해요',
      features: [
        _FeatureItem(Icons.event_outlined, '그룹 일정 등록 & 공유'),
        _FeatureItem(Icons.palette_outlined, '카테고리별 색상 구분'),
        _FeatureItem(Icons.people_outline, '참가자 초대 & 관리'),
      ],
    ),
    _GuidePageData(
      gradient: [Color(0xFF86EFAC), Color(0xFF34D399)],
      skinHex: '#34D399',
      stage: CharacterStage.blossom,
      speech: '할 일은 나랑 같이\n체크하자! ✅',
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
      skinHex: '#A78BFA',
      stage: CharacterStage.glow,
      speech: '준비됐어?\n이제 시작해보자! 🚀',
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
      // 최초 가입 후 진입 → splash/login/terms 스택을 모두 제거하고 홈으로.
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
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
    final accent = data.gradient[1];
    return Stack(
      children: [
        // 부드러운 테마색 장식 원 (배경)
        Positioned(
          top: -70,
          left: -50,
          child: _blurCircle(accent.withValues(alpha: 0.16), 240),
        ),
        Positioned(
          top: 30,
          right: -60,
          child: _blurCircle(data.gradient[0].withValues(alpha: 0.18), 180),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
          child: Column(
            children: [
              // 모찌 + 말풍선 (마스코트가 직접 설명)
              _buildMochiStage(data),
              const SizedBox(height: 22),
              Text(
                data.title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 25,
                  height: 1.3,
                  color: AppColors.gray900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 28),
              ...data.features.map((f) => _buildFeatureRow(f, accent)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  /// 페이지 마스코트 — 모찌(페이지 테마색 배경) + 머리 위 말풍선. 페이지가 넘어갈수록 성장.
  Widget _buildMochiStage(_GuidePageData data) {
    final accent = data.gradient[1];
    return SizedBox(
      height: 248,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 모찌 뒤 halo
          Positioned(
            bottom: 10,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 모찌 본체
          Positioned(
            bottom: 0,
            child: MochiCharacterView(
              appearance:
                  MochiAppearance(skinHex: data.skinHex, skinAssetKey: 'skin/coral'),
              stage: data.stage,
              size: 172,
              expression: MochiEmotion.happy,
            ),
          ),
          // 말풍선 (모찌 우상단)
          Positioned(
            top: 0,
            right: 6,
            child: _speechBubble(data.speech, accent),
          ),
        ],
      ),
    );
  }

  Widget _speechBubble(String text, Color accent) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.35,
          color: AppColors.gray800,
        ),
      ),
    );
  }

  Widget _blurCircle(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
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
  final String skinHex; // 모찌 배경 squircle 색 (페이지 테마색)
  final CharacterStage stage; // 페이지가 넘어갈수록 모찌가 성장
  final String speech; // 모찌 말풍선 대사
  final String title;
  final String subtitle;
  final List<_FeatureItem> features;

  const _GuidePageData({
    required this.gradient,
    required this.skinHex,
    required this.stage,
    required this.speech,
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
