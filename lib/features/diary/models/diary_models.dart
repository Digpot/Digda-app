import '../../common/models/common_models.dart';

/// 7번 도메인(Diary) DTO 정의.

DateTime _parseUtc(String s) {
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }
  if (s.contains('T')) return DateTime.parse('${s}Z');
  return DateTime.parse(s);
}

/// 이모지 리액션 종류. 서버 enum 과 일치.
enum DiaryReactionType {
  heart('HEART'),
  cry('CRY'),
  sparkle('SPARKLE'),
  laugh('LAUGH'),
  fire('FIRE');

  const DiaryReactionType(this.wire);

  /// 서버에서 받은 enum name 문자열.
  final String wire;

  static DiaryReactionType? tryParse(String? s) {
    if (s == null) return null;
    for (final t in values) {
      if (t.wire == s) return t;
    }
    return null;
  }
}

class DiaryReactionSummary {
  DiaryReactionSummary({
    required this.type,
    required this.count,
    required this.reactedByMe,
  });

  final DiaryReactionType type;
  final int count;
  final bool reactedByMe;

  factory DiaryReactionSummary.fromJson(Map<String, dynamic> json) {
    return DiaryReactionSummary(
      type: DiaryReactionType.tryParse(json['type'] as String?) ??
          DiaryReactionType.heart,
      count: (json['count'] as num? ?? 0).toInt(),
      reactedByMe: json['reactedByMe'] as bool? ?? false,
    );
  }
}

class DiarySummary {
  DiarySummary({
    required this.id,
    required this.title,
    required this.date,
    required this.weather,
    required this.mood,
    this.location,
    this.thumbnailUrl,
    required this.imageCount,
    required this.createdBy,
    required this.commentCount,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime date;
  final int weather; // 0 맑음 / 1 구름 / 2 비 / 3 눈
  final int mood; // 0 행복 / 1 평온 / 2 슬픔 / 3 화남 / 4 피곤
  final String? location;
  final String? thumbnailUrl;
  final int imageCount;
  final UserSummary createdBy;
  final int commentCount;
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;

  factory DiarySummary.fromJson(Map<String, dynamic> json) {
    return DiarySummary(
      id: json['id'].toString(),
      title: json['title'] as String,
      date: _parseUtc(json['date'] as String).toLocal(),
      weather: (json['weather'] as num).toInt(),
      mood: (json['mood'] as num).toInt(),
      location: json['location'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageCount: (json['imageCount'] as num? ?? 0).toInt(),
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      commentCount: (json['commentCount'] as num? ?? 0).toInt(),
      likeCount: (json['likeCount'] as num? ?? 0).toInt(),
      likedByMe: json['likedByMe'] as bool? ?? false,
      createdAt: _parseUtc(json['createdAt'] as String),
    );
  }
}

/// 7-2. 일기 캘린더 — 날짜별 대표 일기(사진 그리드용).
class DiaryCalendarEntry {
  DiaryCalendarEntry({
    required this.date,
    required this.diaryId,
    this.thumbnailUrl,
    required this.mood,
    required this.count,
  });

  final DateTime date; // 로컬 날짜(자정)
  final String diaryId;
  final String? thumbnailUrl;
  final int mood; // 0 행복 / 1 평온 / 2 슬픔 / 3 화남 / 4 피곤
  final int count; // 그날 작성된 일기 편수

  factory DiaryCalendarEntry.fromJson(Map<String, dynamic> json) {
    final d = _parseUtc(json['date'] as String).toLocal();
    return DiaryCalendarEntry(
      date: DateTime(d.year, d.month, d.day),
      diaryId: json['diaryId'].toString(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mood: (json['mood'] as num? ?? 0).toInt(),
      count: (json['count'] as num? ?? 1).toInt(),
    );
  }
}

/// 통계 스트립 값 — 편수/연속 기록/최다 기분.
class DiaryCalendarStats {
  DiaryCalendarStats({
    required this.count,
    required this.streak,
    this.topMood,
  });

  final int count;
  final int streak;
  final int? topMood;

  factory DiaryCalendarStats.fromJson(Map<String, dynamic> json) {
    return DiaryCalendarStats(
      count: (json['count'] as num? ?? 0).toInt(),
      streak: (json['streak'] as num? ?? 0).toInt(),
      topMood: (json['topMood'] as num?)?.toInt(),
    );
  }
}

/// 7-2. 일기 캘린더 응답 전체.
class DiaryCalendarResult {
  DiaryCalendarResult({
    required this.dates,
    required this.entries,
    required this.stats,
  });

  final List<DateTime> dates; // 일기 있는 날 (하위호환)
  final List<DiaryCalendarEntry> entries;
  final DiaryCalendarStats stats;

  /// 날짜(자정) → 대표 일기 매핑.
  Map<DateTime, DiaryCalendarEntry> get byDay => {
        for (final e in entries)
          DateTime(e.date.year, e.date.month, e.date.day): e,
      };

  factory DiaryCalendarResult.fromJson(Map<String, dynamic> json) {
    final entries = ((json['entries'] as List?) ?? const [])
        .map((e) => DiaryCalendarEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    // dates 가 비어도 entries 에서 역산(구버전/신버전 모두 대응).
    final rawDates = (json['dates'] as List?) ?? const [];
    final dates = rawDates.isNotEmpty
        ? rawDates.map((e) {
            final d = _parseUtc(e as String).toLocal();
            return DateTime(d.year, d.month, d.day);
          }).toList()
        : entries.map((e) => e.date).toList();
    return DiaryCalendarResult(
      dates: dates,
      entries: entries,
      stats: json['stats'] != null
          ? DiaryCalendarStats.fromJson(json['stats'] as Map<String, dynamic>)
          : DiaryCalendarStats(count: 0, streak: 0),
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
    this.location,
    required this.imageUrls,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.likeCount,
    required this.likedByMe,
    required this.reactions,
  });

  final String id;
  final String title;
  final String content;
  final DateTime date;
  final int weather;
  final int mood;
  final String? location;
  final List<String> imageUrls;
  final UserSummary createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final bool likedByMe;
  final List<DiaryReactionSummary> reactions;

  factory Diary.fromJson(Map<String, dynamic> json) {
    return Diary(
      id: json['id'].toString(),
      title: json['title'] as String,
      content: json['content'] as String,
      date: _parseUtc(json['date'] as String).toLocal(),
      weather: (json['weather'] as num).toInt(),
      mood: (json['mood'] as num).toInt(),
      location: json['location'] as String?,
      imageUrls: ((json['imageUrls'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      createdBy:
          UserSummary.fromJson(json['createdBy'] as Map<String, dynamic>),
      createdAt: _parseUtc(json['createdAt'] as String),
      updatedAt: _parseUtc(json['updatedAt'] as String),
      likeCount: (json['likeCount'] as num? ?? 0).toInt(),
      likedByMe: json['likedByMe'] as bool? ?? false,
      reactions: ((json['reactions'] as List?) ?? const [])
          .map((e) =>
              DiaryReactionSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
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

class DiaryLikeResult {
  DiaryLikeResult({required this.likedByMe, required this.likeCount});

  final bool likedByMe;
  final int likeCount;

  factory DiaryLikeResult.fromJson(Map<String, dynamic> json) =>
      DiaryLikeResult(
        likedByMe: json['likedByMe'] as bool? ?? false,
        likeCount: (json['likeCount'] as num? ?? 0).toInt(),
      );
}

class DiaryReactionToggleResult {
  DiaryReactionToggleResult({required this.reactions});

  final List<DiaryReactionSummary> reactions;

  factory DiaryReactionToggleResult.fromJson(Map<String, dynamic> json) =>
      DiaryReactionToggleResult(
        reactions: ((json['reactions'] as List?) ?? const [])
            .map((e) =>
                DiaryReactionSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 작성/수정 공용 요청.
/// - [imageIds] : null=변경없음(수정시), 빈배열=이미지전부제거, 값=교체. 작성시엔 null=빈배열로 송신.
/// - [location] : null=변경없음(수정시) 또는 미지정(작성시)
class DiaryWriteRequest {
  const DiaryWriteRequest({
    this.title,
    this.content,
    this.date,
    this.weather,
    this.mood,
    this.location = unset,
    this.imageIds = unset,
  });

  factory DiaryWriteRequest.create({
    required String title,
    required String content,
    required DateTime date,
    required int weather,
    required int mood,
    String? location,
    required List<String> imageIds,
  }) {
    return DiaryWriteRequest(
      title: title,
      content: content,
      date: date,
      weather: weather,
      mood: mood,
      location: location,
      imageIds: imageIds,
    );
  }

  final String? title;
  final String? content;
  final DateTime? date;
  final int? weather;
  final int? mood;
  final Object? location; // unset=변경없음, null/빈문자열=제거, String=설정
  final Object? imageIds; // unset=변경없음, List<String>(빈배열=제거, 값=교체)

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
    if (!identical(location, unset)) body['location'] = location;
    if (!identical(imageIds, unset)) body['imageIds'] = imageIds;
    return body;
  }
}
