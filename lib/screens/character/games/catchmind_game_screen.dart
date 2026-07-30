import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/minigame/data/game_socket.dart';
import '../../../features/minigame/models/minigame_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/ad_banner.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/back_header.dart';
import 'game_ui_common.dart';

/// 캐치마인드 화면 — 로비(참가 대기)/라운드 진행/최종 랭킹을 한 화면에서 전환.
///
/// 서버가 진실 출처: 그리기 획·추리는 STOMP 로 보내고, 화면 갱신은
/// `/topic/catchmind/{gameId}` 이벤트로만 한다. 재연결 시 REST 스냅샷으로
/// 누적 획까지 재동기화한다.
class CatchmindGameScreen extends StatefulWidget {
  const CatchmindGameScreen({super.key, required this.gameId, this.initialGame});

  final int gameId;
  final CatchmindGame? initialGame;

  @override
  State<CatchmindGameScreen> createState() => _CatchmindGameScreenState();
}

class _ChatMsg {
  _ChatMsg({
    required this.text,
    this.userName,
    this.system = false,
    this.correct = false,
    this.mine = false,
  });
  final String text;
  final String? userName;
  final bool system;
  final bool correct;
  final bool mine;
}

class _CatchmindGameScreenState extends State<CatchmindGameScreen> {
  CatchmindGame? _game;
  bool _loading = true;
  String? _errorMessage;
  bool _actionPending = false;
  GameSocketSession? _socket;

  /// 실시간 연결 상태 — 끊기면 배너로 알린다(화면이 멈춘 것처럼 보이는 걸 막는다).
  bool _connected = false;

  /// 현재 라운드의 캔버스 획 — strokeId 별로 조각을 이어붙인다.
  final Map<int, CatchmindStroke> _strokes = {};
  final List<int> _strokeOrder = [];

  /// 내가 그린 획의 id — 서버 에코를 다시 그리지 않기 위한 표식.
  /// 역할(`_canDraw`)로 거르면 라운드 전환 순간에 남의 획까지 버려진다.
  final Set<int> _myStrokeIds = {};

  /// 출제자 드로잉 진행 중 상태 — 진행 중 획은 로컬 오버레이로만 그린다.
  List<List<double>> _draftPoints = [];
  int? _draftId;
  int _sentCount = 0;
  String _penColor = _inkBlack;
  double _penWidth = 5.0;

  final List<_ChatMsg> _chat = [];
  final TextEditingController _guessCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  Timer? _ticker;
  int _remainingSec = 0;

  /// 출제자인데 아직 단어를 못 받았을 때의 재시도 — 라운드가 바뀌면 취소된다.
  Timer? _wordRetry;
  int _wordRetryCount = 0;

  static const String _inkBlack = '#2B2B2B';
  static const String _eraser = '#FFFFFF';
  static const List<String> _palette = [
    _inkBlack,
    '#FF6B6B',
    '#F59E0B',
    '#34D399',
    '#60A5FA',
    '#A78BFA',
  ];
  static const List<double> _penWidths = [2.5, 5.0, 9.0, 15.0];

  String get _myId => Di.userSession.profile?.id ?? '';

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loading = _game == null;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _socket?.dispose();
    _ticker?.cancel();
    _wordRetry?.cancel();
    _guessCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _tick() {
    final deadline = _game?.roundDeadlineEpochMs;
    if (deadline == null || _game?.status != CatchmindStatus.active) return;
    final remain =
        ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (remain != _remainingSec && mounted) {
      setState(() => _remainingSec = remain.clamp(0, 999));
    }
  }

  Future<void> _init() async {
    if (_game == null) {
      await _refresh();
    } else {
      setState(() => _syncStrokes(_game!.strokes));
    }
    if (!mounted) return;
    // 첫 조회가 실패해도 소켓은 붙인다 — 붙고 나면 onConnected 가 다시 조회한다.
    await _connectSocket();
  }

  /// REST 스냅샷 재동기화.
  ///
  /// [syncStrokes] 가 false 면 캔버스는 건드리지 않는다. 출제자 단어를 받으려고
  /// 도는 재시도가 실시간으로 들어오던 획을 지워버리던 문제를 막는다.
  Future<void> _refresh({bool syncStrokes = true}) async {
    try {
      final game = await Di.minigameRepository.getCatchmind(widget.gameId);
      if (!mounted) return;
      // 응답이 도는 사이 라운드가 넘어갔으면 낡은 스냅샷이다 — 되돌리지 않는다.
      final current = _game;
      if (current != null && game.roundIndex < current.roundIndex) return;
      setState(() {
        _game = game;
        _loading = false;
        _errorMessage = null;
        if (syncStrokes) _syncStrokes(game.strokes);
      });
      _ensureWordLoaded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_game == null) _errorMessage = errorMessageOf(e);
      });
      // 실패해도 재시도 사슬은 이어간다 — 여기서 끊기면 단어가 영영 안 온다.
      _ensureWordLoaded();
    }
  }

  /// 브로드캐스트 스냅샷엔 단어가 없어(정답 유출 방지) 출제자만 REST 로 따로 받는다.
  /// 한 번 실패하면 예전엔 그대로 "..." 로 남았어서, 받을 때까지 짧게 재시도한다.
  void _ensureWordLoaded() {
    final game = _game;
    _wordRetry?.cancel();
    if (game == null ||
        game.status != CatchmindStatus.active ||
        !game.isDrawer(_myId) ||
        game.word != null) {
      _wordRetryCount = 0;
      return;
    }
    if (_wordRetryCount >= 6) return;
    final delayMs = 250 * (1 << _wordRetryCount).clamp(1, 16);
    _wordRetryCount += 1;
    _wordRetry = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _refresh(syncStrokes: false);
    });
  }

  void _syncStrokes(List<CatchmindStroke> strokes) {
    _strokes.clear();
    _strokeOrder.clear();
    for (final s in strokes) {
      _mergeStroke(s);
    }
  }

  void _mergeStroke(CatchmindStroke s) {
    final existing = _strokes[s.strokeId];
    if (existing == null) {
      _strokes[s.strokeId] = s;
      _strokeOrder.add(s.strokeId);
    } else {
      _strokes[s.strokeId] = CatchmindStroke(
        strokeId: s.strokeId,
        color: existing.color,
        width: existing.width,
        points: [...existing.points, ...s.points],
        done: s.done,
      );
    }
  }

  void _clearBoard() {
    _strokes.clear();
    _strokeOrder.clear();
    _myStrokeIds.clear();
    _draftPoints = [];
    _draftId = null;
    _sentCount = 0;
  }

  Future<void> _connectSocket() async {
    final token = await Di.tokenStorage.readAccessToken();
    if (!mounted || token == null) return;
    final socket = GameSocketSession(
      topic: '/topic/catchmind/${widget.gameId}',
      accessToken: token,
      onJson: (json) => _onEvent(CatchmindEvent.fromJson(json)),
      onConnected: () {
        if (!mounted) return;
        setState(() => _connected = true);
        _refresh();
      },
      onDisconnected: () {
        if (mounted) setState(() => _connected = false);
      },
    );
    _socket = socket;
    socket.connect();
  }

  void _onEvent(CatchmindEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'STROKE':
        final s = event.stroke;
        // 내가 그린 획의 서버 에코는 무시 — 로컬에 이미 그려져 있다.
        if (s == null || _myStrokeIds.contains(s.strokeId)) return;
        setState(() => _mergeStroke(s));
      case 'CLEAR':
        setState(_clearBoard);
      case 'GUESS':
        setState(() {
          _chat.add(_ChatMsg(
            text: event.text ?? '',
            userName: event.userName,
            mine: event.userId == _myId,
          ));
        });
        _scrollChat();
      case 'CORRECT':
        if (event.game != null) _applyGame(event.game!);
        setState(() {
          _chat.add(_ChatMsg(
            text: '🎉 ${event.userName ?? '누군가'}님 정답! — "${event.answer ?? ''}"',
            system: true,
            correct: true,
          ));
        });
        HapticFeedback.mediumImpact();
        _scrollChat();
      case 'ROUND_TIMEOUT':
      case 'ROUND_SKIPPED':
        if (event.game != null) _applyGame(event.game!);
        setState(() {
          _chat.add(_ChatMsg(
            text: event.type == 'ROUND_TIMEOUT'
                ? '⏰ 시간 초과! 정답은 "${event.answer ?? ''}"'
                : '⏭️ 라운드 스킵! 정답은 "${event.answer ?? ''}"',
            system: true,
          ));
        });
        _scrollChat();
      case 'FORFEITED':
        if (event.game != null) _applyGame(event.game!);
        setState(() {
          final answer = event.answer;
          _chat.add(_ChatMsg(
            text: event.userId == _myId
                ? '🏳️ 기권했어요. 남은 라운드는 구경할 수 있어요.'
                : '🏳️ ${event.userName ?? '누군가'}님이 기권했어요.'
                    '${answer == null ? '' : ' 정답은 "$answer"'}',
            system: true,
          ));
        });
        _scrollChat();
      case 'ROUND_START':
        if (event.game != null) {
          _applyGame(event.game!);
          setState(() {
            _clearBoard();
            final g = event.game!;
            final drawerName = g.playerOf(g.drawerUserId ?? '')?.name ?? '';
            _chat.add(_ChatMsg(
              text: '✏️ 라운드 ${g.roundIndex + 1}/${g.totalRounds} — '
                  '$drawerName님이 그려요!',
              system: true,
            ));
          });
          _scrollChat();
          // 내가 출제자면 REST 로 내 단어를 받아온다(브로드캐스트엔 정답 미포함).
          _wordRetryCount = 0;
          _ensureWordLoaded();
        }
      case 'STARTED':
      case 'PLAYER_JOINED':
      case 'PLAYER_DECLINED':
        if (event.game != null) _applyGame(event.game!);
      case 'FINISHED':
        if (event.game != null) _applyGame(event.game!);
        HapticFeedback.mediumImpact();
      case 'CANCELED':
        if (_myId != _game?.hostUserId) {
          _showEndAndPop('방장이 방을 취소했어요.');
        }
      case 'EXPIRED':
        _showEndAndPop('게임이 만료됐어요. 다시 만들어 주세요.');
    }
  }

  void _applyGame(CatchmindGame game) {
    setState(() {
      // 브로드캐스트 스냅샷엔 word 가 없다 — 내가 출제자로 이미 받아둔 단어는 유지.
      final keepWord = _game?.word != null &&
          _game?.drawerUserId == game.drawerUserId &&
          _game?.roundIndex == game.roundIndex;
      _game = keepWord
          ? CatchmindGame(
              gameId: game.gameId,
              groupRoomId: game.groupRoomId,
              status: game.status,
              hostUserId: game.hostUserId,
              hostName: game.hostName,
              players: game.players,
              roundIndex: game.roundIndex,
              totalRounds: game.totalRounds,
              roundSeconds: game.roundSeconds,
              drawerUserId: game.drawerUserId,
              word: _game!.word,
              wordLength: game.wordLength,
              roundDeadlineEpochMs: game.roundDeadlineEpochMs,
              strokes: game.strokes,
            )
          : game;
    });
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// STOMP 전송 — 끊겨 있으면 조용히 실패하지 않고 사용자에게 알린다.
  bool _send(String path, [Map<String, dynamic>? body]) {
    final ok = _socket?.send('/app/catchmind/${widget.gameId}/$path', body) ??
        false;
    if (!ok && mounted) {
      showErrorDialog(context, '실시간 연결이 끊겼어요.\n연결이 돌아오면 다시 시도해 주세요.');
    }
    return ok;
  }

  // ── 로비 액션 ────────────────────────────────────────────────

  Future<void> _lobbyAction(
    Future<CatchmindGame> Function() action, {
    bool popAfter = false,
  }) async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      final game = await action();
      if (!mounted) return;
      if (popAfter) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _game = game;
        _syncStrokes(game.strokes);
      });
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  // ── 드로잉 (출제자) ──────────────────────────────────────────

  bool get _canDraw =>
      _game?.status == CatchmindStatus.active && _game!.isDrawer(_myId);

  void _onPanStart(Offset pos, Size size) {
    if (!_canDraw) return;
    final id = DateTime.now().millisecondsSinceEpoch;
    _draftId = id;
    _myStrokeIds.add(id);
    _sentCount = 0;
    _draftPoints = [_normalize(pos, size)];
    setState(() {});
  }

  void _onPanUpdate(Offset pos, Size size) {
    if (!_canDraw || _draftId == null) return;
    _draftPoints.add(_normalize(pos, size));
    // 12개 포인트마다 조각 전송 — 상대 화면에 거의 실시간으로 이어진다.
    if (_draftPoints.length - _sentCount >= 12) _sendDraft(done: false);
    setState(() {});
  }

  void _onPanEnd() {
    if (!_canDraw || _draftId == null) return;
    _sendDraft(done: true);
    // 마지막에 한 번만 캔버스에 확정 — 진행 중엔 오버레이로만 그려 겹침이 없다.
    final id = _draftId!;
    final points = _draftPoints;
    setState(() {
      _mergeStroke(CatchmindStroke(
        strokeId: id,
        color: _penColor,
        width: _penWidth,
        points: points,
        done: true,
      ));
      _draftId = null;
      _draftPoints = [];
      _sentCount = 0;
    });
  }

  List<double> _normalize(Offset pos, Size size) => [
        (pos.dx / size.width).clamp(0.0, 1.0),
        (pos.dy / size.height).clamp(0.0, 1.0),
      ];

  void _sendDraft({required bool done}) {
    final id = _draftId;
    if (id == null) return;
    // 이미 보낸 포인트 이후의 조각만 전송.
    final pending = _draftPoints.sublist(_sentCount.clamp(0, _draftPoints.length));
    if (pending.isEmpty && !done) return;
    _socket?.send(
      '/app/catchmind/${widget.gameId}/stroke',
      CatchmindStroke(
        strokeId: id,
        color: _penColor,
        width: _penWidth,
        points: pending,
        done: done,
      ).toJson(),
    );
    _sentCount = done ? 0 : _draftPoints.length;
  }

  void _clearCanvas() {
    if (!_canDraw) return;
    _send('clear');
    setState(_clearBoard);
  }

  void _skipRound() {
    if (!_canDraw) return;
    showConfirmDialog(
      context,
      title: '라운드를 넘길까요?',
      message: '이 단어를 포기하고 다음 라운드로 넘어가요.',
      confirmLabel: '넘기기',
      onConfirm: () => _send('skip'),
    );
  }

  // ── 추리 (참가자) ────────────────────────────────────────────

  void _sendGuess() {
    final text = _guessCtrl.text.trim();
    if (text.isEmpty) return;
    if (_send('guess', {'text': text})) _guessCtrl.clear();
  }

  // ── 기권 / 나가기 ────────────────────────────────────────────

  void _confirmForfeit() {
    showConfirmDialog(
      context,
      title: '기권할까요?',
      message: '남은 라운드에서 빠지고 지금까지 얻은 점수만 남아요.\n'
          '남은 사람이 부족해지면 게임이 바로 끝나요.',
      confirmLabel: '기권',
      confirmColor: AppColors.primaryDark,
      onConfirm: () => _send('forfeit'),
    );
  }

  void _onExit() {
    final game = _game;
    if (game == null) {
      Navigator.of(context).pop();
      return;
    }
    switch (game.status) {
      case CatchmindStatus.waiting:
        if (_myId == game.hostUserId) {
          showConfirmDialog(
            context,
            title: '방을 없앨까요?',
            message: '나가면 방이 취소되고 초대도 사라져요.',
            confirmLabel: '방 없애기',
            onConfirm: () => _lobbyAction(
              () => Di.minigameRepository.cancelCatchmind(widget.gameId),
              popAfter: true,
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      case CatchmindStatus.active:
        showConfirmDialog(
          context,
          title: '게임에서 나갈까요?',
          message: '나가도 게임은 계속 진행돼요.\n다시 들어오면 이어서 참여할 수 있어요.\n'
              '아예 빠지려면 기권을 눌러 주세요.',
          confirmLabel: '나가기',
          onConfirm: () => Navigator.of(context).pop(),
        );
      default:
        Navigator.of(context).pop();
    }
  }

  void _showEndAndPop(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.gray900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final canForfeit = game != null &&
        game.status == CatchmindStatus.active &&
        !game.hasForfeited(_myId) &&
        (game.playerOf(_myId)?.joined ?? false);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onExit();
      },
      child: Scaffold(
        backgroundColor: gameSurface,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              BackHeader(
                title: '캐치마인드',
                onBack: _onExit,
                actions: [
                  if (canForfeit) GameForfeitAction(onPressed: _confirmForfeit),
                ],
              ),
              if (game != null && game.status == CatchmindStatus.active)
                GameConnectionBanner(connected: _connected),
              Expanded(child: _buildBody()),
              // 배너 광고 — 키보드가 올라오면 입력을 가리지 않게 숨긴다.
              if (MediaQuery.of(context).viewInsets.bottom == 0)
                const AdBanner(padding: EdgeInsets.only(top: 4, bottom: 4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final game = _game;
    if (game == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage ?? '게임을 찾을 수 없어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.gray700,
            ),
          ),
        ),
      );
    }
    return switch (game.status) {
      CatchmindStatus.waiting => _buildLobby(game),
      CatchmindStatus.active => _buildPlaying(game),
      CatchmindStatus.finished => _buildRanking(game),
      _ => _buildLobby(game),
    };
  }

  // ── 로비 ─────────────────────────────────────────────────────

  Widget _buildLobby(CatchmindGame game) {
    final isHost = _myId == game.hostUserId;
    final me = game.playerOf(_myId);
    final joinedCount = game.joinedPlayers.length;
    final amInvitedNotJoined = me != null && !me.joined;
    final seconds = game.roundSeconds;
    final timeLabel = seconds >= 60
        ? '${seconds ~/ 60}분${seconds % 60 == 0 ? '' : ' ${seconds % 60}초'}'
        : '$seconds초';
    return Column(
      children: [
        GameLobbyIntro(
          emoji: '🎨',
          title: '${game.hostName}님의 캐치마인드',
          subtitle: '참가 $joinedCount명 · 2명 이상 모이면 시작할 수 있어요',
          rule: '총 ${game.totalRounds}라운드 · 라운드당 $timeLabel',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            itemCount: game.players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = game.players[i];
              return GameRosterTile(
                name: p.name,
                isMe: p.userId == _myId,
                isHost: p.isHost,
                joined: p.joined,
                dimmed: p.declined,
                statusLabel: p.joined
                    ? '참가 완료'
                    : p.declined
                        ? '거절'
                        : '대기 중...',
                statusColor: p.joined
                    ? AppColors.primary
                    : p.declined
                        ? AppColors.gray400
                        : AppColors.gray500,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: isHost
              ? Row(
                  children: [
                    Expanded(
                      child: GameGhostButton(
                        label: '방 없애기',
                        onPressed: _actionPending
                            ? null
                            : () => _lobbyAction(
                                  () => Di.minigameRepository
                                      .cancelCatchmind(widget.gameId),
                                  popAfter: true,
                                ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GamePrimaryButton(
                        label: joinedCount < 2 ? '참가를 기다리는 중...' : '게임 시작!',
                        onPressed: (joinedCount < 2 || _actionPending)
                            ? null
                            : () => _lobbyAction(() => Di.minigameRepository
                                .startCatchmind(widget.gameId)),
                      ),
                    ),
                  ],
                )
              : amInvitedNotJoined
                  ? Row(
                      children: [
                        Expanded(
                          child: GameGhostButton(
                            label: '거절',
                            onPressed: _actionPending
                                ? null
                                : () => _lobbyAction(
                                      () => Di.minigameRepository
                                          .declineCatchmind(widget.gameId),
                                      popAfter: true,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GamePrimaryButton(
                            label: '참가하기',
                            onPressed: _actionPending
                                ? null
                                : () => _lobbyAction(() => Di.minigameRepository
                                    .joinCatchmind(widget.gameId)),
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      '방장이 시작하길 기다리는 중...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AppColors.gray500,
                      ),
                    ),
        ),
      ],
    );
  }

  // ── 진행 ─────────────────────────────────────────────────────

  Widget _buildPlaying(CatchmindGame game) {
    final isDrawer = game.isDrawer(_myId);
    final forfeited = game.hasForfeited(_myId);
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;
    return Column(
      children: [
        _buildRoundCard(game, isDrawer),
        // 캔버스 — 키보드가 올라오면 살짝 납작하게 눌러 입력과 채팅을 살린다.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: AspectRatio(
            aspectRatio: keyboardUp ? 1.9 : 1.24,
            child: _buildCanvas(isDrawer),
          ),
        ),
        if (isDrawer) _buildDrawerTools(),
        const SizedBox(height: 2),
        Expanded(child: _buildChatFeed()),
        if (!isDrawer && !forfeited)
          _buildGuessInput()
        else if (forfeited)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 6),
            child: Text(
              '기권했어요 — 남은 라운드를 구경할 수 있어요 👀',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.gray500,
              ),
            ),
          ),
        SizedBox(height: keyboardUp ? 4 : 10),
      ],
    );
  }

  /// 라운드 헤더 카드 — 라운드/출제자/남은 시간 + 단어(또는 글자수 힌트).
  Widget _buildRoundCard(CatchmindGame game, bool isDrawer) {
    final drawerName = game.playerOf(game.drawerUserId ?? '')?.name ?? '';
    final total = game.roundSeconds <= 0 ? 1 : game.roundSeconds;
    final progress = (_remainingSec / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: GameCard(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                GamePill(
                  label: 'R${game.roundIndex + 1}/${game.totalRounds}',
                  fontSize: 11.5,
                ),
                const SizedBox(width: 8),
                GamePlayerAvatar(name: drawerName, size: 26, highlighted: true),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isDrawer ? '내가 그릴 차례!' : '$drawerName님이 그리는 중',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: isDrawer ? AppColors.primary : AppColors.gray800,
                    ),
                  ),
                ),
                GameCountdownPill(seconds: _remainingSec, suffix: '초'),
              ],
            ),
            const SizedBox(height: 10),
            // 남은 시간 게이지 — 숫자보다 먼저 눈에 들어오는 긴장감.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.gray100,
                valueColor: AlwaysStoppedAnimation(
                  _remainingSec <= 10 ? AppColors.primary : AppColors.gray300,
                ),
              ),
            ),
            const SizedBox(height: 11),
            isDrawer ? _buildDrawerWord(game) : _buildWordSlots(game),
          ],
        ),
      ),
    );
  }

  /// 출제자용 단어 — 아직 못 받았으면 "..." 대신 받아오는 중임을 분명히 보여준다.
  Widget _buildDrawerWord(CatchmindGame game) {
    final word = game.word;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: word == null ? null : gamePrimaryGradient,
        color: word == null ? AppColors.gray50 : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: word == null
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gray400,
                  ),
                ),
                SizedBox(width: 9),
                Text(
                  '단어를 받아오는 중...',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                const Text(
                  '이 단어를 그려주세요 (화면을 보여주면 안 돼요!)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  word,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  /// 추리자용 글자수 힌트 — 한 줄 텍스트로 이어붙이면 잘려서 "..." 로 보였다.
  /// 글자마다 칸을 그려 몇 글자인지 한눈에 들어오게 한다.
  Widget _buildWordSlots(CatchmindGame game) {
    final length = game.wordLength ?? 0;
    return Column(
      children: [
        Text(
          length == 0 ? '단어를 기다리는 중...' : '$length글자',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
            color: AppColors.gray500,
          ),
        ),
        if (length > 0) ...[
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < length; i++)
                Container(
                  width: 26,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gray100),
                  ),
                  child: const Text(
                    '?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.gray300,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCanvas(bool isDrawer) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final strokes = [
          for (final id in _strokeOrder) _strokes[id]!,
        ];
        final empty = strokes.isEmpty && _draftPoints.isEmpty;
        return GestureDetector(
          onPanStart:
              isDrawer ? (d) => _onPanStart(d.localPosition, size) : null,
          onPanUpdate:
              isDrawer ? (d) => _onPanUpdate(d.localPosition, size) : null,
          onPanEnd: isDrawer ? (_) => _onPanEnd() : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gray100),
              boxShadow: gameSoftShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CanvasPainter(
                      strokes: strokes,
                      draftPoints: _draftPoints,
                      draftColor: _penColor,
                      draftWidth: _penWidth,
                    ),
                  ),
                ),
                if (empty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDrawer
                              ? Icons.gesture_rounded
                              : Icons.visibility_outlined,
                          size: 30,
                          color: AppColors.gray200,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          isDrawer
                              ? '여기에 그려 주세요'
                              : '곧 그림이 나타나요',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerTools() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              for (final c in _palette) ...[
                _ColorSwatch(
                  hex: c,
                  selected: _penColor == c,
                  onTap: () => setState(() => _penColor = c),
                ),
                const SizedBox(width: 9),
              ],
              // 지우개 = 흰 펜. 캔버스가 순백이라 서버 변경 없이 그대로 동작한다.
              _ToolButton(
                icon: Icons.cleaning_services_outlined,
                selected: _penColor == _eraser,
                onTap: () => setState(() => _penColor = _eraser),
              ),
              const Spacer(),
              _ToolButton(
                icon: Icons.delete_outline_rounded,
                onTap: _clearCanvas,
              ),
              const SizedBox(width: 8),
              _ToolButton(
                icon: Icons.skip_next_rounded,
                onTap: _skipRound,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Text(
                '굵기',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(width: 10),
              for (final w in _penWidths) ...[
                _WidthSwatch(
                  width: w,
                  selected: _penWidth == w,
                  color: _penColor == _eraser
                      ? AppColors.gray400
                      : _CanvasPainter.colorOf(_penColor),
                  onTap: () => setState(() => _penWidth = w),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatFeed() {
    if (_chat.isEmpty) {
      return const Center(
        child: Text(
          '정답이라고 생각하면 바로 입력해보세요!',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            color: AppColors.gray400,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _chatScroll,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      itemCount: _chat.length,
      itemBuilder: (context, i) {
        final m = _chat[i];
        if (m.system) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: m.correct
                      ? const Color(0xFFE7F8F0)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: m.correct
                        ? const Color(0xFFA9E4C9)
                        : AppColors.gray100,
                  ),
                ),
                child: Text(
                  m.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: m.correct
                        ? const Color(0xFF139361)
                        : AppColors.gray600,
                  ),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            mainAxisAlignment:
                m.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!m.mine) ...[
                GamePlayerAvatar(name: m.userName ?? '', size: 22),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: m.mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!m.mine)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 2),
                        child: Text(
                          m.userName ?? '',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            color: AppColors.gray400,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: m.mine ? AppColors.primary : AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: m.mine
                            ? null
                            : Border.all(color: AppColors.gray100),
                      ),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: m.mine ? Colors.white : AppColors.gray900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuessInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _guessCtrl,
              onSubmitted: (_) => _sendGuess(),
              textInputAction: TextInputAction.send,
              maxLength: 20,
              decoration: InputDecoration(
                counterText: '',
                hintText: '정답을 입력하세요',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  color: AppColors.gray400,
                ),
                filled: true,
                fillColor: AppColors.white,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.gray100),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.gray100),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendGuess,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: gamePrimaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── 랭킹 ─────────────────────────────────────────────────────

  Widget _buildRanking(CatchmindGame game) {
    final ranked = game.joinedPlayers
      ..sort((a, b) => b.score.compareTo(a.score));
    const medals = ['🥇', '🥈', '🥉'];
    final topScore = ranked.isEmpty ? 0 : ranked.first.score;
    return Column(
      children: [
        const SizedBox(height: 14),
        const Text('🏆', style: TextStyle(fontSize: 46)),
        const SizedBox(height: 8),
        const Text(
          '게임 종료!',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 21,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ranked.isEmpty
              ? '다음엔 더 신나게 그려봐요!'
              : '${ranked.first.name}님이 $topScore점으로 1등!',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: ranked.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = ranked[i];
              final isMe = p.userId == _myId;
              return GameCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                accent: i == 0
                    ? const Color(0xFFE0AE3A)
                    : isMe
                        ? AppColors.primary
                        : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        i < medals.length ? medals[i] : '${i + 1}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppColors.gray500,
                        ),
                      ),
                    ),
                    GamePlayerAvatar(
                      name: p.name,
                      size: 34,
                      dimmed: p.forfeited,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isMe ? '${p.name} (나)' : p.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: p.forfeited
                              ? AppColors.gray500
                              : AppColors.gray900,
                        ),
                      ),
                    ),
                    if (p.forfeited)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: GamePill(
                          label: '기권',
                          color: AppColors.gray500,
                          fontSize: 10.5,
                        ),
                      ),
                    Text(
                      '${p.score}점',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: GamePrimaryButton(
              label: '나가기',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 펜 색 스와치 — 선택 표시를 색 위가 아니라 바깥 링으로 준다.
/// 예전엔 선택 테두리가 진회색이라 검정 펜을 고르면 표시가 보이지 않았다.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _CanvasPainter.colorOf(hex);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 흰 링(간격) + 색 링 — 어떤 색을 골라도 선택이 또렷하게 보인다.
          color: AppColors.white,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Container(
          width: selected ? 20 : 24,
          height: selected ? 20 : 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gray100),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// 굵기 스와치 — 현재 펜 색으로 실제 굵기를 미리 보여준다.
class _WidthSwatch extends StatelessWidget {
  const _WidthSwatch({
    required this.width,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.gray300 : Colors.transparent,
          ),
        ),
        child: Container(
          width: width + 4,
          height: width + 4,
          decoration: BoxDecoration(
            color: color == Colors.white ? AppColors.gray300 : color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// 도구 버튼 — 지우개/전체 지우기/스킵.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.gray900 : AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.gray900 : AppColors.gray100,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: selected ? Colors.white : AppColors.gray600,
        ),
      ),
    );
  }
}

/// 캔버스 페인터 — 정규화(0..1) 좌표 획들을 현재 크기로 스케일해 그린다.
/// 출제자의 진행 중 획([draftPoints])은 로컬에서 즉시 그려 지연이 없다.
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.strokes,
    required this.draftPoints,
    required this.draftColor,
    required this.draftWidth,
  });

  final List<CatchmindStroke> strokes;
  final List<List<double>> draftPoints;
  final String draftColor;
  final double draftWidth;

  static Color colorOf(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF2B2B2B) : Color(0xFF000000 | v);
  }

  void _drawPolyline(
    Canvas canvas,
    Size size,
    List<List<double>> pts,
    Color color,
    double width,
  ) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      canvas.drawCircle(
        Offset(pts[0][0] * size.width, pts[0][1] * size.height),
        width / 2,
        Paint()..color = color,
      );
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    // 점을 직선으로 잇는 대신 중점을 지나는 2차 베지어로 이어 손그림처럼 매끈하게.
    final path = Path()
      ..moveTo(pts[0][0] * size.width, pts[0][1] * size.height);
    for (var i = 1; i < pts.length - 1; i++) {
      final cx = pts[i][0] * size.width;
      final cy = pts[i][1] * size.height;
      final mx = (cx + pts[i + 1][0] * size.width) / 2;
      final my = (cy + pts[i + 1][1] * size.height) / 2;
      path.quadraticBezierTo(cx, cy, mx, my);
    }
    final last = pts.last;
    path.lineTo(last[0] * size.width, last[1] * size.height);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _drawPolyline(canvas, size, s.points, colorOf(s.color), s.width);
    }
    _drawPolyline(canvas, size, draftPoints, colorOf(draftColor), draftWidth);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}
