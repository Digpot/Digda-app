import 'package:digda/features/highlight/models/highlight_models.dart';
import 'package:digda/screens/highlight/highlight_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HighlightDetail _detail({bool withPhotos = true}) => HighlightDetail(
      month: '2026-10',
      year: 2026,
      monthValue: 10,
      title: '2026년 10월, 우리의 기록',
      groupRoomName: '우리집',
      totalDiaryCount: 23,
      activeDays: 18,
      daysInMonth: 31,
      members: [
        HighlightMember(userId: 'a', name: '가은', diaryCount: 12),
        HighlightMember(userId: 'b', name: '나래', diaryCount: 8),
        HighlightMember(userId: 'c', name: '다온', diaryCount: 0),
      ],
      topWriters: [HighlightMember(userId: 'a', name: '가은', diaryCount: 12)],
      photos: withPhotos ? const ['http://localhost/a.jpg', 'http://localhost/b.jpg', 'http://localhost/c.jpg'] : const [],
      featuredDiaries: [
        HighlightDiary(
          diaryId: '1',
          title: '제주도 여행 첫째 날',
          excerpt: '비행기에서 내리자마자 바람이 정말 시원했다. ' * 4,
          date: '2026-10-05',
          authorName: '가은',
          likeCount: 3,
          reactionCount: 2,
          commentCount: 4,
        ),
        HighlightDiary(
          diaryId: '2',
          title: '평범한 하루',
          excerpt: '짧은 글',
          date: '2026-10-09',
          authorName: '나래',
          likeCount: 0,
          reactionCount: 0,
          commentCount: 0,
        ),
      ],
      topLocation: '제주',
      busiestWeekday: 6,
      summary: '10월에는 18일 동안 모두 23편의 일기가 쌓였어요.',
      closingMessage: '10월의 소중한 순간들이 차곡차곡 모였어요. 11월에도 함께해요!',
    );

void main() {
  for (final size in const [Size(360, 740), Size(412, 915)]) {
    testWidgets('하이라이트 화면이 예외 없이 그려진다 $size', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final d = _detail();
      await tester.pumpWidget(MaterialApp(
        home: HighlightScreen(
          previewItems: [
            HighlightListItem(
              month: '2026-10',
              year: 2026,
              monthValue: 10,
              title: 't',
              totalDiaryCount: 23,
              generatedAt: DateTime(2026, 11, 1),
            ),
            HighlightListItem(
              month: '2026-09',
              year: 2026,
              monthValue: 9,
              title: 't',
              totalDiaryCount: 5,
              generatedAt: DateTime(2026, 10, 1),
            ),
          ],
          previewDetail: d,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('우리의 기록'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);

      // 끝까지 스크롤하며 각 섹션이 빌드되는지 확인.
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 8; i++) {
        await tester.drag(list, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(find.text('일기 보러가기'), findsWidgets);
      expect(tester.takeException(), isNull);
      // 이미지 재시도 타이머가 끝나도록 충분히 흘려보낸다.
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
