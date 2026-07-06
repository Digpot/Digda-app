// 5번 도메인(Membership) DTO 정의.

DateTime _parseServerTime(String s) {
  // 서버(JVM TZ=Asia/Seoul)는 타임존 표기 없는 KST wall-clock 을 내려주므로,
  // 표기 없으면 로컬(KST)로 그대로 파싱한다. 예전처럼 'Z'를 붙이면 +9시간 어긋난다.
  // Z/오프셋이 붙은 값만 실제 시각으로 보고 toLocal 로 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
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
      joinedAt: _parseServerTime(json['joinedAt'] as String),
    );
  }
}
