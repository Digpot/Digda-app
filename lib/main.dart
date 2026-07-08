import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/config/env.dart';
import 'core/di.dart';
import 'core/push_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // iOS 흰 화면 방지 원칙: 첫 프레임(runApp)을 막을 수 있는 작업을 runApp 앞에
  // 두지 않는다. 특히 Firebase.initializeApp 은 iOS 네이티브가 아직 준비 전이면
  // 던지거나 '지연(hang)'될 수 있는데, 이를 await 하면 스플래시조차 못 그려 흰
  // 화면이 된다. 그래서 Firebase/푸시/광고는 runApp '이후' 백그라운드로 미룬다.
  // runApp 전에는 화면 구동에 꼭 필요한 것(.env, DI, 세션 복원)만, 그마저도 각각
  // 감싸 실패해도 스플래시는 무조건 뜨게 한다.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 프레임워크 레벨 예외를 흰 화면 대신 로그로 남긴다.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[main] FlutterError: ${details.exception}');
    };

    // 환경변수: 실패해도 각 getter 가 기본값으로 폴백하므로 진행 가능.
    try {
      await Env.load();
    } catch (e) {
      debugPrint('[main] .env 로드 실패(무시하고 진행): $e');
    }

    // 카카오 SDK 는 Env 만 필요(Firebase 무관) — 로그인 화면 전에 준비돼야 하므로 유지.
    kakao.KakaoSdk.init(
      nativeAppKey: Env.kakaoNativeAppKey,
      javaScriptAppKey: Env.kakaoJavaScriptAppKey,
    );

    // DI 는 화면들이 즉시 참조하므로 부팅에 필수(동기·비throw). 세션 복원은
    // 실패해도 로그인 화면부터 시작하면 되므로 감싼다.
    Di.bootstrap();
    try {
      await Di.authSession.hydrate();
    } catch (e) {
      debugPrint('[main] 세션 복원 실패(무시, 로그인부터 시작): $e');
    }

    // 여기서 즉시 첫 프레임(스플래시)을 띄운다. 아래 무거운 초기화는 절대
    // 이 지점을 막지 못한다 = iOS 흰 화면 원천 차단.
    runApp(const DigdaApp());

    // Firebase/FCM: 실패·지연이 첫 프레임에 영향 없도록 runApp 이후 백그라운드로.
    unawaited(_initFirebaseAndPush());
    // 광고 SDK 초기화도 네트워크 핸드셰이크로 수 초가 걸려 백그라운드로 돌린다.
    unawaited(AdService.init());
  }, (error, stack) {
    // 초기화 경로에서 새어 나온 비동기 예외도 흰 화면 대신 로그로 남긴다.
    debugPrint('[main] 부팅 존 미처리 예외: $error\n$stack');
  });
}

/// Firebase 초기화 + FCM 푸시 설정 + (자동 로그인 시) 디바이스 토큰 재등록.
/// 첫 프레임 이후 백그라운드로 실행돼, 이 경로가 실패/지연해도 앱 화면은 이미 떠 있다.
Future<void> _initFirebaseAndPush() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    await PushService.init();
    // Firebase 준비가 끝난 뒤에 FCM 디바이스 토큰을 재등록한다(푸시 유실 방지).
    Di.authSession.ensureDeviceRegistered();
  } catch (e) {
    debugPrint('[main] Firebase/푸시 초기화 실패(무시, 앱은 정상 동작): $e');
  }
}
