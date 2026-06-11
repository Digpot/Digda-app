/// 캐릭터(모찌) 도메인 DTO. 서버 응답을 그대로 매핑하는 thin layer.
///
/// 서버가 곡선/도달 여부의 진실 출처라, 클라는 임계치를 직접 계산하지 않는다
/// (expForNextLevel, unlocked, owned 등은 응답값을 그대로 사용).
///
/// 외형은 [CharacterState.equippedItems] 에 카테고리별로 들어있는 [EquippedItem]
/// 으로 결정된다. 색상은 더 이상 단일 필드가 아니라 SKIN 아이템이 갖는 [accentColor]
/// 가 배경 squircle 색이 된다.

enum MochiEmotion { idle, happy, excited, sleepy, proud }

enum CharacterStage {
  egg,
  sprout,
  bloom,
  blossom,
  glow,
  master;

  static CharacterStage fromKey(String key) {
    return CharacterStage.values.firstWhere(
      (s) => s.name == key.toLowerCase(),
      orElse: () => CharacterStage.egg,
    );
  }

  String get serverKey => name.toUpperCase();
}

/// 상점 아이템 분류. 서버 [ShopItemType] enum 키와 일치.
enum ShopItemType {
  skin,
  hat,
  glasses,
  hairpin,
  accessory,
  misc;

  static ShopItemType? tryParse(String? raw) {
    if (raw == null) return null;
    final lower = raw.toLowerCase();
    for (final t in values) {
      if (t.name == lower) return t;
    }
    return null;
  }

  String get serverKey => name.toUpperCase();

  String get displayName => switch (this) {
        ShopItemType.skin => '스킨',
        ShopItemType.hat => '모자',
        ShopItemType.glasses => '안경',
        ShopItemType.hairpin => '머리핀',
        ShopItemType.accessory => '액세서리',
        ShopItemType.misc => '잡화',
      };
}

/// 현재 장착 중인 아이템. 렌더러는 [layerOrder] 오름차순으로 그린다.
class EquippedItem {
  EquippedItem({
    required this.itemType,
    required this.itemKey,
    required this.displayName,
    required this.assetKey,
    this.accentColor,
    required this.layerOrder,
  });

  final ShopItemType itemType;
  final String itemKey;
  final String displayName;
  final String assetKey;
  final String? accentColor;
  final int layerOrder;

  factory EquippedItem.fromJson(Map<String, dynamic> json) {
    return EquippedItem(
      itemType: ShopItemType.tryParse(json['itemType'] as String?) ??
          ShopItemType.skin,
      itemKey: json['itemKey'] as String,
      displayName: json['displayName'] as String? ?? '',
      assetKey: json['assetKey'] as String? ?? '',
      accentColor: json['accentColor'] as String?,
      layerOrder: (json['layerOrder'] as num? ?? 0).toInt(),
    );
  }
}

class CharacterState {
  CharacterState({
    required this.stage,
    required this.stageDisplayName,
    required this.level,
    required this.exp,
    required this.expForNextLevel,
    required this.coin,
    required this.maxLevelReached,
    required this.dikoUnlocked,
    this.masterUnlocked = false,
    this.canChallengeMaster = false,
    required this.equippedItems,
  });

  final CharacterStage stage;
  final String stageDisplayName;
  final int level;
  final int exp;
  final int expForNextLevel;
  final int coin;
  final bool maxLevelReached;

  /// 조력자 디코 해금 여부. true 면 메인 화면에서 디코를 함께 렌더.
  final bool dikoUnlocked;

  /// 마스터 진화 시험(챔피언 챌린지) 통과 여부. true 면 stage 가 master.
  final bool masterUnlocked;

  /// 레벨 20 도달 — 챔피언 챌린지(진화 시험/코인 파밍) 응시 가능 여부.
  final bool canChallengeMaster;

  final List<EquippedItem> equippedItems;

  double get progress {
    if (maxLevelReached || expForNextLevel <= 0) return 1.0;
    return (exp / expForNextLevel).clamp(0.0, 1.0);
  }

  /// 현재 장착된 스킨의 hex. 없으면 기본 코랄.
  String get skinHex {
    final skin = equippedItems.firstWhere(
      (e) => e.itemType == ShopItemType.skin,
      orElse: () => EquippedItem(
        itemType: ShopItemType.skin,
        itemKey: 'skin_coral',
        displayName: '코랄',
        assetKey: 'skin/coral',
        accentColor: '#FF6B6B',
        layerOrder: 0,
      ),
    );
    return skin.accentColor ?? '#FF6B6B';
  }

  /// 현재 장착된 스킨 asset key. 렌더러가 패턴(판다 등) 식별에 사용.
  String get skinAssetKey {
    final skin = equippedItems.firstWhere(
      (e) => e.itemType == ShopItemType.skin,
      orElse: () => EquippedItem(
        itemType: ShopItemType.skin,
        itemKey: 'skin_coral',
        displayName: '코랄',
        assetKey: 'skin/coral',
        layerOrder: 0,
      ),
    );
    return skin.assetKey;
  }

  factory CharacterState.fromJson(Map<String, dynamic> json) {
    return CharacterState(
      stage: CharacterStage.fromKey(json['stage'] as String),
      stageDisplayName: json['stageDisplayName'] as String? ?? '',
      level: (json['level'] as num).toInt(),
      exp: (json['exp'] as num).toInt(),
      expForNextLevel: (json['expForNextLevel'] as num).toInt(),
      coin: (json['coin'] as num).toInt(),
      maxLevelReached: json['maxLevelReached'] as bool? ?? false,
      dikoUnlocked: json['dikoUnlocked'] as bool? ?? false,
      masterUnlocked: json['masterUnlocked'] as bool? ?? false,
      canChallengeMaster: json['canChallengeMaster'] as bool? ?? false,
      equippedItems: ((json['equippedItems'] as List?) ?? const [])
          .map((e) => EquippedItem.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
    );
  }
}

class MasterGameReward {
  MasterGameReward({
    required this.score,
    required this.coinReward,
    required this.tier,
    required this.character,
    this.evolvedToMaster = false,
  });

  final int score;
  final int coinReward;
  final String tier;
  final CharacterState character;

  /// 이번 도전(훌륭 이상)으로 마스터 진화가 일어났는지. 진화 연출 트리거용.
  final bool evolvedToMaster;

  factory MasterGameReward.fromJson(Map<String, dynamic> json) {
    return MasterGameReward(
      score: (json['score'] as num? ?? 0).toInt(),
      coinReward: (json['coinReward'] as num? ?? 0).toInt(),
      tier: json['tier'] as String? ?? '',
      character: CharacterState.fromJson(
        (json['character'] as Map).cast<String, dynamic>(),
      ),
      evolvedToMaster: json['evolvedToMaster'] as bool? ?? false,
    );
  }
}

class AddExpResult {
  AddExpResult({
    required this.character,
    required this.levelGained,
    required this.stageBefore,
    required this.stageAfter,
    required this.stageChanged,
    required this.coinDelta,
    required this.dikoJustUnlocked,
  });

  final CharacterState character;
  final int levelGained;
  final CharacterStage stageBefore;
  final CharacterStage stageAfter;
  final bool stageChanged;
  final int coinDelta;

  /// 이번 응답으로 디코가 처음 해금된 경우만 true. 컷씬을 1회 띄울 때 사용.
  final bool dikoJustUnlocked;

  factory AddExpResult.fromJson(Map<String, dynamic> json) {
    return AddExpResult(
      character: CharacterState.fromJson(
        (json['character'] as Map).cast<String, dynamic>(),
      ),
      levelGained: (json['levelGained'] as num? ?? 0).toInt(),
      stageBefore: CharacterStage.fromKey(json['stageBefore'] as String),
      stageAfter: CharacterStage.fromKey(json['stageAfter'] as String),
      stageChanged: json['stageChanged'] as bool? ?? false,
      coinDelta: (json['coinDelta'] as num? ?? 0).toInt(),
      dikoJustUnlocked: json['dikoJustUnlocked'] as bool? ?? false,
    );
  }
}

class CharacterStageInfo {
  CharacterStageInfo({
    required this.stage,
    required this.displayName,
    required this.requiredLevel,
    required this.unlocked,
  });

  final CharacterStage stage;
  final String displayName;
  final int requiredLevel;
  final bool unlocked;

  factory CharacterStageInfo.fromJson(Map<String, dynamic> json) {
    return CharacterStageInfo(
      stage: CharacterStage.fromKey(json['stage'] as String),
      displayName: json['displayName'] as String? ?? '',
      requiredLevel: (json['requiredLevel'] as num).toInt(),
      unlocked: json['unlocked'] as bool? ?? false,
    );
  }
}

class CharacterStageTree {
  CharacterStageTree({
    required this.currentStage,
    required this.currentLevel,
    required this.stages,
  });

  final CharacterStage currentStage;
  final int currentLevel;
  final List<CharacterStageInfo> stages;

  factory CharacterStageTree.fromJson(Map<String, dynamic> json) {
    return CharacterStageTree(
      currentStage: CharacterStage.fromKey(json['currentStage'] as String),
      currentLevel: (json['currentLevel'] as num).toInt(),
      stages: ((json['stages'] as List?) ?? [])
          .map((e) => CharacterStageInfo.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
    );
  }
}

// ───────────────────────────────────────────
//  Shop
// ───────────────────────────────────────────

class ShopItem {
  ShopItem({
    required this.itemKey,
    required this.itemType,
    required this.itemTypeDisplayName,
    required this.displayName,
    this.description,
    required this.cost,
    required this.assetKey,
    this.accentColor,
    required this.layerOrder,
    required this.sortOrder,
    required this.isDefault,
    required this.owned,
    required this.equipped,
  });

  final String itemKey;
  final ShopItemType itemType;
  final String itemTypeDisplayName;
  final String displayName;
  final String? description;
  final int cost;
  final String assetKey;
  final String? accentColor;
  final int layerOrder;
  final int sortOrder;
  final bool isDefault;
  final bool owned;
  final bool equipped;

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      itemKey: json['itemKey'] as String,
      itemType:
          ShopItemType.tryParse(json['itemType'] as String?) ?? ShopItemType.misc,
      itemTypeDisplayName: json['itemTypeDisplayName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      description: json['description'] as String?,
      cost: (json['cost'] as num? ?? 0).toInt(),
      assetKey: json['assetKey'] as String? ?? '',
      accentColor: json['accentColor'] as String?,
      layerOrder: (json['layerOrder'] as num? ?? 0).toInt(),
      sortOrder: (json['sortOrder'] as num? ?? 0).toInt(),
      isDefault: json['isDefault'] as bool? ?? false,
      owned: json['owned'] as bool? ?? false,
      equipped: json['equipped'] as bool? ?? false,
    );
  }

  /// 미리보기/장착 시 사용할 [EquippedItem] 으로 변환.
  EquippedItem toEquipped() => EquippedItem(
        itemType: itemType,
        itemKey: itemKey,
        displayName: displayName,
        assetKey: assetKey,
        accentColor: accentColor,
        layerOrder: layerOrder,
      );
}

class ShopSection {
  ShopSection({
    required this.itemType,
    required this.itemTypeDisplayName,
    required this.slotOrder,
    required this.items,
  });

  final ShopItemType itemType;
  final String itemTypeDisplayName;
  final int slotOrder;
  final List<ShopItem> items;

  factory ShopSection.fromJson(Map<String, dynamic> json) {
    return ShopSection(
      itemType:
          ShopItemType.tryParse(json['itemType'] as String?) ?? ShopItemType.misc,
      itemTypeDisplayName: json['itemTypeDisplayName'] as String? ?? '',
      slotOrder: (json['slotOrder'] as num? ?? 0).toInt(),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => ShopItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class CharacterShop {
  CharacterShop({
    required this.coin,
    required this.sections,
    this.adRewardRemaining,
  });

  final int coin;
  final List<ShopSection> sections;

  /// 오늘 광고 보상으로 더 받을 수 있는 남은 횟수. null 이면 서버가 안 내려준 것(=알 수 없음,
  /// 버튼은 활성 유지). 0 이면 한도 소진으로 버튼 비활성.
  final int? adRewardRemaining;

  factory CharacterShop.fromJson(Map<String, dynamic> json) {
    return CharacterShop(
      coin: (json['coin'] as num? ?? 0).toInt(),
      adRewardRemaining: (json['adRewardRemaining'] as num?)?.toInt(),
      sections: ((json['sections'] as List?) ?? const [])
          .map((e) => ShopSection.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

// ───────────────────────────────────────────
//  Quiz
// ───────────────────────────────────────────

enum QuizCategory {
  personal,
  memory,
  hobby,
  favorite,
  general;

  static QuizCategory fromKey(String key) {
    return QuizCategory.values.firstWhere(
      (c) => c.name == key.toLowerCase(),
      orElse: () => QuizCategory.general,
    );
  }

  String get serverKey => name.toUpperCase();

  String get displayName {
    switch (this) {
      case QuizCategory.personal:
        return '개인';
      case QuizCategory.memory:
        return '추억';
      case QuizCategory.hobby:
        return '취미';
      case QuizCategory.favorite:
        return '좋아하는 것';
      case QuizCategory.general:
        return '일반';
    }
  }
}

class CharacterQuiz {
  CharacterQuiz({
    required this.id,
    required this.groupRoomId,
    required this.category,
    required this.categoryDisplayName,
    required this.question,
    required this.options,
    required this.expMultiplier,
    required this.authorName,
    this.imageUrl,
    this.createdAt,
    this.remainingCount,
  });

  final int id;
  final int groupRoomId;
  final QuizCategory category;
  final String categoryDisplayName;
  final String question;
  final List<String> options;
  final int expMultiplier;
  final String authorName;

  /// 이미지 퀴즈일 때만 채워지는 원격 URL. null/공백이면 기존 텍스트 전용 퀴즈.
  final String? imageUrl;

  /// 서버 응답의 createdAt. 목록 화면이 날짜별 그룹화에 사용. 서버 이전 버전과
  /// 호환 위해 nullable 로 두고, 파싱 실패도 null 로 fallback.
  final DateTime? createdAt;

  /// 퀴즈 풀기(pickRandom) 응답에서만 채워지는 "지금 풀 수 있는 남은 퀴즈 수"
  /// (현재 문제 포함). 목록/생성 응답에서는 null.
  final int? remainingCount;

  factory CharacterQuiz.fromJson(Map<String, dynamic> json) {
    final rawImage = json['imageUrl'] as String?;
    final rawCreated = json['createdAt'] as String?;
    return CharacterQuiz(
      id: (json['id'] as num).toInt(),
      groupRoomId: (json['groupRoomId'] as num).toInt(),
      category: QuizCategory.fromKey(json['category'] as String),
      categoryDisplayName: json['categoryDisplayName'] as String? ?? '',
      question: json['question'] as String,
      options: ((json['options'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      expMultiplier: (json['expMultiplier'] as num? ?? 1).toInt(),
      authorName: json['authorName'] as String? ?? '',
      imageUrl: (rawImage == null || rawImage.trim().isEmpty) ? null : rawImage,
      createdAt: rawCreated == null ? null : DateTime.tryParse(rawCreated),
      remainingCount: (json['remainingCount'] as num?)?.toInt(),
    );
  }
}

class CharacterQuizListResult {
  CharacterQuizListResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalElements,
  });

  final List<CharacterQuiz> items;
  final int page;
  final int totalPages;
  final int totalElements;

  factory CharacterQuizListResult.fromJson(Map<String, dynamic> json) {
    return CharacterQuizListResult(
      items: ((json['items'] as List?) ?? [])
          .map((e) => CharacterQuiz.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
      page: (json['page'] as num? ?? 0).toInt(),
      totalPages: (json['totalPages'] as num? ?? 0).toInt(),
      totalElements: (json['totalElements'] as num? ?? 0).toInt(),
    );
  }
}

class QuizAttemptResult {
  QuizAttemptResult({
    required this.quizId,
    required this.correct,
    required this.correctIndex,
    required this.selectedIndex,
    required this.earnedExp,
    required this.earnedCoin,
    required this.character,
    required this.levelGained,
    required this.stageBefore,
    required this.stageAfter,
    required this.stageChanged,
    required this.dikoJustUnlocked,
  });

  final int quizId;
  final bool correct;
  final int correctIndex;
  final int selectedIndex;
  final int earnedExp;
  final int earnedCoin;
  final CharacterState character;
  final int levelGained;
  final CharacterStage stageBefore;
  final CharacterStage stageAfter;
  final bool stageChanged;
  final bool dikoJustUnlocked;

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    return QuizAttemptResult(
      quizId: (json['quizId'] as num).toInt(),
      correct: json['correct'] as bool? ?? false,
      correctIndex: (json['correctIndex'] as num).toInt(),
      selectedIndex: (json['selectedIndex'] as num).toInt(),
      earnedExp: (json['earnedExp'] as num? ?? 0).toInt(),
      earnedCoin: (json['earnedCoin'] as num? ?? 0).toInt(),
      character: CharacterState.fromJson(
        (json['character'] as Map).cast<String, dynamic>(),
      ),
      levelGained: (json['levelGained'] as num? ?? 0).toInt(),
      stageBefore: CharacterStage.fromKey(json['stageBefore'] as String),
      stageAfter: CharacterStage.fromKey(json['stageAfter'] as String),
      stageChanged: json['stageChanged'] as bool? ?? false,
      dikoJustUnlocked: json['dikoJustUnlocked'] as bool? ?? false,
    );
  }
}

/// 광고 시청 보상 결과. 적립량/오늘 남은 횟수는 서버가 결정해 내려준다.
class AdReward {
  const AdReward({required this.coinReward, required this.dailyRemaining});

  final int coinReward;
  final int dailyRemaining;

  factory AdReward.fromJson(Map<String, dynamic> json) {
    return AdReward(
      coinReward: (json['coinReward'] as num? ?? 0).toInt(),
      dailyRemaining: (json['dailyRemaining'] as num? ?? 0).toInt(),
    );
  }
}
