import '../../../core/network/api_client.dart';
import '../../common/models/common_models.dart';

/// 8번 도메인(Comment) 의 4개 엔드포인트를 래핑.
/// CommentEntity 는 features/common/models/common_models.dart 에 정의됨.
class CommentRepository {
  CommentRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 8-1. 일정 댓글 작성.
  Future<CommentEntity> writeOnSchedule({
    required String groupRoomId,
    required String scheduleId,
    required String text,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId/comments',
      body: {'text': text},
    );
    return CommentEntity.fromJson(res.data!);
  }

  /// 8-2. 일기 댓글 작성. [parentCommentId] 를 주면 그 댓글의 대댓글로 달린다(1단계만).
  Future<CommentEntity> writeOnDiary({
    required String groupRoomId,
    required String diaryId,
    required String text,
    String? parentCommentId,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/diaries/$diaryId/comments',
      body: {
        'text': text,
        if (parentCommentId != null) 'parentCommentId': int.parse(parentCommentId),
      },
    );
    return CommentEntity.fromJson(res.data!);
  }

  /// 8-3. 일정 댓글 삭제.
  Future<void> deleteOnSchedule({
    required String groupRoomId,
    required String scheduleId,
    required String commentId,
  }) async {
    await _api.delete<void>(
      '/group-rooms/$groupRoomId/schedules/$scheduleId/comments/$commentId',
    );
  }

  /// 8-4. 일기 댓글 삭제.
  Future<void> deleteOnDiary({
    required String groupRoomId,
    required String diaryId,
    required String commentId,
  }) async {
    await _api.delete<void>(
      '/group-rooms/$groupRoomId/diaries/$diaryId/comments/$commentId',
    );
  }
}
