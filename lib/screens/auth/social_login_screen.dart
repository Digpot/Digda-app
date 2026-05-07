import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../features/auth/models/auth_models.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';

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
      if (result.isNewUser) {
        Navigator.of(context).pushReplacementNamed('/terms', arguments: provider.key);
      } else {
        final groups = await Di.groupRoomRepository.myList();
        if (!mounted) return;
        if (groups.isEmpty) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/group-list');
        }
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
    if (e is DioException && e.error is ApiException) {
      message = (e.error as ApiException).message;
    } else if (e is ApiException) {
      message = e.message;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                SvgPicture.asset(
                  'assets/svg/logo.svg',
                  width: 48,
                  height: 50,
                ),
                const SizedBox(height: 20),
                const Text(
                  '디지털 그룹 다이어리',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '소셜 계정으로 3초만에 시작하세요',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.gray500,
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
                const SizedBox(height: 12),
                _SocialButton(
                  text: 'Apple로 시작하기',
                  backgroundColor: AppColors.appleBlack,
                  textColor: AppColors.white,
                  icon: const Icon(Icons.apple, size: 20, color: AppColors.white),
                  onPressed: _busy ? null : () => _signIn(SocialProvider.apple),
                ),
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
