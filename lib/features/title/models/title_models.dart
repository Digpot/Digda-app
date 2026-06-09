/// 서버에서 받은 "획득한 칭호" 1건. 표시 메타(이름/아이콘/색)는 [TitleCatalog] 가 code 로 매핑한다.
class EarnedTitle {
  const EarnedTitle({
    required this.code,
    this.groupRoomId,
    this.groupRoomName,
    required this.earnedAt,
  });

  final String code;

  /// 획득 그룹방 id(지역/캐릭터 칭호). 전역 칭호(일기 수)는 null.
  final int? groupRoomId;

  /// 획득 당시 그룹방 이름 스냅샷 — 그룹이 사라져도 "OO 그룹방에서 따셨습니다" 가 남는다.
  final String? groupRoomName;

  final DateTime earnedAt;

  factory EarnedTitle.fromJson(Map<String, dynamic> json) {
    return EarnedTitle(
      code: json['code'] as String,
      groupRoomId: (json['groupRoomId'] as num?)?.toInt(),
      groupRoomName: json['groupRoomName'] as String?,
      earnedAt: DateTime.tryParse(json['earnedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 서버 칭호 카탈로그 1종(원본). 표시 메타·획득 조건이 서버에서 내려온다.
/// 앱은 이걸 받아 [code]·[iconKey] 로 렌더한다(모찌 ShopItem 의 assetKey 와 동일 패턴).
class TitleCatalogItem {
  const TitleCatalogItem({
    required this.code,
    required this.name,
    required this.description,
    required this.category,
    required this.accentColor,
    required this.iconKey,
    required this.conditionType,
    this.conditionValue,
    this.sortOrder = 0,
  });

  final String code;
  final String name;
  final String description;
  final String category; // region / diary / character
  final String accentColor; // hex "#RRGGBB"
  final String iconKey;
  final String conditionType; // region / diary / mochi_level / manual
  final String? conditionValue; // 지역 버킷명 / 일기 임계 / 모찌 레벨
  final int sortOrder;

  factory TitleCatalogItem.fromJson(Map<String, dynamic> json) {
    return TitleCatalogItem(
      code: json['code'] as String,
      name: json['name'] as String? ?? json['code'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'manual',
      accentColor: json['accentColor'] as String? ?? '#999999',
      iconKey: json['iconKey'] as String? ?? 'default',
      conditionType: json['conditionType'] as String? ?? 'manual',
      conditionValue: json['conditionValue'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 그룹 모찌에 장착된 칭호. [code] 가 null 이면 미장착.
class EquippedTitle {
  const EquippedTitle({this.code, this.equippedBy});

  final String? code;
  final String? equippedBy;

  bool get hasTitle => code != null && code!.isNotEmpty;

  factory EquippedTitle.fromJson(Map<String, dynamic> json) {
    return EquippedTitle(
      code: json['code'] as String?,
      equippedBy: json['equippedBy'] as String?,
    );
  }
}

/// 앱이 판정한 "방금 획득한 칭호" — 서버 적재 요청용(멱등).
class TitleClaim {
  const TitleClaim({required this.code, this.groupRoomId});

  final String code;
  final int? groupRoomId;

  Map<String, dynamic> toJson() => {
        'code': code,
        if (groupRoomId != null) 'groupRoomId': groupRoomId,
      };
}
