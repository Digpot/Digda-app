// 10번 도메인(Notification) DTO 정의.

DateTime _parseServerTime(String s) {
  // 서버(JVM TZ=Asia/Seoul)는 타임존 표기 없는 KST wall-clock 을 내려주므로,
  // 표기 없으면 로컬(KST)로 그대로 파싱한다. 예전처럼 'Z'를 붙이면 +9시간 어긋난다.
  // Z/오프셋이 붙은 값만 실제 시각으로 보고 toLocal 로 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
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
      createdAt: _parseServerTime(json['createdAt'] as String),
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

  /// 일기 관련 — 작성 + 일기 댓글. (알림 필터 칩)
  static const Set<String> diaryTypes = {
    diaryWritten,
    commentOnDiary,
  };

  /// 일정 관련 — 작성·수정·리마인더(하루전/당일) + 일정 댓글. (알림 필터 칩)
  static const Set<String> scheduleTypes = {
    scheduleCreated,
    scheduleUpdated,
    scheduleDayBefore,
    scheduleToday,
    commentOnSchedule,
  };
}
