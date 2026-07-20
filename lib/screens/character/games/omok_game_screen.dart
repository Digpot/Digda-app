import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/omok/data/omok_socket.dart';
import '../../../features/omok/models/omok_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/ad_banner.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/back_header.dart';

/// 실시간 오목 대국 화면 — 초대 수락 전(invitee)/대기(inviter)/대국/결과를
/// 한 화면에서 상태로 전환한다.
///
/// 서버가 보드/턴/승패의 진실 출처: 착수는 STOMP 로 보내기만 하고, 화면 갱신은
/// `/topic/omok/{gameId}` 이벤트의 전체 스냅샷으로만 한다. 재연결 시 REST 로
/// 스냅샷을 다시 받아 놓친 수를 메꾼다.
class OmokGameScreen extends StatefulWidget {
  const OmokGameScreen({super.key, required this.gameId, this.initialGame});

  final int gameId;
  final OmokGame? initialGame;

  @override
  State<OmokGameScreen> createState() => _OmokGameScreenState();
}

class _OmokGameScreenState extends State<OmokGameScreen> {
  OmokGame? _game;
  bool _loading = true;
  String? _errorMessage;
  bool _actionPending = false;
  bool _resultShown = false;
  OmokSocketSession? _socket;

  /// 착수 확인 대기 좌표 — 탭하면 바로 두지 않고 반투명 미리보기 돌을 놓고
  /// 확인을 받는다(작은 화면 오터치 방지). 같은 칸 재탭 = 확정.
  int? _pendingX;
  int? _pendingY;

  String get _myId => Di.userSession.profile?.id ?? '';

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loading = _game == null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_game == null) await _refresh();
    if (!mounted || _game == null) return;
    await _connectSocket();
  }

  Future<void> _refresh() async {
    try {
      final game = await Di.omokRepository.get(widget.gameId);
      if (!mounted) return;
      setState(() {
        _game = game;
        _loading = false;
        _errorMessage = null;
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
    final socket = OmokSocketSession(
      gameId: widget.gameId,
      accessToken: token,
      onEvent: _onEvent,
      // (재)연결 직후 스냅샷 재동기화 — 연결 사이에 놓친 수를 메꾼다.
      onConnected: () {
        if (mounted) _refresh();
      },
    );
    _socket = socket;
    socket.connect();
  }

  void _onEvent(OmokEvent event) {
    if (!mounted) return;
    setState(() {
      _game = event.game;
      // 내 착수가 반영됐거나 턴이 넘어갔으면 미리보기는 무효.
      if (!event.game.isMyTurn(_myId)) {
        _pendingX = null;
        _pendingY = null;
      }
    });
    final game = event.game;
    switch (game.status) {
      case OmokStatus.finished:
        HapticFeedback.mediumImpact();
        _maybeShowResult(game);
      case OmokStatus.declined:
        if (_myId == game.inviterUserId) {
          _showEndAndPop('${game.inviteeName}님이 초대를 거절했어요.');
        }
      case OmokStatus.canceled:
        if (_myId == game.inviteeUserId) {
          _showEndAndPop('${game.inviterName}님이 초대를 취소했어요.');
        }
      case OmokStatus.expired:
        _showEndAndPop('대국이 만료됐어요. 다시 초대해 주세요.');
      case OmokStatus.waiting:
      case OmokStatus.active:
        break;
    }
  }

  // ── 액션 ─────────────────────────────────────────────────────

  Future<void> _accept() async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      final game = await Di.omokRepository.accept(widget.gameId);
      if (!mounted) return;
      setState(() => _game = game);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _decline() async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      await Di.omokRepository.decline(widget.gameId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionPending = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _cancelInvite() async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      await Di.omokRepository.cancel(widget.gameId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionPending = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  void _onCellTap(int x, int y) {
    final game = _game;
    if (game == null || !game.isMyTurn(_myId)) return;
    if (game.board[y][x] != 0) return;
    // 같은 칸 재탭 = 확정, 다른 칸 = 미리보기 이동.
    if (_pendingX == x && _pendingY == y) {
      _confirmMove();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _pendingX = x;
      _pendingY = y;
    });
  }

  void _confirmMove() {
    final x = _pendingX;
    final y = _pendingY;
    final game = _game;
    if (x == null || y == null || game == null || !game.isMyTurn(_myId)) return;
    if (game.board[y][x] != 0) {
      setState(() {
        _pendingX = null;
        _pendingY = null;
      });
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _pendingX = null;
      _pendingY = null;
    });
    _socket?.sendMove(x, y);
  }

  void _cancelPendingMove() {
    setState(() {
      _pendingX = null;
      _pendingY = null;
    });
  }

  void _confirmForfeit() {
    showConfirmDialog(
      context,
      title: '기권할까요?',
      message: '기권하면 상대의 승리로 대국이 끝나요.',
      confirmLabel: '기권',
      onConfirm: () => _socket?.sendForfeit(),
    );
  }

  /// 뒤로가기 — 상태별로 안전하게 정리하고 나간다.
  void _onExit() {
    final game = _game;
    if (game == null) {
      Navigator.of(context).pop();
      return;
    }
    switch (game.status) {
      case OmokStatus.active:
        showConfirmDialog(
          context,
          title: '대국을 나갈까요?',
          message: '지금 나가면 기권 처리돼요.',
          confirmLabel: '나가기',
          onConfirm: () {
            _socket?.sendForfeit();
            Navigator.of(context).pop();
          },
        );
      case OmokStatus.waiting:
        if (_myId == game.inviterUserId) {
          _cancelInvite();
        } else {
          Navigator.of(context).pop();
        }
      default:
        Navigator.of(context).pop();
    }
  }

  // ── 결과 처리 ────────────────────────────────────────────────

  void _maybeShowResult(OmokGame game) {
    if (game.status != OmokStatus.finished || _resultShown) return;
    _resultShown = true;
    final isDraw = game.winnerUserId == null;
    final iWon = game.winnerUserId == _myId;
    final title = isDraw ? '무승부!' : (iWon ? '승리! 🏆' : '패배...');
    final reason = switch (game.finishReason) {
      'FORFEIT' => iWon ? '상대가 기권했어요.' : '기권으로 대국이 끝났어요.',
      'DRAW' => '판이 가득 찼어요. 명승부였어요!',
      _ => isDraw
          ? '명승부였어요!'
          : (iWon ? '오목을 완성했어요!' : '${game.nameOf(game.winnerUserId!)}님이 오목을 완성했어요.'),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => _ResultDialog(title: title, message: reason, won: iWon && !isDraw),
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
              BackHeader(title: '오목', onBack: _onExit),
              Expanded(child: _buildBody()),
              // 배너 광고 — 대국 화면 하단 고정(미로드 시 공간 0).
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
            _errorMessage ?? '대국을 찾을 수 없어요.',
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
    if (game.status == OmokStatus.waiting) {
      return _myId == game.inviteeUserId
          ? _buildInvitePrompt(game)
          : _buildWaiting(game);
    }
    return _buildBoard(game);
  }

  /// 초대받은 사람 — 수락/거절 카드.
  Widget _buildInvitePrompt(OmokGame game) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚫⚪', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(
              '${game.inviterName}님의 오목 초대',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '수락하면 바로 대국이 시작돼요.\n초대한 사람이 흑돌(선공)이에요.',
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
                      onPressed: _actionPending ? null : _decline,
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
                      onPressed: _actionPending ? null : _accept,
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

  /// 초대한 사람 — 상대 수락 대기.
  Widget _buildWaiting(OmokGame game) {
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
              onPressed: _actionPending ? null : _cancelInvite,
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

  Widget _buildBoard(OmokGame game) {
    final finished = game.status == OmokStatus.finished;
    return Column(
      children: [
        const SizedBox(height: 8),
        _PlayersBar(game: game, myId: _myId),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 1,
            child: _OmokBoard(
              game: game,
              onCellTap: _onCellTap,
              pendingX: _pendingX,
              pendingY: _pendingY,
              pendingStone: game.stoneOf(_myId),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!finished)
          _pendingX != null
              ? _buildMoveConfirmBar()
              : Text(
                  game.isMyTurn(_myId)
                      ? '내 차례예요 — 자리를 골라주세요!'
                      : '상대의 차례를 기다리는 중...',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: game.isMyTurn(_myId)
                        ? AppColors.primary
                        : AppColors.gray500,
                  ),
                ),
        const Spacer(),
        if (!finished)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton.icon(
              onPressed: _confirmForfeit,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('기권'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray600,
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
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

  /// 미리보기 돌 확정 바 — "여기에 둘까요?" + 취소/착수.
  Widget _buildMoveConfirmBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '여기에 둘까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed: _cancelPendingMove,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gray600,
              side: const BorderSide(color: AppColors.gray200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _confirmMove,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              '착수!',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 상단 플레이어 바 — 흑/백 배지 + 이름, 현재 턴 하이라이트.
class _PlayersBar extends StatelessWidget {
  const _PlayersBar({required this.game, required this.myId});

  final OmokGame game;
  final String myId;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String name,
      required bool isBlack,
      required bool isTurn,
      required bool isMe,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isTurn ? AppColors.primary.withValues(alpha: 0.08) : AppColors.gray50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isTurn ? AppColors.primary : AppColors.gray100,
            width: isTurn ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isBlack
                    ? const RadialGradient(
                        center: Alignment(-0.4, -0.4),
                        colors: [Color(0xFF555555), Color(0xFF111111)],
                      )
                    : const RadialGradient(
                        center: Alignment(-0.4, -0.4),
                        colors: [Colors.white, Color(0xFFCFCFCF)],
                      ),
                border: isBlack ? null : Border.all(color: const Color(0xFFAAAAAA)),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              isMe ? '$name (나)' : name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: isTurn ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                color: AppColors.gray900,
              ),
            ),
          ],
        ),
      );
    }

    final blackTurn = game.currentTurnUserId == game.inviterUserId;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(
          name: game.inviterName,
          isBlack: true,
          isTurn: game.status == OmokStatus.active && blackTurn,
          isMe: myId == game.inviterUserId,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'VS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.gray400,
            ),
          ),
        ),
        chip(
          name: game.inviteeName,
          isBlack: false,
          isTurn: game.status == OmokStatus.active && !blackTurn,
          isMe: myId == game.inviteeUserId,
        ),
      ],
    );
  }
}

/// 오목판 — 탭 좌표를 교차점 셀로 환산해 [onCellTap] 으로 전달.
/// [pendingX]/[pendingY] 가 있으면 그 자리에 내 돌([pendingStone])의
/// 반투명 미리보기 + 하이라이트 링을 그린다.
class _OmokBoard extends StatelessWidget {
  const _OmokBoard({
    required this.game,
    required this.onCellTap,
    this.pendingX,
    this.pendingY,
    this.pendingStone = OmokGame.black,
  });

  final OmokGame game;
  final void Function(int x, int y) onCellTap;
  final int? pendingX;
  final int? pendingY;
  final int pendingStone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final cell = size / OmokGame.boardSize;
        return GestureDetector(
          onTapUp: (details) {
            final x = (details.localPosition.dx / cell - 0.5).round();
            final y = (details.localPosition.dy / cell - 0.5).round();
            if (x < 0 ||
                y < 0 ||
                x >= OmokGame.boardSize ||
                y >= OmokGame.boardSize) {
              return;
            }
            onCellTap(x, y);
          },
          child: CustomPaint(
            size: Size.square(size),
            painter: _OmokBoardPainter(
              game: game,
              pendingX: pendingX,
              pendingY: pendingY,
              pendingStone: pendingStone,
            ),
          ),
        );
      },
    );
  }
}

class _OmokBoardPainter extends CustomPainter {
  _OmokBoardPainter({
    required this.game,
    this.pendingX,
    this.pendingY,
    this.pendingStone = OmokGame.black,
  });

  final OmokGame game;
  final int? pendingX;
  final int? pendingY;
  final int pendingStone;

  static const _n = OmokGame.boardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _n;
    final half = cell / 2;

    // 바둑판 배경 — 원목 톤.
    final bg = Paint()..color = const Color(0xFFEFD1A0);
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(rrect, bg);

    // 격자선.
    final line = Paint()
      ..color = const Color(0xFF9A7546)
      ..strokeWidth = 1;
    for (var i = 0; i < _n; i++) {
      final p = half + i * cell;
      canvas.drawLine(Offset(half, p), Offset(size.width - half, p), line);
      canvas.drawLine(Offset(p, half), Offset(p, size.height - half), line);
    }

    // 화점 5개.
    final star = Paint()..color = const Color(0xFF7C5C33);
    for (final (sx, sy) in const [(3, 3), (11, 3), (7, 7), (3, 11), (11, 11)]) {
      canvas.drawCircle(Offset(half + sx * cell, half + sy * cell), 2.6, star);
    }

    // 승리 라인 하이라이트 — 돌 아래 깔리는 링.
    if (game.winningLine.isNotEmpty) {
      final glow = Paint()
        ..color = const Color(0xFFFFC24B).withValues(alpha: 0.55);
      for (final c in game.winningLine) {
        canvas.drawCircle(
          Offset(half + c[0] * cell, half + c[1] * cell),
          half * 0.95,
          glow,
        );
      }
    }

    // 돌.
    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final stone = game.board[y][x];
        if (stone == 0) continue;
        final center = Offset(half + x * cell, half + y * cell);
        final r = half * 0.82;
        final shadow = Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        canvas.drawCircle(center.translate(0.6, 1.2), r, shadow);
        final paint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: stone == OmokGame.black
                ? const [Color(0xFF5A5A5A), Color(0xFF101010)]
                : const [Colors.white, Color(0xFFC9C9C9)],
          ).createShader(Rect.fromCircle(center: center, radius: r));
        canvas.drawCircle(center, r, paint);
        if (stone == OmokGame.white) {
          final border = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFF9F9F9F);
          canvas.drawCircle(center, r, border);
        }
      }
    }

    // 착수 미리보기 — 반투명 내 돌 + 코랄 하이라이트 링.
    final px = pendingX;
    final py = pendingY;
    if (px != null && py != null && game.board[py][px] == 0) {
      final center = Offset(half + px * cell, half + py * cell);
      final r = half * 0.82;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFFFF6B6B);
      canvas.drawCircle(center, half * 1.02, ring);
      final ghost = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: pendingStone == OmokGame.black
              ? const [Color(0xFF5A5A5A), Color(0xFF101010)]
              : const [Colors.white, Color(0xFFC9C9C9)],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.saveLayer(
        Rect.fromCircle(center: center, radius: r + 2),
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
      canvas.drawCircle(center, r, ghost);
      if (pendingStone == OmokGame.white) {
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFF9F9F9F),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OmokBoardPainter oldDelegate) => true;
}

/// 대국 결과 다이얼로그.
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
            Text(won ? '🏆' : '⚫⚪', style: const TextStyle(fontSize: 44)),
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
