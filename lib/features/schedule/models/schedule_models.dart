import '../../common/models/common_models.dart';

/// 6번 도메인(Schedule) DTO 정의.

DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

class Schedule {
  Schedule({
    required this.id,
    required this.title,
    required this.color,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    required this.allDay,
    required this.participants,
    required this.createdBy,
    required this.commentCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String color;
  final DateTime startDate;
  final DateTime endDate;
  final String? startTime; // 'HH:mm'
  final String? endTime;
  final bool allDay;
  final List<UserSummary> participants;
  final UserSummary createdBy;
  final int commentCount;
  final DateTime createdAt;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'].toString(),
      title: json['title'] as String,
      color: json['color'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      allDay: json['allDay'] as bool? ?? true,
      participants: (json['participants'] as List? ?? [])
          .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      commentCount: (json['commentCount'] as num? ?? 0).toInt(),
      createdAt: _parseUtc(json['createdAt'] as String),
    );
  }
}

class ScheduleDetail {
  ScheduleDetail({required this.schedule, required this.comments});

  final Schedule schedule;
  final List<CommentEntity> comments;

  factory ScheduleDetail.fromJson(Map<String, dynamic> json) {
    return ScheduleDetail(
      schedule: Schedule.fromJson(json['schedule'] as Map<String, dynamic>),
      comments: (json['comments'] as List? ?? [])
          .map((e) => CommentEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 6-3. 일정 생성/수정 공용 요청.
class ScheduleWriteRequest {
  const ScheduleWriteRequest({
    this.title,
    this.color,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.allDay,
    this.participantIds,
  });

  /// 생성 시 필수 필드를 모두 채운 빌더.
  factory ScheduleWriteRequest.create({
    required String title,
    required String color,
    required DateTime startDate,
    required DateTime endDate,
    required bool allDay,
    String? startTime,
    String? endTime,
    List<String>? participantIds,
  }) {
    return ScheduleWriteRequest(
      title: title,
      color: color,
      startDate: startDate,
      endDate: endDate,
      allDay: allDay,
      startTime: startTime,
      endTime: endTime,
      participantIds: participantIds,
    );
  }

  final String? title;
  final String? color;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final bool? allDay;
  final List<String>? participantIds;

  Map<String, dynamic> toJson() {
    String f(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (color != null) body['color'] = color;
    if (startDate != null) body['startDate'] = f(startDate!);
    if (endDate != null) body['endDate'] = f(endDate!);
    if (startTime != null) body['startTime'] = startTime;
    if (endTime != null) body['endTime'] = endTime;
    if (allDay != null) body['allDay'] = allDay;
    if (participantIds != null) body['participantIds'] = participantIds;
    return body;
  }
}
