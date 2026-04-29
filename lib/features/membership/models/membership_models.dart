/// 5번 도메인(Membership) DTO 정의.

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
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}
