import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 모찌의 조력자 캐릭터 디코. 별도 레벨/성장 시스템 없이 보조 역할.
///
/// 디자인 컨셉: 모찌가 둥근 떡 같다면, 디코는 옆에 머무는 작은 별-구체. 머리 위에
/// 작은 안테나(반짝 별) 가 있어 한 눈에 모찌와 구별된다. 톤은 모찌와 같은 핑크
/// 패밀리지만 채도가 한 단계 더 진한 핑크/장미 톤으로 잡아, 모찌(연핑크/코랄)
/// 보다 강조된 보조 캐릭터 인상을 준다. 안테나 별만 따뜻한 옐로우로 포인트.
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
    <radialGradient id="dikoBody" cx="0.5" cy="0.45" r="0.55">
      <stop offset="0%" stop-color="#FFF0F3"/>
      <stop offset="60%" stop-color="#FFC9D9"/>
      <stop offset="100%" stop-color="#FF9FB0"/>
    </radialGradient>
    <radialGradient id="dikoGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="#FFE2EC" stop-opacity="0.7"/>
      <stop offset="100%" stop-color="#FFE2EC" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <circle cx="60" cy="64" r="46" fill="url(#dikoGlow)"/>

  <!-- 머리 위 별 안테나 (핑크 톤) -->
  <line x1="60" y1="36" x2="60" y2="22" stroke="#E63B6E" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M60 6 L63 14 L72 14 L65 19 L67.5 27 L60 22 L52.5 27 L55 19 L48 14 L57 14 Z" fill="#FCD34D" stroke="#E63B6E" stroke-width="1.4" stroke-linejoin="round"/>

  <!-- 본체 (핑크 그라데이션) -->
  <ellipse cx="60" cy="68" rx="40" ry="36" fill="url(#dikoBody)" stroke="#E63B6E" stroke-width="1.6"/>

  <!-- 옅은 별 무늬 (가슴) -->
  <path d="M84 88 L85 92 L89 92 L86 94 L87 98 L84 95.5 L81 98 L82 94 L79 92 L83 92 Z" fill="#FFFFFF" opacity="0.9"/>
  <circle cx="42" cy="88" r="2.2" fill="#FFFFFF" opacity="0.8"/>

  $face

  <!-- 양쪽 볼 홍조 -->
  <ellipse cx="42" cy="74" rx="4.5" ry="2.8" fill="#E63B6E" opacity="0.35"/>
  <ellipse cx="78" cy="74" rx="4.5" ry="2.8" fill="#E63B6E" opacity="0.35"/>
</svg>
''';
  }

  static const String _faceIdle = '''
  <ellipse cx="50" cy="64" rx="2.6" ry="3.4" fill="#2B2B2B"/>
  <ellipse cx="70" cy="64" rx="2.6" ry="3.4" fill="#2B2B2B"/>
  <path d="M54 78 Q60 82 66 78" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round" fill="none"/>
  ''';

  static const String _faceHappy = '''
  <path d="M46 64 Q50 60 54 64" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  <path d="M66 64 Q70 60 74 64" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  <path d="M52 78 Q60 84 68 78" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  ''';

  static const String _faceCurious = '''
  <ellipse cx="50" cy="64" rx="2.4" ry="3.6" fill="#2B2B2B"/>
  <ellipse cx="70" cy="64" rx="2.4" ry="3.6" fill="#2B2B2B"/>
  <ellipse cx="60" cy="80" rx="3.2" ry="2.2" fill="#2B2B2B"/>
  ''';

  static const String _faceWink = '''
  <path d="M46 64 Q50 60 54 64" stroke="#2B2B2B" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  <ellipse cx="70" cy="64" rx="2.6" ry="3.4" fill="#2B2B2B"/>
  <path d="M54 78 Q60 82 66 78" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round" fill="none"/>
  ''';
}

enum DikoMood { idle, happy, curious, wink }
