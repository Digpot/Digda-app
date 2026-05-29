import '../../../core/network/api_client.dart';
import '../models/character_models.dart';

/// 캐릭터(모찌) API 래퍼. 모든 엔드포인트가 인증 필요.
///
/// 모찌는 그룹 1개당 1마리로 그룹원이 함께 키운다. 따라서 모든 메서드는 활성
/// `groupRoomId` 를 인자로 받아 그 그룹의 캐릭터를 조회·변경한다.
///
/// 외형(스킨/안경/모자/머리핀/액세서리/잡화) 관련 작업은 `/character/shop` 하위로
/// 분리되어 있고, 본 클래스는 두 도메인을 한 곳에서 호출할 수 있게 묶었다.
class CharacterRepository {
  CharacterRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 그룹 캐릭터 상태 (없으면 서버가 자동 생성).
  Future<CharacterState> getMyState({required int groupRoomId}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/character',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterState.fromJson(res.data!);
  }

  /// 경험치 가산. source 는 통계용 자유 문자열.
  Future<AddExpResult> addExp({
    required int groupRoomId,
    required int amount,
    String? source,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character/exp',
      query: {'groupRoomId': groupRoomId},
      body: {
        'amount': amount,
        if (source != null) 'source': source,
      },
    );
    return AddExpResult.fromJson(res.data!);
  }

  /// 진화 트리 + 그룹 캐릭터 도달 상태.
  Future<CharacterStageTree> getStageTree({required int groupRoomId}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/character/stages',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterStageTree.fromJson(res.data!);
  }

  /// 마스터 챔피언 챌린지 시작 — 서버에서 입장료(20 코인) 차감.
  /// 잔액 부족 시 INSUFFICIENT_COIN, 마스터 아닌 경우 NOT_MASTER_CHARACTER.
  /// 차감된 잔액이 반영된 캐릭터 상태가 응답.
  Future<CharacterState> startMasterGame({required int groupRoomId}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character/master-game-start',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterState.fromJson(res.data!);
  }

  /// 마스터 챔피언 챌린지 점수를 제출하고 코인 보상을 받는다.
  /// 마스터 단계가 아닐 경우 서버가 NOT_MASTER_CHARACTER 로 응답.
  Future<MasterGameReward> claimMasterGameReward({
    required int groupRoomId,
    required int score,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character/master-game-reward',
      query: {'groupRoomId': groupRoomId},
      body: {'score': score},
    );
    return MasterGameReward.fromJson(res.data!);
  }

  // ─────────── 상점 (아이템 기반) ───────────

  /// 상점 전체 — 카테고리별 [ShopSection] 리스트 + 잔액.
  Future<CharacterShop> getShop({required int groupRoomId}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/character/shop',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterShop.fromJson(res.data!);
  }

  /// 아이템 구매. 잔액 부족·중복 보유는 4xx → 호출자가 다이얼로그 처리.
  Future<CharacterShop> buyItem({
    required int groupRoomId,
    required String itemKey,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character/shop/items/$itemKey/buy',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterShop.fromJson(res.data!);
  }

  /// 보유 아이템을 해당 카테고리 슬롯에 장착. 응답은 갱신된 캐릭터 상태.
  Future<CharacterState> equipItem({
    required int groupRoomId,
    required String itemKey,
  }) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/character/shop/equip',
      query: {'groupRoomId': groupRoomId},
      body: {'itemKey': itemKey},
    );
    return CharacterState.fromJson(res.data!);
  }

  /// 카테고리 슬롯 해제 (스킨은 default 로 복귀, 그 외는 빈 슬롯).
  Future<CharacterState> unequipSlot({
    required int groupRoomId,
    required ShopItemType itemType,
  }) async {
    final res = await _api.delete<Map<String, dynamic>>(
      '/character/shop/equip/${itemType.serverKey}',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterState.fromJson(res.data!);
  }

  // ─────────── 퀴즈 ───────────

  /// 풀 수 있는 퀴즈 1건 랜덤. 없으면 4xx (QUIZ_NO_AVAILABLE).
  Future<CharacterQuiz> pickRandomQuiz(int groupRoomId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/character-quizzes/random',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterQuiz.fromJson(res.data!);
  }

  /// 그룹 퀴즈 목록.
  Future<CharacterQuizListResult> listQuizzes({
    required int groupRoomId,
    int page = 0,
    int size = 20,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/character-quizzes',
      query: {
        'groupRoomId': groupRoomId,
        'page': page,
        'size': size,
      },
    );
    return CharacterQuizListResult.fromJson(res.data!);
  }

  /// 퀴즈 생성.
  Future<CharacterQuiz> createQuiz({
    required int groupRoomId,
    required QuizCategory category,
    required String question,
    required List<String> options,
    required int correctIndex,
    required int expMultiplier,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character-quizzes',
      body: {
        'groupRoomId': groupRoomId,
        'category': category.serverKey,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'expMultiplier': expMultiplier,
      },
    );
    return CharacterQuiz.fromJson(res.data!);
  }

  /// 퀴즈 응시. 보상 + 갱신된 그룹 캐릭터 상태가 함께 옴.
  Future<QuizAttemptResult> attemptQuiz({
    required int quizId,
    required int selectedIndex,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character-quizzes/$quizId/attempt',
      body: {'selectedIndex': selectedIndex},
    );
    return QuizAttemptResult.fromJson(res.data!);
  }
}
