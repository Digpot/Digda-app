import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/minigame/data/game_socket.dart';
import '../../../features/minigame/models/minigame_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/center_title_header.dart';

/// 실시간 두더지 잡기 대결 — 서버가 준 공유 시드로 양쪽이 **같은 두더지 판**을
/// 재현하고, 30초 동안 각자 폰에서 잡은 점수로 겨룬다.
///
/// - 일반 두더지 +1 · 황금 두더지 +3 · 폭탄 💣 -2 (0점 아래로는 안 내려감)
/// - 채점은 로컬(즉각 반응), 400ms 주기로 서버에 보고 — 상대 점수는 SCORE 이벤트.
/// - 종료 판정은 서버(FINISHED).
class MoleBattleScreen extends StatefulWidget {
  const MoleBattleScreen({super.key, required this.gameId, this.initialGame});

  final int gameId;
  final MoleBattleGame? initialGame;

  @override
  State<MoleBattleScreen> createState() => _MoleBattleScreenState();
}

/// 스폰 이벤트 — [startMs] 는 전투 시작 기준 경과 시각.
class _Spawn {
  const _Spawn({required this.startMs, required this.hole, required this.kind});
  final int startMs;
  final int hole;
  final _MoleKind kind;
}

enum _MoleKind { normal, golden, bomb }

class _MoleBattleScreenState extends State<MoleBattleScreen> {
  static const int _spawnIntervalMs = 600;
  static const int _visibleMs = 800;
  static const int _holeCount = 9;

  MoleBattleGame? _game;
  bool _loading = true;
  String? _errorMessage;
  bool _actionPending = false;
  bool _resultShown = false;
  GameSocketSession? _socket;

  List<_Spawn> _spawns = const [];
  final Set<int> _whacked = {};
  int _myScore = 0;

  /// 홀별 최근 타격 피드백 — (문구, 색, 만료 epoch ms).
  final Map<int, (String, Color, int)> _feedback = {};

  Timer? _frameTimer;
  Timer? _reportTimer;

  String get _myId => Di.userSession.profile?.id ?? '';

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loading = _game == null;
    _frameTimer = Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (mounted && _game?.status == MoleBattleStatus.active) setState(() {});
    });
    _reportTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_game?.status == MoleBattleStatus.active && _inBattle) {
        _socket?.send(
          '/app/molebattle/${widget.gameId}/score',
          {'score': _myScore},
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _socket?.dispose();
    _frameTimer?.cancel();
    _reportTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (_game == null) await _refresh();
    if (!mounted || _game == null) return;
    _prepareSpawns(_game!);
    final g = _game!;
    if (g.isParticipant(_myId)) _myScore = g.scoreOf(_myId);
    await _connectSocket();
  }

  Future<void> _refresh() async {
    try {
      final game = await Di.minigameRepository.getMoleBattle(widget.gameId);
      if (!mounted) return;
      setState(() {
        _game = game;
        _loading = false;
        _errorMessage = null;
        _prepareSpawns(game);
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

  /// 시드로 30초 분량의 스폰 스케줄을 결정적으로 생성 — 양쪽이 같은 판.
  void _prepareSpawns(MoleBattleGame game) {
    final seed = game.spawnSeed;
    if (seed == null || _spawns.isNotEmpty) return;
    final rng = math.Random(seed);
    final spawns = <_Spawn>[];
    var prevHole = -1;
    for (var i = 0; i < 30000 ~/ _spawnIntervalMs; i++) {
      int hole;
      do {
        hole = rng.nextInt(_holeCount);
      } while (hole == prevHole);
      prevHole = hole;
      final roll = rng.nextDouble();
      final kind = roll < 0.12
          ? _MoleKind.golden
          : roll < 0.32
              ? _MoleKind.bomb
              : _MoleKind.normal;
      spawns.add(_Spawn(startMs: i * _spawnIntervalMs, hole: hole, kind: kind));
    }
    _spawns = spawns;
  }

  Future<void> _connectSocket() async {
    final token = await Di.tokenStorage.readAccessToken();
    if (!mounted || token == null) return;
    final socket = GameSocketSession(
      topic: '/topic/molebattle/${widget.gameId}',
      accessToken: token,
      onJson: (json) => _onEvent(MoleBattleEvent.fromJson(json)),
      onConnected: () {
        if (mounted) _refresh();
      },
    );
    _socket = socket;
    socket.connect();
  }

  void _onEvent(MoleBattleEvent event) {
    if (!mounted) return;
    final game = event.game;
    setState(() {
      _game = game;
      _prepareSpawns(game);
    });
    switch (game.status) {
      case MoleBattleStatus.finished:
        HapticFeedback.heavyImpact();
        _maybeShowResult(game);
      case MoleBattleStatus.declined:
        if (_myId == game.inviterUserId) {
          _showEndAndPop('${game.inviteeName}님이 초대를 거절했어요.');
        }
      case MoleBattleStatus.canceled:
        if (_myId == game.inviteeUserId) {
          _showEndAndPop('${game.inviterName}님이 초대를 취소했어요.');
        }
      case MoleBattleStatus.expired:
        _showEndAndPop('대결이 만료됐어요. 다시 초대해 주세요.');
      case MoleBattleStatus.waiting:
      case MoleBattleStatus.active:
        break;
    }
  }

  // ── 시간 상태 ────────────────────────────────────────────────

  int get _countdownRemain {
    final start = _game?.countdownStartEpochMs;
    if (start == null) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - start;
    return ((3000 - elapsed) / 1000).ceil().clamp(0, 3);
  }

  bool get _inBattle =>
      _game?.status == MoleBattleStatus.active && _countdownRemain <= 0;

  int get _battleRemain {
    final end = _game?.battleEndEpochMs;
    if (end == null) return 0;
    return ((end - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, 99);
  }

  /// 전투 시작 이후 경과 ms — 스폰 스케줄 재생 기준점.
  int get _battleElapsedMs {
    final start = _game?.countdownStartEpochMs;
    if (start == null) return -1;
    return DateTime.now().millisecondsSinceEpoch - start - 3000;
  }

  /// 지금 [hole] 에 떠 있는(아직 안 잡힌) 스폰. 없으면 null.
  _Spawn? _activeSpawnAt(int hole, int elapsed) {
    for (final s in _spawns) {
      if (s.hole != hole) continue;
      if (s.startMs > elapsed) break;
      if (elapsed < s.startMs + _visibleMs &&
          !_whacked.contains(s.startMs)) {
        return s;
      }
    }
    return null;
  }

  // ── 액션 ─────────────────────────────────────────────────────

  void _whack(int hole) {
    if (!_inBattle || _battleRemain <= 0) return;
    final elapsed = _battleElapsedMs;
    final spawn = _activeSpawnAt(hole, elapsed);
    if (spawn == null) return;
    _whacked.add(spawn.startMs);
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      switch (spawn.kind) {
        case _MoleKind.normal:
          _myScore += 1;
          _feedback[hole] = ('+1', AppColors.primary, now + 500);
          HapticFeedback.selectionClick();
        case _MoleKind.golden:
          _myScore += 3;
          _feedback[hole] = ('+3', const Color(0xFFE8A100), now + 550);
          HapticFeedback.mediumImpact();
        case _MoleKind.bomb:
          _myScore = (_myScore - 2).clamp(0, 999);
          _feedback[hole] = ('-2', const Color(0xFF64748B), now + 550);
          HapticFeedback.heavyImpact();
      }
    });
  }

  Future<void> _restAction(
    Future<MoleBattleGame> Function() action, {
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
        _prepareSpawns(game);
      });
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  void _onExit() {
    final game = _game;
    if (game == null) {
      Navigator.of(context).pop();
      return;
    }
    switch (game.status) {
      case MoleBattleStatus.active:
        showConfirmDialog(
          context,
          title: '대결을 나갈까요?',
          message: '지금 나가면 기권 처리돼요.',
          confirmLabel: '나가기',
          onConfirm: () {
            _socket?.send('/app/molebattle/${widget.gameId}/forfeit');
            Navigator.of(context).pop();
          },
        );
      case MoleBattleStatus.waiting:
        if (_myId == game.inviterUserId) {
          _restAction(
            () => Di.minigameRepository.cancelMoleBattle(widget.gameId),
            popAfter: true,
          );
        } else {
          Navigator.of(context).pop();
        }
      default:
        Navigator.of(context).pop();
    }
  }

  void _maybeShowResult(MoleBattleGame game) {
    if (game.status != MoleBattleStatus.finished || _resultShown) return;
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
              ? '${game.inviterScore} : ${game.inviteeScore} — 완벽한 동점이에요!'
              : '${game.nameOf(game.winnerUserId!)}님이 '
                  '${game.inviterScore} : ${game.inviteeScore} 로 이겼어요!',
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
              CenterTitleHeader(title: '두더지 잡기', onBack: _onExit),
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
    if (game.status == MoleBattleStatus.waiting) {
      return _myId == game.inviteeUserId
          ? _buildInvitePrompt(game)
          : _buildWaiting(game);
    }
    return _buildBattle(game);
  }

  Widget _buildInvitePrompt(MoleBattleGame game) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔨', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(
              '${game.inviterName}님의 두더지 잡기 초대',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '수락하면 3초 후 같은 두더지 판에서 시작!\n30초 동안 더 많이 잡으면 승리해요.\n황금 두더지 +3 · 폭탄은 -2 조심!',
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
                                    .declineMoleBattle(widget.gameId),
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
                              .acceptMoleBattle(widget.gameId)),
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

  Widget _buildWaiting(MoleBattleGame game) {
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
                            .cancelMoleBattle(widget.gameId),
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

  Widget _buildBattle(MoleBattleGame game) {
    final finished = game.status == MoleBattleStatus.finished;
    final countdown = _countdownRemain;
    final opponentId = game.opponentIdOf(_myId);
    final opponentScore = game.scoreOf(opponentId);
    final myShown = finished ? game.scoreOf(_myId) : _myScore;
    final elapsed = _battleElapsedMs;
    const opponentColor = Color(0xFF45B7D1);

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _ScoreCard(
                  name: '나',
                  score: myShown,
                  accent: AppColors.primary,
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
                  score: opponentScore,
                  accent: opponentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 두더지 밭 — 3×3 잔디 그리드.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFBCE49A), Color(0xFF8FCB66)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  for (var row = 0; row < 3; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < 3; col++)
                            Expanded(
                              child: _buildHole(row * 3 + col, elapsed),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (finished)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
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
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              '🐾 일반 +1 · ✨ 황금 +3 · 💣 폭탄 -2',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.gray500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHole(int hole, int elapsed) {
    final spawn =
        _inBattle && elapsed >= 0 ? _activeSpawnAt(hole, elapsed) : null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final fb = _feedback[hole];
    final showFb = fb != null && fb.$3 > now;
    // 등장/퇴장 팝 스케일 — 갓 나오면 커지고 사라지기 직전 줄어든다.
    double scale = 0;
    if (spawn != null) {
      final age = elapsed - spawn.startMs;
      final remain = _visibleMs - age;
      scale = age < 130
          ? age / 130
          : remain < 150
              ? (remain / 150).clamp(0.0, 1.0)
              : 1.0;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _whack(hole),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 구멍(흙무더기).
          Align(
            alignment: const Alignment(0, 0.75),
            child: FractionallySizedBox(
              widthFactor: 0.72,
              heightFactor: 0.30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6B4A32), Color(0xFF4E3423)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          if (spawn != null)
            Align(
              alignment: const Alignment(0, 0.1),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: spawn.kind == _MoleKind.bomb
                    ? const Text('💣', style: TextStyle(fontSize: 38))
                    : CustomPaint(
                        size: const Size(52, 52),
                        painter: _MolePainter(
                            golden: spawn.kind == _MoleKind.golden),
                      ),
              ),
            ),
          if (showFb)
            Align(
              alignment: const Alignment(0, -0.75),
              child: Text(
                fb.$1,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: fb.$2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 미니 두더지 — 두더지 모찌 스킨과 같은 갈색+분홍코 룩. [golden] 이면 황금색.
class _MolePainter extends CustomPainter {
  _MolePainter({required this.golden});
  final bool golden;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: golden
            ? const [Color(0xFFFFE49A), Color(0xFFE8A93B)]
            : const [Color(0xFFC79A6F), Color(0xFF8B6547)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    // 몸통(반원형으로 솟은 두더지).
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.12, h * 0.10, w * 0.76, h * 0.88),
        topLeft: Radius.circular(w * 0.38),
        topRight: Radius.circular(w * 0.38),
        bottomLeft: Radius.circular(w * 0.10),
        bottomRight: Radius.circular(w * 0.10),
      ),
      body,
    );
    // 귀.
    final ear = Paint()..color = golden ? const Color(0xFFE8A93B) : const Color(0xFF7A5336);
    canvas.drawCircle(Offset(w * 0.26, h * 0.16), w * 0.09, ear);
    canvas.drawCircle(Offset(w * 0.74, h * 0.16), w * 0.09, ear);
    // 주둥이.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.56), width: w * 0.34, height: h * 0.24),
      Paint()..color = const Color(0xFFEBD3B4),
    );
    // 분홍 코.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, h * 0.50), width: w * 0.16, height: h * 0.11),
      Paint()..color = const Color(0xFFF58BA3),
    );
    // 눈 + 캐치라이트.
    final eye = Paint()..color = const Color(0xFF2B2B2B);
    canvas.drawCircle(Offset(w * 0.36, h * 0.38), w * 0.05, eye);
    canvas.drawCircle(Offset(w * 0.64, h * 0.38), w * 0.05, eye);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(w * 0.345, h * 0.365), w * 0.016, light);
    canvas.drawCircle(Offset(w * 0.625, h * 0.365), w * 0.016, light);
    // 황금 두더지 반짝이.
    if (golden) {
      final star = Paint()..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(w * 0.20, h * 0.30), w * 0.03, star);
      canvas.drawCircle(Offset(w * 0.82, h * 0.46), w * 0.025, star);
    }
  }

  @override
  bool shouldRepaint(covariant _MolePainter old) => old.golden != golden;
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.name,
    required this.score,
    required this.accent,
  });

  final String name;
  final int score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
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
          const SizedBox(height: 2),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 26,
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
            Text(won ? '🏆' : '🔨', style: const TextStyle(fontSize: 44)),
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
