import 'package:flutter/services.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/network/api_exception.dart';
import '../models/auth_models.dart';

/// 카카오/네이버/애플 SDK 호출을 [SocialCredential] 로 통일하는 어댑터.
class SocialAuthService {
  Future<SocialCredential> sign(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.kakao:
        return _signInKakao();
      case SocialProvider.naver:
        return _signInNaver();
      case SocialProvider.apple:
        return _signInApple();
    }
  }

  Future<void> signOut(SocialProvider provider) async {
    switch (provider) {
      case SocialProvider.kakao:
        await kakao.UserApi.instance.logout();
        break;
      case SocialProvider.naver:
        await FlutterNaverLogin.logOutAndDeleteToken();
        break;
      case SocialProvider.apple:
        // Apple 은 명시적 로그아웃 API 가 없음 (서버 토큰 invalidate 만 수행).
        break;
    }
  }

  Future<SocialCredential> _signInKakao() async {
    // 카카오톡이 설치돼 있으면 앱-투-앱 로그인을 먼저 시도하고, 실패하면 카카오
    // 계정(웹) 로그인으로 폴백한다. 예전엔 KakaoAuthException/KakaoClientException
    // 만 폴백 대상으로 잡았는데, 카카오톡이 설치는 됐지만 로그인이 안 되는 단말
    // (구버전 카카오톡·톡 미로그인·앱 키해시 미등록·앱 연결 실패 등)에선
    // PlatformException 이 던져져 폴백에 걸리지 않고 그대로 실패했다. 이 때문에
    // "어떤 폰에서는 되고 어떤 폰에서는 안 되는" 문제가 생겼다. 이제 사용자가
    // 직접 '취소'한 경우를 제외한 모든 톡 로그인 실패를 계정 로그인으로 흡수한다.
    final installed = await kakao.isKakaoTalkInstalled();
    if (installed) {
      try {
        final token = await kakao.UserApi.instance.loginWithKakaoTalk();
        return _kakaoCredential(token);
      } catch (e) {
        // 사용자가 카카오톡 로그인 화면에서 직접 '취소'를 누른 경우엔 계정
        // 로그인으로 자동 재진입하지 않고 취소로 둔다.
        if (e is PlatformException && e.code == 'CANCELED') {
          rethrow;
        }
        // 그 외 모든 실패는 카카오 계정(웹) 로그인으로 폴백한다.
        final token = await kakao.UserApi.instance.loginWithKakaoAccount();
        return _kakaoCredential(token);
      }
    }
    final token = await kakao.UserApi.instance.loginWithKakaoAccount();
    return _kakaoCredential(token);
  }

  SocialCredential _kakaoCredential(kakao.OAuthToken token) => SocialCredential(
        provider: SocialProvider.kakao,
        accessToken: token.accessToken,
      );

  Future<SocialCredential> _signInNaver() async {
    try {
      final result = await FlutterNaverLogin.logIn();
      if (result.status != NaverLoginStatus.loggedIn) {
        final isCancel = result.status == NaverLoginStatus.loggedOut;
        // SDK 가 돌려준 errorMessage 가 있으면 그대로 노출해 디버깅 가능하게 한다.
        // (errorCode:xxx, errorDesc:xxx 형태로 들어옴)
        final reason = result.errorMessage;
        final fallback = isCancel
            ? '네이버 로그인이 취소되었습니다'
            : '네이버 로그인에 실패했습니다.';
        throw ApiException(
          statusCode: 0,
          code: isCancel ? 'SOCIAL_LOGIN_CANCELLED' : 'SOCIAL_LOGIN_FAILED',
          message: (reason == null || reason.isEmpty)
              ? fallback
              : '$fallback ($reason)',
        );
      }
      // 로그인 성공 후 토큰 획득 — 실패 시 재시도 1회.
      var token = await FlutterNaverLogin.getCurrentAccessToken();
      if (token.accessToken.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        token = await FlutterNaverLogin.getCurrentAccessToken();
      }
      if (token.accessToken.isEmpty) {
        throw ApiException(
          statusCode: 0,
          code: 'SOCIAL_LOGIN_FAILED',
          message: '네이버 액세스 토큰을 받지 못했습니다',
        );
      }
      return SocialCredential(
        provider: SocialProvider.naver,
        accessToken: token.accessToken,
      );
    } on ApiException {
      rethrow;
    } on PlatformException catch (e) {
      throw ApiException(
        statusCode: 0,
        code: 'SOCIAL_LOGIN_FAILED',
        message: '네이버 로그인에 실패했습니다: ${e.message ?? e.code}',
      );
    }
  }

  Future<SocialCredential> _signInApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final identity = credential.identityToken;
    final auth = credential.authorizationCode;
    if (identity == null) {
      throw ApiException(
        statusCode: 0,
        code: 'SOCIAL_LOGIN_FAILED',
        message: 'Apple 로그인 토큰을 받아오지 못했습니다',
      );
    }
    return SocialCredential(
      provider: SocialProvider.apple,
      accessToken: auth,
      idToken: identity,
    );
  }
}
