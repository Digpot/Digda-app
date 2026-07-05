import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../title_catalog.dart';

/// 칭호 메달 뱃지 — 이미지 파일 없이 코드로 그린다.
///
/// 금메달 콘셉트: 골드 메탈릭 로제트 꽃잎 링 + 골드 외곽 링 프레임에
/// 지역색 원반을 박아넣은 구조. 레이어(아래→위): 후광 · 로제트 꽃잎 링 ·
/// 금속 외곽 링(스윕 그라데이션) · 안쪽 원반(라디얼) · 윗 글로스 · 아이콘 ·
/// 반짝임. 획득 시 골드 프레임 + 지역색 원반, 미획득 시 밝은 실버 + 물음표.
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

  // ── 골드 팔레트(획득 프레임) ────────────────────────────
  static const _goldChampagne = Color(0xFFFFF3C2);
  static const _goldLight = Color(0xFFFFE08A);
  static const _gold = Color(0xFFF0C24C);
  static const _goldDeep = Color(0xFFC58917);
  static const _goldShadow = Color(0xFF8C5F10);

  // ── 실버 팔레트(미획득) ─────────────────────────────────
  static const _silverLight = Color(0xFFECEEF2);
  static const _silver = Color(0xFFC6CBD4);
  static const _silverDeep = Color(0xFF98A0AC);

  @override
  Widget build(BuildContext context) {
    final accent = def.accent;

    // 프레임(꽃잎+링)은 골드/실버, 원반만 지역색 — 금메달에 보석을 박은 느낌.
    final Color frameLight = earned ? _goldChampagne : _silverLight;
    final Color frameMid = earned ? _gold : _silver;
    final Color frameDark = earned ? _goldDeep : _silverDeep;
    final Color petalLight = earned ? _goldLight : const Color(0xFFDFE2E8);
    final Color petalDark = earned ? _goldDeep : const Color(0xFFC2C7D1);

    final Color discLight = earned
        ? Color.lerp(accent, Colors.white, 0.55)!
        : _silverLight;
    final Color discBase = earned ? accent : _silver;
    final Color discDark = earned
        ? Color.lerp(accent, const Color(0xFF2B1230), 0.32)!
        : _silverDeep;

    // 작은 사이즈에선 디테일(반짝임)을 접어 노이즈를 막는다.
    final bool detailed = size >= 44;

    final ringSize = size * 0.80;
    final discSize = ringSize * 0.76;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 0) 후광 — 획득 메달 뒤로 은은히 번지는 금빛.
          if (earned)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withValues(alpha: 0.26),
                    _gold.withValues(alpha: 0.0),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),

          // 1) 로제트 꽃잎 링 — 골드 메탈 스캘럽 가장자리.
          CustomPaint(
            size: Size(size, size),
            painter: _PetalRingPainter(
              light: petalLight,
              dark: petalDark,
              petals: 10,
            ),
          ),

          // 2) 외곽 금속 링 — 스윕 그라데이션으로 도는 금속 광택.
          Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: const GradientRotation(-math.pi / 2 - 0.6),
                colors: [
                  frameLight,
                  frameMid,
                  frameDark,
                  frameMid,
                  frameLight,
                ],
                stops: const [0.0, 0.28, 0.55, 0.82, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: (earned ? _goldShadow : Colors.black)
                      .withValues(alpha: earned ? 0.35 : 0.16),
                  blurRadius: size * 0.10,
                  offset: Offset(0, size * 0.045),
                ),
              ],
            ),
          ),

          // 3) 안쪽 원반 — 지역색 보석. 좌상단 광원 라디얼로 입체감.
          Container(
            width: discSize,
            height: discSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.42),
                radius: 1.15,
                colors: [discLight, discBase, discDark],
                stops: const [0.0, 0.58, 1.0],
              ),
              border: Border.all(
                color: earned
                    ? _goldChampagne.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.75),
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
                color: discDark.withValues(alpha: earned ? 0.55 : 0.4),
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
