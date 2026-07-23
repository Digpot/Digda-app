import 'package:flutter/material.dart';

import '../features/character/models/character_models.dart';
import '../screens/character/explore_hub_screen.dart';

/// 탐험(허브/우주/해저) UI 확인용 dev 엔트리포인트 — 로그인/서버 없이 띄운다.
///
///   flutter run -d <device> -t lib/dev/space_preview_main.dart
///
/// 가짜 CharacterState(Lv.7 BLOOM) 로 진입하므로 서버/DI 부트스트랩이 필요 없다.
void main() {
  runApp(const _ExplorePreviewApp());
}

class _ExplorePreviewApp extends StatelessWidget {
  const _ExplorePreviewApp();

  @override
  Widget build(BuildContext context) {
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ExploreHubScreen(character: fake),
    );
  }
}
