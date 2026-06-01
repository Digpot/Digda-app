import '../../../core/network/api_client.dart';
import '../models/group_room_models.dart';

/// 3번 도메인(GroupRoom) 의 6개 엔드포인트를 래핑.
class GroupRoomRepository {
  GroupRoomRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 3-1. 그룹방 생성.
  Future<CreateGroupRoomResult> create(CreateGroupRoomRequest body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms',
      body: body.toJson(),
    );
    return CreateGroupRoomResult.fromJson(res.data!);
  }

  /// 3-2. 내 그룹방 목록.
  Future<List<GroupRoomListItem>> myList() async {
    final res = await _api.get<Map<String, dynamic>>('/group-rooms');
    final list = (res.data!['groupRooms'] as List? ?? []);
    return list
        .map((e) => GroupRoomListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 3-3. 그룹방 상세 조회.
  Future<GroupRoomDetail> detail(String groupRoomId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId',
    );
    return GroupRoomDetail.fromJson(res.data!);
  }

  /// 3-3b. 그룹 홈 대시보드 집계 (오늘 요약 + 활성 그룹 + 다가오는 일정).
  Future<GroupHomeData> home(String groupRoomId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/home',
    );
    return GroupHomeData.fromJson(res.data!);
  }

  /// 3-4. 그룹방 수정 (방장).
  Future<GroupRoom> update(
    String groupRoomId,
    UpdateGroupRoomRequest body,
  ) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId',
      body: body.toJson(),
    );
    return GroupRoom.fromJson(res.data!);
  }

  /// 3-5. 그룹방 삭제 (Soft Delete, 24시간 후 영구 삭제).
  Future<DateTime> softDelete(String groupRoomId) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId',
    );
    return DateTime.parse(res.data!['deleteScheduledAt'] as String);
  }

  /// 3-6. 그룹방 복구.
  Future<GroupRoom> recover(String groupRoomId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/recover',
    );
    return GroupRoom.fromJson(res.data!);
  }
}
