import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/notification_bell_icon.dart';
import '../../features/user/models/user_models.dart';
import '../../features/app_config/models/app_config.dart';

/// 디그팟 개인정보처리방침 호스팅 URL.
const String _privacyPolicyUrl =
    'https://datediary.github.io/Digda-app/privacy-policy.html';


class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  // 피드백 메뉴 노출/링크 — 어드민 설정(서버)에서 받아온다.
  AppConfig _appConfig = AppConfig.empty;

  @override
  void initState() {
    super.initState();
    Di.userSession.addListener(_onSession);
    _appConfig = Di.appConfigRepository.cachedOrEmpty;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileSection(context, profile),
                    const SizedBox(height: 24),
                    _buildSectionLabel('그룹방 관리'),
                    _buildMenuItem(
                      context,
                      icon: Icons.menu_outlined,
                      label: '그룹방 목록 보기',
                      onTap: () =>
                          Navigator.of(context).pushNamed('/group-list'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.keyboard_outlined,
                      label: '초대 코드 입력',
                      onTap: () => _showCodeInputSheet(context),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel('설정'),
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications_outlined,
                      label: '알림 설정',
                      onTap: () => Navigator.of(context)
                          .pushNamed('/notification-settings'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.lock_outline,
                      label: '개인정보 관리',
                      onTap: () => Navigator.of(context)
                          .pushNamed('/privacy-settings'),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel('기타'),
                    _buildMenuItem(
                      context,
                      icon: Icons.menu_book_outlined,
                      label: '앱 사용 가이드',
                      onTap: () => Navigator.of(context)
                          .pushNamed('/app-guide', arguments: true),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.description_outlined,
                      label: '이용약관',
                      onTap: () => Navigator.of(context)
                          .pushNamed('/terms-detail', arguments: 'terms'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.shield_outlined,
                      label: '개인정보처리방침',
                      onTap: () => _openPrivacyPolicy(context),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.info_outline,
                      label: '앱 정보',
                      trailing: const Text(
                        'v1.0.0',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: AppColors.gray400,
                        ),
                      ),
                      onTap: () {},
                    ),
                    if (_appConfig.showFeedback)
                      _buildMenuItem(
                        context,
                        icon: Icons.feedback_outlined,
                        label: '피드백 받기',
                        onTap: () => _openFeedback(context),
                      ),
                    const SizedBox(height: 40),
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

  Future<void> _openFeedback(BuildContext context) async {
    final url = _appConfig.feedbackUrl.trim();
    if (url.isEmpty) {
      showInfoDialog(context, '피드백 받기', '피드백 폼을 준비 중이에요. 곧 열릴 예정입니다!');
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showErrorDialog(context, '브라우저를 열 수 없어요');
    }
  }

  void _showCodeInputSheet(BuildContext context) {
    // 참여 성공 시 시트가 직접 해당 그룹홈으로 이동(스택 비움)한다.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CodeInputBottomSheet(),
    );
  }

  Widget _buildProfileSection(BuildContext context, UserProfile? profile) {
    final name = profile?.name ?? '';
    final imageUrl = profile?.profileImage;
    final initial = name.isNotEmpty ? name[0] : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _avatarFallback(initial),
                        )
                      : _avatarFallback(initial),
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
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed('/edit-profile'),
                  child: Row(
                    children: const [
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
    Color? labelColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: AppColors.white,
        child: Row(
          children: [
            Icon(icon, size: 20, color: labelColor ?? AppColors.gray700),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                  color: labelColor ?? AppColors.gray900,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.gray400,
                ),
          ],
        ),
      ),
    );
  }
}

class _CodeInputBottomSheet extends StatefulWidget {
  const _CodeInputBottomSheet();

  @override
  State<_CodeInputBottomSheet> createState() => _CodeInputBottomSheetState();
}

class _CodeInputBottomSheetState extends State<_CodeInputBottomSheet> {
  static const int _codeLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  bool _submitting = false;

  bool get _isFilled => _controllers.every((c) => c.text.isNotEmpty);
  String get _enteredCode => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    // 붙여넣기(여러 자리) — 0번 칸부터 분배하고 마지막 입력 칸으로 포커스.
    if (digits.length > 1) {
      for (int i = 0; i < _codeLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final focusIdx = digits.length.clamp(1, _codeLength) - 1;
      _focusNodes[focusIdx].requestFocus();
      setState(() {});
      return;
    }
    if (_controllers[index].text != digits) {
      _controllers[index].text = digits;
      _controllers[index].selection =
          TextSelection.collapsed(offset: digits.length);
    }
    if (digits.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (digits.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final code = _enteredCode;
    try {
      await Di.inviteRepository.validate(code);
      if (!mounted) return;
      final result = await Di.inviteRepository.join(code);
      if (!mounted) return;
      // 참여한 그룹을 활성화하고 그 그룹홈으로 이동(스택 비움) — 온보딩 참여와 동일.
      Di.activeGroup.enter(
        groupRoomId: result.groupRoom.id,
        groupRoomName: result.groupRoom.name,
        isOwner: false,
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/group-home',
        (route) => false,
        arguments: {
          'name': result.groupRoom.name,
          'members': result.memberships.length,
          'isOwner': false,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorDialog(errorMessageOf(e, fallback: '유효하지 않은 초대 코드예요'));
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '초대 코드 오류',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '확인',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding:
          EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + keyboardHeight + 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '초대 코드를 입력하세요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.3,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '상대방에게 받은 6자리 코드를 입력해주세요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: List.generate(_codeLength, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _codeLength - 1 ? 0 : 8,
                  ),
                  child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: AppColors.gray900,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.gray50,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _controllers[index].text.isNotEmpty
                            ? AppColors.primary
                            : AppColors.gray100,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (value) => _onChanged(value, index),
                  onTap: () => setState(() {}),
                ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isFilled && !_submitting) ? _onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.gray200,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _submitting ? '참여 중...' : '참여하기',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: (_isFilled && !_submitting)
                      ? AppColors.white
                      : AppColors.gray400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
