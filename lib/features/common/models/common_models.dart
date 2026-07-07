// 공통 객체 — 여러 도메인에서 재사용.

DateTime _parseServerTime(String s) {
  // 서버(JVM TZ=Asia/Seoul)는 타임존 표기 없는 KST wall-clock 을 내려주므로,
  // 표기 없으면 로컬(KST)로 그대로 파싱한다. 예전처럼 'Z'를 붙이면 +9시간 어긋난다.
  // Z/오프셋이 붙은 값만 실제 시각으로 보고 toLocal 로 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
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
    this.parentId,
    this.hidden = false,
    this.hiddenReason,
  });

  final String id;
  final String text;
  final UserSummary createdBy;
  final DateTime createdAt;

  /// 대댓글이면 부모 댓글 id. 최상위 댓글은 null (댓글→대댓글 1단계만 지원).
  final String? parentId;

  /// 차단/신고로 내게 숨겨진 댓글. true 면 [text] 는 비어 있고 플레이스홀더를 표시한다.
  final bool hidden;

  /// 숨김 사유 코드 — BLOCKED_USER / REPORTED / HIDDEN.
  final String? hiddenReason;

  /// 대댓글 여부.
  bool get isReply => parentId != null;

  factory CommentEntity.fromJson(Map<String, dynamic> json) {
    return CommentEntity(
      id: json['id'].toString(),
      text: json['text'] as String? ?? '',
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      createdAt: _parseServerTime(json['createdAt'] as String),
      parentId: json['parentId']?.toString(),
      hidden: json['hidden'] as bool? ?? false,
      hiddenReason: json['hiddenReason'] as String?,
    );
  }
}
