import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/minigame/data/game_socket.dart';
import '../../../features/minigame/models/minigame_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/center_title_header.dart';

/// 실시간 탭배틀 — 각자 폰에서 15초 동안 연타, 서버가 심판.
///
/// 초대 수락 전(invitee)/대기(inviter)/3초 카운트다운/연타/결과를 한 화면에서
/// 상태로 전환한다. 내 탭은 즉시 로컬 반영하고 400ms 주기로 누적 수를 서버에
/// 보고, 상대 수는 SCORE 이벤트로 받는다. 종료 판정은 서버(FINISHED)가 한다.
class TapBattleScreen extends StatefulWidget {
  const TapBattleScreen({super.key, required this.gameId, this.initialGame});

  final int gameId;
  final TapBattleGame? initialGame;

  @override
  State<TapBattleScreen> createState() => _TapBattleScreenState();
}

class _TapBattleScreenState extends State<TapBattleScreen> {
  TapBattleGame? _game;
  bool _loading = true;
  String? _errorMessage;
  bool _actionPending = false;
  bool _resultShown = false;
  GameSocketSession? _socket;

  /// 내 탭 수 — 로컬이 진실(내 화면), 서버 보고는 주기적.
  int _myTaps = 0;
  Timer? _reportTimer;
  Timer? _ticker;

  String get _myId => Di.userSession.profile?.id ?? '';

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loading = _game == null;
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      // 카운트다운/남은 시간 표시 갱신용.
      if (mounted && _game?.status == TapBattleStatus.active) setState(() {});
    });
    _reportTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_game?.status == TapBattleStatus.active && _inBattle) {
        _socket?.send(
          '/app/tapbattle/${widget.gameId}/taps',
          {'taps': _myTaps},
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _socket?.dispose();
    _reportTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (_game == null) await _refresh();
    if (!mounted || _game == null) return;
    // 재입장 시 서버가 기억하는 내 탭 수부터 이어간다.
    final g = _game!;
    if (g.isParticipant(_myId)) _myTaps = g.tapsOf(_myId);
    await _connectSocket();
  }

  Future<void> _refresh() async {
    try {
      final game = await Di.minigameRepository.getTapBattle(widget.gameId);
      if (!mounted) return;
      setState(() {
        _game = game;
        _loading = false;
        _errorMessage = null;
        if (game.tapsOf(_myId) > _myTaps) _myTaps = game.tapsOf(_myId);
      });
      _maybeShowResult(game);
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
      topic: '/topic/tapbattle/${widget.gameId}',
      accessToken: token,
      onJson: (json) => _onEvent(TapBattleEvent.fromJson(json)),
      onConnected: () {
        if (mounted) _refresh();
      },
    );
    _socket = socket;
    socket.connect();
  }

  void _onEvent(TapBattleEvent event) {
    if (!mounted) return;
    final game = event.game;
    setState(() {
      _game = game;
      if (game.tapsOf(_myId) > _myTaps) _myTaps = game.tapsOf(_myId);
    });
    switch (game.status) {
      case TapBattleStatus.finished:
        HapticFeedback.heavyImpact();
        _maybeShowResult(game);
      case TapBattleStatus.declined:
        if (_myId == game.inviterUserId) {
          _showEndAndPop('${game.inviteeName}님이 초대를 거절했어요.');
        }
      case TapBattleStatus.canceled:
        if (_myId == game.inviteeUserId) {
          _showEndAndPop('${game.inviterName}님이 초대를 취소했어요.');
        }
      case TapBattleStatus.expired:
        _showEndAndPop('대결이 만료됐어요. 다시 초대해 주세요.');
      case TapBattleStatus.waiting:
      case TapBattleStatus.active:
        break;
    }
  }

  // ── 시간 상태 ────────────────────────────────────────────────

  /// 카운트다운(3→1) 남은 초. 0 이하면 전투 중.
  int get _countdownRemain {
    final start = _game?.countdownStartEpochMs;
    if (start == null) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - start;
    return ((3000 - elapsed) / 1000).ceil().clamp(0, 3);
  }

  bool get _inBattle =>
      _game?.status == TapBattleStatus.active && _countdownRemain <= 0;

  /// 전투 남은 초.
  int get _battleRemain {
    final end = _game?.battleEndEpochMs;
    if (end == null) return 0;
    return ((end - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, 99);
  }

  // ── 액션 ─────────────────────────────────────────────────────

  Future<void> _restAction(
    Future<TapBattleGame> Function() action, {
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

  void _onTapPad() {
    if (!_inBattle || _battleRemain <= 0) return;
    HapticFeedback.selectionClick();
    setState(() => _myTaps++);
  }

  void _onExit() {
    final game = _game;
    if (game == null) {
      Navigator.of(context).pop();
      return;
    }
    switch (game.status) {
      case TapBattleStatus.active:
        showConfirmDialog(
          context,
          title: '대결을 나갈까요?',
          message: '지금 나가면 기권 처리돼요.',
          confirmLabel: '나가기',
          onConfirm: () {
            _socket?.send('/app/tapbattle/${widget.gameId}/forfeit');
            Navigator.of(context).pop();
          },
        );
      case TapBattleStatus.waiting:
        if (_myId == game.inviterUserId) {
          _restAction(
            () => Di.minigameRepository.cancelTapBattle(widget.gameId),
            popAfter: true,
          );
        } else {
          Navigator.of(context).pop();
        }
      default:
        Navigator.of(context).pop();
    }
  }

  void _maybeShowResult(TapBattleGame game) {
    if (game.status != TapBattleStatus.finished || _resultShown) return;
    _resultShown = true;
    final isDraw = game.winnerUserId == null;
    final iWon = game.winnerUserId == _myId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => _ResultDialog(
          title: isDraw ? '무승부!' : (iWon ? '승리! 🏆' : '패배...'),
          message: isDraw
              ? '${game.inviterTaps} : ${game.inviteeTaps} — 완벽한 동점이에요!'
              : '${game.nameOf(game.winnerUserId!)}님이 '
                  '${game.inviterTaps} : ${game.inviteeTaps} 로 이겼어요!',
          won: iWon && !isDraw,
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
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              CenterTitleHeader(title: '탭배틀', onBack: _onExit),
              Expanded(child: _buildBody()),
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
            _errorMessage ?? '대결을 찾을 수 없어요.',
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
    if (game.status == TapBattleStatus.waiting) {
      return _myId == game.inviteeUserId
          ? _buildInvitePrompt(game)
          : _buildWaiting(game);
    }
    return _buildBattle(game);
  }

  Widget _buildInvitePrompt(TapBattleGame game) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👆⚡', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(
              '${game.inviterName}님의 탭배틀 초대',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '수락하면 3초 카운트다운 후 바로 시작!\n15초 동안 더 많이 탭하면 승리해요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _actionPending
                          ? null
                          : () => _restAction(
                                () => Di.minigameRepository
                                    .declineTapBattle(widget.gameId),
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
                          : () => _restAction(() => Di.minigameRepository
                              .acceptTapBattle(widget.gameId)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _actionPending ? '수락 중...' : '수락',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting(TapBattleGame game) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              '${game.inviteeName}님의 수락을 기다리는 중...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '상대에게 초대 알림을 보냈어요.\n10분 안에 수락하지 않으면 초대가 만료돼요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                height: 1.5,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: _actionPending
                  ? null
                  : () => _restAction(
                        () => Di.minigameRepository
                            .cancelTapBattle(widget.gameId),
                        popAfter: true,
                      ),
              child: const Text(
                '초대 취소',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.gray600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattle(TapBattleGame game) {
    final finished = game.status == TapBattleStatus.finished;
    final countdown = _countdownRemain;
    final opponentId = game.opponentIdOf(_myId);
    final opponentTaps = game.tapsOf(opponentId);
    final myShown = finished ? game.tapsOf(_myId) : _myTaps;
    final total = myShown + opponentTaps;
    final myRatio = total == 0 ? 0.5 : myShown / total;
    const opponentColor = Color(0xFF45B7D1);

    return Column(
      children: [
        const SizedBox(height: 8),
        // 스코어 보드.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _ScoreCard(
                  name: '나',
                  taps: myShown,
                  accent: AppColors.primary,
                  highlight: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  finished
                      ? '끝!'
                      : countdown > 0
                          ? '$countdown'
                          : '$_battleRemain초',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: countdown > 0 ? 30 : 18,
                    color: countdown > 0
                        ? AppColors.primary
                        : AppColors.gray900,
                  ),
                ),
              ),
              Expanded(
                child: _ScoreCard(
                  name: game.nameOf(opponentId),
                  taps: opponentTaps,
                  accent: opponentColor,
                  highlight: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 줄다리기 바.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (myRatio * 1000).round().clamp(1, 999),
                    child: Container(color: AppColors.primary),
                  ),
                  Expanded(
                    flex: ((1 - myRatio) * 1000).round().clamp(1, 999),
                    child: Container(color: opponentColor),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 탭 패드.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _onTapPad(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _inBattle && !finished
                        ? const [Color(0xFFFF8A8A), Color(0xFFFF6B6B)]
                        : const [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: _inBattle && !finished
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        finished
                            ? '🏁'
                            : countdown > 0
                                ? '준비...'
                                : '👆',
                        style: TextStyle(
                          fontSize: countdown > 0 ? 26 : 54,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        finished
                            ? '대결 종료!'
                            : countdown > 0
                                ? '곧 시작해요!'
                                : '미친 듯이 탭!!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: _inBattle && !finished
                              ? Colors.white
                              : AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (finished)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.name,
    required this.taps,
    required this.accent,
    required this.highlight,
  });

  final String name;
  final int taps;
  final Color accent;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: highlight ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: accent,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$taps',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 30,
              color: accent,
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
            Text(won ? '🏆' : '👆⚡', style: const TextStyle(fontSize: 44)),
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
