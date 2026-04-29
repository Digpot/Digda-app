import '../../../core/network/api_client.dart';
import '../models/membership_models.dart';

/// 5번 도메인(Membership) 의 4개 엔드포인트를 래핑.
class MembershipRepository {
  MembershipRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 5-1. 구성원 목록.
  Future<List<Membership>> list(String groupRoomId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/memberships',
    );
    return (res.data!['memberships'] as List? ?? [])
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 5-2. 구성원 내보내기 (방장).
  Future<void> remove(String groupRoomId, String userId) async {
    await _api.delete<void>('/group-rooms/$groupRoomId/memberships/$userId');
  }

  /// 5-3. 방장 양도.
  Future<List<Membership>> transferOwner(
    String groupRoomId,
    String userId,
  ) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/memberships/$userId/role',
      body: {'role': 'owner'},
    );
    return (res.data!['memberships'] as List? ?? [])
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 5-4. 그룹방 탈퇴.
  Future<void> leave(String groupRoomId) async {
    await _api.post<void>('/group-rooms/$groupRoomId/leave');
  }
}
