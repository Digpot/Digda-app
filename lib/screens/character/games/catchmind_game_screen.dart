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
  _ChatMsg({required this.text, this.userName, this.system = false, this.correct = false});
  final String text;
  final String? userName;
  final bool system;
  final bool correct;
}

class _CatchmindGameScreenState extends State<CatchmindGameScreen> {
  CatchmindGame? _game;
  bool _loading = true;
  String? _errorMessage;
  bool _actionPending = false;
  GameSocketSession? _socket;

  /// 현재 라운드의 캔버스 획 — strokeId 별로 조각을 이어붙인다.
  final Map<int, CatchmindStroke> _strokes = {};
  final List<int> _strokeOrder = [];

  /// 출제자 드로잉 진행 중 상태.
  List<List<double>> _draftPoints = [];
  int? _draftId;
  String _penColor = '#2B2B2B';
  double _penWidth = 4.0;

  final List<_ChatMsg> _chat = [];
  final TextEditingController _guessCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  Timer? _ticker;
  int _remainingSec = 0;

  static const List<String> _palette = [
    '#2B2B2B', '#FF6B6B', '#F59E0B', '#34D399', '#60A5FA', '#A78BFA',
  ];

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
      _syncStrokes(_game!.strokes);
    }
    if (!mounted || _game == null) return;
    await _connectSocket();
  }

  Future<void> _refresh() async {
    try {
      final game = await Di.minigameRepository.getCatchmind(widget.gameId);
      if (!mounted) return;
      setState(() {
        _game = game;
        _loading = false;
        _errorMessage = null;
        _syncStrokes(game.strokes);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_game == null) _errorMessage = errorMessageOf(e);
      });
    }
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

  Future<void> _connectSocket() async {
    final token = await Di.tokenStorage.readAccessToken();
    if (!mounted || token == null) return;
    final socket = GameSocketSession(
      topic: '/topic/catchmind/${widget.gameId}',
      accessToken: token,
      onJson: (json) => _onEvent(CatchmindEvent.fromJson(json)),
      onConnected: () {
        if (mounted) _refresh();
      },
    );
    _socket = socket;
    socket.connect();
  }

  void _onEvent(CatchmindEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'STROKE':
        // 내가 출제자면 내 획의 서버 에코 — 이미 로컬에 그렸으므로 무시(중복 방지).
        if (_canDraw) return;
        final s = event.stroke;
        if (s != null) setState(() => _mergeStroke(s));
      case 'CLEAR':
        setState(() {
          _strokes.clear();
          _strokeOrder.clear();
        });
      case 'GUESS':
        setState(() {
          _chat.add(_ChatMsg(text: event.text ?? '', userName: event.userName));
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
      case 'ROUND_START':
        if (event.game != null) {
          _applyGame(event.game!);
          setState(() {
            _strokes.clear();
            _strokeOrder.clear();
            _draftPoints = [];
            _draftId = null;
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
          if (event.game!.isDrawer(_myId)) _refresh();
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
    _draftId = DateTime.now().millisecondsSinceEpoch;
    _sentCount = 0;
    _draftPoints = [
      [
        (pos.dx / size.width).clamp(0.0, 1.0),
        (pos.dy / size.height).clamp(0.0, 1.0),
      ]
    ];
    setState(() {});
  }

  void _onPanUpdate(Offset pos, Size size) {
    if (!_canDraw || _draftId == null) return;
    final x = (pos.dx / size.width).clamp(0.0, 1.0);
    final y = (pos.dy / size.height).clamp(0.0, 1.0);
    _draftPoints.add([x, y]);
    // 12개 포인트마다 조각 전송 — 상대 화면에 거의 실시간으로 이어진다.
    if (_draftPoints.length % 12 == 0) {
      _sendDraft(done: false);
    }
    setState(() {});
  }

  void _onPanEnd() {
    if (!_canDraw || _draftId == null) return;
    _sendDraft(done: true);
    _draftId = null;
    _draftPoints = [];
  }

  int _sentCount = 0;

  void _sendDraft({required bool done}) {
    final id = _draftId;
    if (id == null) return;
    // 이미 보낸 포인트 이후의 조각만 전송.
    final pending = _draftPoints.sublist(_sentCount.clamp(0, _draftPoints.length));
    if (pending.isEmpty && !done) return;
    final stroke = CatchmindStroke(
      strokeId: id,
      color: _penColor,
      width: _penWidth,
      points: pending,
      done: done,
    );
    _socket?.send(
      '/app/catchmind/${widget.gameId}/stroke',
      stroke.toJson(),
    );
    _mergeStroke(stroke);
    if (done) {
      _sentCount = 0;
    } else {
      _sentCount = _draftPoints.length;
    }
  }

  void _clearCanvas() {
    if (!_canDraw) return;
    _socket?.send('/app/catchmind/${widget.gameId}/clear');
    setState(() {
      _strokes.clear();
      _strokeOrder.clear();
    });
  }

  void _skipRound() {
    if (!_canDraw) return;
    showConfirmDialog(
      context,
      title: '라운드를 넘길까요?',
      message: '이 단어를 포기하고 다음 라운드로 넘어가요.',
      confirmLabel: '넘기기',
      onConfirm: () =>
          _socket?.send('/app/catchmind/${widget.gameId}/skip'),
    );
  }

  // ── 추리 (참가자) ────────────────────────────────────────────

  void _sendGuess() {
    final text = _guessCtrl.text.trim();
    if (text.isEmpty) return;
    _guessCtrl.clear();
    _socket?.send(
      '/app/catchmind/${widget.gameId}/guess',
      {'text': text},
    );
  }

  // ── 나가기/종료 ──────────────────────────────────────────────

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
          message: '나가도 게임은 계속 진행돼요.\n다시 들어오면 이어서 참여할 수 있어요.',
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
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              BackHeader(title: '캐치마인드', onBack: _onExit),
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
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text('🎨', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(
          '${game.hostName}님의 캐치마인드',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '참가 $joinedCount명 · 2명 이상 모이면 시작할 수 있어요',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 8),
        // 방장이 고른 게임 설정 — 라운드 수와 라운드 제한시간.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '총 ${game.totalRounds}라운드 · 라운드당 '
            '${game.roundSeconds >= 60 ? '${game.roundSeconds ~/ 60}분${game.roundSeconds % 60 == 0 ? '' : ' ${game.roundSeconds % 60}초'}' : '${game.roundSeconds}초'}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: game.players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = game.players[i];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: p.joined
                      ? AppColors.primary.withValues(alpha: 0.04)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: p.joined ? AppColors.primary : AppColors.gray100,
                    width: p.joined ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    GamePlayerAvatar(name: p.name, dimmed: p.declined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.userId == _myId ? '${p.name} (나)' : p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppColors.gray900,
                        ),
                      ),
                    ),
                    if (p.isHost)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text('👑', style: TextStyle(fontSize: 14)),
                      ),
                    Text(
                      p.joined
                          ? '참가 완료'
                          : p.declined
                              ? '거절'
                              : '대기 중...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: p.joined
                            ? AppColors.primary
                            : p.declined
                                ? AppColors.gray400
                                : AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: isHost
              ? Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _actionPending
                              ? null
                              : () => _lobbyAction(
                                    () => Di.minigameRepository
                                        .cancelCatchmind(widget.gameId),
                                    popAfter: true,
                                  ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gray700,
                            side: const BorderSide(color: AppColors.gray200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '방 없애기',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (joinedCount < 2 || _actionPending)
                              ? null
                              : () => _lobbyAction(() => Di.minigameRepository
                                  .startCatchmind(widget.gameId)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.gray200,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            joinedCount < 2 ? '참가를 기다리는 중...' : '게임 시작!',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : amInvitedNotJoined
                  ? Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _actionPending
                                  ? null
                                  : () => _lobbyAction(
                                        () => Di.minigameRepository
                                            .declineCatchmind(widget.gameId),
                                        popAfter: true,
                                      ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gray700,
                                side:
                                    const BorderSide(color: AppColors.gray200),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '거절',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _actionPending
                                  ? null
                                  : () => _lobbyAction(() => Di
                                      .minigameRepository
                                      .joinCatchmind(widget.gameId)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '참가하기',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
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
    final drawerName = game.playerOf(game.drawerUserId ?? '')?.name ?? '';
    return Column(
      children: [
        _buildRoundBar(game, isDrawer, drawerName),
        // 캔버스 — 정사각형에 가깝게, 화면 폭 기준.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: _buildCanvas(isDrawer),
          ),
        ),
        if (isDrawer) _buildDrawerTools(),
        const SizedBox(height: 4),
        Expanded(child: _buildChatFeed()),
        if (!isDrawer) _buildGuessInput(),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 4 : 10),
      ],
    );
  }

  Widget _buildRoundBar(CatchmindGame game, bool isDrawer, String drawerName) {
    final urgent = _remainingSec <= 10;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'R${game.roundIndex + 1}/${game.totalRounds}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isDrawer
                ? Text(
                    '내 단어: ${game.word ?? '...'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.gray900,
                    ),
                  )
                : Text(
                    '$drawerName님이 그리는 중 · '
                    '${List.filled(game.wordLength ?? 0, '◯').join(' ')}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.gray700,
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: urgent
                  ? const Color(0xFFFFE9E9)
                  : AppColors.gray50,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '⏱ $_remainingSec',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: urgent ? AppColors.primary : AppColors.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(bool isDrawer) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final strokes = [
          for (final id in _strokeOrder) _strokes[id]!,
        ];
        return GestureDetector(
          onPanStart: isDrawer
              ? (d) => _onPanStart(d.localPosition, size)
              : null,
          onPanUpdate: isDrawer
              ? (d) => _onPanUpdate(d.localPosition, size)
              : null,
          onPanEnd: isDrawer ? (_) => _onPanEnd() : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gray200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              size: size,
              painter: _CanvasPainter(
                strokes: strokes,
                draftPoints: _draftPoints,
                draftColor: _penColor,
                draftWidth: _penWidth,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerTools() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final c in _palette) ...[
            GestureDetector(
              onTap: () => setState(() => _penColor = c),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Color(
                      0xFF000000 | int.parse(c.substring(1), radix: 16)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _penColor == c
                        ? AppColors.gray900
                        : Colors.transparent,
                    width: 2.4,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => setState(
                () => _penWidth = _penWidth >= 9 ? 4.0 : _penWidth + 2.5),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.gray200),
              ),
              child: Row(
                children: [
                  Container(
                    width: _penWidth * 1.6,
                    height: _penWidth * 1.6,
                    decoration: const BoxDecoration(
                      color: AppColors.gray700,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '굵기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _clearCanvas,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 22, color: AppColors.gray600),
          ),
          TextButton(
            onPressed: _skipRound,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.gray600,
            ),
            child: const Text(
              '스킵',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      itemCount: _chat.length,
      itemBuilder: (context, i) {
        final m = _chat[i];
        if (m.system) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: m.correct
                      ? const Color(0xFFE9F9F1)
                      : AppColors.gray50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  m.text,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: m.correct
                        ? const Color(0xFF1C9E68)
                        : AppColors.gray600,
                  ),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.userName ?? '',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.text,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppColors.gray900,
                  ),
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
                fillColor: AppColors.gray50,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
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
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
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
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text('🏆', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        const Text(
          '게임 종료!',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: ranked.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = ranked[i];
              final isMe = p.userId == _myId;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: i == 0 ? const Color(0xFFF5C34D) : AppColors.gray100,
                    width: i == 0 ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        i < medals.length ? medals[i] : '${i + 1}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    GamePlayerAvatar(name: p.name, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isMe ? '${p.name} (나)' : p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.gray900,
                        ),
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '나가기',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
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

  static Color _colorOf(String hex) {
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
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (pts.length == 1) {
      canvas.drawCircle(
        Offset(pts[0][0] * size.width, pts[0][1] * size.height),
        width / 2,
        Paint()..color = color,
      );
      return;
    }
    final path = Path()
      ..moveTo(pts[0][0] * size.width, pts[0][1] * size.height);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i][0] * size.width, pts[i][1] * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _drawPolyline(canvas, size, s.points, _colorOf(s.color), s.width);
    }
    _drawPolyline(
        canvas, size, draftPoints, _colorOf(draftColor), draftWidth);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}
