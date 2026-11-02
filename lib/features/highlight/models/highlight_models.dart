// 월간 하이라이트("지난달의 디그팟") DTO. 서버 `HighlightResponses.kt` 와 필드명을 맞춘다.

DateTime _parseServerTime(String s) {
  // 서버는 타임존 표기 없는 KST wall-clock 을 내려준다. 오프셋이 붙은 값만 toLocal 변환.
  if (s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
  return DateTime.parse(s);
}

class HighlightListItem {
  HighlightListItem({
    required this.month,
    required this.year,
    required this.monthValue,
    required this.title,
    required this.totalDiaryCount,
    required this.generatedAt,
    this.coverImageUrl,
  });

  /// "yyyy-MM"
  final String month;
  final int year;
  final int monthValue;
  final String title;
  final int totalDiaryCount;
  final String? coverImageUrl;
  final DateTime generatedAt;

  factory HighlightListItem.fromJson(Map<String, dynamic> json) {
    return HighlightListItem(
      month: json['month'] as String,
      year: (json['year'] as num).toInt(),
      monthValue: (json['monthValue'] as num).toInt(),
      title: json['title'] as String? ?? '',
      totalDiaryCount: (json['totalDiaryCount'] as num? ?? 0).toInt(),
      coverImageUrl: json['coverImageUrl'] as String?,
      generatedAt: _parseServerTime(json['generatedAt'] as String),
    );
  }
}

class HighlightMember {
  HighlightMember({
    required this.userId,
    required this.name,
    required this.diaryCount,
    this.profileImage,
  });

  final String userId;
  final String name;
  final String? profileImage;
  final int diaryCount;

  factory HighlightMember.fromJson(Map<String, dynamic> json) {
    return HighlightMember(
      userId: json['userId'].toString(),
      name: json['name'] as String? ?? '',
      profileImage: json['profileImage'] as String?,
      diaryCount: (json['diaryCount'] as num? ?? 0).toInt(),
    );
  }
}

class HighlightDiary {
  HighlightDiary({
    required this.diaryId,
    required this.title,
    required this.excerpt,
    required this.date,
    required this.authorName,
    required this.likeCount,
    required this.reactionCount,
    required this.commentCount,
    this.imageUrl,
  });

  final String diaryId;
  final String title;
  final String excerpt;

  /// yyyy-MM-dd
  final String date;
  final String authorName;
  final String? imageUrl;
  final int likeCount;
  final int reactionCount;
  final int commentCount;

  /// 좋아요 + 이모지 반응 + 댓글 — 0 이면 반응 배지를 숨긴다.
  int get engagement => likeCount + reactionCount + commentCount;

  factory HighlightDiary.fromJson(Map<String, dynamic> json) {
    return HighlightDiary(
      diaryId: json['diaryId'].toString(),
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      date: json['date'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      likeCount: (json['likeCount'] as num? ?? 0).toInt(),
      reactionCount: (json['reactionCount'] as num? ?? 0).toInt(),
      commentCount: (json['commentCount'] as num? ?? 0).toInt(),
    );
  }
}

class HighlightDetail {
  HighlightDetail({
    required this.month,
    required this.year,
    required this.monthValue,
    required this.title,
    required this.groupRoomName,
    required this.totalDiaryCount,
    required this.activeDays,
    required this.daysInMonth,
    required this.members,
    required this.topWriters,
    required this.photos,
    required this.featuredDiaries,
    required this.summary,
    required this.closingMessage,
    this.coverImageUrl,
    this.topLocation,
    this.busiestWeekday,
  });

  final String month;
  final int year;
  final int monthValue;
  final String title;
  final String groupRoomName;
  final int totalDiaryCount;
  final int activeDays;
  final int daysInMonth;
  final List<HighlightMember> members;
  final List<HighlightMember> topWriters;
  final String? coverImageUrl;
  final List<String> photos;
  final List<HighlightDiary> featuredDiaries;
  final String? topLocation;

  /// 1=월 … 7=일
  final int? busiestWeekday;
  final String summary;
  final String closingMessage;

  factory HighlightDetail.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List? ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return HighlightDetail(
      month: json['month'] as String,
      year: (json['year'] as num).toInt(),
      monthValue: (json['monthValue'] as num).toInt(),
      title: json['title'] as String? ?? '',
      groupRoomName: json['groupRoomName'] as String? ?? '',
      totalDiaryCount: (json['totalDiaryCount'] as num? ?? 0).toInt(),
      activeDays: (json['activeDays'] as num? ?? 0).toInt(),
      daysInMonth: (json['daysInMonth'] as num? ?? 30).toInt(),
      members: list('members', HighlightMember.fromJson),
      topWriters: list('topWriters', HighlightMember.fromJson),
      coverImageUrl: json['coverImageUrl'] as String?,
      photos: (json['photos'] as List? ?? []).map((e) => e as String).toList(),
      featuredDiaries: list('featuredDiaries', HighlightDiary.fromJson),
      topLocation: json['topLocation'] as String?,
      busiestWeekday: (json['busiestWeekday'] as num?)?.toInt(),
      summary: json['summary'] as String? ?? '',
      closingMessage: json['closingMessage'] as String? ?? '',
    );
  }
}
