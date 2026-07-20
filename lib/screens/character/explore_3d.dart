import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

/// 탐험 화면(우주·해저·정글) 공용 3D 원근 시스템.
///
/// 화면은 여러 개의 깊이 평면으로 이루어진다:
/// - `z = 0` — 게임 평면. 탈것과 목적지가 사는 곳으로, 월드 좌표와 화면 좌표가
///   1:1 로 대응해 "가까이 가면 탐험" 판정이 눈에 보이는 것과 정확히 일치한다.
/// - `z > 0` — 배경 평면. 멀수록 느리게 흐르고(시차) 작아지며 대기 원근으로
///   흐려진다.
/// - `z < 0` — 전경 평면. 카메라보다 앞이라 더 빠르게 흐르고 크게 보인다.
///
/// 세 값(시차·크기·대기원근)이 한 초점거리에서 일관되게 나오므로, 날아다닐 때
/// 평면들이 서로 다른 속도로 미끄러지며 깊이가 실제로 읽힌다.
class Depth3D {
  Depth3D._();

  /// 카메라 초점거리(px). 클수록 원근이 완만해진다.
  static const double focal = 900;

  /// 깊이 [z] 평면의 투영 배율. z=0 이면 1.0(등배).
  static double scaleOf(double z) => focal / (focal + z);

  /// 깊이 [z] 에 있는 월드 좌표 [world] 의 화면 좌표.
  ///
  /// [cameraCenter] 는 카메라가 바라보는 월드 지점(보통 탈것 위치를 클램프한 값),
  /// [viewport] 는 화면 크기다.
  static Offset project({
    required Offset world,
    required double z,
    required Offset cameraCenter,
    required Size viewport,
  }) {
    final k = scaleOf(z);
    final center = Offset(viewport.width / 2, viewport.height / 2);
    return center + (world - cameraCenter) * k;
  }

  /// 대기 원근 — 멀수록 배경색에 잠기는 정도(0~0.75).
  static double hazeOf(double z) => (z / 2600).clamp(0.0, 0.75);

  /// 깊이에 따라 [color] 를 [fog] 쪽으로 섞어 거리감을 만든다.
  static Color fogged(Color color, Color fog, double z) =>
      Color.lerp(color, fog, hazeOf(z)) ?? color;
}

/// 깊이가 있는 배경 입자 하나(별·먼지·반딧불·플랑크톤).
class Depth3DMote {
  Depth3DMote({
    required this.x,
    required this.y,
    required this.z,
    required this.r,
    required this.phase,
    required this.twinkle,
  });

  /// 타일 내 0~1 비율 좌표. 타일 랩핑으로 무한히 이어진다.
  final double x;
  final double y;

  /// 깊이. 클수록 멀고 느리게 흐른다.
  final double z;

  /// 기준 반지름(z=0 기준). 실제 크기는 투영 배율이 곱해진다.
  final double r;

  final double phase;

  /// 밝기 흔들림 정도(0=고정, 1=크게 반짝임).
  final double twinkle;

  /// [minZ]~[maxZ] 사이 임의 깊이의 입자를 만든다.
  factory Depth3DMote.random(
    math.Random rand, {
    double minZ = 0,
    double maxZ = 2200,
    double minR = 0.8,
    double maxR = 2.6,
    double twinkle = 1,
  }) {
    return Depth3DMote(
      x: rand.nextDouble(),
      y: rand.nextDouble(),
      z: minZ + rand.nextDouble() * (maxZ - minZ),
      r: minR + rand.nextDouble() * (maxR - minR),
      phase: rand.nextDouble() * 2 * math.pi,
      twinkle: twinkle,
    );
  }
}

/// 깊이 입자 필드를 한 번에 그린다 — 평면마다 시차·크기·밝기가 달라진다.
///
/// [drift] 는 시간에 따라 위(음수)/아래(양수)로 흐르는 속도(px/s, z=0 기준)로,
/// 해저의 상승 기포나 정글의 떠다니는 포자에 쓴다.
void paintDepthMotes(
  Canvas canvas,
  Size size, {
  required List<Depth3DMote> motes,
  required Offset camera,
  required double t,
  required Color color,
  double drift = 0,
  double baseAlpha = 0.9,
  bool stroke = false,
}) {
  final tileW = size.width + 220;
  final tileH = size.height + 220;
  final paint = Paint()
    ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
    ..strokeWidth = 1.2;
  for (final m in motes) {
    final k = Depth3D.scaleOf(m.z);
    // 같은 카메라 이동이라도 깊이에 따라 다른 거리만큼 흐른다 = 원근 시차.
    final px = (m.x * tileW - camera.dx * k) % tileW - 110;
    final py = (m.y * tileH - camera.dy * k - t * drift * k) % tileH - 110;
    final tw = m.twinkle == 0
        ? 1.0
        : 0.35 + 0.65 * (0.5 + 0.5 * math.sin(m.phase + t * 2));
    // 멀수록 흐리게(대기 원근) + 작게.
    final alpha = baseAlpha * tw * (1 - Depth3D.hazeOf(m.z));
    paint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(px, py), math.max(0.4, m.r * k), paint);
  }
}

/// 원근으로 누운 바닥면 — 지평선에서 화면 앞쪽으로 퍼지는 격자.
///
/// 정글의 숲 바닥, 해저의 모래 바닥처럼 "누워 있는 평면"을 만들어 화면에
/// 깊이 축을 부여한다. [horizonY] 아래로만 그려진다.
class PerspectiveGroundPainter {
  PerspectiveGroundPainter({
    required this.horizonY,
    required this.near,
    required this.far,
    this.lineColor,
    this.rows = 9,
    this.cols = 14,
  });

  /// 지평선 화면 y.
  final double horizonY;

  /// 화면 맨 아래(가장 가까운 곳) 색.
  final Color near;

  /// 지평선 근처(가장 먼 곳) 색.
  final Color far;

  /// 격자선 색. null 이면 격자를 그리지 않는다.
  final Color? lineColor;

  final int rows;
  final int cols;

  /// [cameraX] 로 좌우 스크롤, [cameraY] 로 지평선을 위아래로 민다.
  void paint(Canvas canvas, Size size,
      {double cameraX = 0, double cameraY = 0}) {
    final hy = horizonY - cameraY;
    if (hy >= size.height) return;
    final groundRect = Rect.fromLTRB(0, hy, size.width, size.height);
    canvas.save();
    canvas.clipRect(groundRect);
    // 바닥 그라디언트 — 먼 곳은 안개에 잠기고 가까운 곳은 진하다.
    canvas.drawRect(
      groundRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [far, near],
        ).createShader(groundRect),
    );

    final line = lineColor;
    if (line != null) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = line;
      final depth = size.height - hy;
      // 가로선 — 지평선에 가까울수록 촘촘해져 원근을 만든다.
      for (var i = 1; i <= rows; i++) {
        final f = i / rows;
        final y = hy + depth * f * f; // 제곱 간격 = 원근 압축
        canvas.drawLine(Offset(0, y), Offset(size.width, y),
            paint..color = line.withValues(alpha: 0.10 + 0.10 * f));
      }
      // 세로선 — 지평선의 소실점 하나로 모인다.
      final vpx = size.width / 2 - cameraX * 0.25;
      for (var i = 0; i <= cols; i++) {
        final f = i / cols;
        final bottomX = (f - 0.5) * size.width * 3.2 + size.width / 2;
        canvas.drawLine(
          Offset(vpx, hy),
          Offset(bottomX, size.height),
          paint..color = line.withValues(alpha: 0.08),
        );
      }
    }
    canvas.restore();
  }
}

/// 화면 가장자리를 어둡게 눌러 렌즈 느낌을 주는 비네트.
void paintVignette(Canvas canvas, Size size, {double strength = 0.35}) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = math.max(size.width, size.height) * 0.78;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: strength),
        ],
        stops: const [0.55, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

/// 점 여러 개를 한 번에 찍는다(입자 수가 많을 때 drawCircle 반복보다 가볍다).
void paintPoints(Canvas canvas, List<Offset> points, Color color, double size) {
  if (points.isEmpty) return;
  canvas.drawPoints(
    PointMode.points,
    points,
    Paint()
      ..color = color
      ..strokeWidth = size
      ..strokeCap = StrokeCap.round,
  );
}
