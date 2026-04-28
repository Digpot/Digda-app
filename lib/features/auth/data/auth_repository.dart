import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';
import 'social_auth_service.dart';

/// 1번 도메인(Auth) 의 6개 엔드포인트를 래핑한다.
class AuthRepository {
  AuthRepository({required ApiClient apiClient, required SocialAuthService socialAuth})
      : _api = apiClient,
        _social = socialAuth;

  final ApiClient _api;
  final SocialAuthService _social;

  /// 1-1. 소셜 로그인 → JWT 발급 + 보안 저장소에 저장.
  Future<LoginResult> signInWith(SocialProvider provider) async {
    final cred = await _social.sign(provider);
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {
        'provider': cred.provider.key,
        'accessToken': cred.accessToken,
        if (cred.idToken != null) 'idToken': cred.idToken,
      },
      options: Options(extra: {'skipAuth': true}),
    );
    final result = LoginResult.fromJson(res.data!);
    await _api.setSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  /// 1-2. 약관 동의 (신규 가입자).
  Future<void> agreeTerms(TermsAgreement agreement) async {
    await _api.post<void>('/auth/terms', body: agreement.toJson());
  }

  /// 1-3. 약관 본문 조회.
  Future<TermsDocument> fetchTerms(TermsType type) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/auth/terms/${type.path}',
      options: Options(extra: {'skipAuth': true}),
    );
    return TermsDocument.fromJson(res.data!);
  }

  /// 1-5. 로그아웃 + 로컬 토큰 정리.
  Future<void> signOut({SocialProvider? provider}) async {
    try {
      await _api.post<void>('/auth/logout');
    } finally {
      if (provider != null) {
        try {
          await _social.signOut(provider);
        } catch (_) {}
      }
      await _api.clearSession();
    }
  }

  /// 1-6. 회원 탈퇴.
  Future<void> deleteAccount() async {
    await _api.delete<void>('/auth/account');
    await _api.clearSession();
  }
}

enum TermsType {
  termsOfService,
  privacyPolicy,
  marketing;

  String get path {
    switch (this) {
      case TermsType.termsOfService:
        return 'terms-of-service';
      case TermsType.privacyPolicy:
        return 'privacy-policy';
      case TermsType.marketing:
        return 'marketing';
    }
  }

  static TermsType fromKey(String key) {
    switch (key) {
      case 'terms':
      case 'terms-of-service':
        return TermsType.termsOfService;
      case 'privacy':
      case 'privacy-policy':
        return TermsType.privacyPolicy;
      case 'marketing':
        return TermsType.marketing;
      default:
        return TermsType.termsOfService;
    }
  }
}

class TermsDocument {
  TermsDocument({
    required this.title,
    required this.content,
    required this.version,
    required this.updatedAt,
  });

  final String title;
  final String content;
  final String version;
  final String updatedAt;

  factory TermsDocument.fromJson(Map<String, dynamic> json) {
    return TermsDocument(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      version: json['version'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
