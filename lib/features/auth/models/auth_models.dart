/// 소셜 로그인 프로바이더 (서버 enum 과 동일 키).
enum SocialProvider {
  kakao,
  naver,
  apple;

  String get key {
    switch (this) {
      case SocialProvider.kakao:
        return 'kakao';
      case SocialProvider.naver:
        return 'naver';
      case SocialProvider.apple:
        return 'apple';
    }
  }

  static SocialProvider fromKey(String value) {
    switch (value.toLowerCase()) {
      case 'kakao':
        return SocialProvider.kakao;
      case 'naver':
        return SocialProvider.naver;
      case 'apple':
        return SocialProvider.apple;
      default:
        throw ArgumentError('Unknown provider: $value');
    }
  }
}

/// `/auth/login` 응답에 포함되는 사용자 정보 (= `/users/me` 와 동일 스키마).
class AuthUser {
  AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.profileImage,
    required this.provider,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? profileImage;
  final String provider;
  final DateTime? createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      profileImage: json['profileImage'] as String?,
      provider: json['provider'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// `/auth/login` 응답.
class LoginResult {
  LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.isNewUser,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final bool isNewUser;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: AuthUser.fromJson((json['user'] as Map).cast<String, dynamic>()),
      isNewUser: json['isNewUser'] as bool? ?? false,
    );
  }
}

/// `POST /auth/terms` 요청.
class TermsAgreement {
  TermsAgreement({
    required this.termsOfService,
    required this.privacyPolicy,
    required this.ageConfirmation,
    this.marketingConsent = false,
    this.pushConsent = false,
  });

  final bool termsOfService;
  final bool privacyPolicy;
  final bool ageConfirmation;
  final bool marketingConsent;
  final bool pushConsent;

  Map<String, dynamic> toJson() => {
        'termsOfService': termsOfService,
        'privacyPolicy': privacyPolicy,
        'ageConfirmation': ageConfirmation,
        'marketingConsent': marketingConsent,
        'pushConsent': pushConsent,
      };
}

/// 소셜 SDK 에서 받아온 토큰 묶음 (앱 → 서버 전달용).
class SocialCredential {
  SocialCredential({
    required this.provider,
    required this.accessToken,
    this.idToken,
  });

  final SocialProvider provider;
  final String accessToken;
  final String? idToken;
}
