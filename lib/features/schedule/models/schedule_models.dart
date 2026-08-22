import '../../common/models/common_models.dart';
import '../../ledger/models/ledger_models.dart';

/// 6번 도메인(Schedule) DTO 정의.

DateTime _parseServerTime(String s) {
  // 서버(JVM TZ=Asia/Seoul)는 타임존 표기 없는 KST wall-clock 을 내려주므로,
  // 표기 없으면 로컬(KST)로 그대로 파싱한다. 예전처럼 'Z'를 붙이면 +9시간 어긋난다.
  // Z/오프셋이 붙은 값만 실제 시각으로 보고 toLocal 로 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
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
    this.hidden = false,
    this.hiddenReason,
    this.expenses = const [],
    this.expenseTotal = 0,
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

  /// 차단/신고로 내게 숨겨진 일정. 목록에선 보통 제외되며 상세 직접 접근 방어용.
  final bool hidden;
  final String? hiddenReason;

  /// 그룹 가계부 — 이 일정에서 쓴 돈.
  final List<ScheduleExpense> expenses;

  /// 지출 합계. 캘린더 가계부 모드가 금액만 필요할 때 쓴다.
  final int expenseTotal;

  bool get hasExpense => expenseTotal > 0;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
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
      createdAt: _parseServerTime(json['createdAt'] as String),
      hidden: json['hidden'] as bool? ?? false,
      hiddenReason: json['hiddenReason'] as String?,
      expenses: (json['expenses'] as List? ?? [])
          .map((e) => ScheduleExpense.fromJson(e as Map<String, dynamic>))
          .toList(),
      expenseTotal: (json['expenseTotal'] as num? ?? 0).toInt(),
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
    this.expenses,
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
    List<ExpenseWrite>? expenses,
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
      expenses: expenses,
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

  /// 그룹 가계부 지출 목록.
  ///
  /// null 과 빈 배열의 의미가 다르다 — null 이면 서버가 지출을 손대지 않고,
  /// 빈 배열이면 이 일정의 지출을 전부 지운다. 그래서 아래 toJson 도 `!= null`
  /// 로만 걸러야 하고, `isNotEmpty` 로 거르면 '전부 삭제'가 서버에 도달하지 못한다.
  final List<ExpenseWrite>? expenses;

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
    if (expenses != null) {
      body['expenses'] = expenses!.map((e) => e.toJson()).toList();
    }
    return body;
  }
}
