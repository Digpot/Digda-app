import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../title_catalog.dart';

/// 칭호 메달 뱃지 — 이미지 파일 없이 코드로 그린다.
///
/// 레이어(아래→위): 은은한 후광 · 로제트 꽃잎 링(스캘럽) · 금속 외곽 링(스윕
/// 그라데이션) · 안쪽 원반(라디얼) · 윗 글로스 · 아이콘 · 반짝임.
/// 획득 시 지역색 메달, 미획득 시 밝은 실버 실루엣 + 물음표.
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

    // ── 팔레트 ─────────────────────────────────────────────
    // 획득: 지역색 기반 캔디 톤 / 미획득: 밝은 실버.
    final Color base = earned ? accent : const Color(0xFFC6CBD4);
    final Color light = earned
        ? Color.lerp(accent, Colors.white, 0.62)!
        : const Color(0xFFECEEF2);
    final Color dark = earned
        ? Color.lerp(accent, const Color(0xFF2B1230), 0.30)!
        : const Color(0xFF98A0AC);
    final Color petalLight = earned
        ? Color.lerp(accent, Colors.white, 0.55)!
        : const Color(0xFFDFE2E8);
    final Color petalDark = earned
        ? Color.lerp(accent, Colors.white, 0.18)!
        : const Color(0xFFC2C7D1);

    // 작은 사이즈에선 디테일(반짝임)을 접어 노이즈를 막는다.
    final bool detailed = size >= 44;

    final ringSize = size * 0.80;
    final discSize = ringSize * 0.78;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 0) 후광 — 획득 메달 뒤로 은은히 번지는 빛.
          if (earned)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.20),
                    accent.withValues(alpha: 0.0),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),

          // 1) 로제트 꽃잎 링 — 부드러운 스캘럽 가장자리.
          CustomPaint(
            size: Size(size, size),
            painter: _PetalRingPainter(
              light: petalLight,
              dark: petalDark,
              petals: 10,
            ),
          ),

          // 2) 외곽 금속 링 — 스윕 그라데이션으로 도는 광택.
          Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: const GradientRotation(-math.pi / 2 - 0.6),
                colors: [light, base, dark, base, light],
                stops: const [0.0, 0.28, 0.55, 0.82, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: (earned ? dark : Colors.black)
                      .withValues(alpha: earned ? 0.30 : 0.16),
                  blurRadius: size * 0.10,
                  offset: Offset(0, size * 0.045),
                ),
              ],
            ),
          ),

          // 3) 안쪽 원반 — 좌상단 광원 라디얼 그라데이션으로 입체감.
          Container(
            width: discSize,
            height: discSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.42),
                radius: 1.15,
                colors: [light, base, dark],
                stops: const [0.0, 0.58, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: earned ? 0.85 : 0.75),
                width: math.max(1, size * 0.022),
              ),
            ),
          ),

          // 4) 윗 글로스 — 원반 위쪽에 얹힌 유리알 반사광.
          Positioned(
            top: (size - discSize) / 2 + discSize * 0.07,
            child: Container(
              width: discSize * 0.68,
              height: discSize * 0.34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: earned ? 0.42 : 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),

          // 5) 아이콘.
          Icon(
            earned ? def.icon : Icons.question_mark_rounded,
            size: discSize * 0.50,
            color: Colors.white.withValues(alpha: earned ? 1 : 0.9),
            shadows: [
              Shadow(
                color: dark.withValues(alpha: earned ? 0.55 : 0.4),
                blurRadius: size * 0.035,
                offset: Offset(0, size * 0.014),
              ),
            ],
          ),

          // 6) 획득 시 반짝임 — 큰 사이즈에서만.
          if (earned && detailed) ...[
            Positioned(
              right: size * 0.14,
              top: size * 0.12,
              child: Icon(Icons.auto_awesome,
                  size: size * 0.15,
                  color: Colors.white.withValues(alpha: 0.95)),
            ),
            Positioned(
              left: size * 0.18,
              bottom: size * 0.20,
              child: Icon(Icons.auto_awesome,
                  size: size * 0.08,
                  color: Colors.white.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 메달 뒤 로제트 — [petals] 개의 둥근 꽃잎을 링 형태로 배치해
/// 부드러운 스캘럽(조개) 가장자리를 만든다. 위→아래로 밝→진 셰이딩.
class _PetalRingPainter extends CustomPainter {
  _PetalRingPainter({
    required this.light,
    required this.dark,
    required this.petals,
  });

  final Color light;
  final Color dark;
  final int petals;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final ringR = size.width * 0.355;
    final petalR = size.width * 0.145;

    // 전체 링에 하나의 광원(위) — 꽃잎들이 한 몸처럼 셰이딩되도록.
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(c.dx, c.dy - size.height / 2),
        Offset(c.dx, c.dy + size.height / 2),
        [light, dark],
      );

    final path = Path();
    for (var i = 0; i < petals; i++) {
      final a = (i / petals) * 2 * math.pi - math.pi / 2;
      final p = Offset(c.dx + ringR * math.cos(a), c.dy + ringR * math.sin(a));
      path.addOval(Rect.fromCircle(center: p, radius: petalR));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PetalRingPainter old) =>
      old.light != light || old.dark != dark || old.petals != petals;
}
