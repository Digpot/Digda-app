import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../title_catalog.dart';

/// 칭호 메달 뱃지 — 이미지 파일 없이 코드로 그린다.
///
/// 레이어(아래→위): 후광 글로우 · 선버스트(2겹) · 금속 외곽 링(스윕 그라데이션) ·
/// 비드 림 · 안쪽 원반(라디얼) · 안쪽 음각 링 · 아이콘 · 윗 글로스 · 반짝임.
/// 획득 시 지역색 메달, 미획득 시 차분한 회색 실루엣 + 물음표.
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
    // 획득: 지역색 기반 금속 톤 / 미획득: 차분한 그래파이트.
    final Color base = earned ? accent : const Color(0xFF3A3531);
    final Color light = earned
        ? Color.lerp(accent, Colors.white, 0.58)!
        : const Color(0xFF5A554F);
    final Color dark = earned
        ? Color.lerp(accent, const Color(0xFF1A0E0A), 0.34)!
        : const Color(0xFF201D1A);
    final Color rayColor = earned
        ? Color.lerp(accent, Colors.white, 0.16)!
        : const Color(0xFF423D38);

    final ringSize = size * 0.82;
    final discSize = ringSize * 0.76;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 0) 후광 글로우 — 획득 메달 뒤로 은은히 번지는 빛.
          if (earned)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.38),
                    accent.withValues(alpha: 0.0),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),

          // 1) 선버스트 — 긴 광선 + 짧은 광선 2겹으로 별빛 느낌.
          CustomPaint(
            size: Size(size, size),
            painter: _SunburstPainter(
              color: rayColor,
              glowColor: earned
                  ? Color.lerp(accent, Colors.white, 0.35)!
                  : const Color(0xFF4A453F),
              points: 12,
            ),
          ),

          // 2) 외곽 금속 링 — 스윕 그라데이션으로 도는 금속 광택.
          Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: 0,
                endAngle: math.pi * 2,
                transform: const GradientRotation(-math.pi / 2),
                colors: [light, dark, light, dark, light],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: (earned ? accent : Colors.black)
                      .withValues(alpha: earned ? 0.42 : 0.28),
                  blurRadius: size * 0.16,
                  offset: Offset(0, size * 0.06),
                ),
              ],
            ),
          ),

          // 3) 비드 림 — 링 안쪽 가장자리를 따라 박힌 작은 구슬 디테일(보석함 느낌).
          CustomPaint(
            size: Size(ringSize, ringSize),
            painter: _BeadRingPainter(
              color: Colors.white.withValues(alpha: earned ? 0.55 : 0.30),
              shadow: Colors.black.withValues(alpha: 0.18),
              beads: 28,
              radiusFactor: 0.40,
              beadSize: ringSize * 0.022,
            ),
          ),

          // 4) 안쪽 원반 — 비스듬한 라디얼 그라데이션으로 입체감.
          Container(
            width: discSize,
            height: discSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.32, -0.42),
                radius: 1.05,
                colors: [light, base, dark],
                stops: const [0.0, 0.62, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: earned ? 0.55 : 0.3),
                width: size * 0.018,
              ),
            ),
            child: Center(
              child: Icon(
                earned ? def.icon : Icons.question_mark_rounded,
                size: discSize * 0.48,
                color: Colors.white.withValues(alpha: earned ? 1 : 0.7),
                shadows: earned
                    ? [
                        Shadow(
                          color: dark.withValues(alpha: 0.6),
                          blurRadius: size * 0.04,
                          offset: Offset(0, size * 0.012),
                        ),
                      ]
                    : null,
              ),
            ),
          ),

          // 5) 윗쪽 글로스 — 유리알 같은 반사광 띠.
          Positioned(
            top: size * 0.17,
            child: Container(
              width: discSize * 0.62,
              height: discSize * 0.30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: earned ? 0.5 : 0.26),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),

          // 6) 획득 시 반짝임 — 크고 작은 별 2개로 디테일.
          if (earned) ...[
            Positioned(
              right: size * 0.13,
              top: size * 0.11,
              child: Icon(Icons.auto_awesome,
                  size: size * 0.17,
                  color: Colors.white.withValues(alpha: 0.95)),
            ),
            Positioned(
              left: size * 0.17,
              bottom: size * 0.2,
              child: Icon(Icons.auto_awesome,
                  size: size * 0.09,
                  color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 메달 뒤 선버스트 — [points] 개의 긴 광선과 그 사이 짧은 광선을 겹쳐 별빛을 낸다.
class _SunburstPainter extends CustomPainter {
  _SunburstPainter({
    required this.color,
    required this.glowColor,
    required this.points,
  });

  final Color color;
  final Color glowColor;
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2;

    // a) 짧은 광선 — 봉우리 사이를 메우는 보조 빛(연한 글로우).
    _drawSpikes(
      canvas,
      c,
      count: points,
      rTip: rOuter * 0.92,
      rBase: rOuter * 0.62,
      halfWidth: math.pi / points * 0.42,
      angleOffset: math.pi / points, // 긴 광선 사이로 어긋나게
      paint: Paint()
        ..color = glowColor.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    // b) 긴 광선 — 또렷한 메인 빛.
    _drawSpikes(
      canvas,
      c,
      count: points,
      rTip: rOuter,
      rBase: rOuter * 0.66,
      halfWidth: math.pi / points * 0.5,
      angleOffset: 0,
      paint: Paint()..color = color,
    );
  }

  void _drawSpikes(
    Canvas canvas,
    Offset c, {
    required int count,
    required double rTip,
    required double rBase,
    required double halfWidth,
    required double angleOffset,
    required Paint paint,
  }) {
    final path = Path();
    for (var i = 0; i < count; i++) {
      final a = (i / count) * 2 * math.pi - math.pi / 2 + angleOffset;
      final tip = Offset(c.dx + rTip * math.cos(a), c.dy + rTip * math.sin(a));
      final l = Offset(
        c.dx + rBase * math.cos(a - halfWidth),
        c.dy + rBase * math.sin(a - halfWidth),
      );
      final r = Offset(
        c.dx + rBase * math.cos(a + halfWidth),
        c.dy + rBase * math.sin(a + halfWidth),
      );
      path
        ..moveTo(l.dx, l.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(r.dx, r.dy)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter old) =>
      old.color != color ||
      old.glowColor != glowColor ||
      old.points != points;
}

/// 링 안쪽을 따라 박힌 작은 구슬(비드) 림 — 보석함 같은 디테일.
class _BeadRingPainter extends CustomPainter {
  _BeadRingPainter({
    required this.color,
    required this.shadow,
    required this.beads,
    required this.radiusFactor,
    required this.beadSize,
  });

  final Color color;
  final Color shadow;
  final int beads;
  final double radiusFactor;
  final double beadSize;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * radiusFactor;
    final shadowPaint = Paint()..color = shadow;
    final beadPaint = Paint()..color = color;
    for (var i = 0; i < beads; i++) {
      final a = (i / beads) * 2 * math.pi;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      canvas.drawCircle(p.translate(0, beadSize * 0.35), beadSize, shadowPaint);
      canvas.drawCircle(p, beadSize, beadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeadRingPainter old) =>
      old.color != color ||
      old.shadow != shadow ||
      old.beads != beads ||
      old.radiusFactor != radiusFactor ||
      old.beadSize != beadSize;
}
