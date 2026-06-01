/// 3번 도메인(GroupRoom) DTO 정의.

/// 서버에서 수신한 datetime 문자열을 UTC로 파싱한다.
/// 타임존 정보 없는 문자열(예: "2025-05-21T12:00:00")은 UTC로 간주해 9시간 오차를 방지.
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
      createdAt: _parseUtc(json['createdAt'] as String),
      deleteScheduledAt: _tryParseUtc(json['deleteScheduledAt'] as String?),
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
    this.deleteScheduledAt,
  });

  final String id;
  final String name;
  final String? thumbnailImage;
  final int memberCount;
  final int maxMembers;
  final String myRole; // 'owner' | 'member'
  final DateTime lastActivityAt;
  final bool isDeleteScheduled;
  final DateTime? deleteScheduledAt;

  bool get isOwner => myRole == 'owner';

  factory GroupRoomListItem.fromJson(Map<String, dynamic> json) {
    return GroupRoomListItem(
      id: json['id'].toString(),
      name: json['name'] as String,
      thumbnailImage: json['thumbnailImage'] as String?,
      memberCount: (json['memberCount'] as num).toInt(),
      maxMembers: (json['maxMembers'] as num).toInt(),
      myRole: json['myRole'] as String? ?? 'member',
      lastActivityAt: _parseUtc(json['lastActivityAt'] as String),
      isDeleteScheduled: json['isDeleteScheduled'] as bool? ?? false,
      deleteScheduledAt: _tryParseUtc(json['deleteScheduledAt'] as String?),
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

/// `GET /group-rooms/:id/home` — 그룹 홈 대시보드 집계 응답.
/// 활동 피드(최근 소식)는 별도 `/notifications` 로 가져오므로 여기 포함되지 않는다.
class GroupHomeData {
  GroupHomeData({
    required this.userName,
    required this.today,
    required this.activeGroup,
  });

  final String userName;
  final TodaySummary today;
  final ActiveGroupSummary activeGroup;

  factory GroupHomeData.fromJson(Map<String, dynamic> json) {
    return GroupHomeData(
      userName: json['userName'] as String? ?? '',
      today: TodaySummary.fromJson(
        (json['today'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      activeGroup: ActiveGroupSummary.fromJson(
        (json['activeGroup'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class TodaySummary {
  TodaySummary({
    required this.scheduleCount,
    required this.newDiaryCount,
    required this.unreadCount,
  });

  final int scheduleCount;
  final int newDiaryCount;
  final int unreadCount;

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    return TodaySummary(
      scheduleCount: (json['scheduleCount'] as num? ?? 0).toInt(),
      newDiaryCount: (json['newDiaryCount'] as num? ?? 0).toInt(),
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
    );
  }
}

class ActiveGroupSummary {
  ActiveGroupSummary({
    required this.id,
    required this.name,
    this.thumbnailImage,
    required this.memberCount,
    required this.myRole,
    required this.members,
    this.nextEvent,
  });

  final String id;
  final String name;
  final String? thumbnailImage;
  final int memberCount;
  final String myRole; // 'owner' | 'member'
  final List<MembershipSummary> members;
  final HomeNextEvent? nextEvent;

  bool get isOwner => myRole == 'owner';

  factory ActiveGroupSummary.fromJson(Map<String, dynamic> json) {
    final next = json['nextEvent'];
    return ActiveGroupSummary(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      thumbnailImage: json['thumbnailImage'] as String?,
      memberCount: (json['memberCount'] as num? ?? 0).toInt(),
      myRole: json['myRole'] as String? ?? 'member',
      members: (json['members'] as List? ?? [])
          .map((e) => MembershipSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextEvent: next == null
          ? null
          : HomeNextEvent.fromJson((next as Map).cast<String, dynamic>()),
    );
  }
}

/// 활성 그룹 카드에 내장되는 '다가오는 일정' 한 건.
class HomeNextEvent {
  HomeNextEvent({
    required this.id,
    required this.title,
    required this.startDate,
    this.startTime,
    required this.allDay,
    required this.color,
  });

  final String id;
  final String title;
  final DateTime startDate;
  final String? startTime; // 서버 LocalTime 문자열 "HH:mm[:ss]" — 없으면 null
  final bool allDay;
  final String color;

  factory HomeNextEvent.fromJson(Map<String, dynamic> json) {
    return HomeNextEvent(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      startTime: json['startTime'] as String?,
      allDay: json['allDay'] as bool? ?? false,
      color: json['color'] as String? ?? '#FF6B6B',
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
          _parseUtc(json['inviteCodeExpiresAt'] as String),
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
