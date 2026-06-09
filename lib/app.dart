import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_router.dart';
import 'core/di.dart';
import 'core/route_observer.dart';
import 'features/title/widgets/title_earned_dialog.dart';
import 'theme/colors.dart';

class DigdaApp extends StatefulWidget {
  const DigdaApp({super.key});

  @override
  State<DigdaApp> createState() => _DigdaAppState();
}

class _DigdaAppState extends State<DigdaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLink();
    Di.authSession.addListener(_onAuthChanged);
    Di.titleRepository.newlyEarned.addListener(_onNewTitle);
    if (Di.authSession.isAuthenticated) _primeTitles();
  }

  @override
  void dispose() {
    Di.authSession.removeListener(_onAuthChanged);
    Di.titleRepository.newlyEarned.removeListener(_onNewTitle);
    _linkSub?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!Di.authSession.isAuthenticated) {
      // 세션 만료 → 스택 전체 제거 후 로그인 화면으로 이동
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
    } else {
      // 로그인 직후 — 현재 보유 칭호로 기준선을 잡아 이후 획득만 축하한다.
      _primeTitles();
    }
  }

  /// 기준선 설정 — 최초 list() 는 기존 칭호를 축하 없이 흡수한다.
  void _primeTitles() {
    Di.titleRepository.list().then((_) {}, onError: (_) {});
  }

  /// 새로 획득한 칭호가 생기면 축하 팝업을 순차적으로 띄운다.
  void _onNewTitle() {
    if (_celebrating) return;
    final queue = Di.titleRepository.newlyEarned.value;
    if (queue.isEmpty) return;
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    _celebrating = true;
    showTitleEarnedDialog(ctx, queue.first).whenComplete(() {
      _celebrating = false;
      Di.titleRepository.popNewlyEarned(); // 다음 것이 있으면 리스너 재발화
    });
  }

  Future<void> _initDeepLink() async {
    // 앱이 종료 상태에서 딥링크로 시작된 경우
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleDeepLink(initialUri);
        });
      }
    } catch (_) {}

    // 앱이 실행 중일 때 딥링크 수신
    _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    // digda://invite?code=A3X9K2
    if (uri.scheme == 'digda' && uri.host == 'invite') {
      final code = uri.queryParameters['code'];
      if (code != null && code.length == 6) {
        _navigatorKey.currentState?.pushNamed('/code-input', arguments: code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [appRouteObserver],
      title: '디그팟',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Inter',
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.gray900,
        ),
        scaffoldBackgroundColor: AppColors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.gray900),
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
