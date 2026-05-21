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

  /// 7-2. 일기 캘린더 (월별 dot marker).
  Future<List<DateTime>> calendar(
    String groupRoomId,
    DateTime month,
  ) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/calendar',
      query: {'month': _month(month)},
    );
    return (res.data!['dates'] as List? ?? [])
        .map((e) => _parseUtcDate(e as String))
        .toList();
  }

  /// 서버의 timezone-naive datetime 문자열을 UTC로 파싱 후 로컬 시간으로 변환.
  DateTime _parseUtcDate(String s) {
    if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
      return DateTime.parse(s).toLocal();
    }
    if (s.contains('T')) return DateTime.parse('${s}Z').toLocal();
    return DateTime.parse(s).toLocal();
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
}
