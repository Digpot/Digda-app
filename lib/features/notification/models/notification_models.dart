/// 10번 도메인(Notification) DTO 정의.

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.groupRoomId,
    required this.groupRoomName,
    this.relatedId,
    this.relatedType,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String groupRoomId;
  final String groupRoomName;
  final String? relatedId;
  final String? relatedType; // 'schedule' | 'diary' | 'comment'
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      groupRoomId: json['groupRoomId']?.toString() ?? '',
      groupRoomName: json['groupRoomName'] as String? ?? '',
      relatedId: json['relatedId']?.toString(),
      relatedType: json['relatedType'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class NotificationListResult {
  NotificationListResult({
    required this.notifications,
    required this.total,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int total;
  final int unreadCount;

  factory NotificationListResult.fromJson(Map<String, dynamic> json) {
    return NotificationListResult(
      notifications: (json['notifications'] as List? ?? [])
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num? ?? 0).toInt(),
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
    );
  }
}

/// 알림 유형 enum (서버 type 문자열과 일치).
class NotificationType {
  NotificationType._();
  static const String scheduleCreated = 'schedule_created';
  static const String scheduleUpdated = 'schedule_updated';
  static const String diaryWritten = 'diary_written';
  static const String commentOnSchedule = 'comment_on_schedule';
  static const String commentOnDiary = 'comment_on_diary';
  static const String memberJoined = 'member_joined';
  static const String memberRemoved = 'member_removed';
  static const String groupDeleteScheduled = 'group_delete_scheduled';
}
