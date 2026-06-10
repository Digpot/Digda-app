import '../../../core/network/api_client.dart';
import '../models/diary_models.dart';

/// 7번 도메인(Diary) 의 6개 엔드포인트를 래핑.
class DiaryRepository {
  DiaryRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 목록/캘린더 캐시 — 캐시 우선 반환(즉시 표시), 쓰기 시 전체 무효화.
  final Map<String, DiaryListResult> _listCache = {};
  final Map<String, DiaryCalendarResult> _calendarCache = {};

  String _month(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// 일기 변경(작성/수정/삭제/좋아요/리액션) 시 호출 — 캐시 일관성 유지.
  void _invalidate() {
    _listCache.clear();
    _calendarCache.clear();
  }

  /// 7-1. 일기 목록 (월 필터/페이지네이션). 캐시 우선, [forceRefresh] 로 강제 갱신.
  Future<DiaryListResult> list(
    String groupRoomId, {
    DateTime? month,
    int? limit,
    int? offset,
    bool forceRefresh = false,
  }) async {
    final key =
        '$groupRoomId|${month != null ? _month(month) : '-'}|$limit|$offset';
    if (!forceRefresh) {
      final cached = _listCache[key];
      if (cached != null) return cached;
    }
    final query = <String, dynamic>{};
    if (month != null) query['month'] = _month(month);
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;

    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries',
      query: query.isEmpty ? null : query,
    );
    final result = DiaryListResult.fromJson(res.data!);
    _listCache[key] = result;
    return result;
  }

  /// 7-2. 일기 캘린더 (날짜별 썸네일/기분 + 통계). 캐시 우선, [forceRefresh] 로 강제 갱신.
  Future<DiaryCalendarResult> calendar(
    String groupRoomId,
    DateTime month, {
    bool forceRefresh = false,
  }) async {
    final key = '$groupRoomId|${_month(month)}';
    if (!forceRefresh) {
      final cached = _calendarCache[key];
      if (cached != null) return cached;
    }
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/calendar',
      query: {'month': _month(month)},
    );
    final result = DiaryCalendarResult.fromJson(res.data!);
    _calendarCache[key] = result;
    return result;
  }

  /// 시그니처 지도 — 그룹의 지역별 일기 수 집계.
  ///
  /// [scope] 가 `'claim'` 이면 **현재 사용자가 그룹에 가입한 이후 작성된 일기만** 집계한다
  /// (지역 정복 칭호 적재 판정용 — 중간 합류자가 가입 전 그룹 성과를 소급 획득하지 못하게).
  /// 기본(null)은 그룹 전체 집계로, 지도 색칠 표시에 사용한다.
  Future<DiaryRegionMapResult> regionMap(
    String groupRoomId, {
    String? scope,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/region-map',
      query: scope == null ? null : {'scope': scope},
    );
    return DiaryRegionMapResult.fromJson(res.data!);
  }

  /// 시그니처 지도 — 특정 지역(regionKey)의 일기 목록.
  Future<DiaryListResult> listByRegion(
    String groupRoomId,
    String regionKey, {
    int? limit,
    int? offset,
  }) async {
    final query = <String, dynamic>{'regionKey': regionKey};
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/by-region',
      query: query,
    );
    return DiaryListResult.fromJson(res.data!);
  }

  /// 7-3. 일기 상세.
  Future<DiaryDetail> detail(String groupRoomId, String diaryId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/$diaryId',
    );
    return DiaryDetail.fromJson(res.data!);
  }

  /// 7-4. 일기 작성.
  Future<Diary> create(
    String groupRoomId,
    DiaryWriteRequest body,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries',
      body: body.toJson(),
    );
    _invalidate();
    return Diary.fromJson(res.data!);
  }

  /// 7-5. 일기 수정.
  Future<Diary> update(
    String groupRoomId,
    String diaryId,
    DiaryWriteRequest body,
  ) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/$diaryId',
      body: body.toJson(),
    );
    _invalidate();
    return Diary.fromJson(res.data!);
  }

  /// 7-6. 일기 삭제.
  Future<void> delete(String groupRoomId, String diaryId) async {
    await _api.delete<void>('/group-rooms/$groupRoomId/diaries/$diaryId');
    _invalidate();
  }

  /// 7-7. 일기 좋아요 토글.
  Future<DiaryLikeResult> toggleLike(String groupRoomId, String diaryId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/$diaryId/like',
    );
    _invalidate();
    return DiaryLikeResult.fromJson(res.data!);
  }

  /// 7-8. 일기 이모지 리액션 토글.
  Future<DiaryReactionToggleResult> toggleReaction(
    String groupRoomId,
    String diaryId,
    DiaryReactionType type,
  ) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/$diaryId/reactions',
      body: {'type': type.wire},
    );
    _invalidate();
    return DiaryReactionToggleResult.fromJson(res.data!);
  }
}
