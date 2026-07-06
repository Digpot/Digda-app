import '../../../core/network/api_client.dart';
import '../models/invite_models.dart';

/// 4번 도메인(Invite) 의 3개 엔드포인트를 래핑.
class InviteRepository {
  InviteRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 4-1. 초대 코드 재발급 (방장).
  Future<InviteCode> regenerate(String groupRoomId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/invites',
    );
    return InviteCode.fromJson(res.data!);
  }

  /// 4-2. 초대 코드 검증.
  Future<InvitePreview> validate(String code) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/invites/validate',
      body: {'code': code},
    );
    return InvitePreview.fromJson(res.data!);
  }

  /// 4-3. 초대 코드로 참여.
  Future<JoinResult> join(String code) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/invites/join',
      body: {'code': code},
    );
    return JoinResult.fromJson(res.data!);
  }
}
