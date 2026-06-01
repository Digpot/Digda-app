import '../../../core/network/api_client.dart';
import '../models/membership_models.dart';

/// 5번 도메인(Membership) 의 4개 엔드포인트를 래핑.
class MembershipRepository {
  MembershipRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 구성원 목록 캐시 — groupRoomId → 멤버 목록. 멤버는 자주 바뀌지 않으므로
  /// 캐시 우선 반환하고, 멤버 변경(내보내기/양도/탈퇴) 시 무효화한다.
  final Map<String, List<Membership>> _cache = {};

  /// 5-1. 구성원 목록. 기본은 캐시 우선(즉시 표시), [forceRefresh] 로 강제 갱신.
  Future<List<Membership>> list(
    String groupRoomId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache[groupRoomId];
      if (cached != null) return cached;
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/memberships',
    );
    final list = (res.data!['memberships'] as List? ?? [])
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache[groupRoomId] = list;
    return list;
  }

  /// 5-2. 구성원 내보내기 (방장).
  Future<void> remove(String groupRoomId, String userId) async {
    await _api.delete<void>('/group-rooms/$groupRoomId/memberships/$userId');
    _cache.remove(groupRoomId);
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
    final list = (res.data!['memberships'] as List? ?? [])
        .map((e) => Membership.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache[groupRoomId] = list;
    return list;
  }

  /// 5-4. 그룹방 탈퇴.
  Future<void> leave(String groupRoomId) async {
    await _api.post<void>('/group-rooms/$groupRoomId/leave');
    _cache.remove(groupRoomId);
  }
}
