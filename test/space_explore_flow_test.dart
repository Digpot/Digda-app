import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/screens/character/space_explore_screen.dart';

/// 우주 탐험(자유비행) 스모크 — 렌더 → 조종(추진 비행) → 행성 근접 →
/// 탐험 시트 → 진행도 갱신까지 예외 없이 동작하는지 검증한다.
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
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  testWidgets('초기 렌더 — HUD/조종 안내/진행도', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpExplore(tester);
    expect(find.text('우주 탐험'), findsOneWidget);
    expect(find.text('우주선 조종법'), findsOneWidget); // 첫 진입 안내
    expect(find.textContaining('0/9'), findsOneWidget); // 진행도

    // 몇 프레임 돌려도(별 반짝임/부유) 예외가 없어야 한다.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('추진 비행 → 행성 근접 → 탐험 시트 → 진행도 1/9', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpExplore(tester);

    // 우주선 시작(520,1000) 근처에서 수성(760,850) 방향으로 화면을 꾹 누른다.
    // 시작 카메라는 (340,610) — 수성의 화면 좌표는 (420,240) 근방.
    final TestGesture g =
        await tester.startGesture(const Offset(320, 250));
    // 안내 문구는 첫 터치에 사라진다.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('우주선 조종법'), findsNothing);

    // 근접 프롬프트가 뜰 때까지 비행 (최대 ~4초 시뮬레이션).
    var found = false;
    for (var i = 0; i < 250; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('🔭 수성 탐험하기').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 32));
    expect(found, isTrue, reason: '추진 비행으로 수성 근접 프롬프트가 떠야 한다');
    expect(tester.takeException(), isNull);

    // 탐험 시트 열기 — 스탯/일지/연대기 노출.
    await tester.tap(find.text('🔭 수성 탐험하기'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('수성 도착!'), findsOneWidget);
    expect(find.text('행성 연대기'), findsOneWidget);

    // 닫으면 진행도 1/9 + 탐험 완료 뱃지.
    await tester.scrollUntilVisible(find.text('계속 탐험하기'), 300,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('계속 탐험하기'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('1/9'), findsOneWidget);
    expect(find.text('탐험 완료 ✓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
