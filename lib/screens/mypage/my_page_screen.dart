import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/di.dart';
import '../../theme/colors.dart';
import '../onboarding/code_input_screen.dart';
import '../feedback/feedback_form_screen.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/notification_bell_icon.dart';
import '../../features/user/models/user_models.dart';
import '../../features/app_config/models/app_config.dart';

/// 디그팟 개인정보처리방침 호스팅 URL.
const String _privacyPolicyUrl =
    'https://digpot.github.io/Digda-app/privacy-policy.html';


class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  // 피드백 메뉴 노출/링크 — 어드민 설정(서버)에서 받아온다.
  AppConfig _appConfig = AppConfig.empty;
  // 앱 버전 — pubspec(빌드)에서 동적으로 읽어 하드코딩을 피한다. 로드 전엔 빈 값.
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    Di.userSession.addListener(_onSession);
    _appConfig = Di.appConfigRepository.cachedOrEmpty;
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    }, onError: (_) {});
    // 캐시가 비어 있으면 강제 갱신, 있더라도 화면 진입 시 최신화. 실패는 화면 표시에 영향 없음.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Di.userSession.refresh().then(
            (_) {},
            onError: (_) {},
          );
      Di.appConfigRepository.get().then(
        (cfg) {
          if (mounted) setState(() => _appConfig = cfg);
        },
        onError: (_) {},
      );
    });
  }

  @override
  void dispose() {
    Di.userSession.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = Di.userSession.profile;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
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
                  const Text(
                    '마이페이지',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  const NotificationBellIcon(),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pushNamed('/privacy-settings'),
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
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileCard(context, profile),
                    const SizedBox(height: 24),
                    _buildSectionLabel('그룹방 관리'),
                    _buildMenuGroup([
                      _menuRow(
                        icon: Icons.groups_rounded,
                        iconColor: AppColors.primary,
                        label: '그룹방 목록 보기',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/group-list'),
                      ),
                      _menuRow(
                        icon: Icons.vpn_key_rounded,
                        iconColor: AppColors.blue,
                        label: '초대 코드 입력',
                        onTap: () => _showCodeInputSheet(context),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSectionLabel('설정'),
                    _buildMenuGroup([
                      _menuRow(
                        icon: Icons.notifications_rounded,
                        iconColor: const Color(0xFFFBBF24),
                        label: '알림 설정',
                        onTap: () => Navigator.of(context)
                            .pushNamed('/notification-settings'),
                      ),
                      _menuRow(
                        icon: Icons.lock_rounded,
                        iconColor: AppColors.green,
                        label: '개인정보 관리',
                        onTap: () => Navigator.of(context)
                            .pushNamed('/privacy-settings'),
                      ),
                      _menuRow(
                        icon: Icons.block_rounded,
                        iconColor: AppColors.primary,
                        label: '차단 사용자 관리',
                        onTap: () => Navigator.of(context)
                            .pushNamed('/blocked-users'),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSectionLabel('기타'),
                    _buildMenuGroup([
                      _menuRow(
                        icon: Icons.headset_mic_rounded,
                        iconColor: AppColors.blue,
                        label: '고객센터',
                        onTap: () =>
                            Navigator.of(context).pushNamed('/support'),
                      ),
                      _menuRow(
                        icon: Icons.menu_book_rounded,
                        iconColor: AppColors.purple,
                        label: '앱 사용 가이드',
                        onTap: () => Navigator.of(context)
                            .pushNamed('/app-guide', arguments: true),
                      ),
                      _menuRow(
                        icon: Icons.description_rounded,
                        iconColor: AppColors.gray500,
                        label: '이용약관',
                        onTap: () => Navigator.of(context)
                            .pushNamed('/terms-detail', arguments: 'terms'),
                      ),
                      _menuRow(
                        icon: Icons.shield_rounded,
                        iconColor: AppColors.gray500,
                        label: '개인정보처리방침',
                        onTap: () => _openPrivacyPolicy(context),
                      ),
                      _menuRow(
                        icon: Icons.favorite_rounded,
                        iconColor: AppColors.primary,
                        label: '피드백 받기',
                        onTap: () => _openFeedbackForm(context),
                      ),
                      if (_appConfig.showFeedback)
                        _menuRow(
                          icon: Icons.code_rounded,
                          iconColor: AppColors.gray500,
                          label: '개발자 소개',
                          onTap: () => _openDeveloperIntro(context),
                        ),
                      _menuRow(
                        icon: Icons.info_rounded,
                        iconColor: AppColors.gray400,
                        label: '앱 정보',
                        onTap: () {},
                        trailing: Text(
                          _appVersion.isEmpty ? '' : 'v$_appVersion',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: AppColors.gray400,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(_privacyPolicyUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showErrorDialog(context, '브라우저를 열 수 없어요');
    }
  }

  /// 앱 자체 피드백 폼으로 이동.
  void _openFeedbackForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FeedbackFormScreen()),
    );
  }

  /// 개발자 소개 — 어드민이 설정한 외부 링크(app_config.feedbackUrl 재활용)로 이동.
  Future<void> _openDeveloperIntro(BuildContext context) async {
    final url = _appConfig.feedbackUrl.trim();
    if (url.isEmpty) {
      showInfoDialog(context, '개발자 소개', '개발자 소개 페이지를 준비 중이에요. 곧 열릴 예정입니다!');
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showErrorDialog(context, '브라우저를 열 수 없어요');
    }
  }

  void _showCodeInputSheet(BuildContext context) {
    // 온보딩·그룹 리스트와 동일한 단일 컨트롤러 입력 시트를 재사용한다.
    // (예전 마이페이지 전용 시트는 칸별 컨트롤러라 6자리 초과 입력 버그가 있었다.)
    CodeInputScreen.showAsSheet(context);
  }

  Widget _buildProfileCard(BuildContext context, UserProfile? profile) {
    final name = profile?.name ?? '';
    final imageUrl = profile?.profileImage;
    final initial = name.isNotEmpty ? name[0] : '';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1ED), Color(0xFFFDF5FB)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/edit-profile'),
            child: Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gray900.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  // ClipOval 로 명시적 원형 클립 — Container 의 BoxShape.circle
                  // 클립이 일부 환경에서 팔각형으로 렌더되는 현상을 피한다.
                  child: ClipOval(
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 64,
                            height: 64,
                            cacheWidth: 128,
                            cacheHeight: 128,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarFallback(initial),
                          )
                        : _avatarFallback(initial),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.gray700,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 12,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '사용자' : name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.gray900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                // 칭호 화면이 '프로필 편집' 안에 있어 못 찾는 일이 많아, 바로 가는
                // 안내 칩을 위에 둔다(탭하면 칭호 수집 화면으로).
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/titles'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          '칭호를 확인해보세요',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed('/edit-profile'),
                  child: const Row(
                    children: [
                      Text(
                        '프로필 편집',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                          color: AppColors.gray500,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: AppColors.gray500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    if (initial.isEmpty) {
      return const Icon(
        Icons.person,
        size: 36,
        color: AppColors.primary,
      );
    }
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.gray500,
        ),
      ),
    );
  }

  /// 한 섹션의 메뉴 행들을 하나의 카드로 묶고 행 사이에 얇은 구분선을 넣는다.
  Widget _buildMenuGroup(List<Widget> rows) {
    final children = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(const Divider(
          height: 1,
          thickness: 1,
          indent: 62,
          color: AppColors.gray50,
        ));
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(children: children),
    );
  }

  /// 카드 안의 메뉴 한 줄 — 소프트 컬러 아이콘 칩 + 라벨 + 우측(셰브론/커스텀).
  Widget _menuRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.gray900,
                  ),
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.gray300,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
