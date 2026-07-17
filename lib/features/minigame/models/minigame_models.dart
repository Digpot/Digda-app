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
  });

  final String userId;
  final String name;
  final bool joined;
  final bool declined;
  final int score;
  final bool isHost;

  factory CatchmindPlayer.fromJson(Map<String, dynamic> json) =>
      CatchmindPlayer(
        userId: json['userId'].toString(),
        name: json['name'] as String? ?? '',
        joined: json['joined'] as bool? ?? false,
        declined: json['declined'] as bool? ?? false,
        score: (json['score'] as num?)?.toInt() ?? 0,
        isHost: json['isHost'] as bool? ?? false,
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

// ── 두더지 잡기 ───────────────────────────────────────────────

enum MoleBattleStatus {
  waiting,
  active,
  finished,
  declined,
  canceled,
  expired;

  static MoleBattleStatus fromKey(String? key) {
    final lower = key?.toLowerCase();
    return MoleBattleStatus.values.firstWhere(
      (s) => s.name == lower,
      orElse: () => MoleBattleStatus.expired,
    );
  }
}

class MoleBattleGame {
  MoleBattleGame({
    required this.gameId,
    required this.groupRoomId,
    required this.status,
    required this.inviterUserId,
    required this.inviterName,
    required this.inviteeUserId,
    required this.inviteeName,
    required this.inviterScore,
    required this.inviteeScore,
    this.spawnSeed,
    this.countdownStartEpochMs,
    this.battleEndEpochMs,
    this.winnerUserId,
  });

  final int gameId;
  final int groupRoomId;
  final MoleBattleStatus status;
  final String inviterUserId;
  final String inviterName;
  final String inviteeUserId;
  final String inviteeName;
  final int inviterScore;
  final int inviteeScore;

  /// 공유 스폰 시드 — 양쪽이 같은 두더지 순서를 재현한다.
  final int? spawnSeed;
  final int? countdownStartEpochMs;
  final int? battleEndEpochMs;
  final String? winnerUserId;

  bool isParticipant(String userId) =>
      userId == inviterUserId || userId == inviteeUserId;

  String nameOf(String userId) =>
      userId == inviterUserId ? inviterName : inviteeName;

  int scoreOf(String userId) =>
      userId == inviterUserId ? inviterScore : inviteeScore;

  String opponentIdOf(String userId) =>
      userId == inviterUserId ? inviteeUserId : inviterUserId;

  factory MoleBattleGame.fromJson(Map<String, dynamic> json) => MoleBattleGame(
        gameId: (json['gameId'] as num).toInt(),
        groupRoomId: (json['groupRoomId'] as num).toInt(),
        status: MoleBattleStatus.fromKey(json['status'] as String?),
        inviterUserId: json['inviterUserId'].toString(),
        inviterName: json['inviterName'] as String? ?? '',
        inviteeUserId: json['inviteeUserId'].toString(),
        inviteeName: json['inviteeName'] as String? ?? '',
        inviterScore: (json['inviterScore'] as num?)?.toInt() ?? 0,
        inviteeScore: (json['inviteeScore'] as num?)?.toInt() ?? 0,
        spawnSeed: (json['spawnSeed'] as num?)?.toInt(),
        countdownStartEpochMs:
            (json['countdownStartEpochMs'] as num?)?.toInt(),
        battleEndEpochMs: (json['battleEndEpochMs'] as num?)?.toInt(),
        winnerUserId: json['winnerUserId']?.toString(),
      );
}

/// `/topic/molebattle/{gameId}` 이벤트 — 스냅샷이 항상 실린다.
class MoleBattleEvent {
  MoleBattleEvent({required this.type, required this.game});

  /// ACCEPTED / DECLINED / CANCELED / SCORE / FINISHED / EXPIRED
  final String type;
  final MoleBattleGame game;

  factory MoleBattleEvent.fromJson(Map<String, dynamic> json) =>
      MoleBattleEvent(
        type: json['type'] as String? ?? '',
        game: MoleBattleGame.fromJson(
            (json['game'] as Map).cast<String, dynamic>()),
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
