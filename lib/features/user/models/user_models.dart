/// `/users/me` 응답 = `AuthUser` 와 동일 스키마지만 User 도메인 전용 객체로 분리.
class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.profileImage,
    this.statusMessage,
    required this.provider,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? profileImage;
  final String? statusMessage;
  final String provider;
  final DateTime? createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      profileImage: json['profileImage'] as String?,
      statusMessage: json['statusMessage'] as String?,
      provider: json['provider'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? profileImage,
    String? statusMessage,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      statusMessage: statusMessage ?? this.statusMessage,
      provider: provider,
      createdAt: createdAt,
    );
  }
}

/// `PUT /users/me` 요청 — null 명시 의도와 누락(미수정) 의도를 분리하기 위한 sentinel.
class UpdateProfileRequest {
  const UpdateProfileRequest({
    this.name,
    this.statusMessage = unset,
    this.profileImageId = unset,
  });

  final String? name;
  final Object? statusMessage; // null=삭제, unset=변경 없음
  final Object? profileImageId; // null=기본 아바타, unset=변경 없음

  /// "변경 없음" 의도 sentinel. 외부에서도 동일한 인스턴스를 사용하도록 노출.
  static const Object unset = Object();

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (!identical(statusMessage, unset)) body['statusMessage'] = statusMessage;
    if (!identical(profileImageId, unset)) body['profileImageId'] = profileImageId;
    return body;
  }
}

/// 알림 설정.
class NotificationSettings {
  NotificationSettings({
    required this.pushEnabled,
    required this.scheduleNotification,
    required this.diaryNotification,
    required this.commentNotification,
    required this.marketingConsent,
  });

  final bool pushEnabled;
  final bool scheduleNotification;
  final bool diaryNotification;
  final bool commentNotification;
  final bool marketingConsent;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      scheduleNotification: json['scheduleNotification'] as bool? ?? true,
      diaryNotification: json['diaryNotification'] as bool? ?? true,
      commentNotification: json['commentNotification'] as bool? ?? true,
      marketingConsent: json['marketingConsent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'scheduleNotification': scheduleNotification,
        'diaryNotification': diaryNotification,
        'commentNotification': commentNotification,
        'marketingConsent': marketingConsent,
      };

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? scheduleNotification,
    bool? diaryNotification,
    bool? commentNotification,
    bool? marketingConsent,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      scheduleNotification: scheduleNotification ?? this.scheduleNotification,
      diaryNotification: diaryNotification ?? this.diaryNotification,
      commentNotification: commentNotification ?? this.commentNotification,
      marketingConsent: marketingConsent ?? this.marketingConsent,
    );
  }
}

/// 개인정보 설정.
class PrivacySettings {
  PrivacySettings({
    required this.profilePublic,
    required this.activityVisible,
  });

  final bool profilePublic;
  final bool activityVisible;

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      profilePublic: json['profilePublic'] as bool? ?? true,
      activityVisible: json['activityVisible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'profilePublic': profilePublic,
        'activityVisible': activityVisible,
      };

  PrivacySettings copyWith({bool? profilePublic, bool? activityVisible}) {
    return PrivacySettings(
      profilePublic: profilePublic ?? this.profilePublic,
      activityVisible: activityVisible ?? this.activityVisible,
    );
  }
}
