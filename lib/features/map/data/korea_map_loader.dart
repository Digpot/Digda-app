import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';

import 'korea_map_models.dart';
import 'north_korea_geometry.dart';

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

  /// 북한 "업데이트 예정" 장식 레이어.
  ///
  /// 좌표는 tool/mapgen/nk_gen.mjs 가 남한 지도와 **동일한 투영**으로 실제
  /// 경위도(압록강·두만강 국경, 동·서해안)를 베이크한 생성 코드
  /// (north_korea_geometry.dart). 남쪽 변은 남한 데이터의 실제 북쪽 경계를
  /// 추출해 그 밑으로 파묻어 두므로 남한 위에 빈틈없이 붙는다.
  static NorthKoreaLayer _buildNorthKorea() {
    return NorthKoreaLayer(
      outline: _closedPoly(kNkOutline),
      dividers: [for (final line in kNkDividers) _polyline(line)],
      labelCenter: kNkLabelCenter,
    );
  }

  static Path _closedPoly(List<Offset> pts) => _polyline(pts)..close();

  static Path _polyline(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }
}
