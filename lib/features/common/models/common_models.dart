/// 공통 객체 — 여러 도메인에서 재사용.

class UserSummary {
  UserSummary({required this.id, required this.name, this.profileImage});

  final String id;
  final String name;
  final String? profileImage;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
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
      id: json['id'] as String,
      text: json['text'] as String,
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
