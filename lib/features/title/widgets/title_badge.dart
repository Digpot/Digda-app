import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../title_catalog.dart';

/// 칭호 메달 뱃지 — 이미지 파일 없이 코드로 그린다.
///
/// 금메달 + 에나멜 콘셉트: 골드 메탈릭 로제트 프레임 안에 지역색 딥 에나멜
/// 원반을 박고, 그 위에 골드 엠보스 문장(아이콘)을 새긴 구조.
/// 레이어(아래→위): 후광 · 로제트 꽃잎 링(외곽선 포함) · 금속 외곽 링(스윕) ·
/// 에나멜 원반(라디얼+비네트) · 이너 섀도 림 · 골드 엠보스 아이콘 ·
/// 유리 광 스트릭 · 다이아 플레어. 미획득은 실버 + 물음표.
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
  static const _goldChampagne = Color(0xFFFFF7D6);
  static const _goldHi = Color(0xFFFFE289);
  static const _gold = Color(0xFFEFC14E);
  static const _goldDeep = Color(0xFFA9741C);
  static const _goldDark = Color(0xFF7A5410);

  // ── 실버 팔레트(미획득) ─────────────────────────────────
  static const _silverLight = Color(0xFFEFF1F5);
  static const _silver = Color(0xFFC9CED7);
  static const _silverDeep = Color(0xFF9AA1AD);
  static const _silverDark = Color(0xFF7C8390);

  @override
  Widget build(BuildContext context) {
    final accent = def.accent;

    final Color frameLight = earned ? _goldChampagne : _silverLight;
    final Color frameMid = earned ? _gold : _silver;
    final Color frameDark = earned ? _goldDark : _silverDark;
    final Color petalLight = earned ? _goldHi : const Color(0xFFE2E5EB);
    final Color petalDark = earned ? _goldDeep : const Color(0xFFB4BAC5);

    // 에나멜 원반 — 지역색을 깊게 깔아 보석 같은 바탕을 만든다.
    final Color enamelLight = earned
        ? Color.lerp(accent, Colors.white, 0.16)!
        : _silver;
    final Color enamelBase = earned
        ? Color.lerp(accent, const Color(0xFF1D1030), 0.14)!
        : const Color(0xFFB9BFC9);
    final Color enamelDark = earned
        ? Color.lerp(accent, const Color(0xFF150B24), 0.46)!
        : _silverDeep;

    // 작은 사이즈에선 디테일(플레어·스트릭)을 접어 노이즈를 막는다.
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
                    _gold.withValues(alpha: 0.24),
                    _gold.withValues(alpha: 0.0),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),

          // 1) 로제트 꽃잎 링 — 스캘럽 가장자리 + 얇은 외곽선으로 각인.
          CustomPaint(
            size: Size(size, size),
            painter: _PetalRingPainter(
              light: petalLight,
              dark: petalDark,
              outline: frameDark.withValues(alpha: 0.45),
              petals: 12,
            ),
          ),

          // 2) 외곽 금속 링 — 깊은 명암의 스윕 그라데이션 + 가장자리 라인.
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
                stops: const [0.0, 0.30, 0.55, 0.80, 1.0],
              ),
              border: Border.all(
                color: frameDark.withValues(alpha: 0.35),
                width: math.max(0.8, size * 0.008),
              ),
              boxShadow: [
                BoxShadow(
                  color: (earned ? _goldDark : Colors.black)
                      .withValues(alpha: earned ? 0.35 : 0.16),
                  blurRadius: size * 0.10,
                  offset: Offset(0, size * 0.045),
                ),
              ],
            ),
          ),

          // 3) 에나멜 원반 — 좌상단 광원 라디얼 + 샴페인 골드 림.
          Container(
            width: discSize,
            height: discSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.42),
                radius: 1.15,
                colors: [enamelLight, enamelBase, enamelDark],
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: earned
                    ? _goldChampagne.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.85),
                width: math.max(1, size * 0.02),
              ),
            ),
          ),

          // 4) 비네트 + 이너 섀도 림 — 원반 가장자리를 눌러 움푹한 깊이감.
          Container(
            width: discSize * 0.96,
            height: discSize * 0.96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.20),
                ],
                stops: const [0.72, 1.0],
              ),
            ),
          ),

          // 5) 기요셰 텍스처 — 시계 다이얼처럼 새긴 동심원 각인.
          if (detailed)
            CustomPaint(
              size: Size(discSize, discSize),
              painter: _GuillochePainter(
                color: Colors.white.withValues(alpha: earned ? 0.07 : 0.10),
                rings: 7,
              ),
            ),

          // 6) 월계수 리스 — 원반 안쪽을 감싸는 금장 월계관(위가 트인 형태).
          if (detailed)
            CustomPaint(
              size: Size(discSize, discSize),
              painter: _LaurelWreathPainter(
                light: earned ? _goldHi : _silverLight,
                dark: earned ? _goldDeep : _silverDeep,
                outline: (earned ? _goldDark : _silverDark)
                    .withValues(alpha: 0.45),
              ),
            ),

          // 7) 리스 상단 트임에 얹는 작은 골드 플레어.
          if (detailed)
            Transform.translate(
              offset: Offset(0, -discSize * 0.375),
              child: CustomPaint(
                size: Size(discSize * 0.13, discSize * 0.13),
                painter: _DiamondFlarePainter(
                  color: earned ? _goldChampagne : _silverLight,
                  core: Colors.white,
                ),
              ),
            ),

          // 8) 골드 엠보스 문장 — 민팅 외곽선 + 그림자 판 + 골드 그라데이션.
          _EmbossedIcon(
            icon: earned ? def.icon : Icons.question_mark_rounded,
            size: discSize * (detailed ? 0.42 : 0.48),
            drop: size * 0.016,
            shadowColor: earned
                ? enamelDark.withValues(alpha: 0.75)
                : _silverDark.withValues(alpha: 0.6),
            outlineColor: (earned ? const Color(0xFF5A3D08) : _silverDark)
                .withValues(alpha: 0.55),
            gradient: earned
                ? const [Color(0xFFFFFBE8), Color(0xFFFFE28C), Color(0xFFE8B23E)]
                : const [Colors.white, Color(0xFFE7EAEF), Color(0xFFC2C8D2)],
          ),

          // 9) 유리 광 스트릭 — 메달 전체를 가로지르는 비스듬한 폴리시 광.
          if (detailed)
            ClipOval(
              child: SizedBox(
                width: ringSize,
                height: ringSize,
                child: Transform.translate(
                  offset: Offset(-ringSize * 0.10, -ringSize * 0.22),
                  child: Transform.rotate(
                    angle: -0.55,
                    child: Center(
                      child: Container(
                        width: ringSize * 1.5,
                        height: ringSize * 0.30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: earned ? 0.22 : 0.18),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            // 작은 사이즈 — 스트릭 대신 심플한 윗 글로스.
            Positioned(
              top: (size - discSize) / 2 + discSize * 0.08,
              child: Container(
                width: discSize * 0.62,
                height: discSize * 0.30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(size),
                ),
              ),
            ),

          // 10) 다이아 플레어 — 링 하이라이트 자리에 얹는 보석 반짝임.
          if (earned && detailed) ...[
            Positioned(
              right: size * 0.16,
              top: size * 0.13,
              child: CustomPaint(
                size: Size(size * 0.14, size * 0.14),
                painter: _DiamondFlarePainter(
                  color: Colors.white,
                  core: _goldChampagne,
                ),
              ),
            ),
            Positioned(
              left: size * 0.19,
              bottom: size * 0.18,
              child: CustomPaint(
                size: Size(size * 0.08, size * 0.08),
                painter: _DiamondFlarePainter(
                  color: Colors.white.withValues(alpha: 0.85),
                  core: _goldChampagne,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 골드 엠보스 아이콘 — 그림자 판 + 민팅(주조) 외곽선 + 골드 그라데이션
/// 본체로 금속에 새겨 찍은 문장 느낌을 낸다.
class _EmbossedIcon extends StatelessWidget {
  const _EmbossedIcon({
    required this.icon,
    required this.size,
    required this.drop,
    required this.shadowColor,
    required this.outlineColor,
    required this.gradient,
  });

  final IconData icon;
  final double size;
  final double drop;
  final Color shadowColor;
  final Color outlineColor;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final o = math.max(0.6, size * 0.035);
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, drop),
          child: Icon(icon, size: size, color: shadowColor),
        ),
        // 4방향 오프셋 사본으로 만드는 가짜 스트로크 — 글리프를 또렷하게 조각.
        for (final d in [
          Offset(-o, 0),
          Offset(o, 0),
          Offset(0, -o),
          Offset(0, o),
        ])
          Transform.translate(
            offset: d,
            child: Icon(icon, size: size, color: outlineColor),
          ),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Icon(icon, size: size, color: Colors.white),
        ),
      ],
    );
  }
}

/// 기요셰 — 에나멜 위에 시계 다이얼처럼 새긴 미세한 동심원 각인.
class _GuillochePainter extends CustomPainter {
  _GuillochePainter({required this.color, required this.rings});

  final Color color;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rMax = size.width / 2 * 0.86;
    final rMin = size.width / 2 * 0.24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, size.width * 0.008)
      ..color = color;
    for (var i = 0; i < rings; i++) {
      final r = rMin + (rMax - rMin) * (i / (rings - 1));
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuillochePainter old) =>
      old.color != color || old.rings != rings;
}

/// 월계수 리스 — 좌우 대칭 두 가지가 원반 안쪽 가장자리를 감싸 올라가는
/// 금장 월계관. 위쪽은 트여 있고 아래 가운데서 만난다.
class _LaurelWreathPainter extends CustomPainter {
  _LaurelWreathPainter({
    required this.light,
    required this.dark,
    required this.outline,
  });

  final Color light;
  final Color dark;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2;
    final branchR = R * 0.72;

    // 리스 전체에 하나의 광원(위) — 잎들이 한 몸처럼 셰이딩되도록.
    // 아래쪽도 충분히 밝게 유지해 에나멜/비네트에 묻히지 않도록 한다.
    final fill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(c.dx, c.dy - R),
        Offset(c.dx, c.dy + R),
        [light, Color.lerp(light, dark, 0.55)!],
      );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, R * 0.02)
      ..color = outline;

    final leaves = Path();
    const perBranch = 7;
    // 가지 각도 범위: 아래 중앙(π/2) 근처에서 시작해 위쪽 트임 직전까지.
    const startOff = 0.30; // 아래 중앙에서 벌어지는 시작 각
    const endOff = 0.80; // 위 트임을 남기는 끝 각 (−π/2 로부터)
    for (final side in const [1, -1]) {
      for (var i = 0; i < perBranch; i++) {
        final t = i / (perBranch - 1);
        // side=1: 오른쪽 가지(π/2−…→−π/2+…), side=−1: 왼쪽 미러.
        final theta = side == 1
            ? (math.pi / 2 - startOff) - t * (math.pi - startOff - endOff)
            : (math.pi / 2 + startOff) + t * (math.pi - startOff - endOff);
        // 잎 쌍 느낌 — 안/밖으로 살짝 교차 배치.
        final rr = branchR + (i.isEven ? R * 0.07 : -R * 0.05);
        final p = Offset(
          c.dx + rr * math.cos(theta),
          c.dy + rr * math.sin(theta),
        );
        // 성장 방향(가지를 따라 위로) + 바깥쪽 기울임.
        final growth = side == 1 ? theta - math.pi / 2 : theta + math.pi / 2;
        final tilt = side * (0.32 + (i.isEven ? 0.10 : -0.08));
        final len = R * (0.36 - 0.11 * t); // 위로 갈수록 잎이 작아진다.
        leaves.addPath(
          _leaf(len, len * 0.50).transform(
            (Matrix4.translationValues(p.dx, p.dy, 0)
                  ..rotateZ(growth + math.pi / 2 + tilt))
                .storage,
          ),
          Offset.zero,
        );
      }
    }
    canvas.drawPath(leaves, fill);
    canvas.drawPath(leaves, stroke);

    // 아래 중앙 — 가지가 만나는 자리의 베리 두 알.
    final berry = Paint()..color = Color.lerp(light, dark, 0.35)!;
    canvas.drawCircle(
        Offset(c.dx - R * 0.08, c.dy + branchR * 1.02), R * 0.055, berry);
    canvas.drawCircle(
        Offset(c.dx + R * 0.08, c.dy + branchR * 1.02), R * 0.055, berry);
    canvas.drawCircle(
        Offset(c.dx - R * 0.08, c.dy + branchR * 1.02), R * 0.055, stroke);
    canvas.drawCircle(
        Offset(c.dx + R * 0.08, c.dy + branchR * 1.02), R * 0.055, stroke);
  }

  /// 원점 중심 세로 방향 잎사귀(티어드롭) — 위가 뾰족, 아래가 둥근 형태.
  Path _leaf(double len, double width) {
    final h = len / 2;
    final w = width / 2;
    return Path()
      ..moveTo(0, -h)
      ..quadraticBezierTo(w, -h * 0.25, 0, h)
      ..quadraticBezierTo(-w, -h * 0.25, 0, -h)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _LaurelWreathPainter old) =>
      old.light != light || old.dark != dark || old.outline != outline;
}

/// 메달 뒤 로제트 — [petals] 개의 둥근 꽃잎을 링 형태로 배치해 부드러운
/// 스캘럽 가장자리를 만든다. 위→아래 밝→진 셰이딩 + 얇은 외곽선.
class _PetalRingPainter extends CustomPainter {
  _PetalRingPainter({
    required this.light,
    required this.dark,
    required this.outline,
    required this.petals,
  });

  final Color light;
  final Color dark;
  final Color outline;
  final int petals;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final ringR = size.width * 0.37;
    final petalR = size.width * 0.13;

    // 전체 링에 하나의 광원(위) — 꽃잎들이 한 몸처럼 셰이딩되도록.
    final fill = Paint()
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
    canvas.drawPath(path, fill);

    // 스캘럽 실루엣 외곽선 — 프레임의 각인된 가장자리.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, size.width * 0.007)
      ..color = outline;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _PetalRingPainter old) =>
      old.light != light ||
      old.dark != dark ||
      old.outline != outline ||
      old.petals != petals;
}

/// 다이아 플레어 — 네 갈래로 뻗는 별빛. 아이콘 글리프 대신 직접 그려
/// 스티커 느낌 없이 또렷하게.
class _DiamondFlarePainter extends CustomPainter {
  _DiamondFlarePainter({required this.color, required this.core});

  final Color color;
  final Color core;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final pinch = r * 0.18;

    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + pinch, c.dy - pinch, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + pinch, c.dy + pinch, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - pinch, c.dy + pinch, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - pinch, c.dy - pinch, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(c, r * 0.14, Paint()..color = core);
  }

  @override
  bool shouldRepaint(covariant _DiamondFlarePainter old) =>
      old.color != color || old.core != core;
}
