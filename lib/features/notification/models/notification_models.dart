/// 10번 도메인(Notification) DTO 정의.

/// 서버에서 수신한 datetime 문자열을 UTC로 파싱한다.
/// 타임존 정보가 없는 문자열은 UTC로 간주해 KST 표기에서 9시간 오차를 방지.
DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

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
      createdAt: _parseUtc(json['createdAt'] as String),
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
  static const String scheduleDayBefore = 'schedule_day_before';
  static const String scheduleToday = 'schedule_today';
  static const String diaryWritten = 'diary_written';
  static const String commentOnSchedule = 'comment_on_schedule';
  static const String commentOnDiary = 'comment_on_diary';
  static const String memberJoined = 'member_joined';
  static const String memberLeft = 'member_left';
  static const String memberRemoved = 'member_removed';
  static const String ownershipTransferred = 'ownership_transferred';
  static const String groupDeleteScheduled = 'group_delete_scheduled';
  // 모찌 관련 ─────────────────────────────────────
  static const String quizCreated = 'quiz_created';
  static const String quizAnswered = 'quiz_answered';
  static const String mochiLevelup = 'mochi_levelup';
  static const String dikoUnlocked = 'diko_unlocked';
  static const String announcement = 'announcement';

  /// 모찌 캐릭터/퀴즈와 관련된 4종. 알림 필터 칩 동작 + 모찌 화면 헤더 카운트 산정용.
  static const Set<String> mochiTypes = {
    quizCreated,
    quizAnswered,
    mochiLevelup,
    dikoUnlocked,
  };
}
