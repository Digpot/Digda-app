import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 모찌의 조력자 캐릭터 디코. 별도 레벨/성장 시스템 없이 보조 역할.
///
/// 디자인 컨셉: 모찌가 둥근 떡 같다면, 디코는 옆에 머무는 작은 별-구체. 머리 위에
/// 작은 안테나(반짝 별) 가 있어 한 눈에 모찌와 구별된다. 톤은 모찌와 같은 핑크
/// 패밀리지만 채도가 한 단계 더 진한 핑크/장미 톤으로 잡아, 모찌(연핑크/코랄)
/// 보다 강조된 보조 캐릭터 인상을 준다. 안테나 별만 따뜻한 옐로우로 포인트.
///
/// 3D 룩 구현 노트 — 모찌([MochiCharacterView]) 와 같은 접근: flutter_svg 는
/// `<filter>` 를 지원하지 않으므로 입체감은 그라디언트/불투명도 레이어로 만든다.
/// 좌상단 광원 radial 바디(dkBody) + 림 셰이딩(dkRim) + 스펙큘러 하이라이트,
/// 몸 아래 소프트 그림자(dkShadow), 골드 그라디언트 별 안테나로 구성.
///
/// 디코는 단일 SVG 로 그려지고, 표정 변주는 [DikoMood] 로만 결정 — Mochi 처럼 풀
/// 감정 시스템을 두지 않는다 (조력자라 가벼움이 핵심).
class DikoCharacterView extends StatelessWidget {
  const DikoCharacterView({
    super.key,
    this.size = 96,
    this.mood = DikoMood.idle,
  });

  final double size;
  final DikoMood mood;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        _buildSvg(mood),
        width: size,
        height: size,
      ),
    );
  }

  /// [mood] 의 SVG 마크업. 미리보기 재생성 테스트에서 사용.
  @visibleForTesting
  static String debugSvgMarkup(DikoMood mood) => _buildSvg(mood);

  static String _buildSvg(DikoMood mood) {
    final face = switch (mood) {
      DikoMood.idle => _faceIdle,
      DikoMood.happy => _faceHappy,
      DikoMood.curious => _faceCurious,
      DikoMood.wink => _faceWink,
    };
    return '''
<svg width="120" height="120" viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="dkBody" cx="0.38" cy="0.30" r="0.90">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="38%" stop-color="#FFE3EA"/>
      <stop offset="72%" stop-color="#FFB0C1"/>
      <stop offset="100%" stop-color="#F17C97"/>
    </radialGradient>
    <radialGradient id="dkRim" cx="0.40" cy="0.32" r="0.75">
      <stop offset="0%" stop-color="#C2405F" stop-opacity="0"/>
      <stop offset="74%" stop-color="#C2405F" stop-opacity="0"/>
      <stop offset="100%" stop-color="#C2405F" stop-opacity="0.35"/>
    </radialGradient>
    <radialGradient id="dkGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFE2EC" stop-opacity="0.7"/>
      <stop offset="100%" stop-color="#FFE2EC" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="dkShadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#8E2B47" stop-opacity="0.30"/>
      <stop offset="60%" stop-color="#8E2B47" stop-opacity="0.14"/>
      <stop offset="100%" stop-color="#8E2B47" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="dkStar" cx="0.38" cy="0.32" r="0.85">
      <stop offset="0%" stop-color="#FFF3B0"/>
      <stop offset="60%" stop-color="#FCD34D"/>
      <stop offset="100%" stop-color="#D9A21B"/>
    </radialGradient>
    <radialGradient id="dkStarGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFE9A8" stop-opacity="0.75"/>
      <stop offset="100%" stop-color="#FFE9A8" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="dkCheek" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#E63B6E" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#E63B6E" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <circle cx="60" cy="64" r="46" fill="url(#dkGlow)"/>

  <!-- 부유 구체 아래 소프트 그림자 -->
  <ellipse cx="60" cy="108" rx="26" ry="5" fill="url(#dkShadow)"/>

  <!-- 주변 반짝이 — 궤도를 도는 듯한 작은 스파클 3점 -->
  <path d="M22 50 Q22 54 26 54 Q22 54 22 58 Q22 54 18 54 Q22 54 22 50 Z" fill="#FCD34D" opacity="0.6"/>
  <path d="M100 42 Q100 45 103 45 Q100 45 100 48 Q100 45 97 45 Q100 45 100 42 Z" fill="#FCD34D" opacity="0.5"/>
  <circle cx="96" cy="98" r="1.6" fill="#FFB0C1" opacity="0.7"/>

  <!-- 머리 위 별 안테나 (골드 그라디언트 + 글로우) -->
  <line x1="60" y1="36" x2="60" y2="22" stroke="#E63B6E" stroke-width="2.2" stroke-linecap="round"/>
  <line x1="59.2" y1="34" x2="59.2" y2="24" stroke="#FF8FAB" stroke-width="0.9" stroke-linecap="round" opacity="0.8"/>
  <circle cx="60" cy="16" r="13" fill="url(#dkStarGlow)"/>
  <path d="M60 6 L63 14 L72 14 L65 19 L67.5 27 L60 22 L52.5 27 L55 19 L48 14 L57 14 Z" fill="url(#dkStar)" stroke="#C77B1B" stroke-width="1" stroke-linejoin="round"/>
  <circle cx="57.5" cy="13" r="1.2" fill="#FFFFFF" opacity="0.85"/>

  <!-- 짧은 팔 — 본체 뒤에서 좌우로 내민 말랑 스텁 -->
  <ellipse cx="22" cy="74" rx="9" ry="7.5" fill="url(#dkBody)" transform="rotate(-24 22 74)"/>
  <ellipse cx="22" cy="74" rx="9" ry="7.5" fill="url(#dkRim)" transform="rotate(-24 22 74)"/>
  <ellipse cx="98" cy="74" rx="9" ry="7.5" fill="url(#dkBody)" transform="rotate(24 98 74)"/>
  <ellipse cx="98" cy="74" rx="9" ry="7.5" fill="url(#dkRim)" transform="rotate(24 98 74)"/>

  <!-- 본체 — 좌상단 광원 그라디언트 + 림 셰이딩 + 이중 스펙큘러 + 바닥 반사광 -->
  <ellipse cx="60" cy="68" rx="40" ry="36" fill="url(#dkBody)"/>
  <ellipse cx="60" cy="68" rx="40" ry="36" fill="url(#dkRim)"/>
  <ellipse cx="45" cy="52" rx="12" ry="6.5" fill="#FFFFFF" opacity="0.65" transform="rotate(-18 45 52)"/>
  <circle cx="57" cy="42" r="2" fill="#FFFFFF" opacity="0.75"/>
  <circle cx="52" cy="45" r="1.1" fill="#FFFFFF" opacity="0.6"/>
  <ellipse cx="60" cy="99" rx="19" ry="4.5" fill="#FFFFFF" opacity="0.14"/>

  <!-- 옅은 별 무늬 (가슴) -->
  <path d="M84 88 L85 92 L89 92 L86 94 L87 98 L84 95.5 L81 98 L82 94 L79 92 L83 92 Z" fill="#FFFFFF" opacity="0.9"/>
  <circle cx="42" cy="88" r="2.2" fill="#FFFFFF" opacity="0.8"/>

  $face

  <!-- 양쪽 볼 홍조 (radial fade) -->
  <ellipse cx="42" cy="74" rx="6.5" ry="4.4" fill="url(#dkCheek)"/>
  <ellipse cx="78" cy="74" rx="6.5" ry="4.4" fill="url(#dkCheek)"/>
</svg>
''';
  }

  // 채워진 눈에는 이중 캐치라이트(큰 점 + 반대편 작은 점)를 얹어
  // 상용 캐릭터 앱처럼 촉촉한 3D 눈망울을 만든다.
  static const String _faceIdle = '''
  <ellipse cx="50" cy="64" rx="2.9" ry="3.8" fill="#2B2B2B"/>
  <circle cx="49.1" cy="62.7" r="1.0" fill="#FFFFFF" opacity="0.95"/>
  <circle cx="51.2" cy="65.6" r="0.5" fill="#FFFFFF" opacity="0.7"/>
  <ellipse cx="70" cy="64" rx="2.9" ry="3.8" fill="#2B2B2B"/>
  <circle cx="69.1" cy="62.7" r="1.0" fill="#FFFFFF" opacity="0.95"/>
  <circle cx="71.2" cy="65.6" r="0.5" fill="#FFFFFF" opacity="0.7"/>
  <path d="M54 78 Q60 82 66 78" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round" fill="none"/>
  ''';

  static const String _faceHappy = '''
  <path d="M46 64 Q50 60 54 64" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  <path d="M66 64 Q70 60 74 64" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  <path d="M52 78 Q60 84 68 78" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  ''';

  static const String _faceCurious = '''
  <ellipse cx="50" cy="64" rx="2.7" ry="4.0" fill="#2B2B2B"/>
  <circle cx="49.1" cy="62.6" r="1.0" fill="#FFFFFF" opacity="0.95"/>
  <circle cx="51.1" cy="65.8" r="0.5" fill="#FFFFFF" opacity="0.7"/>
  <ellipse cx="70" cy="64" rx="2.7" ry="4.0" fill="#2B2B2B"/>
  <circle cx="69.1" cy="62.6" r="1.0" fill="#FFFFFF" opacity="0.95"/>
  <circle cx="71.1" cy="65.8" r="0.5" fill="#FFFFFF" opacity="0.7"/>
  <ellipse cx="60" cy="80" rx="3.2" ry="2.2" fill="#2B2B2B"/>
  ''';

  static const String _faceWink = '''
  <path d="M46 64 Q50 60 54 64" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  <ellipse cx="70" cy="64" rx="2.9" ry="3.8" fill="#2B2B2B"/>
  <circle cx="69.1" cy="62.7" r="1.0" fill="#FFFFFF" opacity="0.95"/>
  <circle cx="71.2" cy="65.6" r="0.5" fill="#FFFFFF" opacity="0.7"/>
  <path d="M54 78 Q60 82 66 78" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round" fill="none"/>
  ''';
}

enum DikoMood { idle, happy, curious, wink }
