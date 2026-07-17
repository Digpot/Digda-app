import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/character_models.dart';

/// 어떤 레이어를 그릴지. [AnimatedMochiWidget] 처럼 본체만 흔들고 배경은
/// 고정해야 할 때 두 인스턴스로 분리해서 Stack 으로 겹친다.
/// - [full]: squircle 배경 + 본체 + 액세서리 (정적 렌더)
/// - [background]: squircle 색 배경만 (+ 스포트라이트·접지 그림자)
/// - [body]: 본체·표정·액세서리만 (배경 투명)
enum MochiCharacterPart { full, background, body }

/// 모찌의 외형 정보. [skinHex] 는 스킨 색(기본 배경 하늘 톤에 반영), [skinAssetKey] 는
/// 패턴 식별자(예: 'skin/coral', 'skin/panda'). [backgroundAssetKey] 는 배경 씬
/// (예: 'bg/meadow', 'bg/night'). [overlays] 는 머리/얼굴/목·옆에 그릴 액세서리들.
///
/// [CharacterState.equippedItems] 에서 직접 만들거나, 상점 미리보기처럼 임의 조합으로
/// 만들어 사용 가능. SKIN 슬롯은 [skinHex]/[skinAssetKey], BACKGROUND 슬롯은
/// [backgroundAssetKey] 로 분리해 들어가고, 나머지 카테고리는 [overlays] 에 들어간다.
class MochiAppearance {
  const MochiAppearance({
    required this.skinHex,
    required this.skinAssetKey,
    this.backgroundAssetKey = 'bg/meadow',
    this.overlays = const [],
  });

  final String skinHex;
  final String skinAssetKey;
  final String backgroundAssetKey;
  final List<EquippedItem> overlays;

  /// 서버 상태로부터 생성.
  factory MochiAppearance.fromState(CharacterState state) {
    return MochiAppearance(
      skinHex: state.skinHex,
      skinAssetKey: state.skinAssetKey,
      backgroundAssetKey: state.backgroundAssetKey,
      overlays: state.equippedItems
          .where((e) =>
              e.itemType != ShopItemType.skin &&
              e.itemType != ShopItemType.background)
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
    String? backgroundAssetKey,
    List<EquippedItem>? overlays,
  }) {
    return MochiAppearance(
      skinHex: skinHex ?? this.skinHex,
      skinAssetKey: skinAssetKey ?? this.skinAssetKey,
      backgroundAssetKey: backgroundAssetKey ?? this.backgroundAssetKey,
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
    this.heightFactor = 1.0,
    this.clipRadius = 48,
  });

  final MochiAppearance appearance;
  final CharacterStage stage;
  final double size;
  final MochiEmotion expression;

  /// 0.0 (완전히 감은 눈) ~ 1.0 (완전히 뜬 눈)
  final double eyeOpenness;

  /// 렌더할 레이어. 기본 [MochiCharacterPart.full].
  final MochiCharacterPart part;

  /// 세로 확장 배율 — 1.0 이면 기존 정사각형(200×200), 1.3 이면 200×260 세로
  /// 직사각형 씬. 캐릭터/지면은 상단 200 좌표계에 그대로 두고, 하늘과 언덕
  /// 그라디언트가 아래로 자연스럽게 이어져 홈 화면의 "키우기 방" 느낌을 만든다.
  final double heightFactor;

  /// 씬 클리핑 모서리 반경. 정사각형 아바타는 48(squircle), 홈 카드는 28 권장.
  final double clipRadius;

  @override
  Widget build(BuildContext context) {
    final h = size * heightFactor;
    return SizedBox(
      width: size,
      height: h,
      child: SvgPicture.string(debugSvgMarkup(), width: size, height: h),
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
  /// 무늬도 함께 음영을 받는다. [bodyFill] 로 스킨별 바디 그라디언트를 바꾼다.
  static String _body3d({
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    String patches = '',
    String bodyFill = 'mBody',
  }) {
    final hlCx = (cx - rx * 0.40).toStringAsFixed(1);
    final hlCy = (cy - ry * 0.48).toStringAsFixed(1);
    final hlRx = (rx * 0.32).toStringAsFixed(1);
    final hlRy = (ry * 0.18).toStringAsFixed(1);
    final dotCx = (cx - rx * 0.06).toStringAsFixed(1);
    final dotCy = (cy - ry * 0.68).toStringAsFixed(1);
    final dotR = (rx * 0.05).toStringAsFixed(1);
    return '''
  <ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="url(#$bodyFill)"/>
  $patches
  <ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="url(#mRim)"/>
  <ellipse cx="$hlCx" cy="$hlCy" rx="$hlRx" ry="$hlRy" fill="#FFFFFF" opacity="0.6" transform="rotate(-16 $hlCx $hlCy)"/>
  <circle cx="$dotCx" cy="$dotCy" r="$dotR" fill="#FFFFFF" opacity="0.75"/>
''';
  }

  // ─────────────────────────────────────────
  // 스킨 패턴 시스템 — assetKey 별로 (바디 그라디언트, 본체 위 무늬, 본체 뒤 장식)
  // 3요소를 정의한다. 새 패턴 스킨은 이 3개 switch 에 케이스 추가로 끝난다.
  // 서버 시드(ShopItemSeeder)와 assetKey 를 반드시 동기화할 것.
  // ─────────────────────────────────────────

  /// 단계별 본체 타원 지오메트리 — 패턴 좌표 계산의 기준.
  static ({double cx, double cy, double rx, double ry}) _bodyGeom(
      CharacterStage stage) {
    return switch (stage) {
      CharacterStage.egg => (cx: 100.0, cy: 120.0, rx: 52.0, ry: 58.0),
      CharacterStage.sprout => (cx: 100.0, cy: 124.0, rx: 46.0, ry: 40.0),
      _ => (cx: 100.0, cy: 124.0, rx: 50.0, ry: 44.0),
    };
  }

  /// 스킨별 바디 그라디언트 id. 무늬 없는 색상 스킨(코랄 등)은 기본 흰 바디.
  static String _skinBodyFill(String skin) {
    return switch (skin) {
      'skin/panda' => 'mPandaBody',
      'skin/mole' => 'mMoleBody',
      'skin/tiger' => 'mTigerBody',
      'skin/cat' => 'mCatBody',
      'skin/bee' => 'mBeeBody',
      'skin/frog' => 'mFrogBody',
      _ => 'mBody',
    };
  }

  /// 본체 위(림 셰이딩 아래)에 얹는 무늬 — 판다 눈패치, 호랑이 줄무늬 등.
  static String _skinPatches(String skin, CharacterStage stage) {
    final g = _bodyGeom(stage);
    final cx = g.cx;
    final cy = g.cy;
    final rx = g.rx;
    final ry = g.ry;
    final top = cy - ry;
    switch (skin) {
      case 'skin/panda':
        // 진짜 판다 룩 — 비스듬한 눈 패치 + 검정 코 + 양팔 어깨 패치.
        // 눈 패치는 바깥위→안쪽아래로 기울여(±22°) 실제 판다의 팔(八)자 무늬를 재현.
        final eyePatches = switch (stage) {
          CharacterStage.egg =>
            '<ellipse cx="78" cy="106" rx="13" ry="10" fill="url(#mPanda)" transform="rotate(-22 78 106)"/>'
                '<ellipse cx="122" cy="106" rx="13" ry="10" fill="url(#mPanda)" transform="rotate(22 122 106)"/>',
          CharacterStage.sprout =>
            '<ellipse cx="83" cy="119" rx="9.5" ry="7" fill="url(#mPanda)" transform="rotate(-22 83 119)"/>'
                '<ellipse cx="117" cy="119" rx="9.5" ry="7" fill="url(#mPanda)" transform="rotate(22 117 119)"/>',
          _ =>
            '<ellipse cx="85" cy="118" rx="11.5" ry="8.5" fill="url(#mPanda)" transform="rotate(-22 85 118)"/>'
                '<ellipse cx="115" cy="118" rx="11.5" ry="8.5" fill="url(#mPanda)" transform="rotate(22 115 118)"/>',
        };
        if (stage == CharacterStage.egg) return eyePatches;
        // 코: 두 눈 사이 아래 — 하이라이트로 말랑한 젤리 코.
        final noseY = (cy + ry * 0.11).toStringAsFixed(1);
        final nose =
            '<ellipse cx="$cx" cy="$noseY" rx="3.6" ry="2.6" fill="url(#mPanda)"/>'
            '<circle cx="${(cx - 1.2).toStringAsFixed(1)}" cy="${(cy + ry * 0.07).toStringAsFixed(1)}" r="0.9" fill="#FFFFFF" opacity="0.55"/>';
        // 양팔 — 본체 좌우 하단을 감싸는 검정 초승달 패치 (판다의 앞다리).
        final armY = (cy + ry * 0.38).toStringAsFixed(1);
        final armLx = (cx - rx * 0.74).toStringAsFixed(1);
        final armRx = (cx + rx * 0.74).toStringAsFixed(1);
        final armRxV = (rx * 0.34).toStringAsFixed(1);
        final armRyV = (ry * 0.46).toStringAsFixed(1);
        final arms =
            '<ellipse cx="$armLx" cy="$armY" rx="$armRxV" ry="$armRyV" fill="url(#mPanda)" transform="rotate(24 $armLx $armY)"/>'
            '<ellipse cx="$armRx" cy="$armY" rx="$armRxV" ry="$armRyV" fill="url(#mPanda)" transform="rotate(-24 $armRx $armY)"/>';
        return '$arms$eyePatches$nose';
      case 'skin/mole':
        // 두더지 — 밝은 주둥이 + 분홍 젤리코 + 수염 + 굴착 발톱 앞발.
        // 주둥이는 눈(cy-2 근처)을 덮지 않게 코~입 주변만 밝힌다.
        final muzzleY = (cy + ry * 0.26).toStringAsFixed(1);
        final muzzle =
            '<ellipse cx="$cx" cy="$muzzleY" rx="${(rx * 0.30).toStringAsFixed(1)}" ry="${(ry * 0.20).toStringAsFixed(1)}" fill="#EBD3B4" opacity="0.95"/>';
        final noseY = (cy + ry * 0.10).toStringAsFixed(1);
        final nose =
            '<ellipse cx="$cx" cy="$noseY" rx="4.2" ry="3.1" fill="url(#mMoleNose)"/>'
            '<circle cx="${(cx - 1.4).toStringAsFixed(1)}" cy="${(cy + ry * 0.055).toStringAsFixed(1)}" r="1.1" fill="#FFFFFF" opacity="0.7"/>';
        // 수염 — 주둥이 양 옆 2가닥씩, 짧고 아래로 처지게.
        final wy1 = (cy + ry * 0.14).toStringAsFixed(1);
        final wy2 = (cy + ry * 0.28).toStringAsFixed(1);
        final wLo = (cx - rx * 0.78).toStringAsFixed(1);
        final wLi = (cx - rx * 0.44).toStringAsFixed(1);
        final wRo = (cx + rx * 0.78).toStringAsFixed(1);
        final wRi = (cx + rx * 0.44).toStringAsFixed(1);
        final whiskers = '''
    <g stroke="#6B4A32" stroke-width="1.3" stroke-linecap="round" opacity="0.75">
      <line x1="$wLo" y1="$wy1" x2="$wLi" y2="${(cy + ry * 0.18).toStringAsFixed(1)}"/>
      <line x1="$wLo" y1="$wy2" x2="$wLi" y2="$wy2"/>
      <line x1="$wRo" y1="$wy1" x2="$wRi" y2="${(cy + ry * 0.18).toStringAsFixed(1)}"/>
      <line x1="$wRo" y1="$wy2" x2="$wRi" y2="$wy2"/>
    </g>''';
        if (stage == CharacterStage.egg) return '$muzzle$nose';
        // 앞발 — 크림색 굴착 발 + 발톱 3개. 두더지의 상징.
        final pawY = (cy + ry * 0.52).toStringAsFixed(1);
        final pawLx = (cx - rx * 0.68).toStringAsFixed(1);
        final pawRx = (cx + rx * 0.68).toStringAsFixed(1);
        final pawR = (rx * 0.22).toStringAsFixed(1);
        String claw(double px, double py, double dx) =>
            '<path d="M${px.toStringAsFixed(1)} ${py.toStringAsFixed(1)} q${dx.toStringAsFixed(1)} 2.4 ${(dx * 0.6).toStringAsFixed(1)} 5.2" stroke="#F5EAD8" stroke-width="1.7" stroke-linecap="round" fill="none"/>';
        final pawLxD = cx - rx * 0.68;
        final pawRxD = cx + rx * 0.68;
        final pawYD = cy + ry * 0.44;
        final paws =
            '<circle cx="$pawLx" cy="$pawY" r="$pawR" fill="url(#mMolePaw)"/>'
            '${claw(pawLxD - 4.5, pawYD, -1.6)}${claw(pawLxD, pawYD - 1.5, 0)}${claw(pawLxD + 4.5, pawYD, 1.6)}'
            '<circle cx="$pawRx" cy="$pawY" r="$pawR" fill="url(#mMolePaw)"/>'
            '${claw(pawRxD - 4.5, pawYD, -1.6)}${claw(pawRxD, pawYD - 1.5, 0)}${claw(pawRxD + 4.5, pawYD, 1.6)}';
        return '$paws$muzzle$whiskers$nose';
      case 'skin/tiger':
        // 이마 세로 줄 3개 + 양 옆구리 줄 — 호랑이 무늬.
        final ft = (top + ry * 0.10).toStringAsFixed(1);
        final fb = (top + ry * 0.34).toStringAsFixed(1);
        final fm = (top + ry * 0.30).toStringAsFixed(1);
        final sideY1 = (cy - ry * 0.16).toStringAsFixed(1);
        final sideY2 = (cy + ry * 0.16).toStringAsFixed(1);
        final lx = (cx - rx * 0.92).toStringAsFixed(1);
        final lx2 = (cx - rx * 0.62).toStringAsFixed(1);
        final rxx = (cx + rx * 0.92).toStringAsFixed(1);
        final rx2 = (cx + rx * 0.62).toStringAsFixed(1);
        return '''
    <g stroke="#5B3A1E" stroke-width="${(rx * 0.09).toStringAsFixed(1)}" stroke-linecap="round" fill="none" opacity="0.88">
      <path d="M${cx - rx * 0.18} $ft Q${cx - rx * 0.20} $fm ${cx - rx * 0.14} $fb"/>
      <path d="M$cx ${(top + ry * 0.06).toStringAsFixed(1)} Q$cx $fm $cx $fb"/>
      <path d="M${cx + rx * 0.18} $ft Q${cx + rx * 0.20} $fm ${cx + rx * 0.14} $fb"/>
      <path d="M$lx $sideY1 Q$lx2 ${(cy).toStringAsFixed(1)} $lx $sideY2"/>
      <path d="M$rxx $sideY1 Q$rx2 ${(cy).toStringAsFixed(1)} $rxx $sideY2"/>
    </g>''';
      case 'skin/cat':
        // 볼 수염 3가닥씩 — 눈/입과 겹치지 않게 볼 옆 바깥쪽에.
        final wy = (cy + ry * 0.10).toStringAsFixed(1);
        final wy2 = (cy + ry * 0.24).toStringAsFixed(1);
        final wy3 = (cy + ry * 0.38).toStringAsFixed(1);
        final lo = (cx - rx * 0.96).toStringAsFixed(1);
        final li = (cx - rx * 0.58).toStringAsFixed(1);
        final ro = (cx + rx * 0.96).toStringAsFixed(1);
        final ri = (cx + rx * 0.58).toStringAsFixed(1);
        return '''
    <g stroke="#8A8580" stroke-width="1.6" stroke-linecap="round" opacity="0.9">
      <line x1="$lo" y1="$wy" x2="$li" y2="${(cy + ry * 0.16).toStringAsFixed(1)}"/>
      <line x1="$lo" y1="$wy2" x2="$li" y2="$wy2"/>
      <line x1="$lo" y1="$wy3" x2="$li" y2="${(cy + ry * 0.32).toStringAsFixed(1)}"/>
      <line x1="$ro" y1="$wy" x2="$ri" y2="${(cy + ry * 0.16).toStringAsFixed(1)}"/>
      <line x1="$ro" y1="$wy2" x2="$ri" y2="$wy2"/>
      <line x1="$ro" y1="$wy3" x2="$ri" y2="${(cy + ry * 0.32).toStringAsFixed(1)}"/>
    </g>''';
      case 'skin/bee':
        // 아랫배 가로 줄무늬 2줄 — 꿀벌 밴드.
        final b1 = (cy + ry * 0.22).toStringAsFixed(1);
        final b1q = (cy + ry * 0.44).toStringAsFixed(1);
        final b2 = (cy + ry * 0.58).toStringAsFixed(1);
        final b2q = (cy + ry * 0.80).toStringAsFixed(1);
        return '''
    <g stroke="#4A3B1E" stroke-linecap="round" fill="none" opacity="0.82">
      <path d="M${(cx - rx * 0.90).toStringAsFixed(1)} $b1 Q$cx $b1q ${(cx + rx * 0.90).toStringAsFixed(1)} $b1" stroke-width="${(ry * 0.20).toStringAsFixed(1)}"/>
      <path d="M${(cx - rx * 0.66).toStringAsFixed(1)} $b2 Q$cx $b2q ${(cx + rx * 0.66).toStringAsFixed(1)} $b2" stroke-width="${(ry * 0.17).toStringAsFixed(1)}"/>
    </g>''';
      case 'skin/frog':
        // 밝은 배 — 개구리 배 패치.
        return '<ellipse cx="$cx" cy="${(cy + ry * 0.42).toStringAsFixed(1)}" '
            'rx="${(rx * 0.52).toStringAsFixed(1)}" ry="${(ry * 0.38).toStringAsFixed(1)}" '
            'fill="#F2FFE6" opacity="0.85"/>';
      default:
        return '';
    }
  }

  /// 본체 뒤(먼저 그림)에 붙는 장식 — 귀/더듬이/눈두덩 등.
  /// EGG 단계는 아직 부화 전이라 무늬([_skinPatches])만 얹고 장식은 생략한다.
  static String _skinBehind(String skin, CharacterStage stage) {
    if (stage == CharacterStage.egg) return '';
    final g = _bodyGeom(stage);
    final cx = g.cx;
    final cy = g.cy;
    final rx = g.rx;
    final ry = g.ry;
    switch (skin) {
      case 'skin/panda':
        // 동그란 검정 귀 — 판다의 상징. 정수리 좌우에 큼직하게.
        final earY = (cy - ry * 0.84).toStringAsFixed(1);
        final earR = (rx * 0.26).toStringAsFixed(1);
        final lX = (cx - rx * 0.56).toStringAsFixed(1);
        final rX = (cx + rx * 0.56).toStringAsFixed(1);
        final hlR = (rx * 0.08).toStringAsFixed(1);
        return '''
    <circle cx="$lX" cy="$earY" r="$earR" fill="url(#mPanda)"/>
    <circle cx="${(cx - rx * 0.62).toStringAsFixed(1)}" cy="${(cy - ry * 0.92).toStringAsFixed(1)}" r="$hlR" fill="#FFFFFF" opacity="0.35"/>
    <circle cx="$rX" cy="$earY" r="$earR" fill="url(#mPanda)"/>
    <circle cx="${(cx + rx * 0.50).toStringAsFixed(1)}" cy="${(cy - ry * 0.92).toStringAsFixed(1)}" r="$hlR" fill="#FFFFFF" opacity="0.35"/>''';
      case 'skin/mole':
        // 작고 동그란 귀 — 두더지는 귀가 아주 작다. 속귀는 분홍.
        final earY = (cy - ry * 0.78).toStringAsFixed(1);
        final earR = (rx * 0.15).toStringAsFixed(1);
        final inR = (rx * 0.075).toStringAsFixed(1);
        final lX = (cx - rx * 0.60).toStringAsFixed(1);
        final rX = (cx + rx * 0.60).toStringAsFixed(1);
        return '''
    <circle cx="$lX" cy="$earY" r="$earR" fill="url(#mMoleBody)" stroke="#6B4A32" stroke-width="1"/>
    <circle cx="$lX" cy="$earY" r="$inR" fill="url(#mMoleNose)" opacity="0.75"/>
    <circle cx="$rX" cy="$earY" r="$earR" fill="url(#mMoleBody)" stroke="#6B4A32" stroke-width="1"/>
    <circle cx="$rX" cy="$earY" r="$inR" fill="url(#mMoleNose)" opacity="0.75"/>''';
      case 'skin/tiger':
        // 둥근 귀 + 진한 안쪽 — 정수리 좌우.
        final earY = (cy - ry * 0.82).toStringAsFixed(1);
        final earR = (rx * 0.22).toStringAsFixed(1);
        final inR = (rx * 0.11).toStringAsFixed(1);
        final lX = (cx - rx * 0.58).toStringAsFixed(1);
        final rX = (cx + rx * 0.58).toStringAsFixed(1);
        return '''
    <circle cx="$lX" cy="$earY" r="$earR" fill="url(#mTigerBody)" stroke="#C98A3B" stroke-width="1"/>
    <circle cx="$lX" cy="$earY" r="$inR" fill="#5B3A1E" opacity="0.85"/>
    <circle cx="$rX" cy="$earY" r="$earR" fill="url(#mTigerBody)" stroke="#C98A3B" stroke-width="1"/>
    <circle cx="$rX" cy="$earY" r="$inR" fill="#5B3A1E" opacity="0.85"/>''';
      case 'skin/cat':
        // 쫑긋 세모 귀 + 분홍 속귀.
        final baseY = (cy - ry * 0.62).toStringAsFixed(1);
        final tipY = (cy - ry * 1.18).toStringAsFixed(1);
        final lOut = (cx - rx * 0.72).toStringAsFixed(1);
        final lTip = (cx - rx * 0.52).toStringAsFixed(1);
        final lIn = (cx - rx * 0.26).toStringAsFixed(1);
        final rOut = (cx + rx * 0.72).toStringAsFixed(1);
        final rTip = (cx + rx * 0.52).toStringAsFixed(1);
        final rIn = (cx + rx * 0.26).toStringAsFixed(1);
        final inTipY = (cy - ry * 1.02).toStringAsFixed(1);
        return '''
    <path d="M$lOut $baseY Q$lTip $tipY $lIn $baseY Z" fill="url(#mCatBody)" stroke="#B4A99E" stroke-width="1"/>
    <path d="M${(cx - rx * 0.62).toStringAsFixed(1)} $baseY Q$lTip $inTipY ${(cx - rx * 0.36).toStringAsFixed(1)} $baseY Z" fill="url(#mCatEarIn)"/>
    <path d="M$rOut $baseY Q$rTip $tipY $rIn $baseY Z" fill="url(#mCatBody)" stroke="#B4A99E" stroke-width="1"/>
    <path d="M${(cx + rx * 0.62).toStringAsFixed(1)} $baseY Q$rTip $inTipY ${(cx + rx * 0.36).toStringAsFixed(1)} $baseY Z" fill="url(#mCatEarIn)"/>''';
      case 'skin/bee':
        // 더듬이 2개 + 반투명 날개.
        final headY = (cy - ry * 0.92).toStringAsFixed(1);
        final antY = (cy - ry * 1.32).toStringAsFixed(1);
        final lA = (cx - rx * 0.24).toStringAsFixed(1);
        final lAt = (cx - rx * 0.42).toStringAsFixed(1);
        final rA = (cx + rx * 0.24).toStringAsFixed(1);
        final rAt = (cx + rx * 0.42).toStringAsFixed(1);
        final wingY = (cy - ry * 0.46).toStringAsFixed(1);
        final wingL = (cx - rx * 0.94).toStringAsFixed(1);
        final wingR = (cx + rx * 0.94).toStringAsFixed(1);
        final wRx = (rx * 0.34).toStringAsFixed(1);
        final wRy = (ry * 0.22).toStringAsFixed(1);
        return '''
    <ellipse cx="$wingL" cy="$wingY" rx="$wRx" ry="$wRy" fill="#FFFFFF" opacity="0.8" stroke="#D7E3F2" stroke-width="1" transform="rotate(-28 $wingL $wingY)"/>
    <ellipse cx="$wingR" cy="$wingY" rx="$wRx" ry="$wRy" fill="#FFFFFF" opacity="0.8" stroke="#D7E3F2" stroke-width="1" transform="rotate(28 $wingR $wingY)"/>
    <path d="M$lA $headY Q$lAt ${(cy - ry * 1.16).toStringAsFixed(1)} $lAt $antY" stroke="#4A3B1E" stroke-width="2" stroke-linecap="round" fill="none"/>
    <circle cx="$lAt" cy="$antY" r="2.6" fill="#4A3B1E"/>
    <path d="M$rA $headY Q$rAt ${(cy - ry * 1.16).toStringAsFixed(1)} $rAt $antY" stroke="#4A3B1E" stroke-width="2" stroke-linecap="round" fill="none"/>
    <circle cx="$rAt" cy="$antY" r="2.6" fill="#4A3B1E"/>''';
      case 'skin/frog':
        // 정수리 눈두덩 2개 — 개구리 특유의 볼록한 눈.
        final bumpY = (cy - ry * 0.94).toStringAsFixed(1);
        final bumpR = (rx * 0.20).toStringAsFixed(1);
        final hlR = (rx * 0.07).toStringAsFixed(1);
        final lB = (cx - rx * 0.34).toStringAsFixed(1);
        final rB = (cx + rx * 0.34).toStringAsFixed(1);
        return '''
    <circle cx="$lB" cy="$bumpY" r="$bumpR" fill="url(#mFrogBody)" stroke="#5FA544" stroke-width="1"/>
    <circle cx="${(cx - rx * 0.40).toStringAsFixed(1)}" cy="${(cy - ry * 1.00).toStringAsFixed(1)}" r="$hlR" fill="#FFFFFF" opacity="0.8"/>
    <circle cx="$rB" cy="$bumpY" r="$bumpR" fill="url(#mFrogBody)" stroke="#5FA544" stroke-width="1"/>
    <circle cx="${(cx + rx * 0.28).toStringAsFixed(1)}" cy="${(cy - ry * 1.00).toStringAsFixed(1)}" r="$hlR" fill="#FFFFFF" opacity="0.8"/>''';
      default:
        return '';
    }
  }

  // ─────────────────────────────────────────
  // 단계별 본문 SVG (배경 rect 는 외부에서 결합)
  // ─────────────────────────────────────────

  String _buildStageSvg(CharacterStage stage, String hex, MochiAppearance app) {
    final safeHex = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
        ? hex.toUpperCase()
        : '#FF6B6B';
    // 세로 확장 — 캐릭터/지면 좌표(상단 200×200)는 그대로 두고 하늘 rect 와 언덕
    // 그라디언트만 h 까지 늘린다. 씬의 지면(언덕 타원)은 원래 y≈280 까지 뻗어 있어
    // h=260 확장에도 빈틈없이 이어진다 (바닷가 모래사장만 h 로 마감을 늘림).
    final h = (200 * heightFactor).round();
    // 배경 씬 — 장착된 BACKGROUND 아이템의 assetKey 로 결정. 기본 풀밭(meadow)은
    // 스킨색이 하늘 톤에 스며들어 스킨 구매 가치를 유지한다.
    final scene = _scene(app.backgroundAssetKey, safeHex, h);
    final defs = _defs(
      shadowCol: scene.shadowHex,
      sceneDefs: scene.defs,
      height: h,
      clipRadius: clipRadius,
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
    // 씬 전체를 클리핑하고, 캐릭터 뒤 스포트라이트와 접지 그림자를 얹는다.
    final bg = '<g clip-path="url(#mClip)">\n'
        '  <rect width="200" height="$h" fill="url(#bgSky)"/>\n'
        '  ${scene.markup}\n'
        '  <ellipse cx="100" cy="106" rx="82" ry="76" fill="url(#mSpot)"/>\n'
        '  $ground\n'
        '  </g>';
    final skin = app.skinAssetKey;
    final body = switch (stage) {
      CharacterStage.egg => _egg(skin: skin),
      CharacterStage.sprout => _sprout(skin: skin),
      CharacterStage.bloom => _bloom(skin: skin),
      CharacterStage.blossom => _blossom(skin: skin),
      CharacterStage.glow => _glow(skin: skin),
      CharacterStage.master => _master(skin: skin),
    };
    final overlays = _buildOverlays(stage, app.overlays);
    final layers = switch (part) {
      MochiCharacterPart.full => '$bg\n  $body\n  $overlays',
      MochiCharacterPart.background => bg,
      MochiCharacterPart.body => '$body\n  $overlays',
    };
    return '''
<svg width="200" height="$h" viewBox="0 0 200 $h" fill="none" xmlns="http://www.w3.org/2000/svg">
  $defs
  $layers
</svg>
''';
  }

  /// 4각 반짝이 별 — 오목한 곡선 4개로 이어지는 다이아 스파클. 배경 장식용.
  static String _sparkle(double cx, double cy, double r, double opacity,
      {String color = '#FFFFFF'}) {
    final t = (cy - r).toStringAsFixed(1);
    final b = (cy + r).toStringAsFixed(1);
    final l = (cx - r).toStringAsFixed(1);
    final rt = (cx + r).toStringAsFixed(1);
    return '<path d="M$cx $t Q$cx $cy $rt $cy Q$cx $cy $cx $b '
        'Q$cx $cy $l $cy Q$cx $cy $cx $t Z" fill="$color" opacity="$opacity"/>';
  }

  // ─────────────────────────────────────────
  // 배경 씬 — assetKey 별 야외 풍경. 캐릭터 본체(중앙 하단, 바닥 y≈150~170)를
  // 가리지 않도록 큰 장식은 상단·좌우 가장자리에 두고, 지면(언덕/모래/설원)은
  // y≈134 아래에만 깐다. flutter_svg 는 <filter> 미지원 — 흐림/발광은 전부
  // 그라디언트 fade 로 표현한다.
  // ─────────────────────────────────────────

  /// [key] 배경 씬의 (전용 defs, 본문 마크업, 접지 그림자색). 알 수 없는 키는
  /// 기본 풀밭으로 fallback — 구버전 앱이 신규 배경을 만나도 렌더가 깨지지 않는다.
  /// 하늘 rect(id=bgSky) 는 세로 확장을 위해 호출부(_buildStageSvg)가 그린다.
  /// [h] 는 씬 캔버스 높이 — 지면을 캔버스 바닥까지 마감해야 하는 씬(바닷가)이 쓴다.
  static ({String defs, String markup, String shadowHex}) _scene(
      String key, String skinHex, int h) {
    return switch (key) {
      'bg/sakura' => _sceneSakura(),
      'bg/beach' => _sceneBeach(h),
      'bg/night' => _sceneNight(),
      'bg/winter' => _sceneWinter(),
      'bg/space' => _sceneSpace(),
      _ => _sceneMeadow(skinHex),
    };
  }

  /// 기본 풀밭 언덕 — 하늘 톤이 스킨색을 따라간다 (코랄=살구빛 하늘).
  static ({String defs, String markup, String shadowHex}) _sceneMeadow(
      String skinHex) {
    final skyTop = _mixHex(skinHex, 0.80, toWhite: true);
    final skyMid = _mixHex(skinHex, 0.58, toWhite: true);
    final skyLow = _mixHex(skinHex, 0.38, toWhite: true);
    return (
      defs: '''
    <linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="$skyTop"/>
      <stop offset="68%" stop-color="$skyMid"/>
      <stop offset="100%" stop-color="$skyLow"/>
    </linearGradient>
    <radialGradient id="bgSun" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFF7C9" stop-opacity="0.95"/>
      <stop offset="55%" stop-color="#FFEFA8" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="#FFEFA8" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="bgHillBack" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#CBE8A4"/>
      <stop offset="100%" stop-color="#A9D67F"/>
    </linearGradient>
    <linearGradient id="bgHill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#B4E086"/>
      <stop offset="100%" stop-color="#7FC95B"/>
    </linearGradient>''',
      markup: '''
<circle cx="160" cy="38" r="30" fill="url(#bgSun)"/>
  <circle cx="160" cy="38" r="12" fill="#FFF2B8"/>
  <circle cx="156" cy="34" r="4" fill="#FFFFFF" opacity="0.6"/>
  <g opacity="0.92">
    <ellipse cx="52" cy="42" rx="17" ry="9" fill="#FFFFFF"/>
    <ellipse cx="38" cy="46" rx="11" ry="7" fill="#FFFFFF"/>
    <ellipse cx="66" cy="46" rx="12" ry="7" fill="#FFFFFF"/>
  </g>
  <g opacity="0.7">
    <ellipse cx="126" cy="66" rx="12" ry="6" fill="#FFFFFF"/>
    <ellipse cx="137" cy="69" rx="8" ry="5" fill="#FFFFFF"/>
  </g>
  <ellipse cx="42" cy="206" rx="130" ry="72" fill="url(#bgHillBack)"/>
  <ellipse cx="152" cy="214" rx="150" ry="76" fill="url(#bgHill)"/>
  <path d="M27 170 Q25 161 28 155" stroke="#5FA843" stroke-width="1.6" stroke-linecap="round" fill="none"/>
  <path d="M32 171 Q33 163 31 157" stroke="#5FA843" stroke-width="1.6" stroke-linecap="round" fill="none"/>
  <path d="M172 166 Q170 158 173 152" stroke="#5FA843" stroke-width="1.6" stroke-linecap="round" fill="none"/>
  <circle cx="38" cy="176" r="3" fill="#FFFFFF"/>
  <circle cx="38" cy="176" r="1.2" fill="#FCD34D"/>
  <circle cx="62" cy="188" r="2.6" fill="#FFD7E2"/>
  <circle cx="62" cy="188" r="1" fill="#FCD34D"/>
  <circle cx="166" cy="178" r="3" fill="#FFFFFF"/>
  <circle cx="166" cy="178" r="1.2" fill="#FCD34D"/>
  <circle cx="184" cy="162" r="2.4" fill="#FFD7E2"/>
  <circle cx="184" cy="162" r="0.9" fill="#FCD34D"/>''',
      shadowHex: '#3E6B2F',
    );
  }

  /// 벚꽃동산 — 분홍 하늘, 우상단 벚나무 가지, 흩날리는 꽃잎.
  static ({String defs, String markup, String shadowHex}) _sceneSakura() {
    return (
      defs: '''
    <linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFEAF1"/>
      <stop offset="62%" stop-color="#FFD9E5"/>
      <stop offset="100%" stop-color="#FFC9D8"/>
    </linearGradient>
    <radialGradient id="bgGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.75"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="bgHillBack" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#CDE9AB"/>
      <stop offset="100%" stop-color="#A3D47E"/>
    </linearGradient>
    <linearGradient id="bgHill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#BAE18F"/>
      <stop offset="100%" stop-color="#84CB60"/>
    </linearGradient>''',
      markup: '''
<circle cx="48" cy="40" r="24" fill="url(#bgGlow)"/>
  <path d="M204 14 Q166 26 142 50" stroke="#8A5A44" stroke-width="5" stroke-linecap="round" fill="none"/>
  <path d="M172 28 Q160 38 156 48" stroke="#8A5A44" stroke-width="3" stroke-linecap="round" fill="none"/>
  <circle cx="142" cy="52" r="7" fill="#FFB3C7"/>
  <circle cx="155" cy="46" r="8" fill="#FFC3D3"/>
  <circle cx="168" cy="35" r="8.5" fill="#FFAEC5"/>
  <circle cx="183" cy="27" r="9" fill="#FFC3D3"/>
  <circle cx="158" cy="57" r="6.5" fill="#FFAEC5"/>
  <circle cx="176" cy="46" r="7" fill="#FFB3C7"/>
  <circle cx="151" cy="42" r="2" fill="#FFFFFF" opacity="0.75"/>
  <circle cx="171" cy="31" r="2.2" fill="#FFFFFF" opacity="0.75"/>
  <circle cx="146" cy="55" r="1.4" fill="#E86F92"/>
  <circle cx="180" cy="30" r="1.4" fill="#E86F92"/>
  <ellipse cx="60" cy="70" rx="3" ry="1.8" fill="#FFB9CC" opacity="0.9" transform="rotate(-24 60 70)"/>
  <ellipse cx="96" cy="42" rx="2.6" ry="1.6" fill="#FFB9CC" opacity="0.8" transform="rotate(18 96 42)"/>
  <ellipse cx="34" cy="104" rx="3" ry="1.8" fill="#FFAEC5" opacity="0.85" transform="rotate(30 34 104)"/>
  <ellipse cx="122" cy="84" rx="2.4" ry="1.5" fill="#FFB9CC" opacity="0.75" transform="rotate(-40 122 84)"/>
  <ellipse cx="182" cy="106" rx="2.8" ry="1.7" fill="#FFAEC5" opacity="0.8" transform="rotate(12 182 106)"/>
  <ellipse cx="42" cy="206" rx="130" ry="72" fill="url(#bgHillBack)"/>
  <ellipse cx="152" cy="214" rx="150" ry="76" fill="url(#bgHill)"/>
  <ellipse cx="40" cy="174" rx="2.6" ry="1.6" fill="#FFB9CC" transform="rotate(20 40 174)"/>
  <ellipse cx="64" cy="186" rx="2.4" ry="1.5" fill="#FFAEC5" transform="rotate(-16 64 186)"/>
  <ellipse cx="164" cy="178" rx="2.6" ry="1.6" fill="#FFB9CC" transform="rotate(28 164 178)"/>
  <ellipse cx="184" cy="164" rx="2.2" ry="1.4" fill="#FFAEC5" transform="rotate(-8 184 164)"/>''',
      shadowHex: '#5E8A46',
    );
  }

  /// 바닷가 — 하늘·수평선·반짝이는 바다·모래사장, 불가사리와 조개.
  /// [h] 캔버스 높이 — 모래사장을 캔버스 바닥까지 마감한다 (세로 확장 대응).
  static ({String defs, String markup, String shadowHex}) _sceneBeach(int h) {
    return (
      defs: '''
    <linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#CDEEFB"/>
      <stop offset="100%" stop-color="#A5DEF6"/>
    </linearGradient>
    <linearGradient id="bgSea" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#5FC6EA"/>
      <stop offset="100%" stop-color="#2FA3D4"/>
    </linearGradient>
    <linearGradient id="bgSand" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FBE9C6"/>
      <stop offset="100%" stop-color="#EFD49F"/>
    </linearGradient>
    <radialGradient id="bgSun" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFF7C9" stop-opacity="0.95"/>
      <stop offset="55%" stop-color="#FFEFA8" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="#FFEFA8" stop-opacity="0"/>
    </radialGradient>''',
      markup: '''
<circle cx="42" cy="36" r="28" fill="url(#bgSun)"/>
  <circle cx="42" cy="36" r="11" fill="#FFF2B8"/>
  <g opacity="0.85">
    <ellipse cx="138" cy="40" rx="14" ry="7" fill="#FFFFFF"/>
    <ellipse cx="150" cy="44" rx="10" ry="6" fill="#FFFFFF"/>
  </g>
  <path d="M96 26 Q100 22 104 26 M104 26 Q108 22 112 26" stroke="#7FA8C9" stroke-width="1.4" stroke-linecap="round" fill="none"/>
  <rect x="0" y="112" width="200" height="52" fill="url(#bgSea)"/>
  <line x1="0" y1="112" x2="200" y2="112" stroke="#FFFFFF" stroke-width="1.4" opacity="0.6"/>
  <path d="M16 124 Q24 121 32 124" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.7" fill="none"/>
  <path d="M52 134 Q60 131 68 134" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.6" fill="none"/>
  <path d="M150 126 Q158 123 166 126" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.7" fill="none"/>
  ${_sparkle(120, 120, 2.4, 0.8)}
  ${_sparkle(178, 136, 2, 0.7)}
  <path d="M0 156 Q50 146 100 152 Q150 158 200 150 L200 $h L0 $h Z" fill="url(#bgSand)"/>
  <path d="M0 156 Q50 146 100 152 Q150 158 200 150" stroke="#FFFFFF" stroke-width="2" opacity="0.55" fill="none"/>
  <path d="M32 186 L35 179 L40 184 L38 177 L45 178 L39 174 L44 170 L37 172 L36 165 L33 171 L27 168 L31 174 L25 176 L32 177 Z" fill="#FF9E6B" opacity="0.9"/>
  <circle cx="170" cy="180" r="5" fill="#FFD9B0"/>
  <path d="M170 175 Q174 178 172 183 Q168 184 167 180 Q167 177 170 175" stroke="#E8A96F" stroke-width="1.1" fill="none"/>
  <circle cx="140" cy="190" r="1.4" fill="#E2C089"/>
  <circle cx="58" cy="192" r="1.2" fill="#E2C089"/>''',
      shadowHex: '#B08A50',
    );
  }

  /// 밤하늘 — 초승달과 별, 반딧불이가 떠 있는 고요한 언덕.
  static ({String defs, String markup, String shadowHex}) _sceneNight() {
    return (
      defs: '''
    <linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#3A4677"/>
      <stop offset="55%" stop-color="#232C55"/>
      <stop offset="100%" stop-color="#161C3C"/>
    </linearGradient>
    <radialGradient id="bgMoonGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFF3C2" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="#FFF3C2" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="bgHillBack" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#2C3766"/>
      <stop offset="100%" stop-color="#242D56"/>
    </linearGradient>
    <linearGradient id="bgHill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#222B52"/>
      <stop offset="100%" stop-color="#1A2140"/>
    </linearGradient>
    <radialGradient id="bgFly" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#D9F07F" stop-opacity="0.8"/>
      <stop offset="100%" stop-color="#D9F07F" stop-opacity="0"/>
    </radialGradient>''',
      markup: '''
<circle cx="152" cy="44" r="27" fill="url(#bgMoonGlow)"/>
  <circle cx="152" cy="44" r="13" fill="#FFF3C2"/>
  <circle cx="147" cy="40" r="11" fill="#232C55"/>
  ${_sparkle(36, 30, 4, 0.9)}
  ${_sparkle(72, 58, 2.6, 0.7)}
  ${_sparkle(108, 26, 3, 0.8)}
  ${_sparkle(22, 86, 2.4, 0.6)}
  ${_sparkle(184, 92, 2.6, 0.7)}
  <circle cx="56" cy="44" r="1.3" fill="#FFFFFF" opacity="0.8"/>
  <circle cx="92" cy="66" r="1.1" fill="#FFFFFF" opacity="0.65"/>
  <circle cx="126" cy="52" r="1.3" fill="#FFFFFF" opacity="0.75"/>
  <circle cx="14" cy="52" r="1.1" fill="#FFFFFF" opacity="0.6"/>
  <circle cx="176" cy="18" r="1.3" fill="#FFFFFF" opacity="0.7"/>
  <ellipse cx="42" cy="206" rx="130" ry="72" fill="url(#bgHillBack)"/>
  <ellipse cx="152" cy="214" rx="150" ry="76" fill="url(#bgHill)"/>
  <circle cx="46" cy="142" r="6" fill="url(#bgFly)"/>
  <circle cx="46" cy="142" r="1.5" fill="#E4F59B"/>
  <circle cx="162" cy="134" r="5" fill="url(#bgFly)"/>
  <circle cx="162" cy="134" r="1.3" fill="#E4F59B"/>
  <circle cx="128" cy="160" r="4.5" fill="url(#bgFly)"/>
  <circle cx="128" cy="160" r="1.2" fill="#E4F59B"/>''',
      shadowHex: '#0A0E22',
    );
  }

  /// 눈 내리는 언덕 — 설원과 눈사람, 소나무, 흩날리는 눈송이.
  static ({String defs, String markup, String shadowHex}) _sceneWinter() {
    return (
      defs: '''
    <linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#DCEBF8"/>
      <stop offset="100%" stop-color="#C2D8EE"/>
    </linearGradient>
    <radialGradient id="bgGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.8"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="bgHillBack" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#E9F1FB"/>
    </linearGradient>
    <linearGradient id="bgHill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FDFEFF"/>
      <stop offset="100%" stop-color="#DFEAF7"/>
    </linearGradient>''',
      markup: '''
<circle cx="160" cy="36" r="22" fill="url(#bgGlow)"/>
  <g>
    <path d="M28 96 L14 126 L42 126 Z" fill="#5B8E68"/>
    <path d="M28 110 L12 142 L44 142 Z" fill="#4F7D5B"/>
    <ellipse cx="24" cy="103" rx="6" ry="2.4" fill="#FFFFFF" opacity="0.9"/>
    <ellipse cx="30" cy="122" rx="7" ry="2.6" fill="#FFFFFF" opacity="0.9"/>
    <rect x="25" y="142" width="6" height="8" rx="1.5" fill="#7A5A44"/>
  </g>
  <ellipse cx="42" cy="206" rx="130" ry="72" fill="url(#bgHillBack)"/>
  <ellipse cx="152" cy="214" rx="150" ry="76" fill="url(#bgHill)"/>
  <g>
    <circle cx="168" cy="162" r="9" fill="#FFFFFF" stroke="#D9E6F2" stroke-width="1"/>
    <circle cx="168" cy="147" r="6.5" fill="#FFFFFF" stroke="#D9E6F2" stroke-width="1"/>
    <circle cx="166" cy="146" r="0.9" fill="#2B2B2B"/>
    <circle cx="171" cy="146" r="0.9" fill="#2B2B2B"/>
    <path d="M168 148 L172 150 L168 150 Z" fill="#FF9A5B"/>
    <line x1="161" y1="158" x2="152" y2="152" stroke="#7A5A44" stroke-width="1.4" stroke-linecap="round"/>
    <line x1="175" y1="158" x2="184" y2="152" stroke="#7A5A44" stroke-width="1.4" stroke-linecap="round"/>
  </g>
  ${_sparkle(58, 34, 2.6, 0.9)}
  ${_sparkle(112, 52, 2.2, 0.8)}
  <circle cx="76" cy="24" r="1.8" fill="#FFFFFF" opacity="0.95"/>
  <circle cx="132" cy="30" r="1.5" fill="#FFFFFF" opacity="0.9"/>
  <circle cx="44" cy="62" r="1.6" fill="#FFFFFF" opacity="0.9"/>
  <circle cx="94" cy="78" r="1.4" fill="#FFFFFF" opacity="0.85"/>
  <circle cx="152" cy="72" r="1.7" fill="#FFFFFF" opacity="0.9"/>
  <circle cx="186" cy="52" r="1.4" fill="#FFFFFF" opacity="0.85"/>
  <circle cx="18" cy="40" r="1.4" fill="#FFFFFF" opacity="0.85"/>
  <circle cx="66" cy="106" r="1.5" fill="#FFFFFF" opacity="0.8"/>
  <circle cx="140" cy="104" r="1.4" fill="#FFFFFF" opacity="0.8"/>''',
      shadowHex: '#7FA0C2',
    );
  }

  /// 우주 여행 — 고리 행성과 별, 혜성, 보랏빛 달 표면.
  static ({String defs, String markup, String shadowHex}) _sceneSpace() {
    return (
      defs: '''
    <linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#3D2C77"/>
      <stop offset="55%" stop-color="#251C52"/>
      <stop offset="100%" stop-color="#140F33"/>
    </linearGradient>
    <radialGradient id="bgPlanet" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#F7B7D4"/>
      <stop offset="60%" stop-color="#DE8AB5"/>
      <stop offset="100%" stop-color="#B25C90"/>
    </radialGradient>
    <linearGradient id="bgGround" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#4A3C8A"/>
      <stop offset="100%" stop-color="#352A66"/>
    </linearGradient>''',
      markup: '''
<circle cx="44" cy="44" r="15" fill="url(#bgPlanet)"/>
  <ellipse cx="44" cy="46" rx="25" ry="6.5" stroke="#E8D9A8" stroke-width="2.4" fill="none" opacity="0.9" transform="rotate(-16 44 46)"/>
  <circle cx="38" cy="38" r="3.4" fill="#FFFFFF" opacity="0.45"/>
  <circle cx="172" cy="84" r="7" fill="#7EE0D0"/>
  <path d="M165.5 82 Q172 86 178.5 82" stroke="#57BFAE" stroke-width="1.6" fill="none"/>
  <path d="M112 22 Q128 30 142 42" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.5" fill="none"/>
  ${_sparkle(146, 46, 3.4, 0.9)}
  ${_sparkle(96, 60, 2.6, 0.7)}
  ${_sparkle(24, 96, 2.8, 0.75)}
  ${_sparkle(184, 30, 2.6, 0.8)}
  ${_sparkle(66, 112, 2.2, 0.6, color: '#BFD1FF')}
  <circle cx="84" cy="34" r="1.3" fill="#FFFFFF" opacity="0.8"/>
  <circle cx="126" cy="70" r="1.1" fill="#BFD1FF" opacity="0.75"/>
  <circle cx="16" cy="60" r="1.2" fill="#FFFFFF" opacity="0.7"/>
  <circle cx="190" cy="118" r="1.2" fill="#BFD1FF" opacity="0.7"/>
  <circle cx="150" cy="108" r="1" fill="#FFFFFF" opacity="0.6"/>
  <ellipse cx="100" cy="212" rx="145" ry="64" fill="url(#bgGround)"/>
  <ellipse cx="56" cy="176" rx="8" ry="3" fill="#2E2560" opacity="0.75"/>
  <ellipse cx="150" cy="184" rx="10" ry="3.5" fill="#2E2560" opacity="0.75"/>
  <ellipse cx="98" cy="194" rx="6" ry="2.4" fill="#2E2560" opacity="0.7"/>''',
      shadowHex: '#0E0930',
    );
  }

  /// 공용 그라디언트 defs. 모든 레이어(part) 의 SVG 에 동일하게 포함된다 —
  /// 미사용 그라디언트가 섞여 있어도 렌더 비용은 무시 가능하고, id 충돌이 없다.
  /// [sceneDefs] 는 배경 씬 전용 그라디언트 — 씬마다 같은 id(bgSky 등)를 재사용한다.
  static String _defs({
    required String shadowCol,
    required String sceneDefs,
    int height = 200,
    double clipRadius = 48,
  }) => '''
<defs>
    <clipPath id="mClip"><rect width="200" height="$height" rx="${clipRadius.toStringAsFixed(0)}"/></clipPath>
$sceneDefs
    <radialGradient id="mSpot" cx="0.5" cy="0.42" r="0.58">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.30"/>
      <stop offset="65%" stop-color="#FFFFFF" stop-opacity="0.08"/>
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
    <radialGradient id="mPandaBody" cx="0.38" cy="0.30" r="0.88">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="46%" stop-color="#F8F8F6"/>
      <stop offset="78%" stop-color="#E9E9E4"/>
      <stop offset="100%" stop-color="#CFCFC8"/>
    </radialGradient>
    <radialGradient id="mMoleBody" cx="0.38" cy="0.30" r="0.88">
      <stop offset="0%" stop-color="#D9B896"/>
      <stop offset="46%" stop-color="#BC9068"/>
      <stop offset="78%" stop-color="#9A6F4B"/>
      <stop offset="100%" stop-color="#7A5336"/>
    </radialGradient>
    <radialGradient id="mMoleNose" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFC2CF"/>
      <stop offset="60%" stop-color="#F58BA3"/>
      <stop offset="100%" stop-color="#D95E7E"/>
    </radialGradient>
    <radialGradient id="mMolePaw" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#F2E3CB"/>
      <stop offset="60%" stop-color="#E3C9A4"/>
      <stop offset="100%" stop-color="#C8A578"/>
    </radialGradient>
    <radialGradient id="mTigerBody" cx="0.38" cy="0.30" r="0.88">
      <stop offset="0%" stop-color="#FFEDCC"/>
      <stop offset="46%" stop-color="#FFD79E"/>
      <stop offset="78%" stop-color="#F5B25F"/>
      <stop offset="100%" stop-color="#DB8F33"/>
    </radialGradient>
    <radialGradient id="mCatBody" cx="0.38" cy="0.30" r="0.88">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="46%" stop-color="#F4F0EB"/>
      <stop offset="78%" stop-color="#E4DCD3"/>
      <stop offset="100%" stop-color="#C9BEB2"/>
    </radialGradient>
    <radialGradient id="mCatEarIn" cx="0.40" cy="0.35" r="0.85">
      <stop offset="0%" stop-color="#FBD3DA"/>
      <stop offset="100%" stop-color="#EE9AAB"/>
    </radialGradient>
    <radialGradient id="mBeeBody" cx="0.38" cy="0.30" r="0.88">
      <stop offset="0%" stop-color="#FFF9DB"/>
      <stop offset="46%" stop-color="#FFEE9E"/>
      <stop offset="78%" stop-color="#F8D75C"/>
      <stop offset="100%" stop-color="#DCB22F"/>
    </radialGradient>
    <radialGradient id="mFrogBody" cx="0.38" cy="0.30" r="0.88">
      <stop offset="0%" stop-color="#EFFFE0"/>
      <stop offset="46%" stop-color="#CFF3A9"/>
      <stop offset="78%" stop-color="#9FDB72"/>
      <stop offset="100%" stop-color="#71B84C"/>
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
    <linearGradient id="aStraw" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F5E0A6"/>
      <stop offset="100%" stop-color="#DDB96A"/>
    </linearGradient>
    <linearGradient id="aBeret" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#EE6A6A"/>
      <stop offset="100%" stop-color="#B03038"/>
    </linearGradient>
    <linearGradient id="aWiz" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#9B8CF8"/>
      <stop offset="100%" stop-color="#5B4BC4"/>
    </linearGradient>
    <radialGradient id="aBfly" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFE3A3"/>
      <stop offset="60%" stop-color="#FFC85C"/>
      <stop offset="100%" stop-color="#F09B2E"/>
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
      'item/glasses_star' => _glassesStar(a),
      'item/hairpin_star' => _hairpinStar(a),
      'item/hairpin_ribbon' => _hairpinRibbon(a),
      'item/hairpin_flower' => _hairpinFlower(a),
      'item/hairpin_clover' => _hairpinClover(a),
      'item/hat_party' => _hatParty(a),
      'item/hat_chef' => _hatChef(a),
      'item/hat_straw' => _hatStraw(a),
      'item/hat_beret' => _hatBeret(a),
      'item/hat_wizard' => _hatWizard(a),
      'item/bowtie' => _bowtie(a),
      'item/scarf' => _scarf(a),
      'item/necklace' => _necklace(a),
      'item/bell' => _bellNecklace(a),
      'item/balloon' => _balloon(a),
      'item/balloon_heart' => _balloonHeart(a),
      'item/flower' => _flowerSide(a),
      'item/star' => _starCharm(a),
      'item/butterfly' => _butterfly(a),
      'item/music_note' => _musicNotes(a),
      _ => '',
    };
  }

  /// 단계 + 카테고리 → SVG 좌표 anchor. 본체 타원(일반: cx100 cy124 rx50 ry44,
  /// EGG: cx100 cy120 rx52 ry58) 을 기준으로 실제 접점에 맞춘다.
  /// - hat: 머리 정수리(본체 최상단)에 살짝 겹치는 착모점
  /// - glasses: 두 눈의 중심. [_Anchor.gap] 이 눈 간격(중심→눈)이라 렌즈가 눈 위에 온다
  /// - hairpin: 머리 우상단 곡면 위
  /// - accessory: 입 아래 목 위치
  /// - misc: 본체 오른쪽 여백
  _Anchor? _anchor(CharacterStage stage, ShopItemType type) {
    final isEgg = stage == CharacterStage.egg;
    return switch (type) {
      ShopItemType.hat => _Anchor(cx: 100, cy: isEgg ? 68 : 84),
      ShopItemType.glasses => _Anchor(
          cx: 100,
          cy: isEgg ? 116 : 122,
          gap: isEgg ? 12 : 14,
        ),
      ShopItemType.hairpin =>
        _Anchor(cx: isEgg ? 132 : 130, cy: isEgg ? 94 : 100),
      ShopItemType.accessory => _Anchor(cx: 100, cy: isEgg ? 162 : 156),
      ShopItemType.misc => const _Anchor(cx: 164, cy: 104),
      ShopItemType.skin || ShopItemType.background => null,
    };
  }

  // ── 개별 아이템 SVG 단편 (그라디언트 + 하이라이트로 입체감) ──────
  // 안경류는 렌즈 중심을 [_Anchor.gap](눈 간격)에 맞춰 실제로 눈 위에 걸치고,
  // 모자류는 anchor(착모점) 기준 base 가 y≈+2 에 오도록 그려 머리에 딱 앉는다.

  String _glassesRound(_Anchor a) {
    final g = a.gap;
    return '''
  <g transform="translate(${a.cx} ${a.cy})">
    <line x1="${-(g + 8)}" y1="0" x2="${-(g + 14)}" y2="-3.5" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round"/>
    <line x1="${g + 8}" y1="0" x2="${g + 14}" y2="-3.5" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round"/>
    <circle cx="${-g}" cy="0" r="8.5" fill="#FFFFFF" fill-opacity="0.16" stroke="#2B2B2B" stroke-width="2.6"/>
    <circle cx="$g" cy="0" r="8.5" fill="#FFFFFF" fill-opacity="0.16" stroke="#2B2B2B" stroke-width="2.6"/>
    <path d="M${-g + 8.5} -1.5 Q0 -4.5 ${g - 8.5} -1.5" stroke="#2B2B2B" stroke-width="2.2" fill="none"/>
    <path d="M${-g - 4.5} -3.5 Q${-g - 1} -6.5 ${-g + 2.5} -5" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" opacity="0.7" fill="none"/>
    <path d="M${g - 4.5} -3.5 Q${g - 1} -6.5 ${g + 2.5} -5" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" opacity="0.7" fill="none"/>
  </g>
  ''';
  }

  String _glassesHeart(_Anchor a) {
    final g = a.gap;
    return '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M${-g - 8} -3 C${-g - 8} -10 ${-g} -12 ${-g} -5 C${-g} -12 ${-g + 8} -10 ${-g + 8} -3 C${-g + 8} 3 ${-g} 9 ${-g} 9 C${-g} 9 ${-g - 8} 3 ${-g - 8} -3 Z" fill="url(#aHeartGlass)" stroke="#A23838" stroke-width="1.1"/>
    <path d="M${g - 8} -3 C${g - 8} -10 $g -12 $g -5 C$g -12 ${g + 8} -10 ${g + 8} -3 C${g + 8} 3 $g 9 $g 9 C$g 9 ${g - 8} 3 ${g - 8} -3 Z" fill="url(#aHeartGlass)" stroke="#A23838" stroke-width="1.1"/>
    <line x1="${-g + 8}" y1="-3" x2="${g - 8}" y2="-3" stroke="#A23838" stroke-width="2.2"/>
    <circle cx="${-g - 3.5}" cy="-5" r="1.5" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="${g - 3.5}" cy="-5" r="1.5" fill="#FFFFFF" opacity="0.85"/>
  </g>
  ''';
  }

  String _glassesSun(_Anchor a) {
    final g = a.gap;
    return '''
  <g transform="translate(${a.cx} ${a.cy})">
    <line x1="${-(g + 8)}" y1="-2" x2="${-(g + 14)}" y2="-5" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round"/>
    <line x1="${g + 8}" y1="-2" x2="${g + 14}" y2="-5" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round"/>
    <rect x="${-g - 8.5}" y="-7" width="17" height="13" rx="3.5" fill="url(#aSunLens)"/>
    <rect x="${g - 8.5}" y="-7" width="17" height="13" rx="3.5" fill="url(#aSunLens)"/>
    <path d="M${-g + 8.5} -3.5 Q0 -6.5 ${g - 8.5} -3.5" stroke="#2B2B2B" stroke-width="2.4" fill="none"/>
    <line x1="${-g - 5}" y1="-4" x2="${-g + 3}" y2="-4" stroke="#9C9C9C" stroke-width="1.6" stroke-linecap="round" opacity="0.85"/>
    <line x1="${g - 5}" y1="-4" x2="${g + 3}" y2="-4" stroke="#9C9C9C" stroke-width="1.6" stroke-linecap="round" opacity="0.85"/>
  </g>
  ''';
  }

  String _glassesStar(_Anchor a) {
    final g = a.gap;
    String lens(double cx) =>
        '<path d="M$cx -10 L${cx + 2.9} -3.1 L${cx + 10.4} -3.1 L${cx + 4.4} 1.8 L${cx + 6.4} 9.3 L$cx 4.9 L${cx - 6.4} 9.3 L${cx - 4.4} 1.8 L${cx - 10.4} -3.1 L${cx - 2.9} -3.1 Z" '
        'fill="url(#mGold)" fill-opacity="0.92" stroke="#B8860B" stroke-width="1.1" stroke-linejoin="round"/>';
    return '''
  <g transform="translate(${a.cx} ${a.cy})">
    ${lens(-g)}
    ${lens(g)}
    <line x1="${-g + 6}" y1="-3" x2="${g - 6}" y2="-3" stroke="#B8860B" stroke-width="2.2"/>
    <circle cx="${-g - 2.5}" cy="-4.5" r="1.4" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="${g - 2.5}" cy="-4.5" r="1.4" fill="#FFFFFF" opacity="0.85"/>
  </g>
  ''';
  }

  String _hairpinFlower(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy}) scale(1.4) rotate(12)">
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
  <g transform="translate(${a.cx} ${a.cy}) scale(1.4) rotate(-10)">
    <path d="M0 -7 L2.2 -2 L7 -1.5 L3.4 2.3 L4.4 7.5 L0 5 L-4.4 7.5 L-3.4 2.3 L-7 -1.5 L-2.2 -2 Z" fill="url(#mGold)" stroke="#B8860B" stroke-width="0.8"/>
    <circle cx="-1.4" cy="-2.6" r="0.9" fill="#FFFFFF" opacity="0.8"/>
  </g>
  ''';

  String _hairpinRibbon(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy}) scale(1.4) rotate(-14)">
    <path d="M-8 0 Q-2 -4 0 0 Q-2 4 -8 0 Z" fill="url(#aRibbonPink)" stroke="#A23854" stroke-width="0.8"/>
    <path d="M8 0 Q2 -4 0 0 Q2 4 8 0 Z" fill="url(#aRibbonPink)" stroke="#A23854" stroke-width="0.8"/>
    <circle cx="0" cy="0" r="2" fill="#A23854"/>
    <circle cx="-0.6" cy="-0.6" r="0.7" fill="#FFFFFF" opacity="0.7"/>
  </g>
  ''';

  String _hairpinClover(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy}) scale(1.35) rotate(8)">
    <circle cx="0" cy="-3.4" r="3.1" fill="url(#mLeafL)"/>
    <circle cx="3.4" cy="0" r="3.1" fill="url(#mLeafR)"/>
    <circle cx="0" cy="3.4" r="3.1" fill="url(#mLeafL)"/>
    <circle cx="-3.4" cy="0" r="3.1" fill="url(#mLeafR)"/>
    <circle cx="0" cy="0" r="1.4" fill="#3E8C33"/>
    <circle cx="-1.2" cy="-4.2" r="0.9" fill="#FFFFFF" opacity="0.7"/>
  </g>
  ''';

  String _hatParty(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M0 -28 L-13 2 L13 2 Z" fill="url(#aCone)" stroke="#A23838" stroke-width="1"/>
    <path d="M-1.5 -23 L-9 -1" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" opacity="0.45"/>
    <circle cx="0" cy="-29" r="3.4" fill="url(#mGoldR)"/>
    <circle cx="-0.9" cy="-29.9" r="1" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="-6" cy="-8" r="1.7" fill="#FFFFFF"/>
    <circle cx="6" cy="-16" r="1.7" fill="#FFFFFF"/>
    <path d="M-13 2 Q0 6 13 2" stroke="#A23838" stroke-width="1" fill="none" opacity="0.6"/>
  </g>
  ''';

  String _hatChef(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <ellipse cx="-7" cy="-18" rx="8" ry="7" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="7" cy="-18" rx="8" ry="7" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="0" cy="-22" rx="8" ry="7" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <rect x="-13" y="-12" width="26" height="14" rx="3" fill="url(#aChef)" stroke="#9CA3AF" stroke-width="1"/>
    <ellipse cx="-3" cy="-24" rx="3.4" ry="2" fill="#FFFFFF" opacity="0.9"/>
    <line x1="-13" y1="-2.5" x2="13" y2="-2.5" stroke="#C9CDD6" stroke-width="1.2"/>
  </g>
  ''';

  String _hatStraw(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <ellipse cx="0" cy="0.5" rx="22" ry="5.5" fill="url(#aStraw)" stroke="#C9A55A" stroke-width="1"/>
    <path d="M-13 -1 C-13 -12 -8 -17 0 -17 C8 -17 13 -12 13 -1 Z" fill="url(#aStraw)" stroke="#C9A55A" stroke-width="1"/>
    <path d="M-12.6 -2 L12.6 -2 L12.6 -5.6 L-12.6 -5.6 Z" fill="#FF6B6B"/>
    <path d="M-12.6 -2 L12.6 -2" stroke="#D94A4A" stroke-width="0.8"/>
    <path d="M-8 -13 Q-3 -16 3 -15" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" opacity="0.55" fill="none"/>
  </g>
  ''';

  String _hatBeret(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy}) rotate(-6)">
    <ellipse cx="0" cy="-4" rx="16" ry="8.5" fill="url(#aBeret)" stroke="#93262E" stroke-width="1"/>
    <ellipse cx="0" cy="0.8" rx="11.5" ry="3.4" fill="#B03038"/>
    <line x1="0" y1="-12" x2="0" y2="-15.5" stroke="#93262E" stroke-width="2" stroke-linecap="round"/>
    <circle cx="0" cy="-16.5" r="1.8" fill="#B03038"/>
    <ellipse cx="-6" cy="-8" rx="4.5" ry="2.4" fill="#FFFFFF" opacity="0.4" transform="rotate(-14 -6 -8)"/>
  </g>
  ''';

  String _hatWizard(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M0 -36 C5 -24 11 -12 14 0 L-14 0 C-11 -12 -5 -24 0 -36 Z" fill="url(#aWiz)" stroke="#4A3AA8" stroke-width="1"/>
    <ellipse cx="0" cy="1" rx="19" ry="4.5" fill="url(#aWiz)" stroke="#4A3AA8" stroke-width="1"/>
    <path d="M-12.5 -4 L12.5 -4 L13.4 -0.5 L-13.4 -0.5 Z" fill="url(#mGold)"/>
    <path d="M-4 -14 L-2.8 -11.4 L-0.2 -11.4 L-2.3 -9.8 L-1.6 -7.2 L-4 -8.8 L-6.4 -7.2 L-5.7 -9.8 L-7.8 -11.4 L-5.2 -11.4 Z" fill="#FFF59D"/>
    <path d="M5 -22 L5.9 -20 L7.9 -20 L6.3 -18.8 L6.9 -16.8 L5 -18 L3.1 -16.8 L3.7 -18.8 L2.1 -20 L4.1 -20 Z" fill="#FFF59D"/>
    <circle cx="0" cy="-37" r="2.2" fill="url(#mGoldR)"/>
    <path d="M-4 -28 Q-1 -31 2 -29" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round" opacity="0.5" fill="none"/>
  </g>
  ''';

  String _bowtie(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-16 -5.5 L-2.5 0 L-16 5.5 Z" fill="url(#aBow)" stroke="#5A1F30" stroke-width="0.9"/>
    <path d="M16 -5.5 L2.5 0 L16 5.5 Z" fill="url(#aBow)" stroke="#5A1F30" stroke-width="0.9"/>
    <rect x="-3.4" y="-3.4" width="6.8" height="6.8" rx="1.6" fill="#5A1F30"/>
    <rect x="-2.3" y="-2.3" width="2.8" height="2.8" rx="0.9" fill="#FFFFFF" opacity="0.35"/>
  </g>
  ''';

  String _scarf(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-21 -4 Q0 -10 21 -4 L21 4 Q0 -2 -21 4 Z" fill="url(#aScarf)" stroke="#2C5BA6" stroke-width="0.8"/>
    <path d="M-9 4 L-13 20 L-5 16 Z" fill="url(#aScarf)" stroke="#2C5BA6" stroke-width="0.8"/>
    <path d="M-17 -4 Q0 -9 17 -4" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" opacity="0.5" fill="none"/>
  </g>
  ''';

  String _balloon(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 34})">
    <ellipse cx="0" cy="0" rx="14" ry="18" fill="url(#aBalloon)" stroke="#B8860B" stroke-width="0.8"/>
    <ellipse cx="-5" cy="-7" rx="4.5" ry="7" fill="#FFFFFF" opacity="0.5" transform="rotate(-18 -5 -7)"/>
    <path d="M-2 17 L0 22 L2 17 Z" fill="#B8860B"/>
    <path d="M0 22 Q-4 40 4 56" stroke="#9CA3AF" stroke-width="1.2" fill="none"/>
  </g>
  ''';

  String _balloonHeart(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 34})">
    <path d="M0 18 C0 7 -15 5 -15 -5 C-15 -13 -5 -13 0 -5 C5 -13 15 -13 15 -5 C15 5 0 7 0 18 Z" fill="url(#aBalloonHeart)" stroke="#A23838" stroke-width="0.8"/>
    <ellipse cx="-7" cy="-6" rx="3.4" ry="4.6" fill="#FFFFFF" opacity="0.5" transform="rotate(-22 -7 -6)"/>
    <path d="M0 18 Q-4 38 4 56" stroke="#9CA3AF" stroke-width="1.2" fill="none"/>
  </g>
  ''';

  String _necklace(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-19 -3 Q0 15 19 -3" stroke="#E8E8EE" stroke-width="2.2" fill="none"/>
    <circle cx="-9" cy="4.5" r="2.2" fill="#F2F2F7" stroke="#C9CBD6" stroke-width="0.6"/>
    <circle cx="9" cy="4.5" r="2.2" fill="#F2F2F7" stroke="#C9CBD6" stroke-width="0.6"/>
    <circle cx="0" cy="10" r="3.6" fill="url(#mGoldR)" stroke="#C9A227" stroke-width="0.7"/>
    <circle cx="-1" cy="9" r="1" fill="#FFFFFF" opacity="0.85"/>
  </g>
  ''';

  String _bellNecklace(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy})">
    <path d="M-18 -3 Q0 12 18 -3" stroke="#C46A4A" stroke-width="2.4" fill="none"/>
    <circle cx="0" cy="9" r="5" fill="url(#mGoldR)" stroke="#B8860B" stroke-width="0.8"/>
    <line x1="-4.6" y1="9.5" x2="4.6" y2="9.5" stroke="#B8860B" stroke-width="1"/>
    <line x1="0" y1="9.5" x2="0" y2="13" stroke="#B8860B" stroke-width="1.4" stroke-linecap="round"/>
    <circle cx="0" cy="13.6" r="1.1" fill="#B8860B"/>
    <circle cx="-1.6" cy="7" r="1.2" fill="#FFFFFF" opacity="0.85"/>
  </g>
  ''';

  String _starCharm(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy}) scale(1.25)">
    <path d="M0 -9 L2.6 -2.6 L9 -2.6 L3.8 1.6 L5.6 8 L0 4.2 L-5.6 8 L-3.8 1.6 L-9 -2.6 L-2.6 -2.6 Z" fill="url(#mGold)" stroke="#B8860B" stroke-width="0.8"/>
    <circle cx="0" cy="-0.5" r="1.6" fill="#FFF3B0"/>
    <circle cx="-1.8" cy="-3.6" r="0.9" fill="#FFFFFF" opacity="0.8"/>
  </g>
  ''';

  String _flowerSide(_Anchor a) => '''
  <g transform="translate(${a.cx - 4} ${a.cy + 18})">
    <line x1="0" y1="0" x2="0" y2="44" stroke="#4E9C41" stroke-width="2.2"/>
    <line x1="-0.8" y1="3" x2="-0.8" y2="40" stroke="#83CF74" stroke-width="0.9" opacity="0.8"/>
    <path d="M0 26 Q8 20 12 24 Q7 29 0 26 Z" fill="url(#mLeafR)"/>
    <circle cx="0" cy="0" r="5.5" fill="url(#mPetalB)"/>
    <circle cx="4.4" cy="-3.3" r="5.5" fill="url(#mPetalB)"/>
    <circle cx="-4.4" cy="-3.3" r="5.5" fill="url(#mPetalB)"/>
    <circle cx="2.2" cy="3.3" r="5.5" fill="url(#mPetalB)"/>
    <circle cx="-2.2" cy="3.3" r="5.5" fill="url(#mPetalB)"/>
    <circle cx="0" cy="0" r="2.4" fill="url(#mFlowerCore)"/>
    <circle cx="-2.2" cy="-5.5" r="1.4" fill="#FFFFFF" opacity="0.65"/>
  </g>
  ''';

  String _butterfly(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 14}) rotate(-10)">
    <ellipse cx="-5.5" cy="-3" rx="6" ry="4.5" fill="url(#aBfly)" stroke="#D98A2B" stroke-width="0.8" transform="rotate(-24 -5.5 -3)"/>
    <ellipse cx="5.5" cy="-3" rx="6" ry="4.5" fill="url(#aBfly)" stroke="#D98A2B" stroke-width="0.8" transform="rotate(24 5.5 -3)"/>
    <ellipse cx="-4.5" cy="3.5" rx="4.2" ry="3.2" fill="url(#aBfly)" stroke="#D98A2B" stroke-width="0.8" transform="rotate(-40 -4.5 3.5)"/>
    <ellipse cx="4.5" cy="3.5" rx="4.2" ry="3.2" fill="url(#aBfly)" stroke="#D98A2B" stroke-width="0.8" transform="rotate(40 4.5 3.5)"/>
    <ellipse cx="0" cy="0" rx="1.6" ry="5" fill="#5A4632"/>
    <path d="M-1 -4.5 Q-3.5 -8.5 -5 -9.5 M1 -4.5 Q3.5 -8.5 5 -9.5" stroke="#5A4632" stroke-width="1" stroke-linecap="round" fill="none"/>
    <circle cx="-6" cy="-4.5" r="1.2" fill="#FFFFFF" opacity="0.75"/>
    <circle cx="6" cy="-4.5" r="1.2" fill="#FFFFFF" opacity="0.75"/>
  </g>
  ''';

  String _musicNotes(_Anchor a) => '''
  <g transform="translate(${a.cx} ${a.cy - 10})">
    <g transform="rotate(-8)">
      <ellipse cx="-4" cy="6" rx="3.4" ry="2.6" fill="#FF8FA3" stroke="#C25A72" stroke-width="0.8"/>
      <line x1="-0.8" y1="5.4" x2="-0.8" y2="-8" stroke="#C25A72" stroke-width="1.8" stroke-linecap="round"/>
      <path d="M-0.8 -8 Q4 -6.5 5 -2.5" stroke="#C25A72" stroke-width="1.8" stroke-linecap="round" fill="none"/>
    </g>
    <g transform="translate(12 16) rotate(10)">
      <ellipse cx="-2.8" cy="5" rx="2.8" ry="2.2" fill="#7CB1F5" stroke="#4478C8" stroke-width="0.8"/>
      <line x1="-0.2" y1="4.5" x2="-0.2" y2="-6.5" stroke="#4478C8" stroke-width="1.6" stroke-linecap="round"/>
      <path d="M-0.2 -6.5 Q3.4 -5.2 4.2 -2" stroke="#4478C8" stroke-width="1.6" stroke-linecap="round" fill="none"/>
    </g>
    ${_sparkle(-10, -6, 2, 0.8, color: '#FCD34D')}
  </g>
  ''';

  // ─────────────────────────────────────────
  // 단계별 베이스 SVG (스킨이 panda 일 때 흑백 패턴 보강)
  // ─────────────────────────────────────────

  /// EGG (Lv 1): 잠자고 있는 알 모찌. 눈은 ‿ 처럼 감겨 있고, 우상단에 zZz.
  String _egg({required String skin}) {
    return '''
  ${_body3d(cx: 100, cy: 120, rx: 52, ry: 58, patches: _skinPatches(skin, CharacterStage.egg), bodyFill: _skinBodyFill(skin))}
  <path d="M82 116 Q88 119 94 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M106 116 Q112 119 118 116" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  <path d="M92 134 Q100 140 108 134" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
  ${_cheeks(74, 126, 130)}
  <text x="148" y="74" font-family="Inter, Arial, sans-serif" font-size="22" font-weight="700" fill="#FFFFFF" opacity="0.85">Z</text>
  <text x="162" y="92" font-family="Inter, Arial, sans-serif" font-size="14" font-weight="700" fill="#FFFFFF" opacity="0.7">z</text>
  <text x="170" y="106" font-family="Inter, Arial, sans-serif" font-size="9" font-weight="700" fill="#FFFFFF" opacity="0.55">z</text>
  ''';
  }

  String _sprout({required String skin}) {
    return '''
  <g>
    <path d="M100 56 Q86 48 92 64 Q98 68 100 64 Z" fill="url(#mLeafL)"/>
    <path d="M100 56 Q114 48 108 64 Q102 68 100 64 Z" fill="url(#mLeafR)"/>
    <line x1="100" y1="66" x2="100" y2="84" stroke="#6FBF5E" stroke-width="3" stroke-linecap="round"/>
    <line x1="99" y1="68" x2="99" y2="80" stroke="#A5E793" stroke-width="1" stroke-linecap="round" opacity="0.8"/>
  </g>
  ${_skinBehind(skin, CharacterStage.sprout)}
  ${_body3d(cx: 100, cy: 124, rx: 46, ry: 40, patches: _skinPatches(skin, CharacterStage.sprout), bodyFill: _skinBodyFill(skin))}
  ${_eye(88, 122, 2.8, 3.6)}
  ${_eye(112, 122, 2.8, 3.6)}
  ${_mouth(93, 136, 100, 142, 107, 136, 2.4)}
  ${_cheeks(76, 124, 132)}
  ''';
  }

  /// BLOOM (Lv 6) — 꽃 모찌: 머리에 막 피어난 작은 벚꽃. 단독 모찌.
  String _bloom({required String skin}) {
    return '''
  <g>
    ${_skinBehind(skin, CharacterStage.bloom)}
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: _skinPatches(skin, CharacterStage.bloom), bodyFill: _skinBodyFill(skin))}
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
  String _blossom({required String skin}) {
    return '''
  <g>
    ${_skinBehind(skin, CharacterStage.blossom)}
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: _skinPatches(skin, CharacterStage.blossom), bodyFill: _skinBodyFill(skin))}
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
  String _glow({required String skin}) {
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
    ${_skinBehind(skin, CharacterStage.glow)}
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: _skinPatches(skin, CharacterStage.glow), bodyFill: _skinBodyFill(skin))}
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
  String _master({required String skin}) {
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
    ${_skinBehind(skin, CharacterStage.master)}
    ${_body3d(cx: 100, cy: 124, rx: 50, ry: 44, patches: _skinPatches(skin, CharacterStage.master), bodyFill: _skinBodyFill(skin))}
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
  const _Anchor({required this.cx, required this.cy, this.gap = 14});
  final double cx;
  final double cy;

  /// 안경류 전용 — 얼굴 중심에서 각 눈까지의 x 간격. 렌즈가 실제 눈 위에 오도록
  /// 단계별(EGG 는 눈이 조금 안쪽) 로 조정된다.
  final double gap;
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
