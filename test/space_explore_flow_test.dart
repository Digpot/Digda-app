import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/screens/character/space_explore_screen.dart';

/// 우주 탐험 화면 스모크 — 선택 → 워프 → 도착 → 재선택 플로우가 예외/오버플로
/// 없이 렌더되는지 검증한다. (행성 카드 오버플로 회귀를 잡기 위한 테스트.)
void main() {
  Future<void> pumpExplore(WidgetTester tester) async {
    final fake = CharacterState(
      stage: CharacterStage.bloom,
      stageDisplayName: '블룸',
      level: 7,
      exp: 30,
      expForNextLevel: 100,
      coin: 120,
      maxLevelReached: false,
      dikoUnlocked: false,
      equippedItems: const [],
    );
    await tester.pumpWidget(
      MaterialApp(home: SpaceExploreScreen(character: fake)),
    );
    // SVG(모찌) 디코딩은 실제 async 작업이라 runAsync 로 완료를 기다린다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  testWidgets('선택 화면 — 태양계 전 행성 카드 렌더', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpExplore(tester);
    expect(find.text('우주 탐험'), findsOneWidget);
    expect(find.text('수성'), findsOneWidget);

    // 카드 리스트 끝까지 스크롤해도 오버플로 예외가 없어야 한다.
    await tester.drag(find.byType(ListView).last, const Offset(-1200, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('해왕성'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox()); // 리핏 티커 정리
  });

  testWidgets('워프 → 도착 → 재선택 플로우', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpExplore(tester);
    await tester.tap(find.text('수성'));
    // forward() 는 다음 틱부터 경과시간을 재므로 틱 시작용 pump 를 먼저 한다.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 800)); // 워프 중간
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1000)); // 워프 완료
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('수성 도착!'), findsOneWidget);
    expect(find.text('행성 연대기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 다시 선택 화면으로 — 탐험 완료 뱃지 확인.
    await tester.scrollUntilVisible(find.text('다른 행성도 탐험하기'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('다른 행성도 탐험하기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('탐험 완료 ✓'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox()); // 리핏 티커 정리
  });
}
