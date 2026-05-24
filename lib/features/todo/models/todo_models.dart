import '../../common/models/common_models.dart';

/// 9번 도메인(Todo) DTO 정의.

/// 서버에서 수신한 datetime 문자열을 UTC로 파싱한다.
/// 타임존 정보가 없는 문자열(예: "2025-05-21T12:00:00")은 UTC로 간주해
/// 한국 시간(KST = UTC+9) 표기에서 9시간 어긋남이 발생하지 않도록 한다.
DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

DateTime? _tryParseUtc(String? s) {
  if (s == null) return null;
  return _parseUtc(s);
}

class Todo {
  Todo({
    required this.id,
    required this.text,
    required this.completed,
    this.completedAt,
    this.completedBy,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool completed;
  final DateTime? completedAt;
  final UserSummary? completedBy;
  final UserSummary createdBy;
  final DateTime createdAt;

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'].toString(),
      text: json['text'] as String,
      completed: json['completed'] as bool? ?? false,
      completedAt: _tryParseUtc(json['completedAt'] as String?),
      completedBy: json['completedBy'] != null
          ? UserSummary.fromJson(json['completedBy'] as Map<String, dynamic>)
          : null,
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      createdAt: _parseUtc(json['createdAt'] as String),
    );
  }
}

class TodoProgress {
  TodoProgress({
    required this.total,
    required this.completed,
    required this.percent,
  });

  final int total;
  final int completed;
  final int percent;

  factory TodoProgress.fromJson(Map<String, dynamic> json) {
    return TodoProgress(
      total: (json['total'] as num? ?? 0).toInt(),
      completed: (json['completed'] as num? ?? 0).toInt(),
      percent: (json['percent'] as num? ?? 0).toInt(),
    );
  }
}

class TodoListResult {
  TodoListResult({required this.todos, required this.progress});

  final List<Todo> todos;
  final TodoProgress progress;

  factory TodoListResult.fromJson(Map<String, dynamic> json) {
    return TodoListResult(
      todos: (json['todos'] as List? ?? [])
          .map((e) => Todo.fromJson(e as Map<String, dynamic>))
          .toList(),
      progress: TodoProgress.fromJson(
        (json['progress'] as Map?)?.cast<String, dynamic>() ??
            const {'total': 0, 'completed': 0, 'percent': 0},
      ),
    );
  }
}
