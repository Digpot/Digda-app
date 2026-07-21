import '../../../core/network/api_client.dart';
import '../models/alkkagi_models.dart';

/// 알까기 초대/대국 REST 래퍼. 플릭·기권 등 실시간 진행은 공용
/// GameSocketSession(`/topic/alkkagi/{gameId}`)이 담당.
class AlkkagiRepository {
  AlkkagiRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 같은 그룹 멤버에게 알까기 초대. 돌 개수(1~10)는 초대자가 정한다.
  Future<AlkkagiGame> create({
    required int groupRoomId,
    required String inviteeUserId,
    required int stoneCount,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/alkkagi/games',
      query: {'groupRoomId': groupRoomId},
      body: {'inviteeUserId': inviteeUserId, 'stoneCount': stoneCount},
    );
    return AlkkagiGame.fromJson(res.data!);
  }

  /// 대국 스냅샷 — 재접속/알림 진입 시 동기화용.
  Future<AlkkagiGame> get(int gameId) async {
    final res = await _api.get<Map<String, dynamic>>('/alkkagi/games/$gameId');
    return AlkkagiGame.fromJson(res.data!);
  }

  Future<AlkkagiGame> accept(int gameId) async {
    final res =
        await _api.post<Map<String, dynamic>>('/alkkagi/games/$gameId/accept');
    return AlkkagiGame.fromJson(res.data!);
  }

  Future<AlkkagiGame> decline(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/alkkagi/games/$gameId/decline');
    return AlkkagiGame.fromJson(res.data!);
  }

  /// 초대자가 상대 수락 전에 초대를 거둔다.
  Future<AlkkagiGame> cancel(int gameId) async {
    final res =
        await _api.post<Map<String, dynamic>>('/alkkagi/games/$gameId/cancel');
    return AlkkagiGame.fromJson(res.data!);
  }
}
