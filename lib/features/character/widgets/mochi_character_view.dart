import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/character_models.dart';

/// 어떤 레이어를 그릴지. [AnimatedMochiWidget] 처럼 본체만 흔들고 배경은
/// 고정해야 할 때 두 인스턴스로 분리해서 Stack 으로 겹친다.
/// - [full]: squircle 배경 + 본체 + 액세서리 (정적 렌더)
/// - [background]: squircle 색 배경만
/// - [body]: 본체·표정·액세서리만 (배경 투명)
enum MochiCharacterPart { full, background, body }

/// 모찌의 외형 정보. [skinHex] 는 배경 squircle 색, [skinAssetKey] 는 패턴 식별자
/// (예: 'skin/coral', 'skin/panda'). [overlays] 는 머리/얼굴/목·옆에 그릴 액세서리들.
///
/// [CharacterState.equippedItems] 에서 직접 만들거나, 상점 미리보기처럼 임의 조합으로
/// 만들어 사용 가능. SKIN 슬롯은 [skinHex]/[skinAssetKey] 로 분리해 들어가고,
/// 나머지 카테고리는 [overlays] 에 들어간다.
class MochiAppearance {
  const MochiAppearance({
    required this.skinHex,
    required this.skinAssetKey,
    this.overlays = const [],
  });

  final String skinHex;
  final String skinAssetKey;
  final List<EquippedItem> overlays;

  /// 서버 상태로부터 생성.
  factory MochiAppearance.fromState(CharacterState state) {
    return MochiAppearance(
      skinHex: state.skinHex,
      skinAssetKey: state.skinAssetKey,
      overlays: state.equippedItems
          .where((e) => e.itemType != ShopItemType.skin)
          .toList()
        ..sort((a, b) => a.layerOrder.compareTo(b.layerOrder)),
    );
  }

  /// 인트로/임시 미리보기처럼 외형 데이터가 없을 때의 기본값(코랄).
  static const MochiAppearance coral = MochiAppearance(
    skinHex: '#FF6B6B',
    skinAssetKey: 'skin/coral',
    overlays: [],
  );

  MochiAppearance copyWith({
    String? skinHex,
    String? skinAssetKey,
    List<EquippedItem>? overlays,
  }) {
    return MochiAppearance(
      skinHex: skinHex ?? this.skinHex,
      skinAssetKey: skinAssetKey ?? this.skinAssetKey,
      overlays: overlays ?? this.overlays,
    );
  }
}

/// 모찌 캐릭터를 [size]×[size] 정사각형으로 렌더링.
///
/// 단계별 아트워크 — 메인 캐릭터는 항상 모찌 1마리로 고정.
/// - EGG: 자고 있는 알 형태 (zZz)
/// - SPROUT: 새싹이 머리에 난 모찌
/// - BLOOM: 작은 벚꽃을 머리에 얹은 모찌
/// - BLOSSOM: 활짝 핀 벚꽃 + 옆 봉오리 (이 단계부터 조력자 디코가 별개 위젯으로 등장)
/// - GLOW: 왕관 + 스파클
/// - MASTER: 큰 후광 + 별빛 7개 + 왕관 디럭스
///
/// 외형은 [appearance] 로 결정 — 스킨이 배경/바디 색을, 액세서리 overlay 들이 위에 얹힌다.
/// 모찌 본체는 흰/연핑크로 고정 (브랜드 일관성), 단 SKIN 이 `skin/panda` 같은 특수
/// 패턴이면 바디 톤을 함께 바꾼다.
class MochiCharacterView extends StatelessWidget {
  const MochiCharacterView({
    super.key,
    required this.appearance,
    this.stage = CharacterStage.bloom,
    this.size = 200,
    this.expression = MochiEmotion.idle,
    this.eyeOpenness = 1.0,
    this.part = MochiCharacterPart.full,
  });

  final MochiAppearance appearance;
  final CharacterStage stage;
  final double size;
  final MochiEmotion expression;

  /// 0.0 (완전히 감은 눈) ~ 1.0 (완전히 뜬 눈)
  final double eyeOpenness;

  /// 렌더할 레이어. 기본 [MochiCharacterPart.full].
  final MochiCharacterPart part;

  @override
  Widget build(BuildContext context) {
    final cleanHex = appearance.skinHex.startsWith('#')
        ? appearance.skinHex
        : '#${appearance.skinHex}';
    final svg = _buildStageSvg(stage, cleanHex, appearance);
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(svg, width: size, height: size),
    );
  }

  // ── 얼굴 헬퍼 ────────────────────────────────

  /// 눈 하나를 SVG 요소로 반환. 감정·개방도에 따라 모양이 달라짐.
  String _eye(double cx, double cy, double rx, double ry) {
    final ey = (ry * eyeOpenness).clamp(0.15, ry);
    final top = (cy - ry * 2.2 * eyeOpenness.clamp(0.1, 1.0)).toStringAsFixed(1);
    return switch (expression) {
      MochiEmotion.idle => '<ellipse cx="$cx" cy="$cy" rx="$rx" ry="${ey.toStringAsFixed(2)}" fill="#2B2B2B"/>',
      MochiEmotion.happy => '<path d="M${cx - rx} $cy Q$cx $top ${cx + rx} $cy" stroke="#2B2B2B" stroke-width="2.2" fill="none" stroke-linecap="round"/>',
      MochiEmotion.excited => '<ellipse cx="$cx" cy="$cy" rx="${(rx * 1.2).toStringAsFixed(1)}" ry="${(ry * 1.2 * eyeOpenness).clamp(0.1, ry * 1.2).toStringAsFixed(2)}" fill="#2B2B2B"/>',
      MochiEmotion.sleepy => '<ellipse cx="$cx" cy="${(cy + ry * 0.4).toStringAsFixed(1)}" rx="$rx" ry="${(ry * 0.45 * eyeOpenness).clamp(0.1, ry).toStringAsFixed(2)}" fill="#2B2B2B"/>',
      MochiEmotion.proud => '<ellipse cx="$cx" cy="$cy" rx="$rx" ry="${(ry * 0.65 * eyeOpenness).clamp(0.1, ry).toStringAsFixed(2)}" fill="#2B2B2B"/>',
    };
  }

  /// 입 하나를 SVG 요소로 반환. 감정에 따라 모양이 달라짐.
  String _mouth(double x1, double y1, double cx, double cy, double x2, double y2, double sw) {
    final midX = ((x1 + x2) / 2).toStringAsFixed(1);
    final midY = ((y1 + y2) / 2).toStringAsFixed(1);
    final halfW = ((x2 - x1) * 0.44).toStringAsFixed(1);
    final excitedRy = ((cy - y1) * 0.8).toStringAsFixed(1);
    final excitedCy = ((y1 + y2) / 2 + 1).toStringAsFixed(1);
    return switch (expression) {
      MochiEmotion.idle => '<path d="M$x1 $y1 Q$cx $cy $x2 $y2" stroke="#2B2B2B" stroke-width="$sw" stroke-linecap="round" fill="none"/>',
      MochiEmotion.happy => '<path d="M$x1 $y1 Q$cx ${cy + 5} $x2 $y2" stroke="#2B2B2B" stroke-width="$sw" stroke-linecap="round" fill="none"/>',
      MochiEmotion.excited => '<ellipse cx="$midX" cy="$excitedCy" rx="$halfW" ry="$excitedRy" fill="#2B2B2B"/>',
      MochiEmotion.sleepy => '<line x1="${x1 + 3}" y1="$midY" x2="${x2 - 3}" y2="$midY" stroke="#2B2B2B" stroke-width="$sw" stroke-linecap="round"/>',
      MochiEmotion.proud => '<path d="M$x1 $y1 Q${cx + 4} $cy ${x2 - 2} ${y2 - 2}" stroke="#2B2B2B" stroke-width="$sw" stroke-linecap="round" fill="none"/>',
    };
  }

  // ─────────────────────────────────────────
  // 단계별 본문 SVG (배경 rect 는 외부에서 결합)
  // ─────────────────────────────────────────

  String _buildStageSvg(CharacterStage stage, String hex, MochiAppearance app) {
    final bg = '<rect width="200" height="200" rx="48" fill="$hex"/>';
    final isPanda = app.skinAssetKey == 'skin/panda';
    // 모찌 본체는 항상 흰색 — 스킨이 색을 결정하는 것은 배경 squircle 한정.
    // 특수 스킨(판다 등) 만 본체 패치를 그려 시각적 차이를 만든다.
    const bodyFill = '#FFFFFF';
    final bodyAccent = isPanda ? '#2F2F2F' : '#FFFFFF';
    final body = switch (stage) {
      CharacterStage.egg => _egg(bodyFill: bodyFill, accent: bodyAccent, isPanda: isPanda),
      CharacterStage.sprout => _sprout(bodyFill: bodyFill, accent: bodyAccent, isPanda: isPanda),
      CharacterStage.bloom => _bloom(bodyFill: bodyFill, accent: bodyAccent, isPanda: isPanda),
      CharacterStage.blossom => _blossom(bodyFill: bodyFill, accent: bodyAccent, isPanda: isPanda),
      CharacterStage.glow => _glow(bodyFill: bodyFill, accent: bodyAccent, isPanda: isPanda),
      CharacterStage.master => _master(bodyFill: bodyFill, accent: bodyAccent, isPanda: isPanda),
    };
    final overlays = _buildOverlays(stage, app.overlays);
    final layers = switch (part) {
      MochiCharacterPart.full => '$bg\n  $body\n  $overlays',
      MochiCharacterPart.background => bg,
      MochiCharacterPart.body => '$body\n  $overlays',
    };
    return '''
<svg width="200" height="200" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
  $layers
</svg>
''';
  }

  // ─────────────────────────────────────────
  // 액세서리 overlay 렌더 — 카테고리별 anchor 에 SVG 조각을 얹는다.
  // 새 아이템 추가는 `_renderItem` 의 switch 케이스 한 줄로 끝난다.
  // ─────────────────────────────────────────

  String _buildOverlays(CharacterStage stage, List<EquippedItem> overlays) {
    final sorted = [...overlays]..sort((a, b) => a.layerOrder.compareTo(b.layerOrder));
    final buf = StringBuffer();
    for (final item in sorted) {
      buf.writeln(_renderItem(stage, item));
    }
    return buf.toString();
  }

  /// 카테고리/asset key 별 단편 SVG. 단계별 좌표 차이는 [_anchor] 로 해소.
  String _renderItem(CharacterStage stage, EquippedItem item) {
    final a = _anchor(stage, item.itemType);
    if (a == null) return '';
    return switch (item.assetKey) {
      'item/glasses_round' => _glassesRound(a),
      'item/glasses_heart' => _glassesHeart(a),
      'item/hairpin_star' => _hairpinStar(a),
      'item/hairpin_ribbon' => _hairpinRibbon(a),
      'item/hat_party' => _hatParty(a),
      'item/hat_chef' => _hatChef(a),
      'item/bowtie' => _bowtie(a),
      'item/scarf' => _scarf(a),
      'item/balloon' => _balloon(a),
      'item/flower' => _flowerSide(a),
      _ => '',
    };
  }

  /// 단계 + 카테고리 → SVG 좌표 anchor. 모찌는 항상 1마리(중앙) 라 단계마다 좌표가
  /// 거의 동일하며, EGG 만 본체 크기가 살짝 달라 위치를 조금 내린다.
  _Anchor? _anchor(CharacterStage stage, ShopItemType type) {
    final isEgg = stage == CharacterStage.egg;
    const headCx = 100.0;
    final headCy = isEgg ? 100.0 : 92.0;
    final eyesCy = isEgg ? 116.0 : 122.0;
    final neckCy = isEgg ? 168.0 : 162.0;
    const sideCx = 168.0;
    return switch (type) {
      ShopItemType.hat => _Anchor(cx: headCx, cy: headCy),
      ShopItemType.glasses => _Anchor(cx: headCx, cy: eyesCy),
      ShopItemType.hairpin => _Anchor(cx: headCx + 24, cy: headCy + 6),
      ShopItemType.accessory => _Anchor(cx: headCx, cy: neckCy),
      ShopItemType.misc => const _Anchor(cx: sideCx, cy: 100),
      ShopItemType.skin => null,
    };
  }

  // ── 개별 아이템 SVG 단편 ────────────────────────

  String _glassesRound(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <circle cx="-10" cy="0" r="7.5" fill="none" stroke="#2B2B2B" stroke-width="2.5"/>
    <circle cx="10"  cy="0" r="7.5" fill="none" stroke="#2B2B2B" stroke-width="2.5"/>
    <line x1="-2.5" y1="0" x2="2.5" y2="0" stroke="#2B2B2B" stroke-width="2"/>
  </g>
  ''';

  String _glassesHeart(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-16 -2 C-16 -8 -10 -10 -10 -4 C-10 -10 -4 -8 -4 -2 C-4 3 -10 8 -10 8 C-10 8 -16 3 -16 -2 Z" fill="#FF6B6B" stroke="#A23838" stroke-width="1.2"/>
    <path d="M4 -2 C4 -8 10 -10 10 -4 C10 -10 16 -8 16 -2 C16 3 10 8 10 8 C10 8 4 3 4 -2 Z" fill="#FF6B6B" stroke="#A23838" stroke-width="1.2"/>
    <line x1="-4" y1="-2" x2="4" y2="-2" stroke="#A23838" stroke-width="2"/>
  </g>
  ''';

  String _hairpinStar(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M0 -7 L2.2 -2 L7 -1.5 L3.4 2.3 L4.4 7.5 L0 5 L-4.4 7.5 L-3.4 2.3 L-7 -1.5 L-2.2 -2 Z" fill="#FCD34D" stroke="#B8860B" stroke-width="1"/>
  </g>
  ''';

  String _hairpinRibbon(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-8 0 Q-2 -4 0 0 Q-2 4 -8 0 Z" fill="#FF9FB0" stroke="#A23854" stroke-width="1"/>
    <path d="M8 0 Q2 -4 0 0 Q2 4 8 0 Z" fill="#FF9FB0" stroke="#A23854" stroke-width="1"/>
    <circle cx="0" cy="0" r="2" fill="#A23854"/>
  </g>
  ''';

  String _hatParty(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 32})">
    <path d="M0 -22 L-12 6 L12 6 Z" fill="#FF6B6B" stroke="#A23838" stroke-width="1.2"/>
    <circle cx="0" cy="-23" r="3" fill="#FCD34D"/>
    <circle cx="-6" cy="-4" r="1.6" fill="#FFFFFF"/>
    <circle cx="6" cy="-12" r="1.6" fill="#FFFFFF"/>
  </g>
  ''';

  String _hatChef(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 30})">
    <ellipse cx="-6" cy="-12" rx="7" ry="6" fill="#FFFFFF" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="6" cy="-12" rx="7" ry="6" fill="#FFFFFF" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="0" cy="-15" rx="7" ry="6" fill="#FFFFFF" stroke="#9CA3AF" stroke-width="1"/>
    <rect x="-12" y="-6" width="24" height="10" rx="2" fill="#FFFFFF" stroke="#9CA3AF" stroke-width="1"/>
  </g>
  ''';

  String _bowtie(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-14 -4 L-2 0 L-14 4 Z" fill="#A23854" stroke="#5A1F30" stroke-width="0.8"/>
    <path d="M14 -4 L2 0 L14 4 Z" fill="#A23854" stroke="#5A1F30" stroke-width="0.8"/>
    <rect x="-3" y="-3" width="6" height="6" rx="1.4" fill="#5A1F30"/>
  </g>
  ''';

  String _scarf(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-20 -4 Q0 -10 20 -4 L20 4 Q0 -2 -20 4 Z" fill="#7CB1F5" stroke="#2C5BA6" stroke-width="1"/>
    <path d="M-8 4 L-12 22 L-4 18 Z" fill="#7CB1F5" stroke="#2C5BA6" stroke-width="1"/>
  </g>
  ''';

  String _balloon(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 30})">
    <ellipse cx="0" cy="0" rx="14" ry="18" fill="#FCD34D" stroke="#B8860B" stroke-width="1.2"/>
    <path d="M-2 17 L0 22 L2 17 Z" fill="#B8860B"/>
    <path d="M0 22 Q-4 36 4 50" stroke="#9CA3AF" stroke-width="1.2" fill="none"/>
  </g>
  ''';

  String _flowerSide(_Anchor a) => '''
  <g transform="translate(${a.cx - 6} ${a.cy + 22})">
    <line x1="0" y1="0" x2="0" y2="20" stroke="#5BB04A" stroke-width="2"/>
    <circle cx="0" cy="0" r="5" fill="#FFB6C1"/>
    <circle cx="4" cy="-3" r="5" fill="#FFB6C1"/>
    <circle cx="-4" cy="-3" r="5" fill="#FFB6C1"/>
    <circle cx="2" cy="3" r="5" fill="#FFB6C1"/>
    <circle cx="-2" cy="3" r="5" fill="#FFB6C1"/>
    <circle cx="0" cy="0" r="2.2" fill="#FFF8C4"/>
  </g>
  ''';

  // ─────────────────────────────────────────
  // 단계별 베이스 SVG (스킨이 panda 일 때 흑백 패턴 보강)
  // ─────────────────────────────────────────

  /// EGG (Lv 1): 잠자고 있는 알 모찌. 눈은 ‿ 처럼 감겨 있고, 우상단에 zZz.
  String _egg({required String bodyFill, required String accent, required bool isPanda}) {
    final pandaPatches = isPanda
        ? '<ellipse cx="78" cy="106" rx="13" ry="10" fill="$accent"/>'
            '<ellipse cx="122" cy="106" rx="13" ry="10" fill="$accent"/>'
        : '';
    return '''
  <ellipse cx="100" cy="120" rx="52" ry="58" fill="$bodyFill"/>
  $pandaPatches
  <path d="M82 116 Q88 119 94 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M106 116 Q112 119 118 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M92 134 Q100 140 108 134" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <ellipse cx="74" cy="130" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  <ellipse cx="126" cy="130" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  <text x="148" y="74" font-family="Inter, Arial, sans-serif" font-size="22" font-weight="700" fill="#FFFFFF" opacity="0.85">Z</text>
  <text x="162" y="92" font-family="Inter, Arial, sans-serif" font-size="14" font-weight="700" fill="#FFFFFF" opacity="0.7">z</text>
  <text x="170" y="106" font-family="Inter, Arial, sans-serif" font-size="9" font-weight="700" fill="#FFFFFF" opacity="0.55">z</text>
  ''';
  }

  String _sprout({required String bodyFill, required String accent, required bool isPanda}) {
    final pandaPatches = isPanda
        ? '<ellipse cx="82" cy="118" rx="9" ry="6" fill="$accent"/>'
            '<ellipse cx="118" cy="118" rx="9" ry="6" fill="$accent"/>'
        : '';
    return '''
  <g>
    <path d="M100 56 Q86 48 92 64 Q98 68 100 64 Z" fill="#7CCB6B"/>
    <path d="M100 56 Q114 48 108 64 Q102 68 100 64 Z" fill="#5BB04A"/>
    <line x1="100" y1="66" x2="100" y2="84" stroke="#7CCB6B" stroke-width="3" stroke-linecap="round"/>
  </g>
  <ellipse cx="100" cy="124" rx="46" ry="40" fill="$bodyFill"/>
  $pandaPatches
  ${_eye(88, 122, 2.8, 3.6)}
  ${_eye(112, 122, 2.8, 3.6)}
  ${_mouth(93, 136, 100, 142, 107, 136, 2.4)}
  <ellipse cx="76" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  <ellipse cx="124" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  ''';
  }

  /// BLOOM (Lv 6) — 꽃 모찌: 머리에 막 피어난 작은 벚꽃. 단독 모찌.
  String _bloom({required String bodyFill, required String accent, required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="$accent"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="$accent"/>'
        : '';
    return '''
  <g>
    <ellipse cx="100" cy="124" rx="50" ry="44" fill="$bodyFill"/>
    $patches
    <g transform="translate(100 72)">
      ${_flower(scale: 0.85, accent: '#FF9FB0')}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    <ellipse cx="72" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
    <ellipse cx="128" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  </g>
  ''';
  }

  /// BLOSSOM (Lv 10) — 활짝 모찌: 큰 벚꽃 + 옆에 작은 봉오리. 디코는 이 단계부터 별개로 등장.
  String _blossom({required String bodyFill, required String accent, required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="$accent"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="$accent"/>'
        : '';
    return '''
  <g>
    <ellipse cx="100" cy="124" rx="50" ry="44" fill="$bodyFill"/>
    $patches
    <g transform="translate(100 62)">
      ${_flower(scale: 1.35, accent: '#FF9FB0')}
    </g>
    <g transform="translate(140 78)">
      ${_flower(scale: 0.55, accent: '#FFB6C1')}
    </g>
    <g transform="translate(60 78)">
      ${_flower(scale: 0.45, accent: '#FFC9D9')}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    <ellipse cx="72" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
    <ellipse cx="128" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  </g>
  ''';
  }

  /// GLOW (Lv 15) — 왕관과 함께 빛나는 단독 모찌. 주변 스파클 4 점.
  String _glow({required String bodyFill, required String accent, required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="$accent"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="$accent"/>'
        : '';
    return '''
  <g opacity="0.9">
    <circle cx="32" cy="44" r="3.4" fill="#FFF59D"/>
    <circle cx="168" cy="58" r="2.6" fill="#FFF59D"/>
    <circle cx="40" cy="158" r="2.4" fill="#FFF59D"/>
    <circle cx="170" cy="148" r="3" fill="#FFF59D"/>
  </g>
  <g>
    <ellipse cx="100" cy="124" rx="50" ry="44" fill="$bodyFill"/>
    $patches
    <g transform="translate(100 70)">
      ${_crown()}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    <ellipse cx="72" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
    <ellipse cx="128" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  </g>
  ''';
  }

  /// MASTER (Lv 20) — 마스터 모찌: 큰 후광 + 별빛 + 디럭스 왕관. 단독 모찌.
  String _master({required String bodyFill, required String accent, required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="$accent"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="$accent"/>'
        : '';
    return '''
  <defs>
    <radialGradient id="masterHalo" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFF8C4" stop-opacity="0.7"/>
      <stop offset="60%" stop-color="#FFE066" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#FFE066" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <circle cx="100" cy="118" r="92" fill="url(#masterHalo)"/>
  <g opacity="0.95">
    <path d="M30 36 L33 44 L41 44 L34.5 49 L37 57 L30 52 L23 57 L25.5 49 L19 44 L27 44 Z" fill="#FFE066"/>
    <path d="M170 50 L172 56 L178 56 L173 60 L175 66 L170 62.5 L165 66 L167 60 L162 56 L168 56 Z" fill="#FFF59D"/>
    <path d="M40 160 L42 165 L47 165 L43 168 L44.5 173 L40 170 L35.5 173 L37 168 L33 165 L38 165 Z" fill="#FFE066"/>
    <path d="M170 152 L172 158 L178 158 L173 162 L175 168 L170 164.5 L165 168 L167 162 L162 158 L168 158 Z" fill="#FFF59D"/>
    <circle cx="100" cy="30" r="3" fill="#FFE066"/>
    <circle cx="14" cy="100" r="2.4" fill="#FFE066"/>
    <circle cx="186" cy="100" r="2.4" fill="#FFE066"/>
  </g>
  <g>
    <ellipse cx="100" cy="124" rx="50" ry="44" fill="$bodyFill"/>
    $patches
    <g transform="translate(100 68)">
      ${_crownDeluxe()}
    </g>
    <g transform="translate(100 52)">
      ${_starCrown()}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    <ellipse cx="72" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
    <ellipse cx="128" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.55"/>
  </g>
  ''';
  }

  /// 큰 별 왕관 — 오른쪽 모찌용 (MASTER 단계).
  static String _starCrown() => '''
  <path d="M0 -12 L3 -3 L12 -3 L4.5 3 L7 12 L0 7 L-7 12 L-4.5 3 L-12 -3 L-3 -3 Z" fill="#FFD700" stroke="#B8860B" stroke-width="1.2" stroke-linejoin="round"/>
  <circle cx="0" cy="-1" r="2" fill="#FF6B6B"/>
  ''';

  /// 더 화려한 왕관 — 왼쪽 모찌용 (MASTER 단계). 보석 3개 + 별.
  static String _crownDeluxe() => '''
  <path d="M-16 4 L-16 -6 L-10 -2 L-6 -8 L0 -12 L6 -8 L10 -2 L16 -6 L16 4 Z" fill="#FFD700" stroke="#B8860B" stroke-width="1.3" stroke-linejoin="round"/>
  <circle cx="-9" cy="0" r="1.8" fill="#34D399"/>
  <circle cx="0" cy="-2" r="2.2" fill="#FF6B6B"/>
  <circle cx="9" cy="0" r="1.8" fill="#7CB1F5"/>
  <path d="M0 -16 L1.4 -13 L4.5 -13 L2 -11 L2.8 -8 L0 -10 L-2.8 -8 L-2 -11 L-4.5 -13 L-1.4 -13 Z" fill="#FFF59D" stroke="#B8860B" stroke-width="0.8"/>
  ''';

  static String _flower({double scale = 1.0, String accent = '#FFB6C1'}) {
    final s = scale.toStringAsFixed(2);
    return '''
    <g transform="scale($s)">
      <circle cx="0" cy="-6" r="5" fill="$accent"/>
      <circle cx="6" cy="-2" r="5" fill="$accent"/>
      <circle cx="3" cy="6" r="5" fill="$accent"/>
      <circle cx="-3" cy="6" r="5" fill="$accent"/>
      <circle cx="-6" cy="-2" r="5" fill="$accent"/>
      <circle cx="0" cy="0" r="2.6" fill="#FFF8C4"/>
    </g>
    ''';
  }

  static String _crown() => '''
  <path d="M-14 4 L-14 -6 L-7 0 L0 -10 L7 0 L14 -6 L14 4 Z" fill="#FCD34D" stroke="#B8860B" stroke-width="1.2" stroke-linejoin="round"/>
  <circle cx="0" cy="-7" r="1.6" fill="#FF6B6B"/>
  ''';
}

class _Anchor {
  const _Anchor({required this.cx, required this.cy});
  final double cx;
  final double cy;
}

/// GLOW 단계의 추가 외부 스파클 자리. 현재 캐릭터 SVG 안에 4개 포함돼 있어
/// 노출하지 않지만, 호출자에서 추가 효과가 필요할 때 Stack 으로 덮어쓸 수 있도록 보존.
class MochiStageBadge extends StatelessWidget {
  const MochiStageBadge({super.key, required this.stage, required this.size});

  final CharacterStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
