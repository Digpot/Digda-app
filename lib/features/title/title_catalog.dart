import 'package:flutter/material.dart';

import '../../core/di.dart';
import 'models/title_models.dart';

/// 칭호 분류.
enum TitleCategory { region, diary, character }

extension TitleCategoryLabel on TitleCategory {
  String get label {
    switch (this) {
      case TitleCategory.region:
        return '지역 정복';
      case TitleCategory.diary:
        return '기록';
      case TitleCategory.character:
        return '모찌';
    }
  }
}

/// 칭호 1종의 렌더 메타. 서버 카탈로그([TitleCatalogItem])에서 빌드된다.
class TitleDef {
  const TitleDef({
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.accent,
    required this.icon,
  });

  final String code;
  final String name;
  final String description;
  final TitleCategory category;
  final Color accent;
  final IconData icon;
}

/// 칭호 레벨 마일스톤(모찌) — 캐릭터 화면이 레벨로 claim 할 때 사용.
class MochiTitleMilestone {
  const MochiTitleMilestone({required this.level, required this.code});
  final int level;
  final String code;
}

/// 칭호 카탈로그 — **서버가 단일 소스**(모찌 ShopItem 패턴).
/// 앱은 `GET /titles/catalog` 로 메타를 받아 빌드하고, 여기엔 `iconKey→IconData`
/// 매핑(폰트 글리프라 앱에 있을 수밖에 없음)과 hex→Color 변환만 남는다.
class TitleCatalog {
  TitleCatalog._();

  static List<TitleDef> _all = const [];
  static Map<String, TitleDef> _byCode = const {};
  static Map<String, String> _regionBucketToCode = const {};
  static List<MochiTitleMilestone> _mochiMilestones = const [];

  static bool _loaded = false;
  static Future<void>? _loading;

  /// 카탈로그를 1회 로드(메모이즈). 실패 시 비워두고 재시도 가능.
  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _doLoad();
  }

  static Future<void> _doLoad() async {
    try {
      final items = await Di.titleRepository.catalog();
      _apply(items);
      _loaded = true;
    } finally {
      _loading = null;
    }
  }

  static void _apply(List<TitleCatalogItem> items) {
    final sorted = [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final defs = <TitleDef>[];
    final byCode = <String, TitleDef>{};
    final regionMap = <String, String>{};
    final mochi = <MochiTitleMilestone>[];
    // 카테고리별 등장 순서 — 같은 iconKey 가 와도 칭호마다 다른 아이콘이 배정되도록.
    final catSeq = <TitleCategory, int>{};
    for (final it in sorted) {
      final cat = _categoryOf(it.category);
      final def = TitleDef(
        code: it.code,
        name: it.name,
        description: it.description,
        category: cat,
        accent: _colorFromHex(it.accentColor),
        icon: _iconFor(cat, it, catSeq),
      );
      defs.add(def);
      byCode[it.code] = def;
      if (it.conditionType == 'region' && it.conditionValue != null) {
        regionMap[it.conditionValue!] = it.code;
      } else if (it.conditionType == 'mochi_level') {
        final lv = int.tryParse(it.conditionValue ?? '');
        if (lv != null) mochi.add(MochiTitleMilestone(level: lv, code: it.code));
      }
    }
    _all = defs;
    _byCode = byCode;
    _regionBucketToCode = regionMap;
    _mochiMilestones = mochi;
  }

  static List<TitleDef> get all => _all;

  /// 지도 탭 버킷명 → 지역 칭호 code (서버 카탈로그에서 빌드).
  static Map<String, String> get regionBucketToCode => _regionBucketToCode;

  /// 모찌 레벨 마일스톤 목록(서버 카탈로그에서 빌드).
  static List<MochiTitleMilestone> get mochiMilestones => _mochiMilestones;

  static TitleDef? defOf(String code) => _byCode[code];

  static List<TitleDef> ofCategory(TitleCategory c) =>
      _all.where((t) => t.category == c).toList();

  // ── 렌더링 매핑(앱에 남는 부분) ──────────────────────────────

  static TitleCategory _categoryOf(String s) {
    switch (s) {
      case 'region':
        return TitleCategory.region;
      case 'diary':
        return TitleCategory.diary;
      case 'character':
        return TitleCategory.character;
      default:
        return TitleCategory.character;
    }
  }

  static Color _colorFromHex(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v != null ? Color(v) : const Color(0xFF999999);
  }

  /// 지역(색칠 키/버킷)별 특색 아이콘 — 지역 칭호가 전부 깃발로 똑같아 보이지 않도록.
  static const Map<String, IconData> _regionIcon = {
    // 광역시·특별시·특별자치시 — 도시별 특색.
    '서울': Icons.location_city_rounded,
    '부산': Icons.sailing_rounded,
    '대구': Icons.wb_sunny_rounded,
    '인천': Icons.flight_rounded,
    '광주': Icons.palette_rounded,
    '대전': Icons.science_rounded,
    '울산': Icons.factory_rounded,
    '세종': Icons.account_balance_rounded,
    '광역시': Icons.emoji_events_rounded, // 전국 대도시 석권(그랜드)
    // 도(道).
    '경기북부': Icons.castle_rounded,
    '경기남부': Icons.apartment_rounded,
    '강원': Icons.terrain_rounded,
    '충북': Icons.park_rounded,
    '충남': Icons.sailing_rounded,
    '전북': Icons.rice_bowl_rounded,
    '전남': Icons.set_meal_rounded,
    '경북': Icons.temple_buddhist_rounded,
    '경남': Icons.anchor_rounded,
    '제주': Icons.beach_access_rounded,
  };

  /// 기록(일기) 칭호 — 마일스톤이 올라갈수록 풍성해지는 순서.
  static const List<IconData> _diaryIcons = [
    Icons.edit_note_rounded,
    Icons.auto_stories_rounded,
    Icons.menu_book_rounded,
    Icons.local_library_rounded,
    Icons.collections_bookmark_rounded,
    Icons.history_edu_rounded,
    Icons.photo_album_rounded,
    Icons.favorite_rounded,
    Icons.local_florist_rounded,
    Icons.emoji_events_rounded,
  ];

  /// 모찌 칭호 — 알→성장→별→왕관 느낌의 순서.
  static const List<IconData> _mochiIcons = [
    Icons.egg_rounded,
    Icons.pets_rounded,
    Icons.spa_rounded,
    Icons.auto_awesome_rounded,
    Icons.star_rounded,
    Icons.bolt_rounded,
    Icons.local_fire_department_rounded,
    Icons.rocket_launch_rounded,
    Icons.military_tech_rounded,
    Icons.workspace_premium_rounded,
  ];

  /// 칭호 1종의 아이콘 — 지역은 버킷별 고정, 일기/모찌는 카테고리 풀에서 등장 순서대로
  /// 골라 칭호마다 독특하게. 알 수 없으면 서버 iconKey 폴백.
  static IconData _iconFor(
    TitleCategory cat,
    TitleCatalogItem it,
    Map<TitleCategory, int> seq,
  ) {
    if (cat == TitleCategory.region) {
      final byRegion = _regionIcon[it.conditionValue];
      if (byRegion != null) return byRegion;
    }
    final pool = cat == TitleCategory.diary
        ? _diaryIcons
        : cat == TitleCategory.character
            ? _mochiIcons
            : const <IconData>[];
    if (pool.isNotEmpty) {
      final idx = seq[cat] ?? 0;
      seq[cat] = idx + 1;
      return pool[idx % pool.length];
    }
    return _iconForKey(it.iconKey);
  }

  /// iconKey → IconData. 모찌의 assetKey→모양 매핑과 동일 성격(폰트 글리프).
  static IconData _iconForKey(String key) {
    switch (key) {
      case 'location_city':
        return Icons.location_city_rounded;
      case 'flag':
        return Icons.flag_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'auto_stories':
        return Icons.auto_stories_rounded;
      case 'collections_bookmark':
        return Icons.collections_bookmark_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}
