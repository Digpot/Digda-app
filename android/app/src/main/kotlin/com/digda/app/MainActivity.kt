package com.digda.app

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_naver_login 2.x 는 onAttachedToActivity 에서 activity 를 FlutterFragmentActivity
// 로 캐스팅해 ActivityResultLauncher 를 등록한다. 기본 FlutterActivity 로 두면 즉시
// ClassCastException 이 발생해 네이버 로그인 자체가 동작하지 않는다.
class MainActivity : FlutterFragmentActivity()
