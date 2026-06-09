import 'package:flutter/material.dart';

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

/// 칭호 1종의 표시 메타. 획득 여부는 서버([EarnedTitle])가 code 로 알려준다.
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

/// 앱이 소유하는 칭호 카탈로그(이름/설명/색/아이콘 + 획득 조건은 클라가 판정).
/// 서버는 code 만 저장하므로 여기 code 가 서버 diary_* 임계값·지도 버킷과 짝이 맞아야 한다.
class TitleCatalog {
  TitleCatalog._();

  /// 지도 탭 버킷명 → 지역 칭호 code. 지도에서 도를 정복하면 이 code 로 claim 한다.
  static const Map<String, String> regionBucketToCode = {
    '광역시': 'region_metro',
    '경기북부': 'region_gyeonggi_north',
    '경기남부': 'region_gyeonggi_south',
    '강원': 'region_gangwon',
    '충북': 'region_chungbuk',
    '충남': 'region_chungnam',
    '전북': 'region_jeonbuk',
    '전남': 'region_jeonnam',
    '경북': 'region_gyeongbuk',
    '경남': 'region_gyeongnam',
    '제주': 'region_jeju',
  };

  static const List<TitleDef> all = [
    // ── 지역 정복 ──────────────────────────────────────────────
    TitleDef(
      code: 'region_metro',
      name: '광역시 정복자',
      description: '전국 광역시를 모두 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFFFF8A5B),
      icon: Icons.location_city_rounded,
    ),
    TitleDef(
      code: 'region_gyeonggi_north',
      name: '경기북부 정복자',
      description: '경기 북부의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFFFF6B6B),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_gyeonggi_south',
      name: '경기남부 정복자',
      description: '경기 남부의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFFE8553D),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_gangwon',
      name: '강원 정복자',
      description: '강원의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFF5B9BF0),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_chungbuk',
      name: '충북 정복자',
      description: '충청북도의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFFF4B53C),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_chungnam',
      name: '충남 정복자',
      description: '충청남도의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFFE0962B),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_jeonbuk',
      name: '전북 정복자',
      description: '전라북도의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFF33C08A),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_jeonnam',
      name: '전남 정복자',
      description: '전라남도의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFF1FA876),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_gyeongbuk',
      name: '경북 정복자',
      description: '경상북도의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFFA98BF0),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_gyeongnam',
      name: '경남 정복자',
      description: '경상남도의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFF8B6BE0),
      icon: Icons.flag_rounded,
    ),
    TitleDef(
      code: 'region_jeju',
      name: '제주 정복자',
      description: '제주의 모든 시·군을 채웠어요',
      category: TitleCategory.region,
      accent: Color(0xFFF47BB4),
      icon: Icons.flag_rounded,
    ),
    // ── 기록(작성 일기 수) ─────────────────────────────────────
    TitleDef(
      code: 'diary_1',
      name: '첫 발자국',
      description: '첫 일기를 남겼어요',
      category: TitleCategory.diary,
      accent: Color(0xFF7DC4A5),
      icon: Icons.edit_note_rounded,
    ),
    TitleDef(
      code: 'diary_10',
      name: '기록의 시작',
      description: '일기 10개를 작성했어요',
      category: TitleCategory.diary,
      accent: Color(0xFF54B98A),
      icon: Icons.menu_book_rounded,
    ),
    TitleDef(
      code: 'diary_30',
      name: '꾸준한 기록가',
      description: '일기 30개를 작성했어요',
      category: TitleCategory.diary,
      accent: Color(0xFF3FA9D6),
      icon: Icons.auto_stories_rounded,
    ),
    TitleDef(
      code: 'diary_50',
      name: '기록 수집가',
      description: '일기 50개를 작성했어요',
      category: TitleCategory.diary,
      accent: Color(0xFF6E8BE0),
      icon: Icons.collections_bookmark_rounded,
    ),
    TitleDef(
      code: 'diary_100',
      name: '기록 마스터',
      description: '일기 100개를 작성했어요',
      category: TitleCategory.diary,
      accent: Color(0xFFC9A23B),
      icon: Icons.workspace_premium_rounded,
    ),
    // ── 모찌(레벨) ─────────────────────────────────────────────
    TitleDef(
      code: 'mochi_lv5',
      name: '모찌 새싹',
      description: '모찌를 Lv.5까지 키웠어요',
      category: TitleCategory.character,
      accent: Color(0xFFFFB0C0),
      icon: Icons.spa_rounded,
    ),
    TitleDef(
      code: 'mochi_lv10',
      name: '모찌 단짝',
      description: '모찌를 Lv.10까지 키웠어요',
      category: TitleCategory.character,
      accent: Color(0xFFF583A8),
      icon: Icons.favorite_rounded,
    ),
    TitleDef(
      code: 'mochi_lv15',
      name: '모찌 베테랑',
      description: '모찌를 Lv.15까지 키웠어요',
      category: TitleCategory.character,
      accent: Color(0xFFC78BE0),
      icon: Icons.military_tech_rounded,
    ),
    TitleDef(
      code: 'mochi_lv20',
      name: '모찌 마스터',
      description: '모찌를 만렙(Lv.20)까지 키웠어요',
      category: TitleCategory.character,
      accent: Color(0xFFB07BE0),
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  /// code → 정의 (없으면 알 수 없는 칭호용 폴백).
  static final Map<String, TitleDef> byCode = {
    for (final t in all) t.code: t,
  };

  static TitleDef? defOf(String code) => byCode[code];

  static List<TitleDef> ofCategory(TitleCategory c) =>
      all.where((t) => t.category == c).toList();
}
