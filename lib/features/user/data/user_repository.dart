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
  Future<NotificationSettings> getNotificationSettings() async {
    final res = await _api.get<Map<String, dynamic>>('/users/me/notification-settings');
    return NotificationSettings.fromJson(res.data!);
  }

  /// 2-4. 알림 설정 수정.
  Future<NotificationSettings> updateNotificationSettings(NotificationSettings settings) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/users/me/notification-settings',
      body: settings.toJson(),
    );
    return NotificationSettings.fromJson(res.data!);
  }

  /// 2-5. 개인정보 설정 조회.
  Future<PrivacySettings> getPrivacySettings() async {
    final res = await _api.get<Map<String, dynamic>>('/users/me/privacy-settings');
    return PrivacySettings.fromJson(res.data!);
  }

  /// 2-6. 개인정보 설정 수정.
  Future<PrivacySettings> updatePrivacySettings(PrivacySettings settings) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/users/me/privacy-settings',
      body: settings.toJson(),
    );
    return PrivacySettings.fromJson(res.data!);
  }
}
