import 'package:flutter/material.dart';

import '../features/character/models/character_models.dart';
import '../features/character/widgets/animated_mochi_widget.dart';
import '../features/character/widgets/diko_character_view.dart';
import '../features/character/widgets/mochi_character_view.dart';
import '../features/character/widgets/mochi_diko_stage.dart';

/// 캐릭터 렌더 확인용 dev 엔트리포인트 — 로그인/서버 없이 실제 캐릭터 위젯을
/// 그대로 띄운다 (프로덕션 빌드와 무관, main.dart 를 대체하지 않음).
///
///   flutter run -d web-server -t lib/dev/character_preview_main.dart
void main() {
  runApp(const _CharacterPreviewApp());
}

CharacterState _mockState({
  required CharacterStage stage,
  bool dikoUnlocked = false,
  List<EquippedItem> items = const [],
}) {
  return CharacterState(
    stage: stage,
    stageDisplayName: stage.name,
    level: 10,
    exp: 30,
    expForNextLevel: 40,
    coin: 120,
    maxLevelReached: false,
    dikoUnlocked: dikoUnlocked,
    equippedItems: items,
  );
}

class _CharacterPreviewApp extends StatelessWidget {
  const _CharacterPreviewApp();

  @override
  Widget build(BuildContext context) {
    final blossom = _mockState(stage: CharacterStage.blossom, dikoUnlocked: true);
    final accessorized = MochiAppearance(
      skinHex: '#FF6B6B',
      skinAssetKey: 'skin/coral',
      overlays: [
        EquippedItem(
          itemType: ShopItemType.hat,
          itemKey: 'item_hat_party',
          displayName: '파티 모자',
          assetKey: 'item/hat_party',
          layerOrder: 0,
        ),
        EquippedItem(
          itemType: ShopItemType.glasses,
          itemKey: 'item_glasses_round',
          displayName: '동그란 안경',
          assetKey: 'item/glasses_round',
          layerOrder: 1,
        ),
        EquippedItem(
          itemType: ShopItemType.misc,
          itemKey: 'item_balloon',
          displayName: '풍선',
          assetKey: 'item/balloon',
          layerOrder: 2,
        ),
      ],
    );
    const panda = MochiAppearance(
      skinHex: '#9CA3AF',
      skinAssetKey: 'skin/panda',
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF8F8),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('메인 화면 스테이지 (모찌+디코, 실제 위젯)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Center(
                child: MochiDikoStage(
                  state: blossom,
                  mochiController: MochiAnimationController(),
                  onPet: () {},
                ),
              ),
              const SizedBox(height: 24),
              const Text('전 단계 (coral)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final stage in CharacterStage.values)
                    MochiCharacterView(
                      appearance: MochiAppearance.coral,
                      stage: stage,
                      size: 140,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('판다 스킨 / 액세서리 / 디코',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const MochiCharacterView(
                    appearance: panda,
                    stage: CharacterStage.bloom,
                    size: 140,
                  ),
                  MochiCharacterView(
                    appearance: accessorized,
                    stage: CharacterStage.glow,
                    size: 140,
                  ),
                  for (final mood in DikoMood.values)
                    DikoCharacterView(size: 96, mood: mood),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
