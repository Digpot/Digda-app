import '../../../core/network/api_client.dart';
import '../models/diary_models.dart';

/// 7번 도메인(Diary) 의 6개 엔드포인트를 래핑.
class DiaryRepository {
  DiaryRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  String _month(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// 7-1. 일기 목록 (월 필터/페이지네이션).
  Future<DiaryListResult> list(
    String groupRoomId, {
    DateTime? month,
    int? limit,
    int? offset,
  }) async {
    final query = <String, dynamic>{};
    if (month != null) query['month'] = _month(month);
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;

    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries',
      query: query.isEmpty ? null : query,
    );
    return DiaryListResult.fromJson(res.data!);
  }

  /// 7-2. 일기 캘린더 (날짜별 썸네일/기분 + 통계).
  Future<DiaryCalendarResult> calendar(
    String groupRoomId,
    DateTime month,
  ) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/calendar',
      query: {'month': _month(month)},
    );
    return DiaryCalendarResult.fromJson(res.data!);
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
    return Diary.fromJson(res.data!);
  }

  /// 7-6. 일기 삭제.
  Future<void> delete(String groupRoomId, String diaryId) async {
    await _api.delete<void>('/group-rooms/$groupRoomId/diaries/$diaryId');
  }

  /// 7-7. 일기 좋아요 토글.
  Future<DiaryLikeResult> toggleLike(String groupRoomId, String diaryId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/$diaryId/like',
    );
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
    return DiaryReactionToggleResult.fromJson(res.data!);
  }
}
