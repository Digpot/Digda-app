import '../../../core/network/api_client.dart';
import '../models/minigame_models.dart';

/// 캐치마인드/탭배틀/게임 초대목록 REST 래퍼.
/// 실시간 진행은 [GameSocketSession] 이 담당.
class MinigameRepository {
  MinigameRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ── 초대/진행 중 목록 ─────────────────────────────────────

  /// 이 그룹에서 내가 초대받은 대기 게임 + 참여 중 게임(재입장) 목록.
  Future<GameInvitesSummary> invites({required int groupRoomId}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/games/invites',
      query: {'groupRoomId': groupRoomId},
    );
    return GameInvitesSummary.fromJson(res.data!);
  }

  // ── 캐치마인드 ────────────────────────────────────────────

  Future<CatchmindGame> createCatchmind({
    required int groupRoomId,
    required List<String> inviteeUserIds,
    int roundSeconds = 90,
    int totalRounds = 10,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/catchmind/games',
      query: {'groupRoomId': groupRoomId},
      body: {
        'inviteeUserIds': inviteeUserIds,
        'roundSeconds': roundSeconds,
        'totalRounds': totalRounds,
      },
    );
    return CatchmindGame.fromJson(res.data!);
  }

  Future<CatchmindGame> getCatchmind(int gameId) async {
    final res =
        await _api.get<Map<String, dynamic>>('/catchmind/games/$gameId');
    return CatchmindGame.fromJson(res.data!);
  }

  Future<CatchmindGame> joinCatchmind(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/catchmind/games/$gameId/join');
    return CatchmindGame.fromJson(res.data!);
  }

  Future<CatchmindGame> declineCatchmind(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/catchmind/games/$gameId/decline');
    return CatchmindGame.fromJson(res.data!);
  }

  Future<CatchmindGame> cancelCatchmind(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/catchmind/games/$gameId/cancel');
    return CatchmindGame.fromJson(res.data!);
  }

  Future<CatchmindGame> startCatchmind(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/catchmind/games/$gameId/start');
    return CatchmindGame.fromJson(res.data!);
  }

  // ── 끝말잇기 ──────────────────────────────────────────────

  Future<WordChainGame> createWordChain({
    required int groupRoomId,
    required List<String> inviteeUserIds,
    int turnSeconds = 15,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/wordchain/games',
      query: {'groupRoomId': groupRoomId},
      body: {
        'inviteeUserIds': inviteeUserIds,
        'turnSeconds': turnSeconds,
      },
    );
    return WordChainGame.fromJson(res.data!);
  }

  Future<WordChainGame> getWordChain(int gameId) async {
    final res =
        await _api.get<Map<String, dynamic>>('/wordchain/games/$gameId');
    return WordChainGame.fromJson(res.data!);
  }

  Future<WordChainGame> joinWordChain(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/wordchain/games/$gameId/join');
    return WordChainGame.fromJson(res.data!);
  }

  Future<WordChainGame> declineWordChain(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/wordchain/games/$gameId/decline');
    return WordChainGame.fromJson(res.data!);
  }

  Future<WordChainGame> cancelWordChain(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/wordchain/games/$gameId/cancel');
    return WordChainGame.fromJson(res.data!);
  }

  Future<WordChainGame> startWordChain(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/wordchain/games/$gameId/start');
    return WordChainGame.fromJson(res.data!);
  }

  // ── 탭배틀 ────────────────────────────────────────────────

  Future<TapBattleGame> createTapBattle({
    required int groupRoomId,
    required String inviteeUserId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/tapbattle/games',
      query: {'groupRoomId': groupRoomId},
      body: {'inviteeUserId': inviteeUserId},
    );
    return TapBattleGame.fromJson(res.data!);
  }

  Future<TapBattleGame> getTapBattle(int gameId) async {
    final res =
        await _api.get<Map<String, dynamic>>('/tapbattle/games/$gameId');
    return TapBattleGame.fromJson(res.data!);
  }

  Future<TapBattleGame> acceptTapBattle(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/tapbattle/games/$gameId/accept');
    return TapBattleGame.fromJson(res.data!);
  }

  Future<TapBattleGame> declineTapBattle(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/tapbattle/games/$gameId/decline');
    return TapBattleGame.fromJson(res.data!);
  }

  Future<TapBattleGame> cancelTapBattle(int gameId) async {
    final res = await _api
        .post<Map<String, dynamic>>('/tapbattle/games/$gameId/cancel');
    return TapBattleGame.fromJson(res.data!);
  }
}
