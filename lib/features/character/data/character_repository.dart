import '../../../core/network/api_client.dart';
import '../models/character_models.dart';

/// 캐릭터(모찌) API 래퍼. 모든 엔드포인트가 인증 필요.
///
/// 모찌는 그룹 1개당 1마리로 그룹원이 함께 키운다. 따라서 모든 메서드는 활성
/// `groupRoomId` 를 인자로 받아 그 그룹의 캐릭터를 조회·변경한다.
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

  /// 색상 상점 (그룹 보유/현재/잔액 포함).
  Future<CharacterColorShop> getColorShop({required int groupRoomId}) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/character/shop/colors',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterColorShop.fromJson(res.data!);
  }

  /// 색상 구매. 잔액 부족·중복 보유는 4xx → 호출자가 다이얼로그 처리.
  Future<CharacterColorShop> buyColor({
    required int groupRoomId,
    required CharacterColor color,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/character/shop/colors/${color.serverKey}/buy',
      query: {'groupRoomId': groupRoomId},
    );
    return CharacterColorShop.fromJson(res.data!);
  }

  /// 보유한 색상으로 변경.
  Future<CharacterState> applyColor({
    required int groupRoomId,
    required CharacterColor color,
  }) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/character/color',
      query: {'groupRoomId': groupRoomId},
      body: {'color': color.serverKey},
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
