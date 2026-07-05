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
    const panda = MochiAppearance(
      skinHex: '#9CA3AF',
      skinAssetKey: 'skin/panda',
    );

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

    String card(String svg, String label) =>
        '<div class="card">\n${isolateIds(svg)}<div class="label">$label</div>\n</div>\n';

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
    buf.write('</div>\n<h2>모찌 — 판다 스킨</h2>\n<div class="row">\n');
    for (final e in stageLabels.entries) {
      final view = MochiCharacterView(appearance: panda, stage: e.key);
      buf.write(card(view.debugSvgMarkup(), '${e.value} (panda)'));
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
