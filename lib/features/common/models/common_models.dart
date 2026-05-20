/// 공통 객체 — 여러 도메인에서 재사용.

DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

class UserSummary {
  UserSummary({required this.id, required this.name, this.profileImage});

  final String id;
  final String name;
  final String? profileImage;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      // 서버 도메인마다 userId/id 혼용 → 둘 다 허용
      id: (json['userId'] ?? json['id']).toString(),
      name: json['name'] as String,
      profileImage: json['profileImage'] as String?,
    );
  }
}

/// `Comment` — 일정/일기 댓글 공통 구조.
class CommentEntity {
  CommentEntity({
    required this.id,
    required this.text,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String text;
  final UserSummary createdBy;
  final DateTime createdAt;

  factory CommentEntity.fromJson(Map<String, dynamic> json) {
    return CommentEntity(
      id: json['id'].toString(),
      text: json['text'] as String,
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      createdAt: _parseUtc(json['createdAt'] as String),
    );
  }
}
