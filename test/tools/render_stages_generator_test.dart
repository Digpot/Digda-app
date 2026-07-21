import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:digda/features/character/models/character_models.dart';
import 'package:digda/features/character/widgets/diko_character_view.dart';
import 'package:digda/features/character/widgets/mochi_character_view.dart';

/// `tool/render_stages.html` 미리보기를 위젯이 실제로 그리는 SVG 문자열로부터
/// 재생성한다 — 손수 복붙한 마크업이 코드와 어긋나는 드리프트를 원천 차단.
/// 아트워크를 바꾼 뒤 `flutter test test/tools/render_stages_generator_test.dart`
/// 를 돌리면 미리보기가 항상 최신으로 갱신된다.
void main() {
  test('tool/render_stages.html 재생성', () {
    const stageLabels = {
      CharacterStage.egg: 'EGG · Lv 1 — 알 모찌',
      CharacterStage.sprout: 'SPROUT · Lv 3 — 새싹 모찌',
      CharacterStage.bloom: 'BLOOM · Lv 6 — 꽃 모찌',
      CharacterStage.blossom: 'BLOSSOM · Lv 10 — 활짝 모찌',
      CharacterStage.glow: 'GLOW · Lv 15 — 빛나는 모찌',
      CharacterStage.master: 'MASTER · Lv 20 — 마스터 모찌',
    };
    const dikoLabels = {
      DikoMood.idle: 'DIKO — idle',
      DikoMood.happy: 'DIKO — happy',
      DikoMood.curious: 'DIKO — curious',
      DikoMood.wink: 'DIKO — wink',
    };
    const patternSkins = {
      'skin/panda': ('판다', '#9CA3AF'),
      'skin/mole': ('두더지', '#8B6547'),
      'skin/tiger': ('호랑이', '#F59E0B'),
      'skin/cat': ('고양이', '#B0A8A2'),
      'skin/bee': ('꿀벌', '#FCD34D'),
      'skin/frog': ('개구리', '#4ADE80'),
    };

    // 한 HTML 문서에 SVG 를 여러 개 인라인하면 그라디언트 id 가 중복돼 브라우저가
    // 첫 정의만 참조한다 (flutter_svg 는 SVG 별 격리라 앱에서는 무관). 카드마다
    // id 에 고유 접두사를 붙여 미리보기에서도 스킨별 색이 올바르게 보이게 한다.
    var cardSeq = 0;
    String isolateIds(String svg) {
      final prefix = 'c${cardSeq++}-';
      return svg
          .replaceAll('id="', 'id="$prefix')
          .replaceAll('url(#', 'url(#$prefix');
    }

    String card(String svg, String label, {String cls = ''}) =>
        '<div class="card $cls">\n${isolateIds(svg)}<div class="label">$label</div>\n</div>\n';

    final buf = StringBuffer('''
<!doctype html>
<!-- 자동 생성 파일 — 손수정 금지.
     재생성: flutter test test/tools/render_stages_generator_test.dart -->
<html><head><meta charset="utf-8"/>
<style>
  body { margin:0; padding:24px; background:#FFF8F8; font-family: 'Inter', sans-serif; }
  h2 { font-size: 15px; color: #333D4B; margin: 20px 0 10px; }
  .row { display:flex; gap:16px; flex-wrap: wrap; }
  .card { width: 220px; text-align: center; }
  .card svg { width:200px; height:200px; display:block; }
  .card.tall svg { width:200px; height:260px; }
  .card.small svg { width:120px; height:120px; margin: 40px auto; }
  .label { margin-top: 6px; font-size: 13px; color: #4E5968; font-weight: 700; }
</style>
</head>
<body>
<h2>모찌 — 3D 렌더 (coral 스킨)</h2>
<div class="row">
''');
    for (final e in stageLabels.entries) {
      final view = MochiCharacterView(
        appearance: MochiAppearance.coral,
        stage: e.key,
      );
      buf.write(card(view.debugSvgMarkup(), e.value));
    }
    for (final skin in patternSkins.entries) {
      final (label, hex) = skin.value;
      buf.write('</div>\n<h2>모찌 — $label 스킨</h2>\n<div class="row">\n');
      final appearance = MochiAppearance(
        skinHex: hex,
        skinAssetKey: skin.key,
      );
      for (final e in stageLabels.entries) {
        final view = MochiCharacterView(appearance: appearance, stage: e.key);
        buf.write(card(view.debugSvgMarkup(), '${e.value} ($label)'));
      }
    }
    // 배경 씬 — 상점에서 파는 배경 6종을 코랄 BLOOM 모찌 기준으로 미리보기.
    const bgLabels = {
      'bg/meadow': 'BG — 풀밭 언덕 (기본)',
      'bg/sakura': 'BG — 벚꽃동산',
      'bg/beach': 'BG — 바닷가',
      'bg/night': 'BG — 밤하늘',
      'bg/winter': 'BG — 눈 내리는 언덕',
      'bg/space': 'BG — 우주 여행',
    };
    buf.write('</div>\n<h2>배경 씬 — 6종</h2>\n<div class="row">\n');
    for (final e in bgLabels.entries) {
      final view = MochiCharacterView(
        appearance: MochiAppearance(
          skinHex: '#FF6B6B',
          skinAssetKey: 'skin/coral',
          backgroundAssetKey: e.key,
        ),
        stage: CharacterStage.bloom,
      );
      buf.write(card(view.debugSvgMarkup(), e.value));
    }

    // 홈 씬(세로 1.3 직사각형) — 하늘/언덕 확장이 자연스러운지 검수.
    buf.write('</div>\n<h2>홈 씬 — 세로 직사각형 (1.3)</h2>\n<div class="row">\n');
    for (final e in bgLabels.entries) {
      final view = MochiCharacterView(
        appearance: MochiAppearance(
          skinHex: '#FF6B6B',
          skinAssetKey: 'skin/coral',
          backgroundAssetKey: e.key,
        ),
        stage: CharacterStage.bloom,
        heightFactor: 1.3,
        clipRadius: 28,
      );
      buf.write(card(view.debugSvgMarkup(), '${e.value} (홈)', cls: 'tall'));
    }

    // 아이템 착용 미리보기 — 사이즈/좌표가 본체와 맞는지 눈으로 검수하는 용도.
    const itemLabels = {
      'item/glasses_round': ShopItemType.glasses,
      'item/glasses_heart': ShopItemType.glasses,
      'item/glasses_sun': ShopItemType.glasses,
      'item/glasses_star': ShopItemType.glasses,
      'item/hairpin_star': ShopItemType.hairpin,
      'item/hairpin_ribbon': ShopItemType.hairpin,
      'item/hairpin_flower': ShopItemType.hairpin,
      'item/hairpin_clover': ShopItemType.hairpin,
      'item/hat_party': ShopItemType.hat,
      'item/hat_chef': ShopItemType.hat,
      'item/hat_straw': ShopItemType.hat,
      'item/hat_beret': ShopItemType.hat,
      'item/hat_wizard': ShopItemType.hat,
      'item/bowtie': ShopItemType.accessory,
      'item/scarf': ShopItemType.accessory,
      'item/necklace': ShopItemType.accessory,
      'item/bell': ShopItemType.accessory,
      'item/balloon': ShopItemType.misc,
      'item/balloon_heart': ShopItemType.misc,
      'item/flower': ShopItemType.misc,
      'item/star': ShopItemType.misc,
      'item/butterfly': ShopItemType.misc,
      'item/music_note': ShopItemType.misc,
    };
    buf.write('</div>\n<h2>아이템 착용 — BLOOM 기준</h2>\n<div class="row">\n');
    for (final e in itemLabels.entries) {
      final view = MochiCharacterView(
        appearance: MochiAppearance(
          skinHex: '#FF6B6B',
          skinAssetKey: 'skin/coral',
          overlays: [
            EquippedItem(
              itemType: e.value,
              itemKey: e.key,
              displayName: e.key,
              assetKey: e.key,
              layerOrder: 0,
            ),
          ],
        ),
        stage: CharacterStage.bloom,
      );
      buf.write(card(view.debugSvgMarkup(), e.key));
    }
    // EGG 단계 착용 검수 — 앵커가 단계별로 달라 알 모찌도 함께 확인한다.
    buf.write('</div>\n<h2>아이템 착용 — EGG 기준</h2>\n<div class="row">\n');
    for (final e in itemLabels.entries) {
      final view = MochiCharacterView(
        appearance: MochiAppearance(
          skinHex: '#FF6B6B',
          skinAssetKey: 'skin/coral',
          overlays: [
            EquippedItem(
              itemType: e.value,
              itemKey: e.key,
              displayName: e.key,
              assetKey: e.key,
              layerOrder: 0,
            ),
          ],
        ),
        stage: CharacterStage.egg,
      );
      buf.write(card(view.debugSvgMarkup(), '${e.key} (egg)'));
    }

    buf.write('</div>\n<h2>디코 — 3D 렌더</h2>\n<div class="row">\n');
    for (final e in dikoLabels.entries) {
      buf.write(
        '<div class="card small">\n'
        '${isolateIds(DikoCharacterView.debugSvgMarkup(e.key))}'
        '<div class="label">${e.value}</div>\n</div>\n',
      );
    }
    buf.write('</div>\n</body></html>\n');

    File('tool/render_stages.html').writeAsStringSync(buf.toString());
  });
}
