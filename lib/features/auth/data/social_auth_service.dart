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
    try {
      final installed = await kakao.isKakaoTalkInstalled();
      final token = installed
          ? await kakao.UserApi.instance.loginWithKakaoTalk()
          : await kakao.UserApi.instance.loginWithKakaoAccount();
      return SocialCredential(
        provider: SocialProvider.kakao,
        accessToken: token.accessToken,
      );
    } catch (e) {
      // KakaoTalk 사용자가 취소했을 때 fallback for 카카오 계정.
      if (e is kakao.KakaoAuthException || e is kakao.KakaoClientException) {
        try {
          final token = await kakao.UserApi.instance.loginWithKakaoAccount();
          return SocialCredential(
            provider: SocialProvider.kakao,
            accessToken: token.accessToken,
          );
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<SocialCredential> _signInNaver() async {
    try {
      final result = await FlutterNaverLogin.logIn();
      if (result.status != NaverLoginStatus.loggedIn) {
        final isCancel = result.status == NaverLoginStatus.loggedOut;
        throw ApiException(
          statusCode: 0,
          code: isCancel ? 'SOCIAL_LOGIN_CANCELLED' : 'SOCIAL_LOGIN_FAILED',
          message: isCancel ? '네이버 로그인이 취소되었습니다' : '네이버 로그인에 실패했습니다. 잠시 후 다시 시도해주세요.',
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
