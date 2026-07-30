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

/// 끝말잇기 화면 — 로비(참가 대기)/진행(단어 잇기 서든데스)/우승 결과를 한 화면에서.
///
/// 서버가 진실 출처: 단어 제출은 STOMP 로 보내고, 화면 갱신은
/// `/topic/wordchain/{gameId}` 이벤트로만 한다. 제한시간 초과 = 탈락,
/// 마지막 1명이 우승. 재접속 시 REST 스냅샷으로 단어 기록까지 복원.
class WordChainGameScreen extends StatefulWidget {
  const WordChainGameScreen({super.key, required this.gameId, this.initialGame});

  final int gameId;
  final WordChainGame? initialGame;

  @override
  State<WordChainGameScreen> createState() => _WordChainGameScreenState();
}

class _WordChainGameScreenState extends State<WordChainGameScreen> {
  WordChainGame? _game;
  bool _loading = true;
  String? _errorMessage;
  bool _actionPending = false;
  bool _resultShown = false;
  GameSocketSession? _socket;

  /// 실시간 연결 상태 — 끊기면 배너로 알린다(턴이 안 오는 것처럼 보이는 걸 막는다).
  bool _connected = false;

  final TextEditingController _wordCtrl = TextEditingController();
  final ScrollController _feedScroll = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  /// 방금 반려된 단어 안내 문구 — 잠깐 보여주고 사라진다.
  String? _rejectNote;
  Timer? _rejectTimer;

  Timer? _ticker;
  int _remainingSec = 0;

  String get _myId => Di.userSession.profile?.id ?? '';

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loading = _game == null;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _socket?.dispose();
    _ticker?.cancel();
    _rejectTimer?.cancel();
    _wordCtrl.dispose();
    _feedScroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _tick() {
    final deadline = _game?.turnDeadlineEpochMs;
    if (deadline == null || _game?.status != WordChainStatus.active) return;
    final remain =
        ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (remain != _remainingSec && mounted) {
      setState(() => _remainingSec = remain.clamp(0, 99));
    }
  }

  Future<void> _init() async {
    if (_game == null) await _refresh();
    if (!mounted || _game == null) return;
    await _connectSocket();
  }

  Future<void> _refresh() async {
    try {
      final game = await Di.minigameRepository.getWordChain(widget.gameId);
      if (!mounted) return;
      setState(() {
        _game = game;
        _loading = false;
        _errorMessage = null;
      });
      _maybeShowResult(game);
      _scrollFeed();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_game == null) _errorMessage = errorMessageOf(e);
      });
    }
  }

  Future<void> _connectSocket() async {
    final token = await Di.tokenStorage.readAccessToken();
    if (!mounted || token == null) return;
    final socket = GameSocketSession(
      topic: '/topic/wordchain/${widget.gameId}',
      accessToken: token,
      onJson: (json) => _onEvent(WordChainEvent.fromJson(json)),
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

  /// STOMP 전송 — 끊겨 있으면 조용히 실패하지 않고 사용자에게 알린다.
  bool _send(String path, [Map<String, dynamic>? body]) {
    final ok =
        _socket?.send('/app/wordchain/${widget.gameId}/$path', body) ?? false;
    if (!ok && mounted) {
      showErrorDialog(context, '실시간 연결이 끊겼어요.\n연결이 돌아오면 다시 시도해 주세요.');
    }
    return ok;
  }

  void _onEvent(WordChainEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'WORD':
        if (event.game != null) {
          setState(() => _game = event.game);
          _scrollFeed();
          if (event.userId == _myId) HapticFeedback.selectionClick();
        }
      case 'REJECTED':
        // 내 제출이 반려됐을 때만 안내 — 다른 사람 오답은 조용히.
        if (event.userId == _myId) {
          HapticFeedback.heavyImpact();
          final reason = switch (event.reason) {
            'USED' => '이미 나온 단어예요!',
            'RULE' => '끝말을 이어야 해요!',
            _ => '한글 2글자 이상으로 입력해요!',
          };
          _rejectTimer?.cancel();
          setState(() => _rejectNote = '「${event.word ?? ''}」 $reason');
          _rejectTimer = Timer(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _rejectNote = null);
          });
        }
      case 'TIMEOUT':
        if (event.game != null) {
          setState(() => _game = event.game);
          if (event.userId == _myId) {
            showAppSnackBar(context, '시간 초과로 탈락했어요 😢', isError: true);
          }
        }
      case 'STARTED':
      case 'PLAYER_JOINED':
      case 'PLAYER_DECLINED':
        if (event.game != null) {
          setState(() => _game = event.game);
          _scrollFeed();
        }
      case 'FINISHED':
        if (event.game != null) setState(() => _game = event.game);
        HapticFeedback.mediumImpact();
        _maybeShowResult(event.game ?? _game!);
      case 'CANCELED':
        if (_myId != _game?.hostUserId) {
          _showEndAndPop('방장이 방을 취소했어요.');
        }
      case 'EXPIRED':
        _showEndAndPop('게임이 만료됐어요. 다시 만들어 주세요.');
    }
  }

  void _scrollFeed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_feedScroll.hasClients) {
        _feedScroll.animateTo(
          _feedScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 액션 ─────────────────────────────────────────────────────

  Future<void> _lobbyAction(
    Future<WordChainGame> Function() action, {
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
      setState(() => _game = game);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  void _submitWord() {
    final word = _wordCtrl.text.trim();
    if (word.isEmpty) return;
    final game = _game;
    if (game == null || !game.isMyTurn(_myId)) return;
    if (!_send('word', {'word': word})) return;
    _wordCtrl.clear();
    // 내 턴 동안 연속 입력을 위해 포커스 유지.
    _inputFocus.requestFocus();
  }

  /// 기권 — 서버는 탈락 처리하고, 화면은 남아 남은 대결을 구경한다.
  void _confirmForfeit() {
    showConfirmDialog(
      context,
      title: '기권할까요?',
      message: '기권하면 탈락 처리되고, 남은 대결은 구경만 할 수 있어요.',
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
      case WordChainStatus.waiting:
        if (_myId == game.hostUserId) {
          showConfirmDialog(
            context,
            title: '방을 없앨까요?',
            message: '나가면 방이 취소되고 초대도 사라져요.',
            confirmLabel: '방 없애기',
            onConfirm: () => _lobbyAction(
              () => Di.minigameRepository.cancelWordChain(widget.gameId),
              popAfter: true,
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      case WordChainStatus.active:
        final me = game.playerOf(_myId);
        if (me != null && me.joined && !me.eliminated) {
          showConfirmDialog(
            context,
            title: '게임에서 나갈까요?',
            message: '지금 나가면 탈락 처리돼요.',
            confirmLabel: '나가기',
            onConfirm: () {
              _send('forfeit');
              Navigator.of(context).pop();
            },
          );
        } else {
          Navigator.of(context).pop();
        }
      default:
        Navigator.of(context).pop();
    }
  }

  void _maybeShowResult(WordChainGame game) {
    if (game.status != WordChainStatus.finished || _resultShown) return;
    _resultShown = true;
    final winner = game.winnerUserId;
    final iWon = winner == _myId;
    final winnerName =
        winner == null ? null : game.playerOf(winner)?.name ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => _ResultDialog(
          title: iWon ? '우승! 🏆' : '게임 종료!',
          message: winnerName == null
              ? '모두 탈락했어요. 다음엔 더 오래 버텨봐요!'
              : iWon
                  ? '마지막까지 살아남았어요!\n총 ${game.entries.length - 1}개의 단어가 이어졌어요.'
                  : '$winnerName님이 우승했어요!\n총 ${game.entries.length - 1}개의 단어가 이어졌어요.',
          won: iWon,
        ),
      );
    });
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
    final me = game?.playerOf(_myId);
    final canForfeit = game?.status == WordChainStatus.active &&
        me != null &&
        me.joined &&
        !me.eliminated;
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
                title: '끝말잇기',
                onBack: _onExit,
                actions: [
                  if (canForfeit) GameForfeitAction(onPressed: _confirmForfeit),
                ],
              ),
              if (game?.status == WordChainStatus.active)
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
      WordChainStatus.waiting => _buildLobby(game),
      WordChainStatus.active ||
      WordChainStatus.finished =>
        _buildPlaying(game),
      _ => _buildLobby(game),
    };
  }

  // ── 로비 ─────────────────────────────────────────────────────

  Widget _buildLobby(WordChainGame game) {
    final isHost = _myId == game.hostUserId;
    final me = game.playerOf(_myId);
    final joinedCount = game.joinedPlayers.length;
    final amInvitedNotJoined = me != null && !me.joined;
    return Column(
      children: [
        GameLobbyIntro(
          emoji: '🔤',
          title: '${game.hostName}님의 끝말잇기',
          subtitle: '참가 $joinedCount명 · 2명 이상 모이면 시작할 수 있어요',
          rule: '턴당 ${game.turnSeconds}초 · 시간 초과 = 탈락 · 최후의 1인이 우승!',
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
                                      .cancelWordChain(widget.gameId),
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
                                .startWordChain(widget.gameId)),
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
                                          .declineWordChain(widget.gameId),
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
                                    .joinWordChain(widget.gameId)),
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

  // ── 진행/종료 ────────────────────────────────────────────────

  Widget _buildPlaying(WordChainGame game) {
    final finished = game.status == WordChainStatus.finished;
    final myTurn = game.isMyTurn(_myId);
    final me = game.playerOf(_myId);
    final amAlive = me != null && me.joined && !me.eliminated;
    return Column(
      children: [
        _buildTurnBar(game, finished),
        const SizedBox(height: 6),
        _buildPlayersRow(game),
        const Divider(height: 18, color: AppColors.gray100),
        Expanded(child: _buildWordFeed(game)),
        if (_rejectNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _rejectNote!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        if (finished)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: GamePrimaryButton(
                label: '나가기',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          )
        else if (amAlive)
          _buildInput(game, myTurn)
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '탈락했어요 — 남은 대결을 구경할 수 있어요 👀',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.gray500,
              ),
            ),
          ),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 4 : 8),
      ],
    );
  }

  Widget _buildTurnBar(WordChainGame game, bool finished) {
    final lastChar =
        game.lastWord?.characters.last ?? '';
    final turnName = game.currentTurnUserId == null
        ? ''
        : game.playerOf(game.currentTurnUserId!)?.name ?? '';
    final myTurn = game.isMyTurn(_myId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: GameCard(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        accent: myTurn ? AppColors.primary : null,
        child: Row(
        children: [
          // 이어야 할 글자 — 큼직한 원.
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF9A86), AppColors.primary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              lastChar,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finished
                      ? '게임이 끝났어요!'
                      : myTurn
                          ? '내 차례! 「$lastChar」(으)로 시작하는 단어!'
                          : '$turnName님 차례...',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: myTurn ? AppColors.primary : AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '단어 ${game.entries.length - 1}개째 이어지는 중',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 11.5,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          if (!finished)
            GameCountdownPill(seconds: _remainingSec, urgentAt: 5, suffix: '초'),
        ],
        ),
      ),
    );
  }

  /// 참가자 칩 줄 — 탈락자는 흐리게 + ❌.
  Widget _buildPlayersRow(WordChainGame game) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final p in game.joinedPlayers) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.eliminated
                    ? AppColors.gray50
                    : game.currentTurnUserId == p.userId
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : AppColors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: p.eliminated
                      ? AppColors.gray200
                      : game.currentTurnUserId == p.userId
                          ? AppColors.primary
                          : AppColors.gray200,
                ),
              ),
              child: Text(
                p.eliminated
                    ? '❌ ${p.name}'
                    : p.userId == _myId
                        ? '${p.name} (나)'
                        : p.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: p.eliminated
                      ? AppColors.gray400
                      : AppColors.gray800,
                  decoration:
                      p.eliminated ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildWordFeed(WordChainGame game) {
    return ListView.builder(
      controller: _feedScroll,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      itemCount: game.entries.length,
      itemBuilder: (context, i) {
        final e = game.entries[i];
        final isStart = e.userId == null;
        final isMine = e.userId == _myId;
        if (isStart) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '🎬 시작 단어: ${e.word}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.gray900,
                  ),
                ),
              ),
            ),
          );
        }
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 6, bottom: 1),
                  child: Text(
                    e.userName ?? '',
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
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.primary
                        : AppColors.gray50,
                    borderRadius: BorderRadius.circular(16),
                    border: isMine
                        ? null
                        : Border.all(color: AppColors.gray100),
                  ),
                  child: Text(
                    e.word,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isMine ? Colors.white : AppColors.gray900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput(WordChainGame game, bool myTurn) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _wordCtrl,
              focusNode: _inputFocus,
              enabled: myTurn,
              onSubmitted: (_) => _submitWord(),
              textInputAction: TextInputAction.send,
              maxLength: 15,
              decoration: InputDecoration(
                counterText: '',
                hintText: myTurn
                    ? '「${game.lastWord?.characters.last ?? ''}」(으)로 시작하는 단어'
                    : '내 차례를 기다리는 중...',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  color: AppColors.gray400,
                ),
                filled: true,
                fillColor: myTurn ? AppColors.white : AppColors.gray100,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: myTurn ? AppColors.primary : AppColors.gray100,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.gray100),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.gray900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: myTurn ? _submitWord : null,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: myTurn ? gamePrimaryGradient : null,
                color: myTurn ? null : AppColors.gray200,
                shape: BoxShape.circle,
                boxShadow: myTurn
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: const Icon(Icons.send_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.title,
    required this.message,
    required this.won,
  });

  final String title;
  final String message;
  final bool won;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(won ? '🏆' : '🔤', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
