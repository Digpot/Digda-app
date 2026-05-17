import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../features/user/models/user_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 개인정보 관리 화면은 계정 정보 + 로그아웃/탈퇴가 본질이므로 /users/me 만 호출.
      // (공개 설정 토글은 서버 도메인이 정착되기 전까지 화면에서 제외)
      final me = await Di.userSession.refresh();
      if (!mounted) return;
      setState(() => _profile = me);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageOf(e, '정보를 불러오지 못했습니다.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageOf(Object e, String fallback) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).message;
    }
    if (e is ApiException) return e.message;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '개인정보 관리',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: const TextStyle(color: AppColors.gray700, fontSize: 14)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    final profile = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(profile),
          const SizedBox(height: 24),
          _sectionLabel('기본 정보'),
          const SizedBox(height: 10),
          _basicInfoCard(profile),
          const SizedBox(height: 24),
          _sectionLabel('계정 관리'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _actionRow(
                  icon: Icons.logout_outlined,
                  iconColor: AppColors.gray700,
                  label: '로그아웃',
                  onTap: () => _showLogoutDialog(context),
                ),
                const Divider(
                    color: AppColors.gray100, height: 1, indent: 52, endIndent: 16),
                _actionRow(
                  icon: Icons.delete_outline,
                  iconColor: AppColors.primaryDark,
                  label: '회원 탈퇴',
                  labelColor: AppColors.primaryDark,
                  onTap: () => Navigator.of(context).pushNamed('/delete-account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              '탈퇴 시 모든 데이터가 삭제되며 복구할 수 없습니다.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: AppColors.gray400,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile) {
    final initial = profile.name.isNotEmpty ? profile.name[0] : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9A9E), Color(0xFFFF6B6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: profile.profileImage != null && profile.profileImage!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        profile.profileImage!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _initialAvatar(initial),
                      ),
                    )
                  : _initialAvatar(initial),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email ?? '-',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 12),
          _providerBadge(profile.provider),
        ],
      ),
    );
  }

  Widget _initialAvatar(String initial) => Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 28,
          color: AppColors.white,
        ),
      );

  Widget _providerBadge(String provider) {
    final (label, bg, fg) = switch (provider) {
      'naver' => ('네이버 로그인', AppColors.naverGreen, AppColors.white),
      'apple' => ('Apple 로그인', AppColors.appleBlack, AppColors.white),
      'admin' => ('관리자 계정', AppColors.gray700, AppColors.white),
      _ => ('카카오 로그인', AppColors.kakaoYellow, AppColors.kakaoText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: fg,
        ),
      ),
    );
  }

  Widget _basicInfoCard(UserProfile profile) {
    final joined = profile.createdAt;
    final joinedText = joined != null
        ? '${joined.year}.${joined.month.toString().padLeft(2, '0')}.${joined.day.toString().padLeft(2, '0')}'
        : '-';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.person_outline,
            iconColor: AppColors.blue,
            label: '이름',
            value: profile.name,
          ),
          const Divider(color: AppColors.gray100, height: 1, indent: 52, endIndent: 16),
          _infoRow(
            icon: Icons.email_outlined,
            iconColor: AppColors.green,
            label: '이메일',
            value: profile.email ?? '-',
          ),
          const Divider(color: AppColors.gray100, height: 1, indent: 52, endIndent: 16),
          _infoRow(
            icon: Icons.calendar_today_outlined,
            iconColor: AppColors.purple,
            label: '가입일',
            value: joinedText,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.gray500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: labelColor ?? AppColors.gray900,
                ),
              ),
            ),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '로그아웃',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '정말 로그아웃 하시겠어요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final navigator = Navigator.of(context);
              try {
                await Di.authSession.signOut();
                Di.userSession.clear();
                navigator.pushNamedAndRemoveUntil('/login', (_) => false);
              } catch (_) {
                if (mounted) {
                  showErrorDialog(context, '로그아웃에 실패했습니다. 다시 시도해주세요.');
                }
              }
            },
            child: const Text(
              '로그아웃',
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
}
