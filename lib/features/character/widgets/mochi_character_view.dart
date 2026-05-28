import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/character_models.dart';

/// 어떤 레이어를 그릴지. [AnimatedMochiWidget] 처럼 본체만 흔들고 배경은
/// 고정해야 할 때 두 인스턴스로 분리해서 Stack 으로 겹친다.
/// - [full]: squircle 배경 + 본체 (기본, 정적 렌더)
/// - [background]: squircle 색 배경만
/// - [body]: 본체·표정·액세서리만 (배경 투명)
enum MochiCharacterPart { full, background, body }

/// 모찌 캐릭터를 [size]×[size] 정사각형으로 렌더링.
///
/// 단계별 아트워크
/// - EGG: 자고 있는 단일 알 형태 (zZz)
/// - SPROUT: 새싹이 머리에 난 단일 모찌
/// - BLOOM: 모찌 듀오 (브랜드 마스터 디자인)
/// - BLOSSOM: 듀오 + 머리 위 꽃 액세서리
/// - GLOW: 듀오 + 왕관 + 스파클
///
/// 색상은 모든 단계에서 배경 squircle 에만 적용 (브랜드 일관성).
/// 모찌 본체·하트는 흰/연핑크로 고정.
class MochiCharacterView extends StatelessWidget {
  const MochiCharacterView({
    super.key,
    required this.color,
    required this.colorHex,
    this.stage = CharacterStage.bloom,
    this.size = 200,
    this.expression = MochiEmotion.idle,
    this.eyeOpenness = 1.0,
    this.part = MochiCharacterPart.full,
  });

  final CharacterColor color;
  final String colorHex;
  final CharacterStage stage;
  final double size;
  final MochiEmotion expression;

  /// 0.0 (완전히 감은 눈) ~ 1.0 (완전히 뜬 눈)
  final double eyeOpenness;

  /// 렌더할 레이어. 기본 [MochiCharacterPart.full].
  final MochiCharacterPart part;

  @override
  Widget build(BuildContext context) {
    final cleanHex = colorHex.startsWith('#') ? colorHex : '#$colorHex';
    final svg = _buildStageSvg(stage, cleanHex);
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

  String _buildStageSvg(CharacterStage stage, String hex) {
    final bg = '<rect width="200" height="200" rx="48" fill="$hex"/>';
    final body = switch (stage) {
      CharacterStage.egg => _egg(),
      CharacterStage.sprout => _sprout(),
      CharacterStage.bloom => _bloom(),
      CharacterStage.blossom => _blossom(),
      CharacterStage.glow => _glow(),
    };
    final layers = switch (part) {
      MochiCharacterPart.full => '$bg\n  $body',
      MochiCharacterPart.background => bg,
      MochiCharacterPart.body => body,
    };
    return '''
<svg width="200" height="200" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
  $layers
</svg>
''';
  }

  /// EGG (Lv 1): 잠자고 있는 알 모찌. 눈은 ‿ 처럼 감겨 있고, 우상단에 zZz.
  String _egg() => '''
  <ellipse cx="100" cy="120" rx="52" ry="58" fill="#FFFFFF"/>
  <path d="M82 116 Q88 119 94 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M106 116 Q112 119 118 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M92 134 Q100 140 108 134" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <ellipse cx="74" cy="130" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  <ellipse cx="126" cy="130" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  <text x="148" y="74" font-family="Inter, Arial, sans-serif" font-size="22" font-weight="700" fill="#FFFFFF" opacity="0.85">Z</text>
  <text x="162" y="92" font-family="Inter, Arial, sans-serif" font-size="14" font-weight="700" fill="#FFFFFF" opacity="0.7">z</text>
  <text x="170" y="106" font-family="Inter, Arial, sans-serif" font-size="9" font-weight="700" fill="#FFFFFF" opacity="0.55">z</text>
  ''';

  /// SPROUT (Lv 3): 알을 깨고 나온 작은 모찌. 머리 위에 초록 떡잎.
  String _sprout() => '''
  <g>
    <path d="M100 56 Q86 48 92 64 Q98 68 100 64 Z" fill="#7CCB6B"/>
    <path d="M100 56 Q114 48 108 64 Q102 68 100 64 Z" fill="#5BB04A"/>
    <line x1="100" y1="66" x2="100" y2="84" stroke="#7CCB6B" stroke-width="3" stroke-linecap="round"/>
  </g>
  <ellipse cx="100" cy="124" rx="46" ry="40" fill="#FFFFFF"/>
  ${_eye(88, 122, 2.8, 3.6)}
  ${_eye(112, 122, 2.8, 3.6)}
  ${_mouth(93, 136, 100, 142, 107, 136, 2.4)}
  <ellipse cx="76" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  <ellipse cx="124" cy="132" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  ''';

  /// BLOOM (Lv 6): 모찌 듀오 — 기본 마스터 디자인.
  String _bloom() => '''
  <g>
    <ellipse cx="124" cy="112" rx="42" ry="36" fill="#FFE4E4"/>
    ${_eye(112, 110, 2.4, 3.2)}
    ${_eye(136, 110, 2.4, 3.2)}
    ${_mouth(118, 121, 124, 127, 130, 121, 2.0)}
    <ellipse cx="103" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
    <ellipse cx="145" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
  </g>
  <g>
    <ellipse cx="82" cy="118" rx="48" ry="41" fill="#FFFFFF"/>
    <path d="M82 70 C78 64 68 64 68 73 C68 79 75 84 82 90 C89 84 96 79 96 73 C96 64 86 64 82 70 Z" fill="#FF9FB0"/>
    ${_eye(68, 116, 2.8, 3.6)}
    ${_eye(96, 116, 2.8, 3.6)}
    ${_mouth(74, 128, 82, 135, 90, 128, 2.4)}
    <ellipse cx="56" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
    <ellipse cx="108" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  </g>
  ''';

  /// BLOSSOM (Lv 10): 듀오 + 머리 위 벚꽃.
  String _blossom() => '''
  <g>
    <ellipse cx="124" cy="112" rx="42" ry="36" fill="#FFE4E4"/>
    <g transform="translate(124 70)">
      ${_flower(scale: 0.7, accent: '#FFB6C1')}
    </g>
    ${_eye(112, 110, 2.4, 3.2)}
    ${_eye(136, 110, 2.4, 3.2)}
    ${_mouth(118, 121, 124, 127, 130, 121, 2.0)}
    <ellipse cx="103" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
    <ellipse cx="145" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
  </g>
  <g>
    <ellipse cx="82" cy="118" rx="48" ry="41" fill="#FFFFFF"/>
    <g transform="translate(82 72)">
      ${_flower(scale: 1.0, accent: '#FF9FB0')}
    </g>
    ${_eye(68, 116, 2.8, 3.6)}
    ${_eye(96, 116, 2.8, 3.6)}
    ${_mouth(74, 128, 82, 135, 90, 128, 2.4)}
    <ellipse cx="56" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
    <ellipse cx="108" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  </g>
  ''';

  /// GLOW (Lv 15): 듀오 + 왕관 + 스파클 4개.
  String _glow() => '''
  <g opacity="0.9">
    <circle cx="32" cy="44" r="3.4" fill="#FFF59D"/>
    <circle cx="168" cy="58" r="2.6" fill="#FFF59D"/>
    <circle cx="40" cy="158" r="2.4" fill="#FFF59D"/>
    <circle cx="170" cy="148" r="3" fill="#FFF59D"/>
  </g>
  <g>
    <ellipse cx="124" cy="112" rx="42" ry="36" fill="#FFE4E4"/>
    ${_eye(112, 110, 2.4, 3.2)}
    ${_eye(136, 110, 2.4, 3.2)}
    ${_mouth(118, 121, 124, 127, 130, 121, 2.0)}
    <ellipse cx="103" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
    <ellipse cx="145" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
  </g>
  <g>
    <ellipse cx="82" cy="118" rx="48" ry="41" fill="#FFFFFF"/>
    <g transform="translate(82 68)">
      ${_crown()}
    </g>
    ${_eye(68, 116, 2.8, 3.6)}
    ${_eye(96, 116, 2.8, 3.6)}
    ${_mouth(74, 128, 82, 135, 90, 128, 2.4)}
    <ellipse cx="56" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
    <ellipse cx="108" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  </g>
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

/// GLOW 단계의 추가 외부 스파클. 캐릭터 SVG 안에 이미 4개가 들어있어 현재는 노출하지
/// 않지만, 호출자에서 추가 효과가 필요할 때 Stack 으로 덮어쓸 수 있도록 보존.
class MochiStageBadge extends StatelessWidget {
  const MochiStageBadge({super.key, required this.stage, required this.size});

  final CharacterStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
