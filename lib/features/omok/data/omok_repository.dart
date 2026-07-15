import '../../../core/network/api_client.dart';
import '../models/omok_models.dart';

/// 오목 초대/대국 REST 래퍼. 착수·기권 등 실시간 진행은 [OmokSocketSession] 이 담당.
class OmokRepository {
  OmokRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 같은 그룹 멤버에게 오목 초대. 상대에겐 GAME_INVITE 알림이 발송된다.
  Future<OmokGame> create({
    required int groupRoomId,
    required String inviteeUserId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/omok/games',
      query: {'groupRoomId': groupRoomId},
      body: {'inviteeUserId': inviteeUserId},
    );
    return OmokGame.fromJson(res.data!);
  }

  /// 대국 스냅샷 — 재접속/알림 진입 시 동기화용.
  Future<OmokGame> get(int gameId) async {
    final res = await _api.get<Map<String, dynamic>>('/omok/games/$gameId');
    return OmokGame.fromJson(res.data!);
  }

  Future<OmokGame> accept(int gameId) async {
    final res =
        await _api.post<Map<String, dynamic>>('/omok/games/$gameId/accept');
    return OmokGame.fromJson(res.data!);
  }

  Future<OmokGame> decline(int gameId) async {
    final res =
        await _api.post<Map<String, dynamic>>('/omok/games/$gameId/decline');
    return OmokGame.fromJson(res.data!);
  }

  /// 초대자가 상대 수락 전에 초대를 거둔다.
  Future<OmokGame> cancel(int gameId) async {
    final res =
        await _api.post<Map<String, dynamic>>('/omok/games/$gameId/cancel');
    return OmokGame.fromJson(res.data!);
  }
}
