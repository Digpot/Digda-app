/// 3번 도메인(GroupRoom) DTO 정의.

class GroupRoom {
  GroupRoom({
    required this.id,
    required this.name,
    required this.maxMembers,
    required this.memberCount,
    this.thumbnailImage,
    this.ownerId,
    required this.createdAt,
    this.deleteScheduledAt,
  });

  final String id;
  final String name;
  final int maxMembers;
  final int memberCount;
  final String? thumbnailImage;
  final String? ownerId;
  final DateTime createdAt;
  final DateTime? deleteScheduledAt;

  factory GroupRoom.fromJson(Map<String, dynamic> json) {
    return GroupRoom(
      id: json['id'].toString(),
      name: json['name'] as String,
      maxMembers: (json['maxMembers'] as num).toInt(),
      memberCount: (json['memberCount'] as num? ?? 0).toInt(),
      thumbnailImage: json['thumbnailImage'] as String?,
      ownerId: json['ownerId']?.toString(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      deleteScheduledAt: json['deleteScheduledAt'] != null
          ? DateTime.tryParse(json['deleteScheduledAt'] as String)
          : null,
    );
  }
}

class GroupRoomListItem {
  GroupRoomListItem({
    required this.id,
    required this.name,
    this.thumbnailImage,
    required this.memberCount,
    required this.maxMembers,
    required this.myRole,
    required this.lastActivityAt,
    required this.isDeleteScheduled,
  });

  final String id;
  final String name;
  final String? thumbnailImage;
  final int memberCount;
  final int maxMembers;
  final String myRole; // 'owner' | 'member'
  final DateTime lastActivityAt;
  final bool isDeleteScheduled;

  bool get isOwner => myRole == 'owner';

  factory GroupRoomListItem.fromJson(Map<String, dynamic> json) {
    return GroupRoomListItem(
      id: json['id'].toString(),
      name: json['name'] as String,
      thumbnailImage: json['thumbnailImage'] as String?,
      memberCount: (json['memberCount'] as num).toInt(),
      maxMembers: (json['maxMembers'] as num).toInt(),
      myRole: json['myRole'] as String? ?? 'member',
      lastActivityAt: DateTime.parse(json['lastActivityAt'] as String),
      isDeleteScheduled: json['isDeleteScheduled'] as bool? ?? false,
    );
  }
}

class MembershipSummary {
  MembershipSummary({
    this.userId,
    required this.name,
    this.profileImage,
    required this.role,
  });

  final String? userId;
  final String name;
  final String? profileImage;
  final String role; // 'owner' | 'member'

  factory MembershipSummary.fromJson(Map<String, dynamic> json) {
    return MembershipSummary(
      userId: json['userId'] as String?,
      name: json['name'] as String,
      profileImage: json['profileImage'] as String?,
      role: json['role'] as String? ?? 'member',
    );
  }
}

class GroupRoomDetail {
  GroupRoomDetail({
    required this.groupRoom,
    required this.memberships,
    required this.myRole,
    this.inviteCode,
  });

  final GroupRoom groupRoom;
  final List<MembershipSummary> memberships;
  final String myRole;
  final String? inviteCode;

  bool get isOwner => myRole == 'owner';

  factory GroupRoomDetail.fromJson(Map<String, dynamic> json) {
    return GroupRoomDetail(
      groupRoom: GroupRoom.fromJson(json['groupRoom'] as Map<String, dynamic>),
      memberships: (json['memberships'] as List? ?? [])
          .map((e) => MembershipSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      myRole: json['myRole'] as String? ?? 'member',
      inviteCode: json['inviteCode'] as String?,
    );
  }
}

class CreateGroupRoomRequest {
  const CreateGroupRoomRequest({
    required this.name,
    required this.maxMembers,
    this.thumbnailImageId,
  });

  final String name;
  final int maxMembers;
  final String? thumbnailImageId;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'name': name,
      'maxMembers': maxMembers,
    };
    if (thumbnailImageId != null) body['thumbnailImageId'] = thumbnailImageId;
    return body;
  }
}

class CreateGroupRoomResult {
  CreateGroupRoomResult({
    required this.groupRoom,
    required this.inviteCode,
    required this.inviteCodeExpiresAt,
  });

  final GroupRoom groupRoom;
  final String inviteCode;
  final DateTime inviteCodeExpiresAt;

  factory CreateGroupRoomResult.fromJson(Map<String, dynamic> json) {
    return CreateGroupRoomResult(
      groupRoom: GroupRoom.fromJson(json['groupRoom'] as Map<String, dynamic>),
      inviteCode: json['inviteCode'] as String,
      inviteCodeExpiresAt:
          DateTime.parse(json['inviteCodeExpiresAt'] as String),
    );
  }
}

/// `PUT /group-rooms/:id` — null/unset 분리. thumbnailImageId 만 null 의미가 있음.
class UpdateGroupRoomRequest {
  const UpdateGroupRoomRequest({
    this.name,
    this.maxMembers,
    this.thumbnailImageId = unset,
  });

  final String? name;
  final int? maxMembers;
  final Object? thumbnailImageId; // null=썸네일 삭제, unset=변경 없음

  static const Object unset = Object();

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (maxMembers != null) body['maxMembers'] = maxMembers;
    if (!identical(thumbnailImageId, unset)) {
      body['thumbnailImageId'] = thumbnailImageId;
    }
    return body;
  }
}
