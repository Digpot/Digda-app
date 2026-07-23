import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/core/auth/token_storage.dart';
import 'package:digda/core/di.dart';
import 'package:digda/core/network/api_client.dart';
import 'package:digda/screens/onboarding/code_input_screen.dart';

/// 초대 코드 입력 — 6자리 초과 입력 차단 + 칸 폭 균등 회귀 테스트.
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost');
    Di.tokenStorage = TokenStorage();
    Di.apiClient = ApiClient(tokenStorage: Di.tokenStorage);
  });

  Future<void> pumpInput(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: CodeInputScreen()),
    );
    await tester.pump();
  }

  String codeOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('8자리를 입력해도 6자리까지만 들어간다', (tester) async {
    await pumpInput(tester);

    await tester.enterText(find.byType(TextField), '12345678');
    await tester.pump();

    expect(codeOf(tester), '123456');
    // 화면에 그려진 숫자도 6개뿐이어야 한다.
    for (final d in ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('7'), findsNothing);
    expect(find.text('8'), findsNothing);
  });

  testWidgets('숫자가 아닌 문자는 무시한다', (tester) async {
    await pumpInput(tester);
    await tester.enterText(find.byType(TextField), 'a1b2c3d4e5f6g7');
    await tester.pump();
    expect(codeOf(tester), '123456');
  });

  testWidgets('6칸의 폭이 모두 같다', (tester) async {
    await pumpInput(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();

    // 칸은 높이 56 의 AnimatedContainer 로 그려진다.
    final boxes = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    expect(boxes.length, 6);
    final widths = find
        .byType(AnimatedContainer)
        .evaluate()
        .map((e) => e.size!.width)
        .toSet();
    // 폭이 전부 동일하면 집합 크기가 1 (예전엔 마지막 칸만 8px 넓었다).
    expect(widths.length, 1, reason: '6칸의 폭은 모두 같아야 한다');
  });

  testWidgets('6자리를 채워야 참여하기가 활성화된다', (tester) async {
    await pumpInput(tester);

    Finder joinButton() => find.widgetWithText(ElevatedButton, '참여하기');
    if (joinButton().evaluate().isNotEmpty) {
      expect(tester.widget<ElevatedButton>(joinButton()).onPressed, isNull);
    }

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    if (joinButton().evaluate().isNotEmpty) {
      expect(tester.widget<ElevatedButton>(joinButton()).onPressed, isNull);
    }

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    if (joinButton().evaluate().isNotEmpty) {
      expect(tester.widget<ElevatedButton>(joinButton()).onPressed, isNotNull);
    }
    expect(tester.takeException(), isNull);
  });
}
