import '../../common/models/common_models.dart';

/// 7번 도메인(Diary) DTO 정의.

class DiarySummary {
  DiarySummary({
    required this.id,
    required this.title,
    required this.date,
    required this.weather,
    required this.mood,
    this.imageUrl,
    required this.createdBy,
    required this.commentCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime date;
  final int weather; // 0 맑음 / 1 흐림 / 2 비 / 3 눈
  final int mood; // 0 행복 / 1 사랑 / 2 웃음 / 3 뿌듯
  final String? imageUrl;
  final UserSummary createdBy;
  final int commentCount;
  final DateTime createdAt;

  factory DiarySummary.fromJson(Map<String, dynamic> json) {
    return DiarySummary(
      id: json['id'].toString(),
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      weather: (json['weather'] as num).toInt(),
      mood: (json['mood'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      commentCount: (json['commentCount'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DiaryListResult {
  DiaryListResult({required this.diaries, required this.total});

  final List<DiarySummary> diaries;
  final int total;

  factory DiaryListResult.fromJson(Map<String, dynamic> json) {
    return DiaryListResult(
      diaries: (json['diaries'] as List? ?? [])
          .map((e) => DiarySummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num? ?? 0).toInt(),
    );
  }
}

class Diary {
  Diary({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.weather,
    required this.mood,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime date;
  final int weather;
  final int mood;
  final String? imageUrl;
  final UserSummary createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Diary.fromJson(Map<String, dynamic> json) {
    return Diary(
      id: json['id'].toString(),
      title: json['title'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      weather: (json['weather'] as num).toInt(),
      mood: (json['mood'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class DiaryDetail {
  DiaryDetail({required this.diary, required this.comments});

  final Diary diary;
  final List<CommentEntity> comments;

  factory DiaryDetail.fromJson(Map<String, dynamic> json) {
    return DiaryDetail(
      diary: Diary.fromJson(json['diary'] as Map<String, dynamic>),
      comments: (json['comments'] as List? ?? [])
          .map((e) => CommentEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 작성/수정 공용 요청. imageId 만 null 의미가 있음(이미지 삭제).
class DiaryWriteRequest {
  const DiaryWriteRequest({
    this.title,
    this.content,
    this.date,
    this.weather,
    this.mood,
    this.imageId = unset,
  });

  factory DiaryWriteRequest.create({
    required String title,
    required String content,
    required DateTime date,
    required int weather,
    required int mood,
    String? imageId,
  }) {
    return DiaryWriteRequest(
      title: title,
      content: content,
      date: date,
      weather: weather,
      mood: mood,
      imageId: imageId,
    );
  }

  final String? title;
  final String? content;
  final DateTime? date;
  final int? weather;
  final int? mood;
  final Object? imageId; // null=이미지 제거, unset=변경 없음

  static const Object unset = Object();

  Map<String, dynamic> toJson() {
    String f(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (date != null) body['date'] = f(date!);
    if (weather != null) body['weather'] = weather;
    if (mood != null) body['mood'] = mood;
    if (!identical(imageId, unset)) body['imageId'] = imageId;
    return body;
  }
}
