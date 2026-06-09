import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 디그팟 시그니처 지도 — 시군구 한 조각.
///
/// 좌표/패스는 `assets/map/korea_sigungu.json` (변환기 tool/mapgen/convert.mjs 산출)에
/// viewBox(width×height) 기준으로 이미 베이크돼 있다.
class MapRegion {
  MapRegion({
    required this.code,
    required this.name,
    required this.sido,
    required this.group,
    required this.metro,
    required this.key,
    required this.path,
    required this.labelCenter,
  });

  /// 원본 시군구 코드(5자리).
  final String code;

  /// 조각 표시명 (예: "남원시", "강남구", "창원시성산구").
  final String name;

  /// 시도 단축명 (예: "서울", "경기", "전북").
  final String sido;

  /// 권역 (수도권/강원/충청/전라/경상/제주).
  final String group;

  /// 광역시·세종 여부. true 면 색칠 단위가 시도 전체(임계 10), false 면 시·군(임계 1).
  final bool metro;

  /// 색칠 키. 같은 key 를 가진 조각들은 한 덩어리로 같은 색.
  /// 광역시=시도명("인천"), 도=시·군명("남원시"; 통합시는 母市 "창원시").
  final String key;

  /// 화면 좌표 path (이미 viewBox 기준으로 투영됨).
  final Path path;

  /// 라벨 중심(최대 링 무게중심).
  final Offset labelCenter;
}

/// 시그니처 지도 전체 데이터.
class KoreaMapData {
  KoreaMapData({
    required this.width,
    required this.height,
    required this.regions,
  });

  final double width;
  final double height;
  final List<MapRegion> regions;

  /// 색칠 키 → 그 키에 속한 조각들.
  late final Map<String, List<MapRegion>> byKey = () {
    final m = <String, List<MapRegion>>{};
    for (final r in regions) {
      (m[r.key] ??= []).add(r);
    }
    return m;
  }();

  /// 전 조각을 합친 단일 path — ambient 그림자/측벽을 250회가 아니라 1회로 그려 성능 확보.
  late final Path combinedPath = () {
    final p = Path();
    for (final r in regions) {
      p.addPath(r.path, Offset.zero);
    }
    return p;
  }();

  /// 색칠 키 → 라벨 표시 위치(그 키의 최대 면적 조각 중심).
  late final Map<String, Offset> keyCenter = () {
    final m = <String, Offset>{};
    byKey.forEach((key, list) {
      MapRegion best = list.first;
      double bestArea = -1;
      for (final r in list) {
        final b = r.path.getBounds();
        final a = b.width * b.height;
        if (a > bestArea) {
          bestArea = a;
          best = r;
        }
      }
      m[key] = best.labelCenter;
    });
    return m;
  }();

  /// 색칠 키 → 표시명.
  late final Map<String, String> keyLabel = {
    for (final e in byKey.entries)
      e.key: (e.value.first.metro ? e.value.first.sido : e.key),
  };

  /// 색칠 키 → 광역시 여부.
  late final Map<String, bool> keyMetro = {
    for (final e in byKey.entries) e.key: e.value.first.metro,
  };

  /// 색칠 키 → 권역.
  late final Map<String, String> keyGroup = {
    for (final e in byKey.entries) e.key: e.value.first.group,
  };

  /// 색칠 키 → 포커스 탭 버킷(광역시 묶음 + 경기 남/북 분할 + 도 단위).
  late final Map<String, String> keyFocusGroup = {
    for (final e in byKey.entries) e.key: focusGroupOf(e.value.first),
  };

  /// 포커스 버킷(도) → 그 버킷에 속한 색칠 키들. 도 단위 색칠/진행률 집계에 사용.
  late final Map<String, List<String>> keysByFocusGroup = () {
    final m = <String, List<String>>{};
    keyFocusGroup.forEach((key, group) => (m[group] ??= []).add(key));
    return m;
  }();

  /// 경기 북부(북부청사 관할) 10개 시·군의 색칠키.
  /// 나머지 경기 조각은 모두 남부로 본다(김포 포함).
  static const Set<String> gyeonggiNorthKeys = {
    '고양시', '구리시', '남양주시', '동두천시', '양주시',
    '의정부시', '파주시', '포천시', '가평군', '연천군',
  };

  /// 탭 노출 순서(데이터에 존재하는 버킷만 노출). '전체'는 화면에서 앞에 붙인다.
  static const List<String> focusGroupOrder = [
    '광역시',
    '경기북부',
    '경기남부',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];

  /// 조각 → 포커스 탭 버킷. 광역시는 한 덩어리, 경기는 남/북, 그 외는 도(시도) 단위.
  static String focusGroupOf(MapRegion r) {
    if (r.metro) return '광역시';
    switch (r.sido) {
      case '경기':
        return gyeonggiNorthKeys.contains(r.key) ? '경기북부' : '경기남부';
      case '강원':
        return '강원';
      case '충북':
        return '충북';
      case '충남':
        return '충남';
      case '전북':
        return '전북';
      case '전남':
        return '전남';
      case '경북':
        return '경북';
      case '경남':
        return '경남';
      case '제주':
        return '제주';
    }
    return r.sido;
  }

  /// 색칠 키 → 라벨 폰트 크기. 이웃 라벨과의 최단 거리로 적응형 산출(handoff §4).
  /// 밀집 지역은 작게, 한산한 지역은 크게. 광역시는 최소 8.5 보장.
  late final Map<String, double> keyLabelSize = () {
    final keys = keyCenter.keys.toList();
    final m = <String, double>{};
    for (final k in keys) {
      final c = keyCenter[k]!;
      double minSq = double.infinity;
      for (final o in keys) {
        if (o == k) continue;
        final oc = keyCenter[o]!;
        final dx = c.dx - oc.dx, dy = c.dy - oc.dy;
        final d = dx * dx + dy * dy;
        if (d < minSq) minSq = d;
      }
      final minD = minSq == double.infinity ? 1e9 : math.sqrt(minSq);
      double fs;
      if (minD < 9) {
        fs = 6.0;
      } else if (minD < 13) {
        fs = 6.5;
      } else if (minD < 17) {
        fs = 7.5;
      } else if (minD < 23) {
        fs = 8.5;
      } else if (minD < 32) {
        fs = 9.5;
      } else {
        fs = 10.5;
      }
      if (keyMetro[k] == true && fs < 8.5) fs = 8.5;
      m[k] = fs;
    }
    return m;
  }();

  /// 색칠 키 → 대표 메타(metro/group/표시명).
  KoreaKeyMeta? metaOf(String key) {
    final list = byKey[key];
    if (list == null || list.isEmpty) return null;
    final head = list.first;
    return KoreaKeyMeta(
      key: key,
      metro: head.metro,
      group: head.group,
      // 표시명: 광역시는 "서울특별시" 대신 시도 단축명, 도 시군은 조각명을 다듬어 사용.
      label: head.metro ? head.sido : head.key,
    );
  }
}

class KoreaKeyMeta {
  KoreaKeyMeta({
    required this.key,
    required this.metro,
    required this.group,
    required this.label,
  });

  final String key;
  final bool metro;
  final String group;
  final String label;

  /// 색칠에 필요한 일기 수. 광역시 10, 시·군 1.
  int get threshold => metro ? 10 : 1;

  /// 주어진 일기 수로 색칠되는지.
  bool isColored(int count) => count >= threshold;
}

/// ── 디자인 토큰 (handoff §3) ────────────────────────────────────
class KoreaMapTokens {
  KoreaMapTokens._();

  // 빈 지도(웜 아이보리)
  static const List<Color> topFace = [
    Color(0xFFFDFAF4),
    Color(0xFFF6EEE1),
    Color(0xFFECE1CF),
  ];
  static const Color sideWall = Color(0xFFE6D8C4);
  static const Color grooveLo = Color(0xFFCBB89B); // shadow groove
  static const Color grooveHi = Color(0xCCFFFFFF); // highlight groove
  static const Color ambientShadow = Color(0x61B89274);
  static const List<Color> stageRadial = [
    Color(0xFFFAF5EC),
    Color(0xFFF1EADF),
    Color(0xFFE9E0D2),
  ];
  static const Color labelInk = Color(0xFF9C8C78);

  // 채색(코랄) — 임계 달성 시
  static const List<Color> coral = [Color(0xFFFF9A86), Color(0xFFFF6B6B)];
  static const Color coralInk = Color(0xFFC2412F);
  // 진행 중(광역시 1..9) 살짝 번지는 소프트 톤
  static const Color coralSoft = Color(0xFFFFE2DD);
  // 선택 강조 외곽
  static const Color selectedStroke = Color(0xFFFF6B6B);
}
