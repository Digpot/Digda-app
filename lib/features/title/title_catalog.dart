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
    for (final it in sorted) {
      final def = TitleDef(
        code: it.code,
        name: it.name,
        description: it.description,
        category: _categoryOf(it.category),
        accent: _colorFromHex(it.accentColor),
        icon: _iconForKey(it.iconKey),
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
