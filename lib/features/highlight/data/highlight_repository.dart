import '../../../core/network/api_client.dart';
import '../models/highlight_models.dart';

/// 월간 하이라이트 조회. 서버가 매월 1일에 만들어 저장한 결과를 읽기만 한다.
class HighlightRepository {
  HighlightRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 생성된 하이라이트 목록(최신 월 먼저).
  Future<List<HighlightListItem>> list(String groupRoomId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/highlights',
    );
    return (res.data!['highlights'] as List? ?? [])
        .map((e) => HighlightListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 월 상세. [month] 는 "yyyy-MM".
  Future<HighlightDetail> detail(String groupRoomId, String month) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/highlights/$month',
    );
    return HighlightDetail.fromJson(res.data!);
  }
}
