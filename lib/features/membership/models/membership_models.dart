/// 5번 도메인(Membership) DTO 정의.

/// 서버에서 수신한 datetime 문자열을 UTC로 파싱한다.
/// 타임존 정보가 없는 문자열은 UTC로 간주해 KST 표기에서 9시간 오차를 방지.
DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

class Membership {
  Membership({
    required this.userId,
    required this.name,
    this.profileImage,
    required this.color,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String name;
  final String? profileImage;
  final String color; // hex, 예: '#FF6B6B'
  final String role; // 'owner' | 'member'
  final DateTime joinedAt;

  bool get isOwner => role == 'owner';

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      userId: json['userId'] as String,
      name: json['name'] as String,
      profileImage: json['profileImage'] as String?,
      color: json['color'] as String? ?? '#999999',
      role: json['role'] as String? ?? 'member',
      joinedAt: _parseUtc(json['joinedAt'] as String),
    );
  }
}
