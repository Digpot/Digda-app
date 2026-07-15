/// 오목(Omok) 도메인 DTO — 서버 인메모리 대국의 스냅샷을 그대로 매핑.
///
/// 서버가 보드/턴/승패의 진실 출처다. 모든 STOMP 이벤트에 전체 스냅샷([OmokGame])
/// 이 실려 오므로 클라이언트는 이벤트 하나로 화면 전체를 재동기화한다.
library;

enum OmokStatus {
  waiting,
  active,
  finished,
  declined,
  canceled,
  expired;

  static OmokStatus fromKey(String? key) {
    final lower = key?.toLowerCase();
    return OmokStatus.values.firstWhere(
      (s) => s.name == lower,
      orElse: () => OmokStatus.expired,
    );
  }
}

class OmokGame {
  OmokGame({
    required this.gameId,
    required this.groupRoomId,
    required this.status,
    required this.inviterUserId,
    required this.inviterName,
    required this.inviteeUserId,
    required this.inviteeName,
    required this.board,
    this.currentTurnUserId,
    this.winnerUserId,
    this.finishReason,
    this.winningLine = const [],
  });

  static const int boardSize = 15;
  static const int black = 1;
  static const int white = 2;

  final int gameId;
  final int groupRoomId;
  final OmokStatus status;

  /// 초대자 = 흑돌(선공), 수락자 = 백돌.
  final String inviterUserId;
  final String inviterName;
  final String inviteeUserId;
  final String inviteeName;

  /// board[y][x] — 0 빈칸 / 1 흑 / 2 백.
  final List<List<int>> board;
  final String? currentTurnUserId;
  final String? winnerUserId;

  /// FIVE_IN_ROW / FORFEIT / DRAW (종료 시에만).
  final String? finishReason;

  /// 승리 완성 라인 [x, y] 목록 — 하이라이트용.
  final List<List<int>> winningLine;

  int stoneOf(String userId) => userId == inviterUserId ? black : white;

  String nameOf(String userId) =>
      userId == inviterUserId ? inviterName : inviteeName;

  String opponentIdOf(String userId) =>
      userId == inviterUserId ? inviteeUserId : inviterUserId;

  bool isMyTurn(String userId) =>
      status == OmokStatus.active && currentTurnUserId == userId;

  factory OmokGame.fromJson(Map<String, dynamic> json) {
    return OmokGame(
      gameId: (json['gameId'] as num).toInt(),
      groupRoomId: (json['groupRoomId'] as num).toInt(),
      status: OmokStatus.fromKey(json['status'] as String?),
      inviterUserId: json['inviterUserId'].toString(),
      inviterName: json['inviterName'] as String? ?? '',
      inviteeUserId: json['inviteeUserId'].toString(),
      inviteeName: json['inviteeName'] as String? ?? '',
      board: ((json['board'] as List?) ?? const [])
          .map((row) =>
              ((row as List).map((c) => (c as num).toInt())).toList())
          .toList(),
      currentTurnUserId: json['currentTurnUserId']?.toString(),
      winnerUserId: json['winnerUserId']?.toString(),
      finishReason: json['finishReason'] as String?,
      winningLine: ((json['winningLine'] as List?) ?? const [])
          .map((cell) =>
              ((cell as List).map((v) => (v as num).toInt())).toList())
          .toList(),
    );
  }
}

/// `/topic/omok/{gameId}` 이벤트 — [game] 스냅샷이 항상 포함된다.
class OmokEvent {
  OmokEvent({required this.type, required this.game, this.lastMove});

  /// ACCEPTED / DECLINED / CANCELED / MOVE / FINISHED / EXPIRED
  final String type;
  final OmokGame game;

  /// MOVE 일 때 [x, y, stone].
  final List<int>? lastMove;

  factory OmokEvent.fromJson(Map<String, dynamic> json) {
    return OmokEvent(
      type: json['type'] as String? ?? '',
      game: OmokGame.fromJson((json['game'] as Map).cast<String, dynamic>()),
      lastMove: (json['lastMove'] as List?)
          ?.map((v) => (v as num).toInt())
          .toList(),
    );
  }
}
