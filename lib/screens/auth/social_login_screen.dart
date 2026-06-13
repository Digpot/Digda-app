import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../features/auth/models/auth_models.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../widgets/app_dialog.dart';

class SocialLoginScreen extends StatefulWidget {
  const SocialLoginScreen({super.key});

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen> {
  bool _busy = false;

  Future<void> _signIn(SocialProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await Di.authSession.signIn(provider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (result.isNewUser) {
        // 약관 동의는 다음 단계가 있어 login 위에 push (가입 완료 후 그쪽에서 스택 정리).
        nav.pushReplacementNamed('/terms', arguments: provider.key);
      } else {
        final groups = await Di.groupRoomRepository.myList();
        if (!mounted) return;
        final target = groups.isEmpty ? '/home' : '/group-list';
        nav.pushNamedAndRemoveUntil(target, (_) => false);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    String message = '로그인 중 문제가 발생했습니다.';
    ApiException? api;
    if (e is DioException && e.error is ApiException) {
      api = e.error as ApiException;
    } else if (e is ApiException) {
      api = e;
    }
    if (api != null) message = api.message;

    // 이메일 중복으로 가입이 막힌 경우 전용 안내 — 기존 소셜 계정으로 로그인하도록 유도.
    if (api?.code == 'DUPLICATE_EMAIL') {
      showErrorDialog(
        context,
        '이미 같은 이메일을 사용하는 계정이 있어요.\n기존에 가입했던 소셜 계정으로 로그인해 주세요.',
        title: '이미 가입된 이메일이에요',
      );
      return;
    }
    showErrorDialog(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const Spacer(flex: 2),
                // 스플래시 화면과 동일한 로고·문구 블록.
                SvgPicture.asset(
                  'assets/svg/logo.svg',
                  width: 96,
                  height: 99,
                ),
                const SizedBox(height: 22),
                const Text(
                  '디그팟',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '디지털 그룹 포켓',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                    color: AppColors.gray700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'DIGITAL  GROUP  POCKET',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                    letterSpacing: 3.2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  width: 28,
                  height: 1.2,
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 18),
                Text(
                  '디그팟, 우리만의 일정을 담는 공간',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 1),
                _SocialButton(
                  text: '카카오로 시작하기',
                  backgroundColor: AppColors.kakaoYellow,
                  textColor: AppColors.kakaoText,
                  icon: SvgPicture.asset(
                    'assets/svg/kakao_logo.svg',
                    width: 20,
                    height: 20,
                  ),
                  onPressed: _busy ? null : () => _signIn(SocialProvider.kakao),
                ),
                const SizedBox(height: 12),
                _SocialButton(
                  text: '네이버로 시작하기',
                  backgroundColor: AppColors.naverGreen,
                  textColor: AppColors.white,
                  icon: const Text(
                    'N',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.white,
                    ),
                  ),
                  onPressed: _busy ? null : () => _signIn(SocialProvider.naver),
                ),
                // 안드로이드 전용 빌드라 Apple 로그인 버튼은 비활성화(주석 처리).
                // iOS 배포 시 아래 블록을 다시 살리면 된다.
                // const SizedBox(height: 12),
                // _SocialButton(
                //   text: 'Apple로 시작하기',
                //   backgroundColor: AppColors.appleBlack,
                //   textColor: AppColors.white,
                //   icon: const Icon(Icons.apple, size: 20, color: AppColors.white),
                //   onPressed: _busy ? null : () => _signIn(SocialProvider.apple),
                // ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '로그인 시 ',
                      style: AppTextStyles.captionLarge.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/terms-detail', arguments: 'terms'),
                      child: Text(
                        '이용약관',
                        style: AppTextStyles.captionLarge.copyWith(
                          color: AppColors.gray500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      '과 ',
                      style: AppTextStyles.captionLarge.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/terms-detail', arguments: 'privacy'),
                      child: Text(
                        '개인정보처리방침',
                        style: AppTextStyles.captionLarge.copyWith(
                          color: AppColors.gray500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      '에 동의하게 됩니다',
                      style: AppTextStyles.captionLarge.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 345,
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.21,
                  letterSpacing: 0,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
