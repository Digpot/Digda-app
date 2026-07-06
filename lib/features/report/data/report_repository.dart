import '../../../core/network/api_client.dart';
import '../models/report_models.dart';

/// 신고 API 래퍼. POST /reports.
class ReportRepository {
  ReportRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 신고하기. 콘텐츠형(일기/댓글/일정) 신고는 서버가 신고자 본인에게 자동 숨김까지 처리한다.
  ///
  /// [targetId] 는 콘텐츠는 PK 문자열, [ReportTargetType.user] 는 UUID 문자열.
  Future<void> submit({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? detail,
    String? groupRoomId,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/reports',
      body: {
        'targetType': targetType.wire,
        'targetId': targetId,
        'reason': reason.wire,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
        if (groupRoomId != null) 'groupRoomId': int.tryParse(groupRoomId),
      },
    );
  }
}
