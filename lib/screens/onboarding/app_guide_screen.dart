import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';

/// 페이지별 일러스트 종류.
enum _Illo { welcome, invite, diary, calendar, footprint, mochi }

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

  // 읽는 가이드 → 보는 가이드: 페이지마다 일러스트 1개 + 한 문장 가치.
  // 환영 → 그룹·초대 → 그림일기 → 일정 → 퀴즈·모찌 (5단계 흐름).
  final List<_GuidePageData> _pages = const [
    _GuidePageData(
      illo: _Illo.welcome,
      accent: Color(0xFFFF6B6B),
      accentBg: Color(0xFFFFF1F1),
      eyebrow: 'WELCOME 🌷',
      title: '함께 쓰는 그림일기,\n디그팟',
      body: '친구·연인·가족과 일정과 추억을\n한 권에 모아두는 우리만의 공간이에요',
      mochiSkinHex: '#FF6B6B',
      mochiStage: CharacterStage.bloom,
    ),
    _GuidePageData(
      illo: _Illo.invite,
      accent: Color(0xFF60A5FA),
      accentBg: Color(0xFFEFF6FF),
      eyebrow: 'STEP 1',
      title: '그룹을 만들고 초대해요',
      body: '초대코드 하나면 친구를\n손쉽게 우리 그룹으로 부를 수 있어요',
    ),
    _GuidePageData(
      illo: _Illo.diary,
      accent: Color(0xFF34D399),
      accentBg: Color(0xFFECFDF5),
      eyebrow: 'STEP 2',
      title: '그림일기를 함께 남겨요',
      body: '사진과 글로 하루를 기록하고\n댓글로 서로의 마음을 나눠요',
    ),
    _GuidePageData(
      illo: _Illo.calendar,
      accent: Color(0xFFF59E0B),
      accentBg: Color(0xFFFFFBEB),
      eyebrow: 'STEP 3',
      title: '일정을 함께 관리해요',
      body: '모임·기념일을 하나의 캘린더에 모아\n다 같이 챙길 수 있어요',
    ),
    _GuidePageData(
      illo: _Illo.footprint,
      accent: Color(0xFF14B8A6),
      accentBg: Color(0xFFF0FDFA),
      eyebrow: 'STEP 4',
      title: '발자취를 지도에 남겨요',
      body: '장소와 함께 일기를 쓰면 그 지역이\n지도에 채워지고, 다 채우면 칭호를 받아요',
    ),
    _GuidePageData(
      illo: _Illo.mochi,
      accent: Color(0xFFA78BFA),
      accentBg: Color(0xFFF5F3FF),
      eyebrow: 'STEP 5',
      title: '퀴즈 풀고 모찌를 키워요',
      body: '함께 퀴즈를 풀수록\n우리 그룹 모찌가 무럭무럭 자라요',
      cta: '디그팟 시작하기',
      mochiSkinHex: '#A78BFA',
      mochiStage: CharacterStage.master,
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

  void _onBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).maybePop();
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
    final data = _pages[_currentPage];
    final isLastPage = _currentPage == _pages.length - 1;
    final canGoBack = _currentPage > 0 || widget.isFromMyPage;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바: 뒤로 + 건너뛰기 (마지막 페이지는 건너뛰기 없음)
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (canGoBack)
                      _TopIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: _onBack,
                      )
                    else
                      const SizedBox(width: 44),
                    const Spacer(),
                    if (!isLastPage)
                      Semantics(
                        button: true,
                        label: '건너뛰기',
                        child: GestureDetector(
                          onTap: _finish,
                          child: Container(
                            height: 36,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      ),
                  ],
                ),
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
            // 인디케이터 + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Column(
                children: [
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
                          color: isActive ? data.accent : AppColors.gray200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: data.accent,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isLastPage ? (data.cta ?? '시작하기') : '다음',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
      child: Column(
        children: [
          // 일러스트 (페이지별 소프트 배경)
          _IllustrationCard(data: data),
          const SizedBox(height: 28),
          // eyebrow (STEP n)
          Text(
            data.eyebrow,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.5,
              color: data.accent,
            ),
          ),
          const SizedBox(height: 10),
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
          Text(
            data.body,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 15,
              height: 1.6,
              color: AppColors.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 페이지별 일러스트를 담는 소프트 배경 카드.
class _IllustrationCard extends StatelessWidget {
  final _GuidePageData data;
  const _IllustrationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true, // 장식 — 의미는 제목/본문으로 전달
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          color: data.accentBg,
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 은은한 장식 원
            Positioned(
              top: -40,
              right: -30,
              child: _softCircle(data.accent.withValues(alpha: 0.10), 160),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: _softCircle(data.accent.withValues(alpha: 0.08), 150),
            ),
            _buildIllo(),
          ],
        ),
      ),
    );
  }

  Widget _buildIllo() {
    switch (data.illo) {
      case _Illo.welcome:
        return _WelcomeIllo(data: data);
      case _Illo.invite:
        return _InviteIllo(accent: data.accent);
      case _Illo.diary:
        return _DiaryIllo(accent: data.accent);
      case _Illo.calendar:
        return _CalendarIllo(accent: data.accent);
      case _Illo.footprint:
        return _FootprintIllo(accent: data.accent);
      case _Illo.mochi:
        return _MochiLevelUpIllo(data: data);
    }
  }

  Widget _softCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 01 · 환영 — 모찌 + 일기/하트/캘린더 버블
// ─────────────────────────────────────────────────────────────
class _WelcomeIllo extends StatelessWidget {
  final _GuidePageData data;
  const _WelcomeIllo({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // halo
        Positioned(
          bottom: 4,
          child: Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.accent.withValues(alpha: 0.20),
                  data.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          // 모찌 squircle 배경이 카드(Clip.antiAlias) 아래로 잘리지 않도록 양수 오프셋.
          bottom: 8,
          child: MochiCharacterView(
            appearance: MochiAppearance(
                skinHex: data.mochiSkinHex!, skinAssetKey: 'skin/coral'),
            stage: data.mochiStage!,
            size: 184,
            expression: MochiEmotion.happy,
          ),
        ),
        Positioned(top: 30, left: 14, child: _bubble('✏️ 오늘 일기', data.accent)),
        Positioned(top: 18, right: 16, child: _bubble('❤️ 좋아요', data.accent)),
        Positioned(bottom: 28, right: 6, child: _bubble('📅 약속', data.accent)),
      ],
    );
  }

  Widget _bubble(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.gray800,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 02 · 그룹·초대 — 초대코드 카드 + 멤버/추가 버블
// ─────────────────────────────────────────────────────────────
class _InviteIllo extends StatelessWidget {
  final Color accent;
  const _InviteIllo({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 초대코드 카드
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                '초대코드',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'A8K-2F9',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      letterSpacing: 3,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.copy_rounded, size: 16, color: accent),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // 멤버 아바타 + 추가
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatar(const Color(0xFFFF8FA3), 'J'),
            _avatar(const Color(0xFFFFD166), 'M'),
            _avatar(const Color(0xFF6EE7B7), 'Y'),
            const SizedBox(width: 6),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.5),
                  width: 1.6,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(Icons.add_rounded, color: accent, size: 22),
            ),
          ],
        ),
      ],
    );
  }

  Widget _avatar(Color color, String letter) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 03 · 그림일기 — 일기 카드(사진 placeholder) + 펜/댓글
// ─────────────────────────────────────────────────────────────
class _DiaryIllo extends StatelessWidget {
  final Color accent;
  const _DiaryIllo({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 230,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 사진 placeholder
              Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.image_outlined,
                  color: accent.withValues(alpha: 0.7),
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              _line(140, accent.withValues(alpha: 0.55)),
              const SizedBox(height: 8),
              _line(180, AppColors.gray200),
              const SizedBox(height: 6),
              _line(120, AppColors.gray200),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 16, color: accent),
                  const SizedBox(width: 4),
                  const Text('3',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray500)),
                  const SizedBox(width: 14),
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 15, color: AppColors.gray400),
                  const SizedBox(width: 4),
                  const Text('2',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray500)),
                ],
              ),
            ],
          ),
        ),
        // 펜 버블
        Positioned(
          top: -14,
          right: -10,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.edit_rounded,
                size: 18, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _line(double width, Color color) {
    return Container(
      width: width,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 04 · 일정 — 미니 캘린더(날짜 강조 + 일정 칩)
// ─────────────────────────────────────────────────────────────
class _CalendarIllo extends StatelessWidget {
  final Color accent;
  const _CalendarIllo({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '6월',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 12),
          // 날짜 그리드 (강조 1칸)
          ...List.generate(2, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (col) {
                  final isHighlight = row == 0 && col == 2;
                  return Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isHighlight ? accent : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isHighlight
                            ? AppColors.white
                            : AppColors.gray200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: 6),
          _eventChip(accent, '모임 · 오후 7시'),
          const SizedBox(height: 8),
          _eventChip(const Color(0xFFF472B6), '기념일'),
        ],
      ),
    );
  }

  Widget _eventChip(Color color, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 05 · 발자취 — 한반도 지도(채운 지역 강조 + 위치 핀) + 발자국·칭호 배지
// ─────────────────────────────────────────────────────────────
class _FootprintIllo extends StatelessWidget {
  final Color accent;
  const _FootprintIllo({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 한반도 지도 카드 — 실제 반도 실루엣에 다녀온 지역을 코랄로 채운다.
        Container(
          width: 210,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            width: 150,
            height: 196,
            child: CustomPaint(
              painter: _PeninsulaPainter(accent),
            ),
          ),
        ),
        // 발자국 — 지도를 가로지르는 동선.
        Positioned(
          top: 16,
          left: 26,
          child: Text('👣',
              style: TextStyle(
                  fontSize: 18, color: accent.withValues(alpha: 0.9))),
        ),
        const Positioned(
          bottom: 34,
          right: 24,
          child: Text('👣', style: TextStyle(fontSize: 16)),
        ),
        // 칭호 배지 — "한 권역을 다 채우면 칭호".
        Positioned(
          bottom: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 18, color: accent),
                const SizedBox(width: 6),
                Text(
                  '여행가 칭호 획득!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 한반도 실루엣을 그리는 페인터 — 부드러운 반도 윤곽 + 다녀온 지역(코랄) + 위치 핀.
/// 온보딩 장식용이라 행정 경계가 아니라 양식화된 실루엣으로, 앱 코랄 톤에 맞춰 재조명.
class _PeninsulaPainter extends CustomPainter {
  _PeninsulaPainter(this.accent);

  final Color accent;

  // 정규화 박스(100×130, y는 아래로). 한반도를 단순화한 윤곽 점들.
  static const List<Offset> _outline = [
    Offset(38, 6), Offset(52, 2), Offset(66, 5), Offset(82, 9),
    Offset(89, 20), Offset(80, 30), Offset(76, 45), Offset(72, 61),
    Offset(70, 77), Offset(64, 89), Offset(54, 94), Offset(46, 89),
    Offset(40, 99), Offset(32, 91), Offset(35, 77), Offset(26, 67),
    Offset(33, 57), Offset(24, 47), Offset(31, 36), Offset(22, 26),
    Offset(30, 15),
  ];

  // 다녀온(채워진) 지역 중심 — 정규화 좌표.
  static const List<Offset> _filled = [
    Offset(52, 42), Offset(45, 66), Offset(59, 80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 100, size.height / 130);
    final ox = (size.width - 100 * s) / 2;
    final oy = (size.height - 130 * s) / 2;
    Offset p(Offset n) => Offset(ox + n.dx * s, oy + n.dy * s);

    // 1) 윤곽 점들을 중점 경유 2차 베지어로 이어 매끄러운 반도 path 생성.
    final pts = _outline.map(p).toList();
    final n = pts.length;
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final path = Path();
    path.moveTo(mid(pts[n - 1], pts[0]).dx, mid(pts[n - 1], pts[0]).dy);
    for (var i = 0; i < n; i++) {
      final c = pts[i];
      final next = mid(pts[i], pts[(i + 1) % n]);
      path.quadraticBezierTo(c.dx, c.dy, next.dx, next.dy);
    }
    path.close();

    // 2) 반도 채움(은은한 그라데이션) + 윤곽선.
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.10),
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.40),
    );

    // 3) 다녀온 지역 — 반도 안쪽을 코랄 원으로 또렷이 채운다.
    final fillPaint = Paint()..color = accent.withValues(alpha: 0.85);
    for (final f in _filled) {
      canvas.drawCircle(p(f), 9 * s, fillPaint);
    }

    // 4) 첫 채운 지역 위에 위치 핀.
    _drawPin(canvas, p(const Offset(52, 42)), s);
  }

  void _drawPin(Canvas canvas, Offset anchor, double s) {
    final r = 8 * s;
    final center = Offset(anchor.dx, anchor.dy - r * 1.7);
    final tip = Offset(anchor.dx, anchor.dy + r * 0.4);

    // 그림자
    canvas.drawCircle(
      center.translate(0, 2 * s),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
    );

    // 물방울(원 + 아래 꼭지) 핀.
    final pin = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    pin.moveTo(tip.dx, tip.dy);
    pin.lineTo(center.dx - r * 0.72, center.dy + r * 0.72);
    pin.lineTo(center.dx + r * 0.72, center.dy + r * 0.72);
    pin.close();
    canvas.drawPath(pin, Paint()..color = accent);
    canvas.drawPath(
      pin,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
    );
    canvas.drawCircle(center, r * 0.4, Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(_PeninsulaPainter old) => old.accent != accent;
}

// ─────────────────────────────────────────────────────────────
// 06 · 퀴즈·모찌 — 모찌(레벨업 ✨) + 퀴즈/Lv 카드
// ─────────────────────────────────────────────────────────────
class _MochiLevelUpIllo extends StatelessWidget {
  final _GuidePageData data;
  const _MochiLevelUpIllo({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 4,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.accent.withValues(alpha: 0.22),
                  data.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          // 모찌 squircle 배경이 카드(Clip.antiAlias) 아래로 잘리지 않도록 양수 오프셋.
          bottom: 8,
          child: MochiCharacterView(
            appearance: MochiAppearance(
                skinHex: data.mochiSkinHex!, skinAssetKey: 'skin/coral'),
            stage: data.mochiStage!,
            size: 176,
            expression: MochiEmotion.happy,
          ),
        ),
        // Lv 배지
        Positioned(
          top: 22,
          left: 18,
          child: _card(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 15, color: data.accent),
                const SizedBox(width: 5),
                Text('Lv.5',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: data.accent)),
              ],
            ),
            data.accent,
          ),
        ),
        // 퀴즈 카드
        Positioned(
          top: 14,
          right: 14,
          child: _card(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Q',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.gray900)),
                SizedBox(width: 6),
                Text('오늘의 퀴즈',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.gray700)),
              ],
            ),
            data.accent,
          ),
        ),
        const Positioned(
          bottom: 96,
          right: 30,
          child: Text('✨', style: TextStyle(fontSize: 22)),
        ),
        const Positioned(
          top: 70,
          left: 44,
          child: Text('✨', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _card(Widget child, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 20, color: AppColors.gray700),
      ),
    );
  }
}

class _GuidePageData {
  final _Illo illo;
  final Color accent; // 페이지 테마색
  final Color accentBg; // 일러스트 소프트 배경
  final String eyebrow; // STEP n / WELCOME
  final String title;
  final String body;
  final String? cta; // 마지막 페이지만 커스텀
  final String? mochiSkinHex; // 모찌 일러스트 페이지용
  final CharacterStage? mochiStage;

  const _GuidePageData({
    required this.illo,
    required this.accent,
    required this.accentBg,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.cta,
    this.mochiSkinHex,
    this.mochiStage,
  });
}
