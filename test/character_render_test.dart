import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/features/character/widgets/animated_mochi_widget.dart';
import 'package:digda/features/character/widgets/diko_character_view.dart';
import 'package:digda/features/character/widgets/mochi_character_view.dart';
import 'package:digda/features/character/widgets/mochi_diko_stage.dart';

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
    'item/glasses_star',
    'item/hairpin_star',
    'item/hairpin_ribbon',
    'item/hairpin_flower',
    'item/hairpin_clover',
    'item/hat_party',
    'item/hat_chef',
    'item/hat_straw',
    'item/hat_beret',
    'item/hat_wizard',
    'item/bowtie',
    'item/scarf',
    'item/necklace',
    'item/bell',
    'item/balloon',
    'item/balloon_heart',
    'item/flower',
    'item/star',
    'item/butterfly',
    'item/music_note',
  ];

  const allBackgrounds = [
    'bg/meadow',
    'bg/sakura',
    'bg/beach',
    'bg/night',
    'bg/winter',
    'bg/space',
  ];

  ShopItemType typeFor(String assetKey) {
    if (assetKey.contains('glasses')) return ShopItemType.glasses;
    if (assetKey.contains('hairpin')) return ShopItemType.hairpin;
    if (assetKey.contains('hat')) return ShopItemType.hat;
    if (assetKey.contains('bowtie') ||
        assetKey.contains('scarf') ||
        assetKey.contains('necklace') ||
        assetKey.contains('bell')) {
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

  testWidgets('모찌 — 패턴 스킨 전종 × 전 단계 렌더 (+눈 감김)', (tester) async {
    const patternSkins = {
      'skin/panda': '#8B8B8B',
      'skin/mole': '#8B6547',
      'skin/tiger': '#F59E0B',
      'skin/cat': '#B0A8A2',
      'skin/bee': '#FCD34D',
      'skin/frog': '#4ADE80',
    };
    for (final e in patternSkins.entries) {
      final appearance = MochiAppearance(
        skinHex: e.value,
        skinAssetKey: e.key,
      );
      for (final stage in CharacterStage.values) {
        await pumpCharacter(
          tester,
          MochiCharacterView(
            appearance: appearance,
            stage: stage,
            eyeOpenness: 0.0,
          ),
        );
      }
    }
  });

  testWidgets('모찌 — 패턴 스킨 + 배경 동시 적용 렌더 (판다+우주 회귀)', (tester) async {
    const panda = MochiAppearance(
      skinHex: '#2F2F2F',
      skinAssetKey: 'skin/panda',
      backgroundAssetKey: 'bg/space',
    );
    for (final stage in CharacterStage.values) {
      await pumpCharacter(
        tester,
        MochiCharacterView(appearance: panda, stage: stage),
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

  testWidgets('모찌 — 전 배경 씬 × 전 단계 렌더', (tester) async {
    for (final bg in allBackgrounds) {
      for (final stage in CharacterStage.values) {
        await pumpCharacter(
          tester,
          MochiCharacterView(
            appearance: MochiAppearance(
              skinHex: '#FF6B6B',
              skinAssetKey: 'skin/coral',
              backgroundAssetKey: bg,
            ),
            stage: stage,
          ),
        );
      }
    }
  });

  testWidgets('모찌 — 세로 확장(1.3) 홈 씬 × 전 배경 렌더', (tester) async {
    for (final bg in allBackgrounds) {
      for (final part in MochiCharacterPart.values) {
        await pumpCharacter(
          tester,
          MochiCharacterView(
            appearance: MochiAppearance(
              skinHex: '#FF6B6B',
              skinAssetKey: 'skin/coral',
              backgroundAssetKey: bg,
            ),
            stage: CharacterStage.bloom,
            heightFactor: 1.3,
            clipRadius: 28,
            part: part,
          ),
        );
      }
    }
  });

  testWidgets('모찌 — 알 수 없는 배경 키는 풀밭으로 폴백', (tester) async {
    await pumpCharacter(
      tester,
      const MochiCharacterView(
        appearance: MochiAppearance(
          skinHex: '#FF6B6B',
          skinAssetKey: 'skin/coral',
          backgroundAssetKey: 'bg/unknown',
        ),
      ),
    );
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

  testWidgets('홈 씬 — 디코 유/무 렌더 + 돌봄 리액션 트리거', (tester) async {
    CharacterState state({required bool diko}) => CharacterState(
          stage: diko ? CharacterStage.blossom : CharacterStage.bloom,
          stageDisplayName: '',
          level: diko ? 10 : 6,
          exp: 10,
          expForNextLevel: 40,
          coin: 0,
          maxLevelReached: false,
          dikoUnlocked: diko,
          equippedItems: const [],
        );
    for (final diko in const [false, true]) {
      final controller = MochiAnimationController();
      await pumpCharacter(
        tester,
        SizedBox(
          width: 340,
          child: MochiHomeScene(
            state: state(diko: diko),
            mochiController: controller,
            onPet: () {},
          ),
        ),
      );
      // 돌봄 액션 전종 트리거 — 파티클/말풍선/점프가 예외 없이 재생되는지.
      for (final action in MochiCareAction.values) {
        controller.triggerCare(action);
        await tester.pump(const Duration(milliseconds: 200));
      }
      // 파티클(820ms)·말풍선(4.5s)·감정리셋(3s) 타이머 소진.
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      // 남은 주기 타이머(깜빡임 등)는 위젯 폐기로 정리.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
