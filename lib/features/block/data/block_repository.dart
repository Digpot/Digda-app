import '../../../core/network/api_client.dart';
import '../models/block_models.dart';

/// 차단/숨김 API 래퍼.
/// - 사용자 차단: POST/DELETE /blocks/users/{userId}, GET /blocks/users
/// - 개별 숨김:   POST/DELETE /blocks/content
class BlockRepository {
  BlockRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<void> blockUser(String userId) async {
    await _api.post<void>('/blocks/users/$userId');
  }

  Future<void> unblockUser(String userId) async {
    await _api.delete<void>('/blocks/users/$userId');
  }

  Future<List<BlockedUser>> listBlockedUsers() async {
    final res = await _api.get<List<dynamic>>('/blocks/users');
    return (res.data ?? const [])
        .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> hideContent(HideTargetType targetType, String targetId) async {
    await _api.post<void>(
      '/blocks/content',
      body: {'targetType': targetType.wire, 'targetId': int.tryParse(targetId)},
    );
  }

  Future<void> unhideContent(HideTargetType targetType, String targetId) async {
    await _api.delete<void>(
      '/blocks/content',
      body: {'targetType': targetType.wire, 'targetId': int.tryParse(targetId)},
    );
  }
}
