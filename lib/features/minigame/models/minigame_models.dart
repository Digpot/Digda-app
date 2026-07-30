/// 미니게임(캐치마인드·탭배틀) 도메인 DTO — 서버 인메모리 게임 스냅샷 매핑.
/// 오목([OmokGame])과 같은 원칙: 서버가 진실 출처, 이벤트마다 스냅샷 재동기화.
library;

// ── 공통: 게임 초대/진행 목록 ────────────────────────────────

/// GET /games/invites 의 항목 — 게임 메뉴의 "초대받은/진행 중" 카드.
class GameInviteItem {
  GameInviteItem({
    required this.gameType,
    required this.gameId,
    required this.groupRoomId,
    required this.title,
    required this.createdAtEpochMs,
    required this.playerCount,
  });

  /// OMOK / CATCHMIND / TAP_BATTLE
  final String gameType;
  final int gameId;
  final int groupRoomId;
  final String title;
  final int createdAtEpochMs;
  final int playerCount;

  factory GameInviteItem.fromJson(Map<String, dynamic> json) => GameInviteItem(
        gameType: json['gameType'] as String? ?? '',
        gameId: (json['gameId'] as num).toInt(),
        groupRoomId: (json['groupRoomId'] as num).toInt(),
        title: json['title'] as String? ?? '',
        createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
        playerCount: (json['playerCount'] as num?)?.toInt() ?? 2,
      );
}

class GameInvitesSummary {
  GameInvitesSummary({required this.invites, required this.active});

  final List<GameInviteItem> invites;
  final List<GameInviteItem> active;

  factory GameInvitesSummary.fromJson(Map<String, dynamic> json) =>
      GameInvitesSummary(
        invites: ((json['invites'] as List?) ?? const [])
            .map((e) =>
                GameInviteItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        active: ((json['active'] as List?) ?? const [])
            .map((e) =>
                GameInviteItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

// ── 캐치마인드 ───────────────────────────────────────────────

enum CatchmindStatus {
  waiting,
  active,
  finished,
  canceled,
  expired;

  static CatchmindStatus fromKey(String? key) {
    final lower = key?.toLowerCase();
    return CatchmindStatus.values.firstWhere(
      (s) => s.name == lower,
      orElse: () => CatchmindStatus.expired,
    );
  }
}

class CatchmindPlayer {
  CatchmindPlayer({
    required this.userId,
    required this.name,
    required this.joined,
    required this.declined,
    required this.score,
    required this.isHost,
    this.forfeited = false,
  });

  final String userId;
  final String name;
  final bool joined;
  final bool declined;
  final int score;
  final bool isHost;

  /// 진행 중 기권 — 점수는 남지만 출제 순서/추리에서 빠진다.
  final bool forfeited;

  factory CatchmindPlayer.fromJson(Map<String, dynamic> json) =>
      CatchmindPlayer(
        userId: json['userId'].toString(),
        name: json['name'] as String? ?? '',
        joined: json['joined'] as bool? ?? false,
        declined: json['declined'] as bool? ?? false,
        score: (json['score'] as num?)?.toInt() ?? 0,
        isHost: json['isHost'] as bool? ?? false,
        forfeited: json['forfeited'] as bool? ?? false,
      );
}

/// 캔버스 한 획(또는 이어지는 조각) — 좌표는 0..1 정규화.
class CatchmindStroke {
  CatchmindStroke({
    required this.strokeId,
    required this.color,
    required this.width,
    required this.points,
    required this.done,
  });

  final int strokeId;
  final String color;
  final double width;
  final List<List<double>> points;
  final bool done;

  Map<String, dynamic> toJson() => {
        'strokeId': strokeId,
        'color': color,
        'width': width,
        'points': points,
        'done': done,
      };

  factory CatchmindStroke.fromJson(Map<String, dynamic> json) =>
      CatchmindStroke(
        strokeId: (json['strokeId'] as num).toInt(),
        color: json['color'] as String? ?? '#2B2B2B',
        width: (json['width'] as num?)?.toDouble() ?? 4.0,
        points: ((json['points'] as List?) ?? const [])
            .map((p) =>
                ((p as List).map((v) => (v as num).toDouble())).toList())
            .toList(),
        done: json['done'] as bool? ?? true,
      );
}

class CatchmindGame {
  CatchmindGame({
    required this.gameId,
    required this.groupRoomId,
    required this.status,
    required this.hostUserId,
    required this.hostName,
    required this.players,
    required this.roundIndex,
    required this.totalRounds,
    this.roundSeconds = 90,
    this.drawerUserId,
    this.word,
    this.wordLength,
    this.roundDeadlineEpochMs,
    this.strokes = const [],
  });

  final int gameId;
  final int groupRoomId;
  final CatchmindStatus status;
  final String hostUserId;
  final String hostName;
  final List<CatchmindPlayer> players;
  final int roundIndex;
  final int totalRounds;

  /// 방장이 고른 라운드 제한시간(초) — 로비 표시용.
  final int roundSeconds;
  final String? drawerUserId;

  /// 내가 출제자일 때만 서버가 채워준다.
  final String? word;
  final int? wordLength;
  final int? roundDeadlineEpochMs;
  final List<CatchmindStroke> strokes;

  List<CatchmindPlayer> get joinedPlayers =>
      players.where((p) => p.joined).toList();

  /// 아직 게임에 남아 있는 참가자 — 기권자 제외.
  List<CatchmindPlayer> get activePlayers =>
      players.where((p) => p.joined && !p.forfeited).toList();

  bool hasForfeited(String userId) => playerOf(userId)?.forfeited ?? false;

  CatchmindPlayer? playerOf(String userId) {
    for (final p in players) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  bool isDrawer(String userId) => drawerUserId == userId;

  factory CatchmindGame.fromJson(Map<String, dynamic> json) => CatchmindGame(
        gameId: (json['gameId'] as num).toInt(),
        groupRoomId: (json['groupRoomId'] as num).toInt(),
        status: CatchmindStatus.fromKey(json['status'] as String?),
        hostUserId: json['hostUserId'].toString(),
        hostName: json['hostName'] as String? ?? '',
        players: ((json['players'] as List?) ?? const [])
            .map((e) =>
                CatchmindPlayer.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        roundIndex: (json['roundIndex'] as num?)?.toInt() ?? -1,
        totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 0,
        roundSeconds: (json['roundSeconds'] as num?)?.toInt() ?? 90,
        drawerUserId: json['drawerUserId']?.toString(),
        word: json['word'] as String?,
        wordLength: (json['wordLength'] as num?)?.toInt(),
        roundDeadlineEpochMs:
            (json['roundDeadlineEpochMs'] as num?)?.toInt(),
        strokes: ((json['strokes'] as List?) ?? const [])
            .map((e) =>
                CatchmindStroke.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// `/topic/catchmind/{gameId}` 이벤트.
class CatchmindEvent {
  CatchmindEvent({
    required this.type,
    this.game,
    this.stroke,
    this.userId,
    this.userName,
    this.text,
    this.answer,
  });

  /// PLAYER_JOINED / PLAYER_DECLINED / STARTED / ROUND_START / STROKE / CLEAR /
  /// GUESS / CORRECT / ROUND_TIMEOUT / ROUND_SKIPPED / FINISHED / CANCELED / EXPIRED
  final String type;
  final CatchmindGame? game;
  final CatchmindStroke? stroke;
  final String? userId;
  final String? userName;
  final String? text;
  final String? answer;

  factory CatchmindEvent.fromJson(Map<String, dynamic> json) => CatchmindEvent(
        type: json['type'] as String? ?? '',
        game: json['game'] == null
            ? null
            : CatchmindGame.fromJson(
                (json['game'] as Map).cast<String, dynamic>()),
        stroke: json['stroke'] == null
            ? null
            : CatchmindStroke.fromJson(
                (json['stroke'] as Map).cast<String, dynamic>()),
        userId: json['userId']?.toString(),
        userName: json['userName'] as String?,
        text: json['text'] as String?,
        answer: json['answer'] as String?,
      );
}

// ── 탭배틀 ───────────────────────────────────────────────────

enum TapBattleStatus {
  waiting,
  active,
  finished,
  declined,
  canceled,
  expired;

  static TapBattleStatus fromKey(String? key) {
    final lower = key?.toLowerCase();
    return TapBattleStatus.values.firstWhere(
      (s) => s.name == lower,
      orElse: () => TapBattleStatus.expired,
    );
  }
}

class TapBattleGame {
  TapBattleGame({
    required this.gameId,
    required this.groupRoomId,
    required this.status,
    required this.inviterUserId,
    required this.inviterName,
    required this.inviteeUserId,
    required this.inviteeName,
    required this.inviterTaps,
    required this.inviteeTaps,
    this.countdownStartEpochMs,
    this.battleEndEpochMs,
    this.winnerUserId,
  });

  final int gameId;
  final int groupRoomId;
  final TapBattleStatus status;
  final String inviterUserId;
  final String inviterName;
  final String inviteeUserId;
  final String inviteeName;
  final int inviterTaps;
  final int inviteeTaps;
  final int? countdownStartEpochMs;
  final int? battleEndEpochMs;
  final String? winnerUserId;

  bool isParticipant(String userId) =>
      userId == inviterUserId || userId == inviteeUserId;

  String nameOf(String userId) =>
      userId == inviterUserId ? inviterName : inviteeName;

  int tapsOf(String userId) =>
      userId == inviterUserId ? inviterTaps : inviteeTaps;

  String opponentIdOf(String userId) =>
      userId == inviterUserId ? inviteeUserId : inviterUserId;

  factory TapBattleGame.fromJson(Map<String, dynamic> json) => TapBattleGame(
        gameId: (json['gameId'] as num).toInt(),
        groupRoomId: (json['groupRoomId'] as num).toInt(),
        status: TapBattleStatus.fromKey(json['status'] as String?),
        inviterUserId: json['inviterUserId'].toString(),
        inviterName: json['inviterName'] as String? ?? '',
        inviteeUserId: json['inviteeUserId'].toString(),
        inviteeName: json['inviteeName'] as String? ?? '',
        inviterTaps: (json['inviterTaps'] as num?)?.toInt() ?? 0,
        inviteeTaps: (json['inviteeTaps'] as num?)?.toInt() ?? 0,
        countdownStartEpochMs:
            (json['countdownStartEpochMs'] as num?)?.toInt(),
        battleEndEpochMs: (json['battleEndEpochMs'] as num?)?.toInt(),
        winnerUserId: json['winnerUserId']?.toString(),
      );
}

// ── 끝말잇기 ─────────────────────────────────────────────────

enum WordChainStatus {
  waiting,
  active,
  finished,
  canceled,
  expired;

  static WordChainStatus fromKey(String? key) {
    final lower = key?.toLowerCase();
    return WordChainStatus.values.firstWhere(
      (s) => s.name == lower,
      orElse: () => WordChainStatus.expired,
    );
  }
}

class WordChainPlayer {
  WordChainPlayer({
    required this.userId,
    required this.name,
    required this.joined,
    required this.declined,
    required this.eliminated,
    required this.wordCount,
    required this.isHost,
  });

  final String userId;
  final String name;
  final bool joined;
  final bool declined;
  final bool eliminated;
  final int wordCount;
  final bool isHost;

  factory WordChainPlayer.fromJson(Map<String, dynamic> json) =>
      WordChainPlayer(
        userId: json['userId'].toString(),
        name: json['name'] as String? ?? '',
        joined: json['joined'] as bool? ?? false,
        declined: json['declined'] as bool? ?? false,
        eliminated: json['eliminated'] as bool? ?? false,
        wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
        isHost: json['isHost'] as bool? ?? false,
      );
}

/// 단어 기록 한 줄 — [userId] null 이면 서버 제시 시작 단어.
class WordChainEntry {
  WordChainEntry({this.userId, this.userName, required this.word});

  final String? userId;
  final String? userName;
  final String word;

  factory WordChainEntry.fromJson(Map<String, dynamic> json) => WordChainEntry(
        userId: json['userId']?.toString(),
        userName: json['userName'] as String?,
        word: json['word'] as String? ?? '',
      );
}

class WordChainGame {
  WordChainGame({
    required this.gameId,
    required this.groupRoomId,
    required this.status,
    required this.hostUserId,
    required this.hostName,
    required this.players,
    required this.entries,
    this.currentTurnUserId,
    this.turnDeadlineEpochMs,
    this.turnSeconds = 15,
    this.winnerUserId,
  });

  final int gameId;
  final int groupRoomId;
  final WordChainStatus status;
  final String hostUserId;
  final String hostName;
  final List<WordChainPlayer> players;
  final List<WordChainEntry> entries;
  final String? currentTurnUserId;
  final int? turnDeadlineEpochMs;
  final int turnSeconds;
  final String? winnerUserId;

  List<WordChainPlayer> get joinedPlayers =>
      players.where((p) => p.joined).toList();

  WordChainPlayer? playerOf(String userId) {
    for (final p in players) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  bool isMyTurn(String userId) =>
      status == WordChainStatus.active && currentTurnUserId == userId;

  String? get lastWord => entries.isEmpty ? null : entries.last.word;

  factory WordChainGame.fromJson(Map<String, dynamic> json) => WordChainGame(
        gameId: (json['gameId'] as num).toInt(),
        groupRoomId: (json['groupRoomId'] as num).toInt(),
        status: WordChainStatus.fromKey(json['status'] as String?),
        hostUserId: json['hostUserId'].toString(),
        hostName: json['hostName'] as String? ?? '',
        players: ((json['players'] as List?) ?? const [])
            .map((e) =>
                WordChainPlayer.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        entries: ((json['entries'] as List?) ?? const [])
            .map((e) =>
                WordChainEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        currentTurnUserId: json['currentTurnUserId']?.toString(),
        turnDeadlineEpochMs: (json['turnDeadlineEpochMs'] as num?)?.toInt(),
        turnSeconds: (json['turnSeconds'] as num?)?.toInt() ?? 15,
        winnerUserId: json['winnerUserId']?.toString(),
      );
}

/// `/topic/wordchain/{gameId}` 이벤트.
class WordChainEvent {
  WordChainEvent({
    required this.type,
    this.game,
    this.userId,
    this.userName,
    this.word,
    this.reason,
  });

  /// PLAYER_JOINED / PLAYER_DECLINED / STARTED / WORD / REJECTED /
  /// TIMEOUT / FINISHED / CANCELED / EXPIRED
  final String type;
  final WordChainGame? game;
  final String? userId;
  final String? userName;
  final String? word;

  /// REJECTED 사유 — FORMAT / USED / RULE.
  final String? reason;

  factory WordChainEvent.fromJson(Map<String, dynamic> json) => WordChainEvent(
        type: json['type'] as String? ?? '',
        game: json['game'] == null
            ? null
            : WordChainGame.fromJson(
                (json['game'] as Map).cast<String, dynamic>()),
        userId: json['userId']?.toString(),
        userName: json['userName'] as String?,
        word: json['word'] as String?,
        reason: json['reason'] as String?,
      );
}

/// `/topic/tapbattle/{gameId}` 이벤트 — 스냅샷이 항상 실린다.
class TapBattleEvent {
  TapBattleEvent({required this.type, required this.game});

  /// ACCEPTED / DECLINED / CANCELED / SCORE / FINISHED / EXPIRED
  final String type;
  final TapBattleGame game;

  factory TapBattleEvent.fromJson(Map<String, dynamic> json) => TapBattleEvent(
        type: json['type'] as String? ?? '',
        game: TapBattleGame.fromJson(
            (json['game'] as Map).cast<String, dynamic>()),
      );
}
