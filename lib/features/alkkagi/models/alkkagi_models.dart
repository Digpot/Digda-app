/// 알까기(Alkkagi) 도메인 DTO — 서버 인메모리 대국의 스냅샷을 그대로 매핑.
///
/// 서버가 돌 상태/턴/승패의 진실 출처다. 물리 시뮬레이션은 튕긴 클라이언트가
/// 수행해 최종 돌 상태를 올리고, 모든 STOMP 이벤트에 전체 스냅샷([AlkkagiGame])이
/// 실려 오므로 클라이언트는 이벤트 하나로 화면 전체를 재동기화한다.
library;

enum AlkkagiStatus {
  waiting,
  active,
  finished,
  declined,
  canceled,
  expired;

  static AlkkagiStatus fromKey(String? key) {
    final lower = key?.toLowerCase();
    return AlkkagiStatus.values.firstWhere(
      (s) => s.name == lower,
      orElse: () => AlkkagiStatus.expired,
    );
  }
}

/// 돌 하나 — 좌표는 0..1 정규화(서버 기준: 초대자 진영이 아래).
class AlkkagiStone {
  AlkkagiStone({
    required this.id,
    required this.owner,
    required this.x,
    required this.y,
    required this.alive,
  });

  final int id;

  /// 1=초대자 돌, 2=수락자 돌.
  final int owner;
  final double x;
  final double y;
  final bool alive;

  AlkkagiStone copyWith({double? x, double? y, bool? alive}) => AlkkagiStone(
        id: id,
        owner: owner,
        x: x ?? this.x,
        y: y ?? this.y,
        alive: alive ?? this.alive,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'owner': owner, 'x': x, 'y': y, 'alive': alive};

  factory AlkkagiStone.fromJson(Map<String, dynamic> json) => AlkkagiStone(
        id: (json['id'] as num).toInt(),
        owner: (json['owner'] as num).toInt(),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        alive: json['alive'] as bool? ?? true,
      );
}

class AlkkagiGame {
  AlkkagiGame({
    required this.gameId,
    required this.groupRoomId,
    required this.status,
    required this.inviterUserId,
    required this.inviterName,
    required this.inviteeUserId,
    required this.inviteeName,
    required this.stoneCount,
    required this.stones,
    this.currentTurnUserId,
    this.turnDeadlineEpochMs,
    this.winnerUserId,
    this.finishReason,
  });

  static const int inviterSide = 1;
  static const int inviteeSide = 2;

  final int gameId;
  final int groupRoomId;
  final AlkkagiStatus status;

  /// 초대자 진영=아래(서버 좌표 기준), 선공.
  final String inviterUserId;
  final String inviterName;
  final String inviteeUserId;
  final String inviteeName;

  /// 한 쪽당 돌 개수(1~10) — 초대자가 초대 시 설정.
  final int stoneCount;
  final List<AlkkagiStone> stones;
  final String? currentTurnUserId;

  /// 현재 턴 마감 시각(epoch ms) — 30초 제한. ACTIVE 가 아니면 null.
  final int? turnDeadlineEpochMs;
  final String? winnerUserId;

  /// KNOCKOUT / FORFEIT (종료 시에만).
  final String? finishReason;

  int sideOf(String userId) =>
      userId == inviterUserId ? inviterSide : inviteeSide;

  String nameOf(String userId) =>
      userId == inviterUserId ? inviterName : inviteeName;

  bool isMyTurn(String userId) =>
      status == AlkkagiStatus.active && currentTurnUserId == userId;

  int aliveCountOf(int side) =>
      stones.where((s) => s.owner == side && s.alive).length;

  factory AlkkagiGame.fromJson(Map<String, dynamic> json) {
    return AlkkagiGame(
      gameId: (json['gameId'] as num).toInt(),
      groupRoomId: (json['groupRoomId'] as num).toInt(),
      status: AlkkagiStatus.fromKey(json['status'] as String?),
      inviterUserId: json['inviterUserId'].toString(),
      inviterName: json['inviterName'] as String? ?? '',
      inviteeUserId: json['inviteeUserId'].toString(),
      inviteeName: json['inviteeName'] as String? ?? '',
      stoneCount: (json['stoneCount'] as num?)?.toInt() ?? 5,
      stones: ((json['stones'] as List?) ?? const [])
          .map((s) => AlkkagiStone.fromJson((s as Map).cast<String, dynamic>()))
          .toList(),
      currentTurnUserId: json['currentTurnUserId']?.toString(),
      turnDeadlineEpochMs: (json['turnDeadlineEpochMs'] as num?)?.toInt(),
      winnerUserId: json['winnerUserId']?.toString(),
      finishReason: json['finishReason'] as String?,
    );
  }
}

/// `/topic/alkkagi/{gameId}` 이벤트 — [game] 스냅샷이 항상 포함된다.
/// MOVE/FINISHED 엔 상대 화면 재생용 [flick] 이 실린다.
class AlkkagiEvent {
  AlkkagiEvent({required this.type, required this.game, this.flick});

  /// ACCEPTED / DECLINED / CANCELED / MOVE / FINISHED / EXPIRED
  final String type;
  final AlkkagiGame game;
  final AlkkagiFlick? flick;

  factory AlkkagiEvent.fromJson(Map<String, dynamic> json) {
    final flickJson = json['flick'];
    return AlkkagiEvent(
      type: json['type'] as String? ?? '',
      game:
          AlkkagiGame.fromJson((json['game'] as Map).cast<String, dynamic>()),
      flick: flickJson == null
          ? null
          : AlkkagiFlick.fromJson((flickJson as Map).cast<String, dynamic>()),
    );
  }
}

/// 마지막 플릭 — 튕긴 돌과 초기 속도(정규화 좌표계 단위/초).
class AlkkagiFlick {
  AlkkagiFlick({
    required this.byUserId,
    required this.stoneId,
    required this.vx,
    required this.vy,
  });

  final String byUserId;
  final int stoneId;
  final double vx;
  final double vy;

  factory AlkkagiFlick.fromJson(Map<String, dynamic> json) => AlkkagiFlick(
        byUserId: json['byUserId'].toString(),
        stoneId: (json['stoneId'] as num).toInt(),
        vx: (json['vx'] as num).toDouble(),
        vy: (json['vy'] as num).toDouble(),
      );
}
