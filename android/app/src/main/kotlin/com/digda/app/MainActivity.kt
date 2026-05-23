package com.digda.app

import android.os.Bundle
import com.navercorp.nid.NaverIdLoginSDK
import com.navercorp.nid.oauth.NidOAuthBehavior
import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_naver_login 2.x 는 onAttachedToActivity 에서 activity 를 FlutterFragmentActivity
// 로 캐스팅해 ActivityResultLauncher 를 등록한다. 기본 FlutterActivity 로 두면 즉시
// ClassCastException 이 발생해 네이버 로그인 자체가 동작하지 않는다.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 네이버 앱 SSO 는 기기에 따라 no_catagorized_error 를 반환한다.
        // CUSTOMTABS 로 고정해 항상 브라우저 기반 OAuth 로 처리한다.
        try {
            NaverIdLoginSDK.INSTANCE.setBehavior(NidOAuthBehavior.CUSTOMTABS)
        } catch (_: Exception) {}
    }
}
