import '../../../core/network/api_client.dart';
import '../models/notification_models.dart';

/// 10번 도메인(Notification) 의 4개 엔드포인트를 래핑.
class NotificationRepository {
  NotificationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 10-1. 알림 목록.
  Future<NotificationListResult> list({int? limit, int? offset}) async {
    final query = <String, dynamic>{};
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;
    final res = await _api.get<Map<String, dynamic>>(
      '/notifications',
      query: query.isEmpty ? null : query,
    );
    return NotificationListResult.fromJson(res.data!);
  }

  /// 10-2. 단건 읽음 처리.
  ///
  /// POST `/notifications/{id}/read` 규약 (전체 읽음과 동일한 동사·경로 구조).
  Future<void> markRead(String notificationId) async {
    await _api.post<void>('/notifications/$notificationId/read');
  }

  /// 10-3. 전체 읽음 처리.
  Future<void> markAllRead() async {
    await _api.post<void>('/notifications/read-all');
  }

  /// 10-4. 알림 삭제.
  Future<void> delete(String notificationId) async {
    await _api.delete<void>('/notifications/$notificationId');
  }
}
