import 'package:digda/features/common/models/common_models.dart';
import 'package:digda/features/highlight/models/highlight_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HighlightDetail 파싱 — 선택 필드가 없어도 안전하다', () {
    final d = HighlightDetail.fromJson({
      'month': '2026-10',
      'year': 2026,
      'monthValue': 10,
      'title': '2026년 10월, 우리의 기록',
      'groupRoomName': '우리집',
      'totalDiaryCount': 3,
      'activeDays': 2,
      'daysInMonth': 31,
      'members': [
        {'userId': 'a', 'name': '가은', 'profileImage': null, 'diaryCount': 2},
      ],
      'topWriters': [],
      'coverImageUrl': null,
      'photos': [],
      'featuredDiaries': [
        {
          'diaryId': 7,
          'title': 't',
          'excerpt': 'e',
          'date': '2026-10-05',
          'authorName': '가은',
          'imageUrl': null,
          'likeCount': 1,
          'reactionCount': 0,
          'commentCount': 2,
        }
      ],
      'topLocation': null,
      'busiestWeekday': null,
      'summary': 's',
      'closingMessage': 'c',
    });
    expect(d.members.single.diaryCount, 2);
    expect(d.coverImageUrl, isNull);
    expect(d.busiestWeekday, isNull);
    expect(d.featuredDiaries.single.diaryId, '7');
    expect(d.featuredDiaries.single.engagement, 3);
  });

  test('CommentEntity — createdAt 이 null 이어도 파싱된다', () {
    final base = {
      'id': 1,
      'text': 'hi',
      'createdBy': {'userId': 'u', 'name': 'n'},
    };
    expect(CommentEntity.fromJson({...base, 'createdAt': null}).createdAt,
        isNull);
    final c = CommentEntity.fromJson({...base, 'createdAt': '2026-11-02T14:32:00'});
    expect(c.createdAt, DateTime(2026, 11, 2, 14, 32));
  });
}
