import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/user_models.dart';

/// 2번 도메인(User) 의 6개 엔드포인트를 래핑.
class UserRepository {
  UserRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 2-1. 내 프로필 조회.
  Future<UserProfile> me() async {
    final res = await _api.get<Map<String, dynamic>>('/users/me');
    return UserProfile.fromJson(res.data!);
  }

  /// 2-2. 프로필 수정.
  Future<UserProfile> updateMe(UpdateProfileRequest body) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/users/me',
      body: body.toJson(),
    );
    return UserProfile.fromJson(res.data!);
  }

  /// 2-3. 알림 설정 조회.
  ///
  /// 서버 엔드포인트 미구현(404) 시 화면이 통째로 막히지 않도록 기본값으로 폴백.
  /// 저장(updateNotificationSettings) 은 그대로 실패하므로 호출자가 토스트로 안내.
  Future<NotificationSettings> getNotificationSettings() async {
    try {
      final res =
          await _api.get<Map<String, dynamic>>('/users/me/notification-settings');
      return NotificationSettings.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return _defaultNotificationSettings();
      }
      rethrow;
    }
  }

  /// 2-4. 알림 설정 수정.
  Future<NotificationSettings> updateNotificationSettings(
      NotificationSettings settings) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/users/me/notification-settings',
      body: settings.toJson(),
    );
    return NotificationSettings.fromJson(res.data!);
  }

  /// 2-5. 개인정보 설정 조회. 404 폴백 — getNotificationSettings 와 동일 정책.
  Future<PrivacySettings> getPrivacySettings() async {
    try {
      final res =
          await _api.get<Map<String, dynamic>>('/users/me/privacy-settings');
      return PrivacySettings.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return _defaultPrivacySettings();
      }
      rethrow;
    }
  }

  /// 2-6. 개인정보 설정 수정.
  Future<PrivacySettings> updatePrivacySettings(
      PrivacySettings settings) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/users/me/privacy-settings',
      body: settings.toJson(),
    );
    return PrivacySettings.fromJson(res.data!);
  }

  NotificationSettings _defaultNotificationSettings() => NotificationSettings(
        pushEnabled: true,
        scheduleNotification: true,
        diaryNotification: true,
        commentNotification: true,
        marketingConsent: false,
      );

  PrivacySettings _defaultPrivacySettings() => PrivacySettings(
        profilePublic: true,
        activityVisible: true,
      );
}
