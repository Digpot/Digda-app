import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/character_models.dart';

/// 모찌 캐릭터를 [size]×[size] 정사각형으로 렌더링.
///
/// 색상 적용은 배경 squircle 컬러만 바꾸는 방식 (logo_digda 의 COLOR VARIANTS 패턴).
/// 모찌(흰/연핑크)·하트는 어느 배경에서도 동일하게 유지된다.
class MochiCharacterView extends StatelessWidget {
  const MochiCharacterView({
    super.key,
    required this.color,
    required this.colorHex,
    this.size = 200,
    this.cornerRadius,
  });

  final CharacterColor color;
  final String colorHex;
  final double size;
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final radius = cornerRadius ?? size * 0.24;
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        _buildSvg(colorHex, radius),
        width: size,
        height: size,
      ),
    );
  }

  static String _buildSvg(String hex, double radiusRatio) {
    final cleanHex = hex.startsWith('#') ? hex : '#$hex';
    return '''
<svg width="200" height="200" viewBox="0 0 200 200" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="200" height="200" rx="48" fill="$cleanHex"/>
  <g>
    <ellipse cx="124" cy="112" rx="42" ry="36" fill="#FFE4E4"/>
    <ellipse cx="112" cy="110" rx="2.4" ry="3.2" fill="#2B2B2B"/>
    <ellipse cx="136" cy="110" rx="2.4" ry="3.2" fill="#2B2B2B"/>
    <path d="M118 121 Q124 127 130 121" stroke="#2B2B2B" stroke-width="2" stroke-linecap="round" fill="none"/>
    <ellipse cx="103" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
    <ellipse cx="145" cy="120" rx="4.2" ry="2.8" fill="#FF9AAA" opacity="0.7"/>
  </g>
  <g>
    <ellipse cx="82" cy="118" rx="48" ry="41" fill="#FFFFFF"/>
    <path d="M82 70 C78 64 68 64 68 73 C68 79 75 84 82 90 C89 84 96 79 96 73 C96 64 86 64 82 70 Z" fill="#FF9FB0"/>
    <ellipse cx="68" cy="116" rx="2.8" ry="3.6" fill="#2B2B2B"/>
    <ellipse cx="96" cy="116" rx="2.8" ry="3.6" fill="#2B2B2B"/>
    <path d="M74 128 Q82 135 90 128" stroke="#2B2B2B" stroke-width="2.4" stroke-linecap="round" fill="none"/>
    <ellipse cx="56" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
    <ellipse cx="108" cy="126" rx="5" ry="3.3" fill="#FF9AAA" opacity="0.75"/>
  </g>
</svg>
''';
  }
}

/// 진화 단계에 따른 보조 표시(스파클 등). 현재는 GLOW 단계에서만 light dot 4개를 띄움.
class MochiStageBadge extends StatelessWidget {
  const MochiStageBadge({super.key, required this.stage, required this.size});

  final CharacterStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (stage != CharacterStage.glow) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(top: size * 0.05, left: size * 0.1, child: _dot(size * 0.04)),
            Positioned(top: size * 0.12, right: size * 0.12, child: _dot(size * 0.03)),
            Positioned(bottom: size * 0.18, left: size * 0.08, child: _dot(size * 0.025)),
            Positioned(bottom: size * 0.1, right: size * 0.18, child: _dot(size * 0.035)),
          ],
        ),
      ),
    );
  }

  Widget _dot(double d) => Container(
        width: d,
        height: d,
        decoration: const BoxDecoration(
          color: Color(0xCCFFF8C4),
          shape: BoxShape.circle,
        ),
      );
}
