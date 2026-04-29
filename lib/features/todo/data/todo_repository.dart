import '../../../core/network/api_client.dart';
import '../models/todo_models.dart';

/// 9번 도메인(Todo) 의 4개 엔드포인트를 래핑.
class TodoRepository {
  TodoRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 9-1. 할 일 목록 + 진행률.
  Future<TodoListResult> list(String groupRoomId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/todos',
    );
    return TodoListResult.fromJson(res.data!);
  }

  /// 9-2. 할 일 생성.
  Future<Todo> create(String groupRoomId, String text) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/todos',
      body: {'text': text},
    );
    return Todo.fromJson(res.data!);
  }

  /// 9-3. 완료 토글.
  Future<Todo> toggle(
    String groupRoomId,
    String todoId, {
    required bool completed,
  }) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/group-rooms/$groupRoomId/todos/$todoId',
      body: {'completed': completed},
    );
    return Todo.fromJson(res.data!);
  }

  /// 9-4. 할 일 삭제.
  Future<void> delete(String groupRoomId, String todoId) async {
    await _api.delete<void>('/group-rooms/$groupRoomId/todos/$todoId');
  }
}
