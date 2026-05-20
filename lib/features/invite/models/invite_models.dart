import '../../group_room/models/group_room_models.dart';

/// 4번 도메인(Invite) DTO 정의.

DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

class InviteCode {
  InviteCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      code: json['code'] as String,
      expiresAt: _parseUtc(json['expiresAt'] as String),
    );
  }
}

/// 4-2. 초대 코드 검증 응답.
class InvitePreview {
  InvitePreview({
    required this.groupRoomName,
    this.thumbnailImage,
    required this.memberCount,
    required this.maxMembers,
    required this.expiresAt,
  });

  final String groupRoomName;
  final String? thumbnailImage;
  final int memberCount;
  final int maxMembers;
  final DateTime expiresAt;

  bool get isFull => memberCount >= maxMembers;

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    return InvitePreview(
      groupRoomName: json['groupRoomName'] as String,
      thumbnailImage: json['thumbnailImage'] as String?,
      memberCount: (json['memberCount'] as num).toInt(),
      maxMembers: (json['maxMembers'] as num).toInt(),
      expiresAt: _parseUtc(json['expiresAt'] as String),
    );
  }
}

/// 4-3. 초대 코드 참여 응답.
class JoinResult {
  JoinResult({required this.groupRoom, required this.memberships});

  final GroupRoom groupRoom;
  final List<MembershipSummary> memberships;

  factory JoinResult.fromJson(Map<String, dynamic> json) {
    return JoinResult(
      groupRoom: GroupRoom.fromJson(json['groupRoom'] as Map<String, dynamic>),
      memberships: (json['memberships'] as List? ?? [])
          .map((e) => MembershipSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
