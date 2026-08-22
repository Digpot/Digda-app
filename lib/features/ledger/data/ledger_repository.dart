import '../../../core/network/api_client.dart';
import '../models/ledger_models.dart';

/// 그룹 가계부 조회. 쓰기는 일정 저장(ScheduleRepository)에 함께 실려 나가므로
/// 여기엔 읽기만 있다.
class LedgerRepository {
  LedgerRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 월 요약 캐시 — 'groupId|year|month'. 일정이 바뀌면 금액도 바뀌므로
  /// 일정 쓰기 시 [invalidateCaches] 로 통째로 비운다.
  final Map<String, LedgerSummary> _cache = {};

  Future<LedgerSummary> monthly(
    String groupRoomId, {
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    final key = '$groupRoomId|$year|$month';
    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null) return cached;
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/ledger',
      query: {'year': year, 'month': month},
    );
    final summary = LedgerSummary.fromJson(res.data!);
    _cache[key] = summary;
    return summary;
  }

  void invalidateCaches() => _cache.clear();
}
