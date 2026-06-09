import 'package:flutter/material.dart';

import '../title_catalog.dart';

/// 칭호 메달 뱃지 — 이미지 파일 없이 코드로 그린다(지역색 + 아이콘).
/// 획득 시 컬러 메달, 미획득 시 회색 + 자물쇠.
class TitleBadge extends StatelessWidget {
  const TitleBadge({
    super.key,
    required this.def,
    required this.earned,
    this.size = 84,
  });

  final TitleDef def;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = def.accent;
    final base = earned ? accent : const Color(0xFFB9B3A8);
    final light =
        earned ? Color.lerp(accent, Colors.white, 0.5)! : const Color(0xFFD9D3C8);
    final dark =
        earned ? Color.lerp(accent, Colors.black, 0.20)! : const Color(0xFF9A948A);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 바깥 링 (테두리 금속감)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [light, dark],
              ),
              boxShadow: earned
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.38),
                        blurRadius: size * 0.2,
                        offset: Offset(0, size * 0.07),
                      ),
                    ]
                  : null,
            ),
          ),
          // 안쪽 원반
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                radius: 1.0,
                colors: [light, base],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: earned ? 0.5 : 0.3),
                width: size * 0.02,
              ),
            ),
            child: Center(
              child: Icon(
                earned ? def.icon : Icons.lock_rounded,
                size: size * 0.36,
                color: Colors.white.withValues(alpha: earned ? 1 : 0.85),
              ),
            ),
          ),
          // 윗쪽 하이라이트 글로스
          Positioned(
            top: size * 0.15,
            child: Container(
              width: size * 0.36,
              height: size * 0.17,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: earned ? 0.38 : 0.2),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
