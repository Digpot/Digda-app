import '../../../core/network/api_client.dart';
import '../models/schedule_models.dart';

/// 6번 도메인(Schedule) 의 5개 엔드포인트를 래핑.
class ScheduleRepository {
  ScheduleRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 기간 목록 캐시 — 'groupId|start|end' → 일정 목록. 쓰기(생성/수정/삭제) 시 전체 무효화.
  final Map<String, List<Schedule>> _listCache = {};

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 6-1. 일정 목록 (기간 조회). 캐시 우선 반환(즉시 표시), [forceRefresh] 로 강제 갱신.
  Future<List<Schedule>> list(
    String groupRoomId, {
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    final key = '$groupRoomId|${_date(startDate)}|${_date(endDate)}';
    if (!forceRefresh) {
      final cached = _listCache[key];
      if (cached != null) return cached;
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules',
      query: {
        'startDate': _date(startDate),
        'endDate': _date(endDate),
      },
    );
    final list = (res.data!['schedules'] as List? ?? [])
        .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
        .toList();
    _listCache[key] = list;
    return list;
  }

  /// 6-2. 일정 상세.
  Future<ScheduleDetail> detail(String groupRoomId, String scheduleId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId',
    );
    return ScheduleDetail.fromJson(res.data!);
  }

  /// 6-3. 일정 생성.
  Future<Schedule> create(
    String groupRoomId,
    ScheduleWriteRequest body,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules',
      body: body.toJson(),
    );
    _listCache.clear();
    return Schedule.fromJson(res.data!);
  }

  /// 6-4. 일정 수정.
  Future<Schedule> update(
    String groupRoomId,
    String scheduleId,
    ScheduleWriteRequest body,
  ) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId',
      body: body.toJson(),
    );
    _listCache.clear();
    return Schedule.fromJson(res.data!);
  }

  /// 6-5. 일정 삭제.
  Future<void> delete(String groupRoomId, String scheduleId) async {
    await _api.delete<void>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId',
    );
    _listCache.clear();
  }

  /// 신고/차단/숨김으로 일정 가시성이 바뀐 뒤 목록을 강제 갱신하기 위한 공개 진입점.
  void invalidateCaches() => _listCache.clear();
}
