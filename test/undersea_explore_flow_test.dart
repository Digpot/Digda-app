import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/screens/character/explore_hub_screen.dart';
import 'package:digda/screens/character/undersea_explore_screen.dart';

/// 해저 탐험(자유비행 잠수함) + 탐험 허브 스모크.
void main() {
  CharacterState fakeState() => CharacterState(
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

  Future<void> settleSvg(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('탐험 허브 — 우주/해저 카드 렌더와 해저 진입', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ExploreHubScreen(character: fakeState())),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('모찌 탐험대'), findsOneWidget);
    expect(find.text('우주 탐험'), findsOneWidget);
    expect(find.text('해저 탐험'), findsOneWidget);

    await tester.tap(find.text('해저 탐험'));
    await settleSvg(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('잠수함 조종법'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잠수 비행 → 산호초 근접 → 탐험 시트 → 진행도 1/6', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: UnderseaExploreScreen(character: fakeState())),
    );
    await settleSvg(tester);
    expect(find.textContaining('0/6'), findsOneWidget);

    // 잠수함 시작(460,330) → 산호초(700,430) 방향으로 꾹 누른다.
    final g = await tester.startGesture(const Offset(350, 430));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('잠수함 조종법'), findsNothing);

    var found = false;
    for (var i = 0; i < 250; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('🤿 산호초 정원 탐험하기').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 32));
    expect(found, isTrue, reason: '잠수 비행으로 산호초 근접 프롬프트가 떠야 한다');

    await tester.tap(find.text('🤿 산호초 정원 탐험하기'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('산호초 정원 도착!'), findsOneWidget);
    expect(find.text('심해 연대기'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('계속 탐험하기'), 300,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('계속 탐험하기'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('1/6'), findsOneWidget);
    expect(find.text('탐험 완료 ✓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
