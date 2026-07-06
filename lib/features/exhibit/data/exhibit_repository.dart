import '../../../core/network/api_client.dart';
import '../models/exhibit_models.dart';

/// 역대 별명 전시관 API 래퍼. 접근 권한은 어드민이 사용자별로 부여한다.
class ExhibitRepository {
  ExhibitRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 현재 사용자가 전시관에 접근 가능한지. (모찌 화면 버튼 노출 판단용)
  Future<bool> checkAccess() async {
    final res = await _api.get<Map<String, dynamic>>('/nickname-exhibits/access');
    return res.data?['allowed'] == true;
  }

  /// 전시관 카드 목록. 접근 권한 없으면 403(EXHIBIT_ACCESS_DENIED).
  Future<List<NicknameExhibit>> list() async {
    final res = await _api.get<List<dynamic>>('/nickname-exhibits');
    final items = res.data ?? const [];
    return items
        .map((e) => NicknameExhibit.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
