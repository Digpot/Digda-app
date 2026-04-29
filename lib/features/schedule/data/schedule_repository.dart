import '../../../core/network/api_client.dart';
import '../models/schedule_models.dart';

/// 6번 도메인(Schedule) 의 5개 엔드포인트를 래핑.
class ScheduleRepository {
  ScheduleRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 6-1. 일정 목록 (기간 조회).
  Future<List<Schedule>> list(
    String groupRoomId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules',
      query: {
        'startDate': _date(startDate),
        'endDate': _date(endDate),
      },
    );
    return (res.data!['schedules'] as List? ?? [])
        .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
        .toList();
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
    return Schedule.fromJson(res.data!);
  }

  /// 6-5. 일정 삭제.
  Future<void> delete(String groupRoomId, String scheduleId) async {
    await _api.delete<void>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId',
    );
  }
}
