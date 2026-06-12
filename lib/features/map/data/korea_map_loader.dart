import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';

import 'korea_map_models.dart';

/// `assets/map/korea_sigungu.json` 을 한 번 로드/파싱해 [KoreaMapData] 로 캐시한다.
///
/// path 파싱(250개)은 비용이 있어 최초 1회만 수행하고 이후 같은 Future 를 재사용한다.
class KoreaMapLoader {
  KoreaMapLoader._();

  static const String _assetPath = 'assets/map/korea_sigungu.json';

  static Future<KoreaMapData>? _cache;

  /// 캐시 우선. 화면 진입 시 await.
  static Future<KoreaMapData> load() => _cache ??= _parse();

  static Future<KoreaMapData> _parse() async {
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final w = (json['W'] as num).toDouble();
    final h = (json['H'] as num).toDouble();
    // 남한 조각을 밴드만큼 아래로 내려 위쪽에 북한 공간을 만든다(좌표계 일관 유지).
    const shift = Offset(0, kNorthKoreaBand);
    final regions = <MapRegion>[];
    for (final e in (json['regions'] as List)) {
      final r = e as Map<String, dynamic>;
      regions.add(
        MapRegion(
          code: r['code'] as String,
          name: r['name'] as String,
          sido: r['sido'] as String,
          group: r['group'] as String,
          metro: r['metro'] as bool? ?? false,
          key: r['key'] as String,
          path: parseSvgPathData(r['d'] as String).shift(shift),
          labelCenter: Offset(
            (r['cx'] as num).toDouble(),
            (r['cy'] as num).toDouble() + kNorthKoreaBand,
          ),
        ),
      );
    }
    return KoreaMapData(
      width: w,
      height: h + kNorthKoreaBand,
      regions: regions,
      northKorea: _buildNorthKorea(),
    );
  }

  /// 북한 "업데이트 예정" 장식 레이어(하드코딩).
  ///
  /// 행정 경계 데이터가 없어 docs/north_korea.png 를 참고해 실루엣과 시·군 느낌의
  /// 분할선을 손으로 근사했다(정밀 좌표 아님). 색칠/칭호와 무관한 장식이라 근사로 충분.
  /// 좌표계: 남한과 같은 x[0..W], 위쪽 밴드 y[0..kNorthKoreaBand](아래=DMZ 접합).
  static NorthKoreaLayer _buildNorthKorea() {
    // 외곽 실루엣 — 북서(신의주)→북부 국경→북동(라선)→동해안 남하→DMZ→서해안.
    const outlinePts = <Offset>[
      Offset(150, 150), Offset(225, 120), Offset(300, 95), Offset(370, 78),
      Offset(430, 60), Offset(495, 40), Offset(560, 60), Offset(595, 100),
      Offset(560, 150), Offset(515, 215), Offset(470, 285), Offset(430, 350),
      Offset(395, 410), Offset(355, 470), Offset(310, 500), Offset(270, 492),
      Offset(255, 445), Offset(205, 458), Offset(180, 410), Offset(220, 372),
      Offset(165, 335), Offset(205, 295), Offset(150, 255), Offset(190, 210),
      Offset(140, 175),
    ];

    // 시·군 느낌의 분할선들 — 실루엣에 클립해 갈라보이게.
    const dividerPts = <List<Offset>>[
      [Offset(120, 150), Offset(260, 128), Offset(400, 108), Offset(560, 95)],
      [Offset(130, 225), Offset(280, 205), Offset(430, 190), Offset(560, 170)],
      [Offset(150, 300), Offset(300, 288), Offset(430, 275), Offset(540, 255)],
      [Offset(175, 375), Offset(300, 378), Offset(410, 368)],
      [Offset(370, 75), Offset(360, 180), Offset(370, 300), Offset(380, 430)],
      [Offset(235, 130), Offset(245, 255), Offset(265, 400)],
      [Offset(500, 90), Offset(475, 200), Offset(450, 330)],
      [Offset(180, 190), Offset(300, 170)],
      [Offset(420, 150), Offset(540, 130)],
      [Offset(300, 250), Offset(440, 235)],
      [Offset(250, 330), Offset(380, 320)],
      [Offset(330, 400), Offset(430, 390)],
      [Offset(210, 420), Offset(300, 470)],
      [Offset(150, 260), Offset(230, 250)],
    ];

    return NorthKoreaLayer(
      outline: _smoothClosed(outlinePts),
      dividers: [for (final line in dividerPts) _polyline(line)],
      labelCenter: const Offset(360, 250),
    );
  }

  /// 점들을 중점 경유 2차 베지어로 이어 매끄러운 닫힌 path(점토 실루엣) 생성.
  static Path _smoothClosed(List<Offset> pts) {
    final n = pts.length;
    Offset mid(Offset a, Offset b) =>
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final path = Path();
    final start = mid(pts[n - 1], pts[0]);
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final next = mid(pts[i], pts[(i + 1) % n]);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, next.dx, next.dy);
    }
    path.close();
    return path;
  }

  static Path _polyline(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }
}
