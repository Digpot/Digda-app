import '../../../core/network/api_client.dart';
import '../models/feedback_models.dart';

/// 앱 자체 피드백 폼 API 래퍼.
/// - 문항 조회: GET  /feedback/questions  (어드민이 구성한 활성 문항)
/// - 제출:      POST /feedback
class FeedbackRepository {
  FeedbackRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<FeedbackQuestion>> getQuestions() async {
    final res = await _api.get<List<dynamic>>('/feedback/questions');
    final list = (res.data ?? const [])
        .map((e) => FeedbackQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// [answers] 는 {questionId, answer(표시용 문자열)} 목록.
  Future<void> submit(List<Map<String, dynamic>> answers) async {
    await _api.post<void>('/feedback', body: {'answers': answers});
  }
}
