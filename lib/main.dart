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
  // 부팅 초기화 중 무엇이 던지더라도 runApp 에는 반드시 도달해야 한다. 어느 한
  // await 가 예외로 새면 첫 프레임이 안 그려져 iOS 에서 흰 화면이 되기 때문이다.
  // 그래서 실패해도 앱 사용에 치명적이지 않은 단계(Firebase/푸시/세션복원/광고)는
  // 각각 감싸 로그만 남기고 진행한다.
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

    // Firebase / 푸시: 실패해도 앱은 떠야 한다(푸시만 비활성으로 저하).
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      await PushService.init();
    } catch (e) {
      debugPrint('[main] Firebase/푸시 초기화 실패(무시하고 진행): $e');
    }

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
    // 자동 로그인 상태면 FCM 디바이스 토큰을 다시 등록한다(푸시 유실 방지).
    // UI 블로킹을 피하려 await 하지 않고 백그라운드로 진행.
    Di.authSession.ensureDeviceRegistered();

    runApp(const DigdaApp());

    // 광고 SDK 초기화는 네트워크 핸드셰이크로 수백 ms~수초가 걸려 첫 프레임을 늦출 수
    // 있어, runApp 이후 백그라운드로 돌린다(실패해도 내부 try/catch 로 부팅 영향 없음).
    unawaited(AdService.init());
  }, (error, stack) {
    // 초기화 경로에서 새어 나온 비동기 예외도 흰 화면 대신 로그로 남긴다.
    debugPrint('[main] 부팅 존 미처리 예외: $error\n$stack');
  });
}
