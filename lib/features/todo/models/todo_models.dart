import '../../common/models/common_models.dart';

/// 9번 도메인(Todo) DTO 정의.

DateTime _parseServerTime(String s) {
  // 서버(JVM TZ=Asia/Seoul)는 타임존 표기 없는 KST wall-clock 을 내려주므로,
  // 표기 없으면 로컬(KST)로 그대로 파싱한다. 예전처럼 'Z'를 붙이면 +9시간 어긋난다.
  // Z/오프셋이 붙은 값만 실제 시각으로 보고 toLocal 로 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
  return DateTime.parse(s);
}

DateTime? _tryParseUtc(String? s) {
  if (s == null) return null;
  return _parseServerTime(s);
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
      createdAt: _parseServerTime(json['createdAt'] as String),
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
