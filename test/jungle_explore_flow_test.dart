import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/screens/character/explore_hub_screen.dart';
import 'package:digda/screens/character/jungle_explore_screen.dart';

/// 정글 탐험(자유비행 열기구) + 허브에 정글 카드가 붙었는지 스모크 검증.
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

  testWidgets('허브에 우주·해저·정글 카드가 모두 있다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ExploreHubScreen(character: fakeState())),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('우주 탐험'), findsOneWidget);
    expect(find.text('해저 탐험'), findsOneWidget);
    expect(find.text('정글 탐험'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('열기구 비행 → 신전 근접 → 탐험 시트 → 진행도 1/6', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: JungleExploreScreen(character: fakeState())),
    );
    await settleSvg(tester);
    expect(find.text('열기구 조종법'), findsOneWidget);
    expect(find.textContaining('0/6'), findsOneWidget);

    // 열기구 시작(420,900) → 잊혀진 신전(760,980) 방향(화면 오른쪽 아래)으로
    // 꾹 누른다. 화면 폭이 360 이므로 x 는 그 안이어야 한다.
    final g = await tester.startGesture(const Offset(350, 470));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('열기구 조종법'), findsNothing);

    var found = false;
    for (var i = 0; i < 250; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('🔍 잊혀진 신전 탐험하기').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 32));
    expect(found, isTrue, reason: '열기구 비행으로 신전 근접 프롬프트가 떠야 한다');

    await tester.tap(find.text('🔍 잊혀진 신전 탐험하기'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('잊혀진 신전 도착!'), findsOneWidget);
    expect(find.text('밀림 연대기'), findsOneWidget);

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
