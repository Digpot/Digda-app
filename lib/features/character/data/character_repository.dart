import '../../../core/network/api_client.dart';
import '../models/character_models.dart';

/// 캐릭터(모찌) API 래퍼. 모든 엔드포인트가 인증 필요.
class CharacterRepository {
  CharacterRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 내 캐릭터 상태 (없으면 서버가 자동 생성).
  Future<CharacterState> getMyState() async {
    final res = await _api.get<Map<String, dynamic>>('/character/me');
    return CharacterState.fromJson(res.data!);
  }

  /// 경험치 가산. source 는 통계용 자유 문자열.
  Future<AddExpResult> addExp({required int amount, String? source}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character/me/exp',
      body: {
        'amount': amount,
        if (source != null) 'source': source,
      },
    );
    return AddExpResult.fromJson(res.data!);
  }

  /// 진화 트리 + 내 도달 상태.
  Future<CharacterStageTree> getStageTree() async {
    final res = await _api.get<Map<String, dynamic>>('/character/stages');
    return CharacterStageTree.fromJson(res.data!);
  }

  /// 색상 상점 (보유/현재/잔액 포함).
  Future<CharacterColorShop> getColorShop() async {
    final res = await _api.get<Map<String, dynamic>>('/character/shop/colors');
    return CharacterColorShop.fromJson(res.data!);
  }

  /// 색상 구매. 잔액 부족·중복 보유는 4xx → 호출자가 다이얼로그 처리.
  Future<CharacterColorShop> buyColor(CharacterColor color) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character/shop/colors/${color.serverKey}/buy',
    );
    return CharacterColorShop.fromJson(res.data!);
  }

  /// 보유한 색상으로 변경.
  Future<CharacterState> applyColor(CharacterColor color) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/character/me/color',
      body: {'color': color.serverKey},
    );
    return CharacterState.fromJson(res.data!);
  }
}
