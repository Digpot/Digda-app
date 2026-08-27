import '../../../core/network/api_client.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../ledger/models/ledger_models.dart';
import '../models/schedule_models.dart';

/// 6번 도메인(Schedule) 의 5개 엔드포인트를 래핑.
class ScheduleRepository {
  ScheduleRepository({
    required ApiClient apiClient,
    LedgerRepository? ledgerRepository,
  })  : _api = apiClient,
        _ledger = ledgerRepository;

  final ApiClient _api;

  /// 가계부 금액은 일정에 매달려 있어서, 일정을 쓰면 월 요약도 같이 낡는다.
  /// 일정 쓰기 한 곳에서 함께 무효화해 "저장했는데 총액이 그대로"를 막는다.
  final LedgerRepository? _ledger;

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
    _invalidateAfterWrite();
    return Schedule.fromJson(res.data!);
  }

  /// 6-6. 일정 여러 날짜 복사 — 선택한 각 날짜를 시작일로 복사본을 만든다.
  /// 기간 일정은 길이 유지, 참여자 포함. 서버가 최대 31개 날짜로 제한한다.
  Future<List<Schedule>> copy(
    String groupRoomId,
    String scheduleId,
    List<DateTime> dates,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId/copy',
      body: {'dates': dates.map(_date).toList()},
    );
    _invalidateAfterWrite();
    return (res.data!['schedules'] as List? ?? [])
        .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
        .toList();
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
    _invalidateAfterWrite();
    return Schedule.fromJson(res.data!);
  }

  /// 일정에 지출 **한 건만** 추가 — 일정 수정을 거치지 않고 그 자리에서 저장한다.
  ///
  /// 일정 수정(PUT)의 `expenses` 는 전체 교체라, 지출 목록 전부를 편집 상태로 들고 있지
  /// 않은 화면(일정 상세)에서 쓰면 그 사이 다른 멤버가 넣은 금액을 덮어 지운다.
  /// 그래서 서버에 덧붙이기 전용 엔드포인트를 따로 뒀다.
  ///
  /// 가계부 도메인이지만 여기(ScheduleRepository)에 두는 이유: 이 쓰기는 일정 목록
  /// 캐시(칸에 뜨는 금액)와 가계부 월 요약을 **둘 다** 낡게 만든다. 무효화를 한 곳에서
  /// 하려면 둘을 모두 아는 쪽에 있어야 한다.
  Future<List<ScheduleExpense>> addExpense(
    String groupRoomId,
    String scheduleId,
    ExpenseWrite expense,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId/expenses',
      body: expense.toJson(),
    );
    _invalidateAfterWrite();
    return (res.data!['expenses'] as List? ?? [])
        .map((e) => ScheduleExpense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 6-5. 일정 삭제.
  Future<void> delete(String groupRoomId, String scheduleId) async {
    await _api.delete<void>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId',
    );
    _invalidateAfterWrite();
  }

  /// 일정 쓰기 후 — 일정 목록과 가계부 월 요약을 함께 버린다.
  void _invalidateAfterWrite() {
    _listCache.clear();
    _ledger?.invalidateCaches();
  }

  /// 신고/차단/숨김으로 일정 가시성이 바뀐 뒤 목록을 강제 갱신하기 위한 공개 진입점.
  void invalidateCaches() => _invalidateAfterWrite();
}
