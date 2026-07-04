import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/features/character/widgets/diko_character_view.dart';
import 'package:digda/features/character/widgets/mochi_character_view.dart';

/// 3D 셰이딩 SVG(그라디언트/하이라이트 레이어) 가 flutter_svg 에서 실제로
/// 파싱·렌더되는지 전 조합 스모크 검증. SVG 문자열 생성 로직이 바뀔 때
/// 잘못된 마크업(닫히지 않은 태그, 미정의 그라디언트 id 참조 등)을 잡는다.
void main() {
  Future<void> pumpCharacter(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
    // SVG 디코딩은 실제 async 작업이라 runAsync 로 완료를 기다린 뒤 한 프레임 더.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  const allItems = [
    'item/glasses_round',
    'item/glasses_heart',
    'item/glasses_sun',
    'item/hairpin_star',
    'item/hairpin_ribbon',
    'item/hairpin_flower',
    'item/hat_party',
    'item/hat_chef',
    'item/bowtie',
    'item/scarf',
    'item/necklace',
    'item/balloon',
    'item/balloon_heart',
    'item/flower',
    'item/star',
  ];

  ShopItemType typeFor(String assetKey) {
    if (assetKey.contains('glasses')) return ShopItemType.glasses;
    if (assetKey.contains('hairpin')) return ShopItemType.hairpin;
    if (assetKey.contains('hat')) return ShopItemType.hat;
    if (assetKey.contains('bowtie') ||
        assetKey.contains('scarf') ||
        assetKey.contains('necklace')) {
      return ShopItemType.accessory;
    }
    return ShopItemType.misc;
  }

  testWidgets('모찌 — 전 단계 × 전 감정 × 레이어 파트 렌더', (tester) async {
    for (final stage in CharacterStage.values) {
      for (final emotion in MochiEmotion.values) {
        for (final part in MochiCharacterPart.values) {
          await pumpCharacter(
            tester,
            MochiCharacterView(
              appearance: MochiAppearance.coral,
              stage: stage,
              expression: emotion,
              part: part,
            ),
          );
        }
      }
    }
  });

  testWidgets('모찌 — 판다 스킨 + 눈 감김(blink) 렌더', (tester) async {
    const panda = MochiAppearance(
      skinHex: '#8B8B8B',
      skinAssetKey: 'skin/panda',
    );
    for (final stage in CharacterStage.values) {
      await pumpCharacter(
        tester,
        MochiCharacterView(appearance: panda, stage: stage, eyeOpenness: 0.0),
      );
    }
  });

  testWidgets('모찌 — 전 액세서리 장착 렌더', (tester) async {
    for (final assetKey in allItems) {
      final appearance = MochiAppearance(
        skinHex: '#FF6B6B',
        skinAssetKey: 'skin/coral',
        overlays: [
          EquippedItem(
            itemType: typeFor(assetKey),
            itemKey: assetKey,
            displayName: assetKey,
            assetKey: assetKey,
            layerOrder: 0,
          ),
        ],
      );
      await pumpCharacter(
        tester,
        MochiCharacterView(appearance: appearance),
      );
    }
  });

  testWidgets('모찌 — 비정상 skinHex 는 코랄로 폴백', (tester) async {
    const broken = MochiAppearance(skinHex: 'oops', skinAssetKey: 'skin/x');
    await pumpCharacter(
      tester,
      const MochiCharacterView(appearance: broken),
    );
  });

  testWidgets('디코 — 전 무드 렌더', (tester) async {
    for (final mood in DikoMood.values) {
      await pumpCharacter(tester, DikoCharacterView(mood: mood));
    }
  });
}
