import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import 'app.dart';
import 'core/config/env.dart';
import 'core/di.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Env.load();
  kakao.KakaoSdk.init(
    nativeAppKey: Env.kakaoNativeAppKey,
    javaScriptAppKey: Env.kakaoJavaScriptAppKey,
  );
  // flutter_naver_login 2.x: 설정은 AndroidManifest meta-data 로 수행 (com.naver.sdk.clientId 등).
  Di.bootstrap();
  await Di.authSession.hydrate();
  runApp(const DigdaApp());
}
