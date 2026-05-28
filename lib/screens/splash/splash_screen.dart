import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/di.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  Future<void> _decideRoute() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 1200));
    String nextRoute = '/login';

    if (Di.authSession.isAuthenticated) {
      // 저장된 토큰으로 사용자 정보를 받아 자동 로그인.
      // 실패하면 토큰이 만료/무효 → 로그인 화면으로 이동.
      try {
        await Di.userSession.refresh();
        try {
          final groups = await Di.groupRoomRepository.myList();
          nextRoute = groups.isEmpty ? '/home' : '/group-list';
        } catch (_) {
          nextRoute = '/home';
        }
      } catch (e) {
        final isAuthFailure = e is DioException &&
            (e.response?.statusCode == 401 || e.response?.statusCode == 403);
        if (isAuthFailure) {
          await Di.apiClient.clearSession();
        }
        nextRoute = '/login';
      }
    }

    await minDelay;
    if (!mounted) return;
    // pushNamedAndRemoveUntil 로 splash/login 을 백스택에서 제거 → 앱 사용 중 뒤로가기로
    // 로그인 화면이 다시 노출되는 문제를 차단.
    Navigator.of(context).pushNamedAndRemoveUntil(nextRoute, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.white, Color(0xFFFFF8F8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  '디그팟, 우리만의 일정을 담다',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 44),
                const _LoadingDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
          child: AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animations[index].value),
                child: child,
              );
            },
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }),
    );
  }
}
