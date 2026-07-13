import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/character_models.dart';

/// 어떤 레이어를 그릴지. [AnimatedMochiWidget] 처럼 본체만 흔들고 배경은
/// 고정해야 할 때 두 인스턴스로 분리해서 Stack 으로 겹친다.
/// - [full]: squircle 배경 + 본체 + 액세서리 (정적 렌더)
/// - [background]: squircle 색 배경만 (+ 스포트라이트·접지 그림자)
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

/// 모찌 캐릭터를 [size]×[size] 정사각형으로 3D 렌더 스타일로 그린다.
///
/// 3D 룩 구현 노트 — flutter_svg 는 `<filter>`(blur/drop-shadow) 를 지원하지
/// 않으므로, 입체감은 전부 그라디언트/불투명도 레이어로 만든다:
/// - 본체: 좌상단 광원 radial 그라디언트(mBody) + 외곽 림 셰이딩(mRim)
///   + 스펙큘러 하이라이트 타원 → 말랑한 구체 볼륨
/// - 배경: 스킨색 상→하 그라디언트(mBg) + 캐릭터 뒤 스포트라이트(mSpot)
/// - 바닥: 소프트 접지 그림자(mGround, radial fade) — background 레이어에 있어
///   본체가 점프해도 그림자는 바닥에 남는다
/// - 액세서리/왕관/꽃도 각자 그라디언트+하이라이트로 통일
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
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(debugSvgMarkup(), width: size, height: size),
    );
  }

  /// 이 인스턴스가 그릴 SVG 마크업. `tool/render_stages.html` 미리보기 재생성
  /// (test/tools/render_stages_generator_test.dart) 에서 사용 — 위젯이 실제로
  /// 렌더하는 문자열과 항상 동일함을 보장한다.
  @visibleForTesting
  String debugSvgMarkup() {
    final cleanHex = appearance.skinHex.startsWith('#')
        ? appearance.skinHex
        : '#${appearance.skinHex}';
    return _buildStageSvg(stage, cleanHex, appearance);
  }

  // ── 색 유틸 ────────────────────────────────

  /// '#RRGGBB' 를 흰색([toWhite]=true) 또는 검정과 [t] 비율로 섞은 hex 반환.
  /// 스킨색 하나로 배경 그라디언트의 밝은/어두운 톤과 접지 그림자 색을 만든다.
  static String _mixHex(String hex, double t, {required bool toWhite}) {
    final v = int.parse(hex.substring(1), radix: 16);
    int mix(int c) => toWhite
        ? (c + ((255 - c) * t)).round().clamp(0, 255)
        : ((c * (1 - t)).round()).clamp(0, 255);
    final r = mix((v >> 16) & 0xFF);
    final g = mix((v >> 8) & 0xFF);
    final b = mix(v & 0xFF);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  // ── 얼굴 헬퍼 ────────────────────────────────

  /// 눈 하나를 SVG 요소로 반환. 감정·개방도에 따라 모양이 달라짐.
  /// 3D 룩: 채워진 눈(타원)에는 좌상단 캐치라이트(반사광 점)를 얹는다.
  /// sleepy 는 나른한 인상을 위해, happy(호선) 는 면이 없어 캐치라이트 생략.
  String _eye(double cx, double cy, double rx, double ry) {
    final ey = (ry * eyeOpenness).clamp(0.15, ry);
    final top = (cy - ry * 2.2 * eyeOpenness.clamp(0.1, 1.0)).toStringAsFixed(1);
    final showLight = eyeOpenness > 0.5;
    String catchlight(double dx, double dy, double r) => showLight
        ? '<circle cx="${(cx + dx).toStringAsFixed(1)}" cy="${(cy + dy).toStringAsFixed(1)}" r="$r" fill="#FFFFFF" opacity="0.9"/>'
        : '';
    return switch (expression) {
      MochiEmotion.idle =>
        '<ellipse cx="$cx" cy="$cy" rx="$rx" ry="${ey.toStringAsFixed(2)}" fill="#2B2B2B"/>'
            '${catchlight(-0.9, -1.2, 0.9)}',
      MochiEmotion.happy =>
        '<path d="M${cx - rx} $cy Q$cx $top ${cx + rx} $cy" stroke="#2B2B2B" stroke-width="2.2" fill="none" stroke-linecap="round"/>',
      MochiEmotion.excited =>
        '<ellipse cx="$cx" cy="$cy" rx="${(rx * 1.2).toStringAsFixed(1)}" ry="${(ry * 1.2 * eyeOpenness).clamp(0.1, ry * 1.2).toStringAsFixed(2)}" fill="#2B2B2B"/>'
            '${catchlight(-1.1, -1.4, 1.1)}',
      MochiEmotion.sleepy =>
        '<ellipse cx="$cx" cy="${(cy + ry * 0.4).toStringAsFixed(1)}" rx="$rx" ry="${(ry * 0.45 * eyeOpenness).clamp(0.1, ry).toStringAsFixed(2)}" fill="#2B2B2B"/>',
      MochiEmotion.proud =>
        '<ellipse cx="$cx" cy="$cy" rx="$rx" ry="${(ry * 0.65 * eyeOpenness).clamp(0.1, ry).toStringAsFixed(2)}" fill="#2B2B2B"/>'
            '${catchlight(-0.9, -1.0, 0.8)}',
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

  /// 볼 홍조 한 쌍 — radial fade 로 부드럽게 스며드는 3D 톤.
  static String _cheeks(double leftCx, double rightCx, double cy) =>
      '<ellipse cx="$leftCx" cy="$cy" rx="6.5" ry="4.2" fill="url(#mCheek)"/>'
      '<ellipse cx="$rightCx" cy="$cy" rx="6.5" ry="4.2" fill="url(#mCheek)"/>';

  // ─────────────────────────────────────────
  // 3D 본체 헬퍼 — 그라디언트 바디 + 림 셰이딩 + 스펙큘러 하이라이트
  // ─────────────────────────────────────────

  /// 말랑한 구체 본체. [patches] (판다 무늬 등) 는 바디 위·림 셰이딩 아래에 끼워
  /// 무늬도 함께 음영을 받는다.
  static String _body3d({
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    String patches = '',
  }) {
    final hlCx = (cx - rx * 0.40).toStringAsFixed(1);
    final hlCy = (cy - ry * 0.48).toStringAsFixed(1);
    final hlRx = (rx * 0.32).toStringAsFixed(1);
    final hlRy = (ry * 0.18).toStringAsFixed(1);
    final dotCx = (cx - rx * 0.06).toStringAsFixed(1);
    final dotCy = (cy - ry * 0.68).toStringAsFixed(1);
    final dotR = (rx * 0.05).toStringAsFixed(1);
    return '''
  <ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="url(#mBody)"/>
  $patches
  <ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="url(#mRim)"/>
  <ellipse cx="$hlCx" cy="$hlCy" rx="$hlRx" ry="$hlRy" fill="#FFFFFF" opacity="0.6" transform="rotate(-16 $hlCx $hlCy)"/>
  <circle cx="$dotCx" cy="$dotCy" r="$dotR" fill="#FFFFFF" opacity="0.75"/>
''';
  }

  // ─────────────────────────────────────────
  // 단계별 본문 SVG (배경 rect 는 외부에서 결합)
  // ─────────────────────────────────────────

  String _buildStageSvg(CharacterStage stage, String hex, MochiAppearance app) {
    final safeHex = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
        ? hex.toUpperCase()
        : '#FF6B6B';
    final bgLight = _mixHex(safeHex, 0.20, toWhite: true);
    final bgDark = _mixHex(safeHex, 0.14, toWhite: false);
    final shadowCol = _mixHex(safeHex, 0.48, toWhite: false);
    final defs = _defs(
      bgLight: bgLight,
      bgBase: safeHex,
      bgDark: bgDark,
      shadowCol: shadowCol,
    );
    final isEgg = stage == CharacterStage.egg;
    // 접지 그림자 — 본체 바닥에 맞춰 단계별 위치 보정. background 레이어에 있어
    // 점프 애니메이션 때 본체만 떠오르고 그림자는 바닥에 남는다.
    final bodyBottom = switch (stage) {
      CharacterStage.egg => 178.0,
      CharacterStage.sprout => 164.0,
      _ => 168.0,
    };
    final ground =
        '<ellipse cx="100" cy="${(bodyBottom + 3.5).toStringAsFixed(1)}" rx="${isEgg ? 44 : 42}" ry="7.5" fill="url(#mGround)"/>';
    // 판타지 배경 — 스킨색 그라디언트 위에 오로라 글로우 2개(흰빛·보랏빛)와
    // 반짝이 별·빛 방울(보케)을 흩뿌린다. 캐릭터 본체(중앙 하단)를 가리지 않도록
    // 장식은 상단·좌우 가장자리에만 둔다. flutter_svg 는 <filter> 미지원이라
    // 흐림 효과는 전부 radial 그라디언트 fade 로 표현한다.
    final bg = '<rect width="200" height="200" rx="48" fill="url(#mBg)"/>\n'
        '  <ellipse cx="52" cy="30" rx="64" ry="42" fill="url(#mAuroraW)"/>\n'
        '  <ellipse cx="158" cy="52" rx="52" ry="38" fill="url(#mAuroraV)"/>\n'
        '  <ellipse cx="24" cy="120" rx="40" ry="52" fill="url(#mAuroraV)" opacity="0.55"/>\n'
        '  <ellipse cx="100" cy="106" rx="82" ry="76" fill="url(#mSpot)"/>\n'
        '  ${_sparkle(31, 32, 5.5, 0.85)}\n'
        '  ${_sparkle(170, 27, 4.5, 0.7)}\n'
        '  ${_sparkle(146, 14, 2.8, 0.55)}\n'
        '  ${_sparkle(22, 78, 3.2, 0.6)}\n'
        '  ${_sparkle(181, 96, 3.8, 0.65)}\n'
        '  ${_sparkle(58, 14, 2.4, 0.5)}\n'
        '  <circle cx="40" cy="58" r="4" fill="url(#mOrb)"/>\n'
        '  <circle cx="167" cy="72" r="3" fill="url(#mOrb)"/>\n'
        '  <circle cx="14" cy="150" r="2.6" fill="url(#mOrb)"/>\n'
        '  <circle cx="186" cy="140" r="3.4" fill="url(#mOrb)"/>\n'
        '  <circle cx="92" cy="18" r="2.2" fill="url(#mOrb)"/>\n'
        '  $ground';
    final isPanda = app.skinAssetKey == 'skin/panda';
    final body = switch (stage) {
      CharacterStage.egg => _egg(isPanda: isPanda),
      CharacterStage.sprout => _sprout(isPanda: isPanda),
      CharacterStage.bloom => _bloom(isPanda: isPanda),
      CharacterStage.blossom => _blossom(isPanda: isPanda),
      CharacterStage.glow => _glow(isPanda: isPanda),
      CharacterStage.master => _master(isPanda: isPanda),
    };
    final overlays = _buildOverlays(stage, app.overlays);
    final layers = switch (part) {
      MochiCharacterPart.full => '$bg\n  $body\n  $overlays',
      MochiCharacterPart.background => bg,
      MochiCharacterPart.body => '$body\n  $overlays',
    };
    return '''
<svg width="200" height="200" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
  $defs
  $layers
</svg>
''';
  }

  /// 4각 반짝이 별 — 오목한 곡선 4개로 이어지는 다이아 스파클. 배경 장식용.
  static String _sparkle(double cx, double cy, double r, double opacity) {
    final t = (cy - r).toStringAsFixed(1);
    final b = (cy + r).toStringAsFixed(1);
    final l = (cx - r).toStringAsFixed(1);
    final rt = (cx + r).toStringAsFixed(1);
    return '<path d="M$cx $t Q$cx $cy $rt $cy Q$cx $cy $cx $b '
        'Q$cx $cy $l $cy Q$cx $cy $cx $t Z" fill="#FFFFFF" opacity="$opacity"/>';
  }

  /// 공용 그라디언트 defs. 모든 레이어(part) 의 SVG 에 동일하게 포함된다 —
  /// 미사용 그라디언트가 섞여 있어도 렌더 비용은 무시 가능하고, id 충돌이 없다.
  static String _defs({
    required String bgLight,
    required String bgBase,
    required String bgDark,
    required String shadowCol,
  }) => '''
<defs>
    <linearGradient id="mBg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="$bgLight"/>
      <stop offset="52%" stop-color="$bgBase"/>
      <stop offset="100%" stop-color="$bgDark"/>
    </linearGradient>
    <radialGradient id="mSpot" cx="0.5" cy="0.42" r="0.58">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.30"/>
      <stop offset="65%" stop-color="#FFFFFF" stop-opacity="0.08"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="mAuroraW" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.42"/>
      <stop offset="55%" stop-color="#FFFFFF" stop-opacity="0.14"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="mAuroraV" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#A78BFA" stop-opacity="0.38"/>
      <stop offset="55%" stop-color="#A78BFA" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#A78BFA" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="mOrb" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.9"/>
      <stop offset="60%" stop-color="#FFFFFF" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="mGround" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="$shadowCol" stop-opacity="0.34"/>
      <stop offset="60%" stop-color="$shadowCol" stop-opacity="0.16"/>
      <stop offset="100%" stop-color="$shadowCol" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="mBody" cx="0.38" cy="0.30" r="0.88">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="46%" stop-color="#FFF6F7"/>
      <stop offset="78%" stop-color="#F5E2E8"/>
      <stop offset="100%" stop-color="#E4C9D2"/>
    </radialGradient>
    <radialGradient id="mRim" cx="0.40" cy="0.32" r="0.75">
      <stop offset="0%" stop-color="#B9899B" stop-opacity="0"/>
      <stop offset="74%" stop-color="#B9899B" stop-opacity="0"/>
      <stop offset="100%" stop-color="#B9899B" stop-opacity="0.32"/>
    </radialGradient>
    <radialGradient id="mCheek" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FF8FA3" stop-opacity="0.75"/>
      <stop offset="100%" stop-color="#FF8FA3" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="mPanda" cx="0.40" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#565656"/>
      <stop offset="60%" stop-color="#343434"/>
      <stop offset="100%" stop-color="#1E1E1E"/>
    </radialGradient>
    <linearGradient id="mLeafL" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#A5E793"/>
      <stop offset="100%" stop-color="#5BB04A"/>
    </linearGradient>
    <linearGradient id="mLeafR" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#7ECB6C"/>
      <stop offset="100%" stop-color="#3E8C33"/>
    </linearGradient>
    <radialGradient id="mPetalA" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFD9E1"/>
      <stop offset="60%" stop-color="#FF9FB0"/>
      <stop offset="100%" stop-color="#F0788F"/>
    </radialGradient>
    <radialGradient id="mPetalB" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFE3E9"/>
      <stop offset="60%" stop-color="#FFB6C1"/>
      <stop offset="100%" stop-color="#F58CA0"/>
    </radialGradient>
    <radialGradient id="mPetalC" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFF0F5"/>
      <stop offset="60%" stop-color="#FFC9D9"/>
      <stop offset="100%" stop-color="#F7A6BF"/>
    </radialGradient>
    <radialGradient id="mFlowerCore" cx="0.40" cy="0.35" r="0.80">
      <stop offset="0%" stop-color="#FFFDE8"/>
      <stop offset="60%" stop-color="#FFEFA8"/>
      <stop offset="100%" stop-color="#E5BE55"/>
    </radialGradient>
    <linearGradient id="mGold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFF3A6"/>
      <stop offset="55%" stop-color="#FCD34D"/>
      <stop offset="100%" stop-color="#D69A18"/>
    </linearGradient>
    <radialGradient id="mGoldR" cx="0.38" cy="0.32" r="0.80">
      <stop offset="0%" stop-color="#FFF8D2"/>
      <stop offset="60%" stop-color="#FFE08A"/>
      <stop offset="100%" stop-color="#C9A227"/>
    </radialGradient>
    <radialGradient id="mGemR" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFB3B3"/>
      <stop offset="60%" stop-color="#FF6B6B"/>
      <stop offset="100%" stop-color="#C43333"/>
    </radialGradient>
    <radialGradient id="mGemG" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#A9F0D3"/>
      <stop offset="60%" stop-color="#34D399"/>
      <stop offset="100%" stop-color="#1D9A6C"/>
    </radialGradient>
    <radialGradient id="mGemB" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#C4DCFB"/>
      <stop offset="60%" stop-color="#7CB1F5"/>
      <stop offset="100%" stop-color="#4478C8"/>
    </radialGradient>
    <radialGradient id="mSparkGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFF59D" stop-opacity="0.85"/>
      <stop offset="100%" stop-color="#FFF59D" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="masterHalo" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFF8C4" stop-opacity="0.75"/>
      <stop offset="55%" stop-color="#FFE066" stop-opacity="0.28"/>
      <stop offset="100%" stop-color="#FFE066" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="aCone" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FF9D9D"/>
      <stop offset="100%" stop-color="#D94A4A"/>
    </linearGradient>
    <linearGradient id="aScarf" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#A8CBFA"/>
      <stop offset="100%" stop-color="#5F97E6"/>
    </linearGradient>
    <linearGradient id="aBow" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#C75A7E"/>
      <stop offset="100%" stop-color="#7E2440"/>
    </linearGradient>
    <linearGradient id="aSunLens" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#4E4E4E"/>
      <stop offset="100%" stop-color="#101010"/>
    </linearGradient>
    <radialGradient id="aHeartGlass" cx="0.38" cy="0.30" r="0.85">
      <stop offset="0%" stop-color="#FF9D9D"/>
      <stop offset="100%" stop-color="#E14A4A"/>
    </radialGradient>
    <radialGradient id="aBalloon" cx="0.36" cy="0.30" r="0.85">
      <stop offset="0%" stop-color="#FFF3BC"/>
      <stop offset="55%" stop-color="#FCD34D"/>
      <stop offset="100%" stop-color="#D19A1E"/>
    </radialGradient>
    <radialGradient id="aBalloonHeart" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFB1B1"/>
      <stop offset="55%" stop-color="#FF6B6B"/>
      <stop offset="100%" stop-color="#C13A3A"/>
    </radialGradient>
    <linearGradient id="aChef" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#E4E4EC"/>
    </linearGradient>
    <radialGradient id="aRibbonPink" cx="0.40" cy="0.35" r="0.85">
      <stop offset="0%" stop-color="#FFC6D2"/>
      <stop offset="100%" stop-color="#F0789B"/>
    </radialGradient>
  </defs>''';

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
      'item/glasses_sun' => _glassesSun(a),
      'item/hairpin_star' => _hairpinStar(a),
      'item/hairpin_ribbon' => _hairpinRibbon(a),
      'item/hairpin_flower' => _hairpinFlower(a),
      'item/hat_party' => _hatParty(a),
      'item/hat_chef' => _hatChef(a),
      'item/bowtie' => _bowtie(a),
      'item/scarf' => _scarf(a),
      'item/necklace' => _necklace(a),
      'item/balloon' => _balloon(a),
      'item/balloon_heart' => _balloonHeart(a),
      'item/flower' => _flowerSide(a),
      'item/star' => _starCharm(a),
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

  // ── 개별 아이템 SVG 단편 (그라디언트 + 하이라이트로 입체감) ──────

  String _glassesRound(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <circle cx="-10" cy="0" r="7.5" fill="#FFFFFF" fill-opacity="0.16" stroke="#2B2B2B" stroke-width="2.5"/>
    <circle cx="10"  cy="0" r="7.5" fill="#FFFFFF" fill-opacity="0.16" stroke="#2B2B2B" stroke-width="2.5"/>
    <line x1="-2.5" y1="0" x2="2.5" y2="0" stroke="#2B2B2B" stroke-width="2"/>
    <path d="M-14 -3 Q-11 -5.5 -8 -4.5" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round" opacity="0.7" fill="none"/>
    <path d="M6 -3 Q9 -5.5 12 -4.5" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round" opacity="0.7" fill="none"/>
  </g>
  ''';

  String _glassesHeart(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-16 -2 C-16 -8 -10 -10 -10 -4 C-10 -10 -4 -8 -4 -2 C-4 3 -10 8 -10 8 C-10 8 -16 3 -16 -2 Z" fill="url(#aHeartGlass)" stroke="#A23838" stroke-width="1"/>
    <path d="M4 -2 C4 -8 10 -10 10 -4 C10 -10 16 -8 16 -2 C16 3 10 8 10 8 C10 8 4 3 4 -2 Z" fill="url(#aHeartGlass)" stroke="#A23838" stroke-width="1"/>
    <line x1="-4" y1="-2" x2="4" y2="-2" stroke="#A23838" stroke-width="2"/>
    <circle cx="-13" cy="-4" r="1.2" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="7" cy="-4" r="1.2" fill="#FFFFFF" opacity="0.85"/>
  </g>
  ''';

  String _glassesSun(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <rect x="-17" y="-6" width="14" height="11" rx="3" fill="url(#aSunLens)"/>
    <rect x="3" y="-6" width="14" height="11" rx="3" fill="url(#aSunLens)"/>
    <line x1="-3" y1="-3" x2="3" y2="-3" stroke="#2B2B2B" stroke-width="2"/>
    <line x1="-14" y1="-4" x2="-7" y2="-4" stroke="#9C9C9C" stroke-width="1.4" stroke-linecap="round" opacity="0.85"/>
    <line x1="6" y1="-4" x2="13" y2="-4" stroke="#9C9C9C" stroke-width="1.4" stroke-linecap="round" opacity="0.85"/>
  </g>
  ''';

  String _hairpinFlower(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <circle cx="0" cy="-3.2" r="3" fill="url(#mPetalA)"/>
    <circle cx="3" cy="-0.5" r="3" fill="url(#mPetalA)"/>
    <circle cx="-3" cy="-0.5" r="3" fill="url(#mPetalA)"/>
    <circle cx="1.8" cy="3" r="3" fill="url(#mPetalA)"/>
    <circle cx="-1.8" cy="3" r="3" fill="url(#mPetalA)"/>
    <circle cx="0" cy="0" r="1.7" fill="url(#mFlowerCore)"/>
    <circle cx="-1" cy="-4" r="0.9" fill="#FFFFFF" opacity="0.7"/>
  </g>
  ''';

  String _hairpinStar(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M0 -7 L2.2 -2 L7 -1.5 L3.4 2.3 L4.4 7.5 L0 5 L-4.4 7.5 L-3.4 2.3 L-7 -1.5 L-2.2 -2 Z" fill="url(#mGold)" stroke="#B8860B" stroke-width="0.8"/>
    <circle cx="-1.4" cy="-2.6" r="0.9" fill="#FFFFFF" opacity="0.8"/>
  </g>
  ''';

  String _hairpinRibbon(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-8 0 Q-2 -4 0 0 Q-2 4 -8 0 Z" fill="url(#aRibbonPink)" stroke="#A23854" stroke-width="0.8"/>
    <path d="M8 0 Q2 -4 0 0 Q2 4 8 0 Z" fill="url(#aRibbonPink)" stroke="#A23854" stroke-width="0.8"/>
    <circle cx="0" cy="0" r="2" fill="#A23854"/>
    <circle cx="-0.6" cy="-0.6" r="0.7" fill="#FFFFFF" opacity="0.7"/>
  </g>
  ''';

  String _hatParty(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 32})">
    <path d="M0 -22 L-12 6 L12 6 Z" fill="url(#aCone)" stroke="#A23838" stroke-width="1"/>
    <path d="M-1.5 -18 L-8 3" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.45"/>
    <circle cx="0" cy="-23" r="3" fill="url(#mGoldR)"/>
    <circle cx="-0.8" cy="-23.8" r="0.9" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="-6" cy="-4" r="1.6" fill="#FFFFFF"/>
    <circle cx="6" cy="-12" r="1.6" fill="#FFFFFF"/>
  </g>
  ''';

  String _hatChef(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 30})">
    <ellipse cx="-6" cy="-12" rx="7" ry="6" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="6" cy="-12" rx="7" ry="6" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="0" cy="-15" rx="7" ry="6" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <rect x="-12" y="-6" width="24" height="10" rx="2" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="-3" cy="-17" rx="3" ry="1.8" fill="#FFFFFF" opacity="0.9"/>
  </g>
  ''';

  String _bowtie(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-14 -4 L-2 0 L-14 4 Z" fill="url(#aBow)" stroke="#5A1F30" stroke-width="0.8"/>
    <path d="M14 -4 L2 0 L14 4 Z" fill="url(#aBow)" stroke="#5A1F30" stroke-width="0.8"/>
    <rect x="-3" y="-3" width="6" height="6" rx="1.4" fill="#5A1F30"/>
    <rect x="-2" y="-2" width="2.4" height="2.4" rx="0.8" fill="#FFFFFF" opacity="0.35"/>
  </g>
  ''';

  String _scarf(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-20 -4 Q0 -10 20 -4 L20 4 Q0 -2 -20 4 Z" fill="url(#aScarf)" stroke="#2C5BA6" stroke-width="0.8"/>
    <path d="M-8 4 L-12 22 L-4 18 Z" fill="url(#aScarf)" stroke="#2C5BA6" stroke-width="0.8"/>
    <path d="M-16 -4 Q0 -9 16 -4" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" opacity="0.5" fill="none"/>
  </g>
  ''';

  String _balloon(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 30})">
    <ellipse cx="0" cy="0" rx="14" ry="18" fill="url(#aBalloon)" stroke="#B8860B" stroke-width="0.8"/>
    <ellipse cx="-5" cy="-7" rx="4.5" ry="7" fill="#FFFFFF" opacity="0.5" transform="rotate(-18 -5 -7)"/>
    <path d="M-2 17 L0 22 L2 17 Z" fill="#B8860B"/>
    <path d="M0 22 Q-4 36 4 50" stroke="#9CA3AF" stroke-width="1.2" fill="none"/>
  </g>
  ''';

  String _balloonHeart(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 30})">
    <path d="M0 18 C0 7 -15 5 -15 -5 C-15 -13 -5 -13 0 -5 C5 -13 15 -13 15 -5 C15 5 0 7 0 18 Z" fill="url(#aBalloonHeart)" stroke="#A23838" stroke-width="0.8"/>
    <ellipse cx="-7" cy="-6" rx="3.4" ry="4.6" fill="#FFFFFF" opacity="0.5" transform="rotate(-22 -7 -6)"/>
    <path d="M0 18 Q-4 34 4 50" stroke="#9CA3AF" stroke-width="1.2" fill="none"/>
  </g>
  ''';

  String _necklace(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-18 -3 Q0 14 18 -3" stroke="#E8E8EE" stroke-width="2" fill="none"/>
    <circle cx="-8" cy="4" r="2" fill="#F2F2F7" stroke="#C9CBD6" stroke-width="0.6"/>
    <circle cx="8" cy="4" r="2" fill="#F2F2F7" stroke="#C9CBD6" stroke-width="0.6"/>
    <circle cx="0" cy="9" r="3.2" fill="url(#mGoldR)" stroke="#C9A227" stroke-width="0.7"/>
    <circle cx="-0.9" cy="8.1" r="0.9" fill="#FFFFFF" opacity="0.85"/>
  </g>
  ''';

  String _starCharm(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M0 -9 L2.6 -2.6 L9 -2.6 L3.8 1.6 L5.6 8 L0 4.2 L-5.6 8 L-3.8 1.6 L-9 -2.6 L-2.6 -2.6 Z" fill="url(#mGold)" stroke="#B8860B" stroke-width="0.8"/>
    <circle cx="0" cy="-0.5" r="1.6" fill="#FFF3B0"/>
    <circle cx="-1.8" cy="-3.6" r="0.9" fill="#FFFFFF" opacity="0.8"/>
  </g>
  ''';

  String _flowerSide(_Anchor a) => '''
  <g transform="translate(${a.cx - 6} ${a.cy + 22})">
    <line x1="0" y1="0" x2="0" y2="20" stroke="#4E9C41" stroke-width="2"/>
    <line x1="-0.7" y1="2" x2="-0.7" y2="18" stroke="#83CF74" stroke-width="0.8" opacity="0.8"/>
    <circle cx="0" cy="0" r="5" fill="url(#mPetalB)"/>
    <circle cx="4" cy="-3" r="5" fill="url(#mPetalB)"/>
    <circle cx="-4" cy="-3" r="5" fill="url(#mPetalB)"/>
    <circle cx="2" cy="3" r="5" fill="url(#mPetalB)"/>
    <circle cx="-2" cy="3" r="5" fill="url(#mPetalB)"/>
    <circle cx="0" cy="0" r="2.2" fill="url(#mFlowerCore)"/>
    <circle cx="-2" cy="-5" r="1.3" fill="#FFFFFF" opacity="0.65"/>
  </g>
  ''';

  // ─────────────────────────────────────────
  // 단계별 베이스 SVG (스킨이 panda 일 때 흑백 패턴 보강)
  // ─────────────────────────────────────────

  /// EGG (Lv 1): 잠자고 있는 알 모찌. 눈은 ‿ 처럼 감겨 있고, 우상단에 zZz.
  String _egg({required bool isPanda}) {
    final pandaPatches = isPanda
        ? '<ellipse cx="78" cy="106" rx="13" ry="10" fill="url(#mPanda)"/>'
            '<ellipse cx="122" cy="106" rx="13" ry="10" fill="url(#mPanda)"/>'
        : '';
    return '''
  ${_body3d(cx: 100, cy: 120, rx: 52, ry: 58, patches: pandaPatches)}
  <path d="M82 116 Q88 119 94 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M106 116 Q112 119 118 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M92 134 Q100 140 108 134" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  ${_cheeks(74, 126, 130)}
  <text x="148" y="74" font-family="Inter, Arial, sans-serif" font-size="22" font-weight="700" fill="#FFFFFF" opacity="0.85">Z</text>
  <text x="162" y="92" font-family="Inter, Arial, sans-serif" font-size="14" font-weight="700" fill="#FFFFFF" opacity="0.7">z</text>
  <text x="170" y="106" font-family="Inter, Arial, sans-serif" font-size="9" font-weight="700" fill="#FFFFFF" opacity="0.55">z</text>
  ''';
  }

  String _sprout({required bool isPanda}) {
    final pandaPatches = isPanda
        ? '<ellipse cx="82" cy="118" rx="9" ry="6" fill="url(#mPanda)"/>'
            '<ellipse cx="118" cy="118" rx="9" ry="6" fill="url(#mPanda)"/>'
        : '';
    return '''
  <g>
    <path d="M100 56 Q86 48 92 64 Q98 68 100 64 Z" fill="url(#mLeafL)"/>
    <path d="M100 56 Q114 48 108 64 Q102 68 100 64 Z" fill="url(#mLeafR)"/>
    <line x1="100" y1="66" x2="100" y2="84" stroke="#6FBF5E" stroke-width="3" stroke-linecap="round"/>
    <line x1="99" y1="68" x2="99" y2="80" stroke="#A5E793" stroke-width="1" stroke-linecap="round" opacity="0.8"/>
  </g>
  ${_body3d(cx: 100, cy: 124, rx: 46, ry: 40, patches: pandaPatches)}
  ${_eye(88, 122, 2.8, 3.6)}
  ${_eye(112, 122, 2.8, 3.6)}
  ${_mouth(93, 136, 100, 142, 107, 136, 2.4)}
  ${_cheeks(76, 124, 132)}
  ''';
  }

  /// BLOOM (Lv 6) — 꽃 모찌: 머리에 막 피어난 작은 벚꽃. 단독 모찌.
  String _bloom({required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
        : '';
    return '''
  <g>
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: patches)}
    <g transform="translate(100 72)">
      ${_flower(scale: 0.85, petalId: 'mPetalA')}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    ${_cheeks(72, 128, 132)}
  </g>
  ''';
  }

  /// BLOSSOM (Lv 10) — 활짝 모찌: 큰 벚꽃 + 옆에 작은 봉오리. 디코는 이 단계부터 별개로 등장.
  String _blossom({required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
        : '';
    return '''
  <g>
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: patches)}
    <g transform="translate(100 62)">
      ${_flower(scale: 1.35, petalId: 'mPetalA')}
    </g>
    <g transform="translate(140 78)">
      ${_flower(scale: 0.55, petalId: 'mPetalB')}
    </g>
    <g transform="translate(60 78)">
      ${_flower(scale: 0.45, petalId: 'mPetalC')}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    ${_cheeks(72, 128, 132)}
  </g>
  ''';
  }

  /// GLOW (Lv 15) — 왕관과 함께 빛나는 단독 모찌. 주변 스파클 4 점 (glow halo 포함).
  String _glow({required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
        : '';
    return '''
  <g opacity="0.95">
    <circle cx="32" cy="44" r="9" fill="url(#mSparkGlow)"/>
    <circle cx="32" cy="44" r="3.4" fill="#FFF59D"/>
    <circle cx="168" cy="58" r="7" fill="url(#mSparkGlow)"/>
    <circle cx="168" cy="58" r="2.6" fill="#FFF59D"/>
    <circle cx="40" cy="158" r="6.5" fill="url(#mSparkGlow)"/>
    <circle cx="40" cy="158" r="2.4" fill="#FFF59D"/>
    <circle cx="170" cy="148" r="8" fill="url(#mSparkGlow)"/>
    <circle cx="170" cy="148" r="3" fill="#FFF59D"/>
  </g>
  <g>
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: patches)}
    <g transform="translate(100 70)">
      ${_crown()}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    ${_cheeks(72, 128, 132)}
  </g>
  ''';
  }

  /// MASTER (Lv 20) — 마스터 모찌: 큰 후광 + 별빛 + 디럭스 왕관. 단독 모찌.
  String _master({required bool isPanda}) {
    final patches = isPanda
        ? '<ellipse cx="86" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
            '<ellipse cx="114" cy="116" rx="11" ry="8" fill="url(#mPanda)"/>'
        : '';
    return '''
  <circle cx="100" cy="118" r="92" fill="url(#masterHalo)"/>
  <g opacity="0.95">
    <path d="M30 36 L33 44 L41 44 L34.5 49 L37 57 L30 52 L23 57 L25.5 49 L19 44 L27 44 Z" fill="url(#mGold)"/>
    <path d="M170 50 L172 56 L178 56 L173 60 L175 66 L170 62.5 L165 66 L167 60 L162 56 L168 56 Z" fill="#FFF59D"/>
    <path d="M40 160 L42 165 L47 165 L43 168 L44.5 173 L40 170 L35.5 173 L37 168 L33 165 L38 165 Z" fill="url(#mGold)"/>
    <path d="M170 152 L172 158 L178 158 L173 162 L175 168 L170 164.5 L165 168 L167 162 L162 158 L168 158 Z" fill="#FFF59D"/>
    <circle cx="100" cy="30" r="3" fill="#FFE066"/>
    <circle cx="14" cy="100" r="2.4" fill="#FFE066"/>
    <circle cx="186" cy="100" r="2.4" fill="#FFE066"/>
  </g>
  <g>
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: patches)}
    <g transform="translate(100 68)">
      ${_crownDeluxe()}
    </g>
    <g transform="translate(100 52)">
      ${_starCrown()}
    </g>
    ${_eye(86, 122, 2.8, 3.6)}
    ${_eye(114, 122, 2.8, 3.6)}
    ${_mouth(92, 136, 100, 142, 108, 136, 2.4)}
    ${_cheeks(72, 128, 132)}
  </g>
  ''';
  }

  /// 큰 별 왕관 — 머리 위 별 (MASTER 단계).
  static String _starCrown() => '''
  <path d="M0 -12 L3 -3 L12 -3 L4.5 3 L7 12 L0 7 L-7 12 L-4.5 3 L-12 -3 L-3 -3 Z" fill="url(#mGold)" stroke="#B8860B" stroke-width="1" stroke-linejoin="round"/>
  <circle cx="0" cy="-1" r="2" fill="url(#mGemR)"/>
  <circle cx="-2.6" cy="-5.4" r="1" fill="#FFFFFF" opacity="0.85"/>
  ''';

  /// 더 화려한 왕관 (MASTER 단계). 보석 3개 + 별 — 골드 그라디언트 + 보석 광택.
  static String _crownDeluxe() => '''
  <path d="M-16 4 L-16 -6 L-10 -2 L-6 -8 L0 -12 L6 -8 L10 -2 L16 -6 L16 4 Z" fill="url(#mGold)" stroke="#B8860B" stroke-width="1" stroke-linejoin="round"/>
  <path d="M-16 1.8 L16 1.8 L16 4 L-16 4 Z" fill="#B8761A" opacity="0.35"/>
  <circle cx="-9" cy="0" r="1.8" fill="url(#mGemG)"/>
  <circle cx="0" cy="-2" r="2.2" fill="url(#mGemR)"/>
  <circle cx="9" cy="0" r="1.8" fill="url(#mGemB)"/>
  <circle cx="-0.7" cy="-2.8" r="0.7" fill="#FFFFFF" opacity="0.9"/>
  <path d="M0 -16 L1.4 -13 L4.5 -13 L2 -11 L2.8 -8 L0 -10 L-2.8 -8 L-2 -11 L-4.5 -13 L-1.4 -13 Z" fill="#FFF59D" stroke="#B8860B" stroke-width="0.8"/>
  ''';

  /// 벚꽃 한 송이 — 꽃잎은 [petalId] 그라디언트, 중심은 mFlowerCore + 하이라이트.
  static String _flower({double scale = 1.0, String petalId = 'mPetalA'}) {
    final s = scale.toStringAsFixed(2);
    return '''
    <g transform="scale($s)">
      <circle cx="0" cy="-6" r="5" fill="url(#$petalId)"/>
      <circle cx="6" cy="-2" r="5" fill="url(#$petalId)"/>
      <circle cx="3" cy="6" r="5" fill="url(#$petalId)"/>
      <circle cx="-3" cy="6" r="5" fill="url(#$petalId)"/>
      <circle cx="-6" cy="-2" r="5" fill="url(#$petalId)"/>
      <circle cx="0" cy="0" r="2.6" fill="url(#mFlowerCore)"/>
      <circle cx="-1.5" cy="-7.5" r="1.4" fill="#FFFFFF" opacity="0.55"/>
    </g>
    ''';
  }

  /// GLOW 단계 왕관 — 골드 그라디언트 + 하이라이트.
  static String _crown() => '''
  <path d="M-14 4 L-14 -6 L-7 0 L0 -10 L7 0 L14 -6 L14 4 Z" fill="url(#mGold)" stroke="#B8860B" stroke-width="1" stroke-linejoin="round"/>
  <path d="M-14 2 L14 2 L14 4 L-14 4 Z" fill="#B8761A" opacity="0.35"/>
  <circle cx="0" cy="-7" r="1.6" fill="url(#mGemR)"/>
  <circle cx="-0.5" cy="-7.5" r="0.5" fill="#FFFFFF" opacity="0.9"/>
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
