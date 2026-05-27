/// 캐릭터(모찌) 도메인 DTO. 서버 응답을 그대로 매핑하는 thin layer.
///
/// 서버가 곡선/도달 여부의 진실 출처라, 클라는 임계치를 직접 계산하지 않는다
/// (expForNextLevel, unlocked, owned 등은 응답값을 그대로 사용).

enum CharacterStage {
  egg,
  sprout,
  bloom,
  blossom,
  glow;

  static CharacterStage fromKey(String key) {
    return CharacterStage.values.firstWhere(
      (s) => s.name == key.toLowerCase(),
      orElse: () => CharacterStage.egg,
    );
  }

  String get serverKey => name.toUpperCase();
}

enum CharacterColor {
  coral,
  mint,
  lavender,
  butter,
  midnight;

  static CharacterColor fromKey(String key) {
    return CharacterColor.values.firstWhere(
      (c) => c.name == key.toLowerCase(),
      orElse: () => CharacterColor.coral,
    );
  }

  String get serverKey => name.toUpperCase();
}

class CharacterState {
  CharacterState({
    required this.stage,
    required this.stageDisplayName,
    required this.color,
    required this.colorHex,
    required this.level,
    required this.exp,
    required this.expForNextLevel,
    required this.coin,
    required this.maxLevelReached,
  });

  final CharacterStage stage;
  final String stageDisplayName;
  final CharacterColor color;
  final String colorHex;
  final int level;
  final int exp;
  final int expForNextLevel;
  final int coin;
  final bool maxLevelReached;

  double get progress {
    if (maxLevelReached || expForNextLevel <= 0) return 1.0;
    return (exp / expForNextLevel).clamp(0.0, 1.0);
  }

  factory CharacterState.fromJson(Map<String, dynamic> json) {
    return CharacterState(
      stage: CharacterStage.fromKey(json['stage'] as String),
      stageDisplayName: json['stageDisplayName'] as String? ?? '',
      color: CharacterColor.fromKey(json['color'] as String),
      colorHex: json['colorHex'] as String? ?? '#FF6B6B',
      level: (json['level'] as num).toInt(),
      exp: (json['exp'] as num).toInt(),
      expForNextLevel: (json['expForNextLevel'] as num).toInt(),
      coin: (json['coin'] as num).toInt(),
      maxLevelReached: json['maxLevelReached'] as bool? ?? false,
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
  });

  final CharacterState character;
  final int levelGained;
  final CharacterStage stageBefore;
  final CharacterStage stageAfter;
  final bool stageChanged;
  final int coinDelta;

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

class CharacterColorInfo {
  CharacterColorInfo({
    required this.color,
    required this.displayName,
    required this.hex,
    required this.cost,
    required this.owned,
    required this.isCurrent,
    required this.isDefault,
  });

  final CharacterColor color;
  final String displayName;
  final String hex;
  final int cost;
  final bool owned;
  final bool isCurrent;
  final bool isDefault;

  factory CharacterColorInfo.fromJson(Map<String, dynamic> json) {
    return CharacterColorInfo(
      color: CharacterColor.fromKey(json['color'] as String),
      displayName: json['displayName'] as String? ?? '',
      hex: json['hex'] as String? ?? '#FF6B6B',
      cost: (json['cost'] as num).toInt(),
      owned: json['owned'] as bool? ?? false,
      isCurrent: json['isCurrent'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class CharacterColorShop {
  CharacterColorShop({required this.coin, required this.items});

  final int coin;
  final List<CharacterColorInfo> items;

  factory CharacterColorShop.fromJson(Map<String, dynamic> json) {
    return CharacterColorShop(
      coin: (json['coin'] as num? ?? 0).toInt(),
      items: ((json['items'] as List?) ?? [])
          .map((e) => CharacterColorInfo.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
    );
  }
}
