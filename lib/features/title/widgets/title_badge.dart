import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../title_catalog.dart';

/// 칭호 메달 뱃지 — 이미지 파일 없이 코드로 그린다(별빛 광선 + 금속 링 + 지역색 + 아이콘).
/// 획득 시 컬러 메달, 미획득 시 회색 실루엣 + 물음표.
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
    final base = earned ? accent : const Color(0xFF35302B);
    final light =
        earned ? Color.lerp(accent, Colors.white, 0.5)! : const Color(0xFF55504A);
    final dark =
        earned ? Color.lerp(accent, Colors.black, 0.20)! : const Color(0xFF1F1D1A);
    // 별빛 광선 — 메달 뒤로 살짝 삐져나오는 뾰족한 톱니(메달다움).
    final rayColor = earned
        ? Color.lerp(accent, Colors.white, 0.18)!
        : const Color(0xFF45403A);

    final ringSize = size * 0.84;
    final discSize = ringSize * 0.78;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 0) 별빛 광선(톱니 스타) — 메달 뒤 배경.
          CustomPaint(
            size: Size(size, size),
            painter: _MedalRaysPainter(color: rayColor, points: 16),
          ),
          // 1) 바깥 링 (테두리 금속감)
          Container(
            width: ringSize,
            height: ringSize,
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
                        blurRadius: size * 0.18,
                        offset: Offset(0, size * 0.06),
                      ),
                    ]
                  : null,
            ),
          ),
          // 2) 안쪽 원반
          Container(
            width: discSize,
            height: discSize,
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
                earned ? def.icon : Icons.question_mark_rounded,
                size: discSize * 0.46,
                color: Colors.white.withValues(alpha: earned ? 1 : 0.7),
              ),
            ),
          ),
          // 3) 윗쪽 하이라이트 글로스
          Positioned(
            top: size * 0.18,
            child: Container(
              width: size * 0.3,
              height: size * 0.14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: earned ? 0.4 : 0.2),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          // 4) 획득 시 우상단 반짝임 — 살짝의 디테일.
          if (earned)
            Positioned(
              right: size * 0.14,
              top: size * 0.12,
              child: Icon(Icons.auto_awesome,
                  size: size * 0.16, color: Colors.white.withValues(alpha: 0.9)),
            ),
        ],
      ),
    );
  }
}

/// 메달 뒤 뾰족한 톱니 스타(광선). [points] 개의 봉우리로 별빛 느낌을 준다.
class _MedalRaysPainter extends CustomPainter {
  _MedalRaysPainter({required this.color, required this.points});

  final Color color;
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2;
    final rInner = rOuter * 0.84;
    final n = points * 2;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final r = i.isEven ? rOuter : rInner;
      final a = (i / n) * 2 * math.pi - math.pi / 2;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MedalRaysPainter old) =>
      old.color != color || old.points != points;
}
