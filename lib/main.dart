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
  await Di.authSession.hydrate();
  // 자동 로그인 상태면 FCM 디바이스 토큰을 다시 등록한다(푸시 유실 방지).
  // UI 블로킹을 피하려 await 하지 않고 백그라운드로 진행.
  Di.authSession.ensureDeviceRegistered();
  runApp(const DigdaApp());
  // 광고 SDK 초기화는 네트워크 핸드셰이크로 수백 ms~수초가 걸려 첫 프레임을 늦출 수
  // 있어, runApp 이후 백그라운드로 돌린다(실패해도 내부 try/catch 로 부팅 영향 없음).
  unawaited(AdService.init());
}
