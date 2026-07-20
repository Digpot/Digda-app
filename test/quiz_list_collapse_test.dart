import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/core/auth/token_storage.dart';
import 'package:digda/core/di.dart';
import 'package:digda/core/network/api_client.dart';
import 'package:digda/features/character/data/character_repository.dart';
import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/features/group_room/state/active_group_session.dart';
import 'package:digda/screens/character/quiz/character_quiz_list_screen.dart';

/// 퀴즈 목록의 날짜 섹션 기본 접힘(오늘만 펼침) + 전체 열기/닫기 검증.
class _FakeCharacterRepository extends CharacterRepository {
  _FakeCharacterRepository({required super.apiClient});

  /// Di 필드가 late final 이라 한 번만 주입할 수 있어, 인스턴스는 하나를 두고
  /// 테스트마다 응답할 목록만 바꾼다.
  List<CharacterQuiz> quizzes = const [];

  @override
  Future<CharacterQuizListResult> listQuizzes({
    required int groupRoomId,
    int page = 0,
    int size = 20,
  }) async {
    return CharacterQuizListResult(
      items: quizzes,
      page: 0,
      totalPages: 1,
      totalElements: quizzes.length,
    );
  }

  @override
  Future<CharacterState> getMyState({required int groupRoomId}) async {
    throw StateError('캐릭터 상태는 best-effort — 실패해도 목록은 떠야 한다');
  }
}

CharacterQuiz _quiz(int id, DateTime createdAt) => CharacterQuiz(
      id: id,
      groupRoomId: 1,
      category: QuizCategory.general,
      categoryDisplayName: '일반',
      question: '퀴즈 $id 질문',
      options: const ['1번', '2번', '3번', '4번'],
      expMultiplier: 1,
      authorName: '모찌',
      createdAt: createdAt,
    );

void main() {
  final now = DateTime.now();
  // 최신순(오늘 → 어제 → 그제) 정렬된 응답을 가정.
  final today = _quiz(1, now);
  final yesterday = _quiz(2, now.subtract(const Duration(days: 1)));
  final twoDaysAgo = _quiz(3, now.subtract(const Duration(days: 2)));

  late _FakeCharacterRepository fakeRepo;

  setUpAll(() {
    // ApiClient 생성자가 Env(dotenv) 를 읽으므로 테스트용 값을 심어 둔다.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost');
    Di.tokenStorage = TokenStorage();
    Di.apiClient = ApiClient(tokenStorage: Di.tokenStorage);
    Di.activeGroup = ActiveGroupSession()
      ..enter(groupRoomId: '1', groupRoomName: '테스트방', isOwner: true);
    fakeRepo = _FakeCharacterRepository(apiClient: Di.apiClient);
    Di.characterRepository = fakeRepo;
  });

  Future<void> pumpList(WidgetTester tester, List<CharacterQuiz> quizzes) async {
    fakeRepo.quizzes = quizzes;
    await tester.pumpWidget(
      const MaterialApp(home: CharacterQuizListScreen()),
    );
    await tester.pump(); // postFrameCallback 의 _fetchPage
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('오늘 섹션만 펼치고 나머지는 접는다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpList(tester, [today, yesterday, twoDaysAgo]);

    // 헤더는 3개 모두 보이고, 카드는 오늘 것만 펼쳐져 있다.
    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('어제'), findsOneWidget);
    expect(find.text('퀴즈 1 질문'), findsOneWidget);
    expect(find.text('퀴즈 2 질문'), findsNothing);
    expect(find.text('퀴즈 3 질문'), findsNothing);
  });

  testWidgets('오늘이 없으면 가장 최근 날짜만 펼친다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpList(tester, [yesterday, twoDaysAgo]);

    expect(find.text('오늘'), findsNothing);
    expect(find.text('퀴즈 2 질문'), findsOneWidget); // 어제 = 최근
    expect(find.text('퀴즈 3 질문'), findsNothing);
  });

  testWidgets('전체 열기 / 전체 닫기', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpList(tester, [today, yesterday, twoDaysAgo]);
    expect(find.text('날짜 3 · 문제 3'), findsOneWidget);

    await tester.tap(find.text('전체 열기'));
    await tester.pump();
    // 접혀 있던 어제 섹션의 카드가 드러난다. (셋째 카드는 화면 밖이라
    // ListView.builder 가 아직 만들지 않으므로 스크롤해서 확인한다.)
    expect(find.text('퀴즈 1 질문'), findsOneWidget);
    expect(find.text('퀴즈 2 질문'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('퀴즈 3 질문'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump();

    await tester.tap(find.text('전체 닫기'));
    await tester.pump();
    expect(find.text('퀴즈 1 질문'), findsNothing);
    expect(find.text('퀴즈 2 질문'), findsNothing);
    expect(find.text('퀴즈 3 질문'), findsNothing);
    // 헤더는 남아 있어야 한다.
    expect(find.text('오늘'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색 중에는 접힘을 무시하고 전부 보여준다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpList(tester, [today, yesterday, twoDaysAgo]);
    await tester.enterText(find.byType(TextField), '퀴즈 2');
    await tester.pump();

    // 접혀 있던 어제 섹션의 결과도 검색 중엔 펼쳐서 보여준다.
    expect(find.text('퀴즈 2 질문'), findsOneWidget);
    // 검색 중엔 툴바를 감춘다.
    expect(find.text('전체 열기'), findsNothing);
  });
}
