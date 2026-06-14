import '../../../core/network/api_client.dart';
import '../models/inquiry_models.dart';

/// 고객센터 문의 API 래퍼.
/// - 작성:    POST /inquiries  (서버에서 하루 2건 제한 — 초과 시 INQUIRY_DAILY_LIMIT 429)
/// - 내 목록: GET  /inquiries
class InquiryRepository {
  InquiryRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<Inquiry> submit(String content) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/inquiries',
      body: {'content': content.trim()},
    );
    return Inquiry.fromJson(res.data!);
  }

  Future<List<Inquiry>> myInquiries() async {
    final res = await _api.get<List<dynamic>>('/inquiries');
    return (res.data ?? const [])
        .map((e) => Inquiry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
