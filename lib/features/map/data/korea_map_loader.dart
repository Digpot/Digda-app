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
          path: parseSvgPathData(r['d'] as String),
          labelCenter: Offset(
            (r['cx'] as num).toDouble(),
            (r['cy'] as num).toDouble(),
          ),
        ),
      );
    }
    return KoreaMapData(width: w, height: h, regions: regions);
  }
}
