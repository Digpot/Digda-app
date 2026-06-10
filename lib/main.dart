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
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  await PushService.init();
  await Env.load();
  kakao.KakaoSdk.init(
    nativeAppKey: Env.kakaoNativeAppKey,
    javaScriptAppKey: Env.kakaoJavaScriptAppKey,
  );
  Di.bootstrap();
  // 광고 SDK 초기화 — 실패해도 앱 부팅을 막지 않는다(내부에서 try/catch).
  await AdService.init();
  await Di.authSession.hydrate();
  // 자동 로그인 상태면 FCM 디바이스 토큰을 다시 등록한다(푸시 유실 방지).
  // UI 블로킹을 피하려 await 하지 않고 백그라운드로 진행.
  Di.authSession.ensureDeviceRegistered();
  runApp(const DigdaApp());
}
