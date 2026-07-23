import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/alkkagi/models/alkkagi_models.dart';
import '../../../features/minigame/data/game_socket.dart';
import '../../../theme/colors.dart';
import '../../../widgets/ad_banner.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/back_header.dart';
import 'alkkagi_formation.dart';

/// 실시간 알까기 대국 화면.
///
/// 물리 시뮬레이션은 튕긴 클라이언트가 로컬로 돌리고, 끝나면 최종 돌 상태를
/// STOMP 로 서버에 보낸다. 서버는 턴 검증·승패 판정 후 전체 스냅샷 + 플릭
/// 정보를 브로드캐스트하고, 상대 화면은 같은 플릭으로 재생 애니메이션을 돌린 뒤
/// 서버 스냅샷으로 스냅해 어긋남을 없앤다.
///
/// 조작: 내 턴에 내 돌을 잡아 뒤로 끌었다 놓으면(슬링샷) 반대 방향으로 날아간다.
/// 한 수 제한시간 30초 — 서버가 초과 턴을 자동으로 넘긴다(TIMEOUT 이벤트).
class AlkkagiGameScreen extends StatefulWidget {
  const AlkkagiGameScreen({super.key, required this.gameId, this.initialGame});

  final int gameId;
  final AlkkagiGame? initialGame;

  @override
  State<AlkkagiGameScreen> createState() => _AlkkagiGameScreenState();
}

/// 시뮬레이션용 돌 — 게임 스냅샷의 돌에 속도를 붙인 가변 상태.
class _SimStone {
  _SimStone({
    required this.id,
    required this.owner,
    required this.x,
    required this.y,
    required this.alive,
  });

  final int id;
  final int owner;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  bool alive;

  /// 판 밖으로 떨어지는 연출용 — 죽은 직후 잠깐 스케일 다운.
  double deathT = 0;

  factory _SimStone.of(AlkkagiStone s) =>
      _SimStone(id: s.id, owner: s.owner, x: s.x, y: s.y, alive: s.alive);
}

class _AlkkagiGameScreenState extends State<AlkkagiGameScreen>
    with SingleTickerProviderStateMixin {
  // ── 물리 상수 (정규화 보드 좌표계: 한 변 = 1) ─────────────────────
  static const double _stoneR = 0.045;
  static const double _damping = 2.1; // 마찰(지수 감쇠)
  static const double _restitution = 0.93; // 충돌 반발
  static const double _stopSpeed = 0.035; // 이 밑이면 정지
  static const double _maxFlickSpeed = 3.0;
  static const double _minFlickSpeed = 0.22;
  static const double _flickPowerScale = 3.4;

  AlkkagiGame? _game;
  bool _loading = true;
  String? _errorMessage;
  bool _actionPending = false;
  bool _resultShown = false;
  GameSocketSession? _socket;

  // ── 로컬 시뮬 상태 ────────────────────────────────────────────────
  final Map<int, _SimStone> _sim = {};
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _simulating = false;

  /// 시뮬 종료 시 처리 — 내 플릭이면 서버 전송, 상대 재생이면 스냅샷 적용.
  bool _simIsMine = false;
  int? _simStoneId;
  Offset? _simFlickVelocity;
  AlkkagiGame? _pendingSnapshot;

  // ── 플릭 드래그 ───────────────────────────────────────────────────
  int? _dragStoneId;
  Offset? _dragVector; // 뷰 좌표계(픽셀 아님, 정규화)

  // ── 턴 카운트다운 ─────────────────────────────────────────────────
  Timer? _countdownTimer;
  int _remainSeconds = 0;
  String? _timeoutBanner;
  Timer? _bannerTimer;

  /// 수락 화면에서 고르는 내 시작 대형.
  AlkkagiFormation _acceptFormation = AlkkagiFormation.line;

  String get _myId => Di.userSession.profile?.id ?? '';

  int get _mySide => _game?.sideOf(_myId) ?? AlkkagiGame.inviterSide;

  /// 보드 세로 길이(가로=1) — 서버가 내려주는 공유 상수.
  double get _boardH => _game?.boardHeight ?? 1.35;

  /// 수락자는 보드를 180도 뒤집어 내 진영이 항상 아래에 오게 렌더링한다.
  bool get _flipView => _mySide == AlkkagiGame.inviteeSide;

  @override
  void initState() {
    super.initState();
    _game = widget.initialGame;
    _loading = _game == null;
    if (_game != null) _syncSimFromGame(_game!);
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _socket?.dispose();
    _countdownTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    if (_game == null) await _refresh();
    if (!mounted || _game == null) return;
    await _connectSocket();
    _startCountdown();
  }

  Future<void> _refresh() async {
    try {
      final game = await Di.alkkagiRepository.get(widget.gameId);
      if (!mounted) return;
      setState(() {
        _game = game;
        _loading = false;
        _errorMessage = null;
        if (!_simulating) _syncSimFromGame(game);
      });
      _startCountdown();
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
      topic: '/topic/alkkagi/${widget.gameId}',
      accessToken: token,
      onJson: (json) => _onEvent(AlkkagiEvent.fromJson(json)),
      // (재)연결 직후 스냅샷 재동기화 — 연결 사이에 놓친 수를 메꾼다.
      onConnected: () {
        if (mounted && !_simulating) _refresh();
      },
    );
    _socket = socket;
    socket.connect();
  }

  // ── 스냅샷 ↔ 시뮬 동기화 ─────────────────────────────────────────

  void _syncSimFromGame(AlkkagiGame game) {
    _sim
      ..clear()
      ..addEntries(game.stones.map((s) => MapEntry(s.id, _SimStone.of(s))));
  }

  List<Map<String, dynamic>> _simToPayload() => [
        for (final s in _sim.values)
          {'id': s.id, 'owner': s.owner, 'x': s.x, 'y': s.y, 'alive': s.alive},
      ];

  // ── 이벤트 ───────────────────────────────────────────────────────

  void _onEvent(AlkkagiEvent event) {
    if (!mounted) return;
    final game = event.game;
    final flick = event.flick;

    final isOpponentMove = (event.type == 'MOVE' || event.type == 'FINISHED') &&
        flick != null &&
        flick.byUserId != _myId;

    if (isOpponentMove && !_simulating) {
      // 상대 플릭 재생 — 현재 로컬 상태에서 같은 플릭을 돌리고, 끝나면
      // 서버 스냅샷으로 스냅한다.
      setState(() => _game = game);
      _startCountdown();
      _pendingSnapshot = game;
      final stone = _sim[flick.stoneId];
      if (stone != null && stone.alive) {
        HapticFeedback.lightImpact();
        stone.vx = flick.vx;
        stone.vy = flick.vy;
        _beginSimulation(mine: false);
      } else {
        _applySnapshotNow(game);
      }
      return;
    }

    setState(() {
      _game = game;
      if (!_simulating) _syncSimFromGame(game);
    });
    _startCountdown();

    switch (event.type) {
      case 'TIMEOUT':
        HapticFeedback.mediumImpact();
        final myTurnNow = game.isMyTurn(_myId);
        _showBanner(
          myTurnNow ? '상대가 시간을 초과했어요 — 내 차례!' : '시간 초과! 턴이 넘어갔어요',
        );
      case 'FINISHED':
        HapticFeedback.mediumImpact();
        if (!_simulating) _maybeShowResult(game);
      case 'DECLINED':
        if (_myId == game.inviterUserId) {
          _showEndAndPop('${game.inviteeName}님이 초대를 거절했어요.');
        }
      case 'CANCELED':
        if (_myId == game.inviteeUserId) {
          _showEndAndPop('${game.inviterName}님이 초대를 취소했어요.');
        }
      case 'EXPIRED':
        _showEndAndPop('대국이 만료됐어요. 다시 초대해 주세요.');
      default:
        break;
    }
  }

  void _applySnapshotNow(AlkkagiGame game) {
    setState(() {
      _game = game;
      _syncSimFromGame(game);
    });
    _maybeShowResult(game);
  }

  // ── 카운트다운 ───────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    final deadline = _game?.turnDeadlineEpochMs;
    if (deadline == null || _game?.status != AlkkagiStatus.active) {
      setState(() => _remainSeconds = 0);
      return;
    }
    void tick() {
      final remainMs = deadline - DateTime.now().millisecondsSinceEpoch;
      final s = (remainMs / 1000).ceil().clamp(0, 99);
      if (mounted && s != _remainSeconds) setState(() => _remainSeconds = s);
    }

    tick();
    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  void _showBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _timeoutBanner = text);
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _timeoutBanner = null);
    });
  }

  // ── 물리 시뮬레이션 ───────────────────────────────────────────────

  void _beginSimulation({required bool mine}) {
    _simIsMine = mine;
    _simulating = true;
    _lastTick = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.05) dt = 0.016;
    if (!_simulating) return;

    final stones = _sim.values.where((s) => s.alive).toList();

    // 적분 + 마찰.
    final damp = math.exp(-_damping * dt);
    for (final s in stones) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vx *= damp;
      s.vy *= damp;
      if (s.vx * s.vx + s.vy * s.vy < _stopSpeed * _stopSpeed) {
        s.vx = 0;
        s.vy = 0;
      }
    }

    // 돌끼리 충돌 — 등질량 탄성 충돌 + 겹침 보정.
    for (var i = 0; i < stones.length; i++) {
      for (var j = i + 1; j < stones.length; j++) {
        final a = stones[i];
        final b = stones[j];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final distSq = dx * dx + dy * dy;
        const minDist = _stoneR * 2;
        if (distSq >= minDist * minDist || distSq == 0) continue;
        final dist = math.sqrt(distSq);
        final nx = dx / dist;
        final ny = dy / dist;
        // 겹침 밀어내기.
        final overlap = (minDist - dist) / 2;
        a.x -= nx * overlap;
        a.y -= ny * overlap;
        b.x += nx * overlap;
        b.y += ny * overlap;
        // 법선 방향 탄성 충돌(등질량) — 접근 중일 때만.
        final relVn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (relVn < 0) {
          final j = -(1 + _restitution) * relVn / 2;
          a.vx -= j * nx;
          a.vy -= j * ny;
          b.vx += j * nx;
          b.vy += j * ny;
          if (j > 0.3) HapticFeedback.selectionClick();
        }
      }
    }

    // 낙사 판정 — 돌이 판을 완전히 벗어나면 아웃.
    for (final s in stones) {
      if (s.x < -_stoneR ||
          s.x > 1 + _stoneR ||
          s.y < -_stoneR ||
          s.y > _boardH + _stoneR) {
        s.alive = false;
        s.vx = 0;
        s.vy = 0;
        HapticFeedback.mediumImpact();
      }
    }

    // 종료 판정.
    final moving = _sim.values
        .any((s) => s.alive && (s.vx != 0 || s.vy != 0));
    if (!moving) {
      _simulating = false;
      _ticker.stop();
      _onSimulationSettled();
    }
    if (mounted) setState(() {});
  }

  void _onSimulationSettled() {
    if (_simIsMine) {
      final stoneId = _simStoneId;
      final v = _simFlickVelocity;
      _simStoneId = null;
      _simFlickVelocity = null;
      if (stoneId != null && v != null) {
        _socket?.send('/app/alkkagi/${widget.gameId}/move', {
          'stoneId': stoneId,
          'flickVx': v.dx,
          'flickVy': v.dy,
          'stones': _simToPayload(),
        });
      }
    } else {
      final snapshot = _pendingSnapshot;
      _pendingSnapshot = null;
      if (snapshot != null) _applySnapshotNow(snapshot);
    }
  }

  // ── 플릭 입력 (뷰 좌표 → 서버 좌표 변환 포함) ─────────────────────

  Offset _toView(double x, double y) =>
      _flipView ? Offset(1 - x, _boardH - y) : Offset(x, y);

  bool get _canFlick =>
      _game != null &&
      _game!.isMyTurn(_myId) &&
      !_simulating &&
      _remainSeconds > 0;

  void _onDragStart(Offset viewPos) {
    if (!_canFlick) return;
    // 뷰 좌표에서 가장 가까운 내 돌을 찾는다(터치 반경 살짝 여유).
    _SimStone? best;
    double bestD = _stoneR * 1.8;
    for (final s in _sim.values) {
      if (!s.alive || s.owner != _mySide) continue;
      final vp = _toView(s.x, s.y);
      final d = (vp - viewPos).distance;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    if (best == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dragStoneId = best!.id;
      _dragVector = Offset.zero;
    });
  }

  void _onDragUpdate(Offset viewDelta) {
    if (_dragStoneId == null) return;
    setState(() {
      _dragVector = (_dragVector ?? Offset.zero) + viewDelta;
    });
  }

  void _onDragEnd() {
    final stoneId = _dragStoneId;
    final drag = _dragVector;
    setState(() {
      _dragStoneId = null;
      _dragVector = null;
    });
    if (stoneId == null || drag == null || !_canFlick) return;

    // 슬링샷 — 끈 방향의 반대로 날아간다. 뷰 좌표 → 서버 좌표는 부호 반전.
    var v = -drag * _flickPowerScale;
    if (_flipView) v = -v;
    final speed = v.distance;
    if (speed < _minFlickSpeed) return; // 너무 약한 플릭은 무시
    if (speed > _maxFlickSpeed) v = v / speed * _maxFlickSpeed;

    final stone = _sim[stoneId];
    if (stone == null || !stone.alive) return;
    HapticFeedback.lightImpact();
    stone.vx = v.dx;
    stone.vy = v.dy;
    _simStoneId = stoneId;
    _simFlickVelocity = v;
    _beginSimulation(mine: true);
  }

  // ── 액션 (수락/거절/취소/기권) ────────────────────────────────────

  Future<void> _accept() async {
    if (_actionPending) return;
    setState(() => _actionPending = true);
    try {
      final game = await Di.alkkagiRepository
          .accept(widget.gameId, formation: _acceptFormation.key);
      if (!mounted) return;
      setState(() {
        _game = game;
        _syncSimFromGame(game);
      });
      _startCountdown();
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
      await Di.alkkagiRepository.decline(widget.gameId);
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
      await Di.alkkagiRepository.cancel(widget.gameId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionPending = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  void _confirmForfeit() {
    showConfirmDialog(
      context,
      title: '기권할까요?',
      message: '기권하면 상대의 승리로 대결이 끝나요.',
      confirmLabel: '기권',
      onConfirm: () =>
          _socket?.send('/app/alkkagi/${widget.gameId}/forfeit'),
    );
  }

  void _onExit() {
    final game = _game;
    if (game == null) {
      Navigator.of(context).pop();
      return;
    }
    switch (game.status) {
      case AlkkagiStatus.active:
        showConfirmDialog(
          context,
          title: '대결을 나갈까요?',
          message: '지금 나가면 기권 처리돼요.',
          confirmLabel: '나가기',
          onConfirm: () {
            _socket?.send('/app/alkkagi/${widget.gameId}/forfeit');
            Navigator.of(context).pop();
          },
        );
      case AlkkagiStatus.waiting:
        if (_myId == game.inviterUserId) {
          _cancelInvite();
        } else {
          Navigator.of(context).pop();
        }
      default:
        Navigator.of(context).pop();
    }
  }

  // ── 결과 ─────────────────────────────────────────────────────────

  void _maybeShowResult(AlkkagiGame game) {
    if (game.status != AlkkagiStatus.finished || _resultShown) return;
    _resultShown = true;
    final iWon = game.winnerUserId == _myId;
    final title = iWon ? '승리! 🏆' : '패배...';
    final reason = switch (game.finishReason) {
      'FORFEIT' => iWon ? '상대가 기권했어요.' : '기권으로 대결이 끝났어요.',
      _ => iWon
          ? '상대 돌을 모두 튕겨냈어요!'
          : '내 돌이 모두 판 밖으로 나갔어요.',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) =>
            _ResultDialog(title: title, message: reason, won: iWon),
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

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF221507),
        body: SafeArea(
          child: Column(
            children: [
              BackHeader(title: '알까기', onBack: _onExit, dark: true),
              Expanded(child: _buildBody()),
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
            _errorMessage ?? '대결을 찾을 수 없어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }
    if (game.status == AlkkagiStatus.waiting) {
      return _myId == game.inviteeUserId
          ? _buildInvitePrompt(game)
          : _buildWaiting(game);
    }
    return _buildArena(game);
  }

  Widget _buildInvitePrompt(AlkkagiGame game) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪨🫰', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(
              '${game.inviterName}님의 알까기 초대',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '한 사람당 돌 ${game.stoneCount}개!\n'
              '상대 돌을 모두 판 밖으로 튕겨내면 승리해요.\n'
              '한 수 제한시간은 30초예요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
                height: 1.5,
                color: Color(0xFFCBB897),
              ),
            ),
            const SizedBox(height: 20),
            // 내 시작 대형 선택 — 수락하면 이 대형으로 배치된다.
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '⚔️ 내 시작 대형 고르기',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AlkkagiFormationPicker(
              selected: _acceptFormation,
              stoneCount: game.stoneCount,
              dark: true,
              onChanged: (f) => setState(() => _acceptFormation = f),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _actionPending ? null : _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
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

  Widget _buildWaiting(AlkkagiGame game) {
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '돌 ${game.stoneCount}개 대결로 초대 알림을 보냈어요.\n10분 안에 수락하지 않으면 초대가 만료돼요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFCBB897),
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
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArena(AlkkagiGame game) {
    final finished = game.status == AlkkagiStatus.finished;
    final myTurn = game.isMyTurn(_myId) && !_simulating;
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildPlayersBar(game),
        const SizedBox(height: 10),
        // 세로로 긴 큰 판 — 가용 영역을 최대한 채운다.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1 / _boardH,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = constraints.maxWidth;
                    return GestureDetector(
                      onPanStart: (d) =>
                          _onDragStart(_pxToNorm(d.localPosition, side)),
                      onPanUpdate: (d) =>
                          _onDragUpdate(d.delta / side),
                      onPanEnd: (_) => _onDragEnd(),
                      child: CustomPaint(
                        size: Size(side, side * _boardH),
                        painter: _AlkkagiBoardPainter(
                          stones: _sim.values.toList(),
                          mySide: _mySide,
                          flip: _flipView,
                          boardH: _boardH,
                          myTurn: myTurn && !finished,
                          dragStoneId: _dragStoneId,
                          dragVector: _dragVector,
                          stoneR: _stoneR,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_timeoutBanner != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
            ),
            child: Text(
              '⏰ $_timeoutBanner',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: Color(0xFFFCD34D),
              ),
            ),
          )
        else if (!finished)
          Text(
            _simulating
                ? '돌이 움직이는 중...'
                : myTurn
                    ? '내 차례! 내 돌을 끌었다 놓아 튕기세요'
                    : '상대의 차례를 기다리는 중...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: myTurn ? const Color(0xFFFCD34D) : Colors.white54,
            ),
          ),
        if (!finished)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextButton.icon(
              onPressed: _confirmForfeit,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('기권'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
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
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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

  Offset _pxToNorm(Offset px, double side) => Offset(px.dx / side, px.dy / side);

  /// 상단 플레이어 바 — 남은 돌 수 + 현재 턴 + 30초 카운트다운.
  Widget _buildPlayersBar(AlkkagiGame game) {
    Widget chip({
      required String name,
      required int side,
      required bool isMe,
    }) {
      final isTurn = game.status == AlkkagiStatus.active &&
          game.currentTurnUserId ==
              (side == AlkkagiGame.inviterSide
                  ? game.inviterUserId
                  : game.inviteeUserId);
      final alive = game.aliveCountOf(side);
      final isBlack = side == AlkkagiGame.inviterSide;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isTurn
              ? const Color(0xFFFCD34D).withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isTurn ? const Color(0xFFFCD34D) : Colors.white24,
            width: isTurn ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 15,
              height: 15,
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
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${isMe ? '$name (나)' : name} ×$alive',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: isTurn ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final active = game.status == AlkkagiStatus.active;
    final urgent = _remainSeconds <= 10;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: chip(
                name: game.inviterName,
                side: AlkkagiGame.inviterSide,
                isMe: _myId == game.inviterUserId,
              ),
            ),
          ),
          // 카운트다운 — VS 자리를 겸한다.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: active
                ? Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: urgent
                          ? const Color(0xFFDC2626).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: urgent
                            ? const Color(0xFFF87171)
                            : Colors.white24,
                        width: urgent ? 1.8 : 1,
                      ),
                    ),
                    child: Text(
                      '$_remainSeconds',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: urgent
                            ? const Color(0xFFF87171)
                            : Colors.white,
                      ),
                    ),
                  )
                : const Text(
                    'VS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: chip(
                name: game.inviteeName,
                side: AlkkagiGame.inviteeSide,
                isMe: _myId == game.inviteeUserId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 알까기 판 — 원목 세로 직사각 판 위 돌 + 플릭 조준선.
/// [flip]=true 면 180도 회전 렌더(수락자 시점).
class _AlkkagiBoardPainter extends CustomPainter {
  _AlkkagiBoardPainter({
    required this.stones,
    required this.mySide,
    required this.flip,
    required this.boardH,
    required this.myTurn,
    required this.dragStoneId,
    required this.dragVector,
    required this.stoneR,
  });

  final List<_SimStone> stones;
  final int mySide;
  final bool flip;
  final double boardH;
  final bool myTurn;
  final int? dragStoneId;
  final Offset? dragVector;
  final double stoneR;

  Offset _view(double x, double y, double side) {
    final vx = flip ? 1 - x : x;
    final vy = flip ? boardH - y : y;
    return Offset(vx * side, vy * side);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );

    // 테이블 그림자 — 판이 떠 있는 느낌(밖 = 낭떠러지).
    canvas.drawRRect(
      rrect.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 원목 판.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2D6A4), Color(0xFFE0B87B), Color(0xFFD3A768)],
        ).createShader(Offset.zero & size),
    );

    // 나뭇결 — 은은한 가로 웨이브.
    final grain = Paint()
      ..color = const Color(0xFF9A7546).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final rows = (boardH * 9).round();
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      final path = Path()..moveTo(6, y);
      for (double x = 6; x < side - 6; x += 14) {
        path.lineTo(x, y + math.sin(x / 34 + i * 2.1) * 2.2);
      }
      canvas.drawPath(path, grain);
    }

    // 중앙선 + 진영 표시.
    final midY = size.height / 2;
    final mid = Paint()
      ..color = const Color(0xFF9A7546).withValues(alpha: 0.55)
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(10, midY), Offset(side - 10, midY), mid);
    canvas.drawCircle(
      Offset(side / 2, midY),
      side * 0.09,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF9A7546).withValues(alpha: 0.4),
    );

    // 가장자리 경고 림 — 여기 넘어가면 아웃.
    canvas.drawRRect(
      rrect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF7F1D1D).withValues(alpha: 0.35),
    );

    // 죽은 돌은 그리지 않는다(판 밖으로 사라짐). 살아있는 돌 렌더.
    for (final s in stones) {
      if (!s.alive) continue;
      final c = _view(s.x, s.y, side);
      final r = stoneR * side;
      final isMine = s.owner == mySide;
      final isBlack = s.owner == AlkkagiGame.inviterSide;

      // 내 턴 하이라이트 링.
      if (isMine && myTurn) {
        canvas.drawCircle(
          c,
          r * 1.22,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFCD34D).withValues(alpha: 0.75),
        );
      }

      canvas.drawCircle(
        c.translate(1, 2.4),
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: isBlack
                ? const [Color(0xFF5A5A5A), Color(0xFF101010)]
                : const [Colors.white, Color(0xFFC9C9C9)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      if (!isBlack) {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = const Color(0xFF9F9F9F),
        );
      }
    }

    // 플릭 조준 — 당긴 반대 방향 화살표 + 파워 게이지.
    final dragId = dragStoneId;
    final drag = dragVector;
    if (dragId != null && drag != null && drag.distance > 0.01) {
      final stone = stones.where((s) => s.id == dragId).firstOrNull;
      if (stone != null && stone.alive) {
        final c = _view(stone.x, stone.y, side);
        final pull = drag * side.toDouble();
        final power = (drag.distance * 3.4 / 3.0).clamp(0.0, 1.0);
        final aim = -pull; // 날아갈 방향

        // 당김 고무줄.
        canvas.drawLine(
          c,
          c + pull,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
        // 발사 방향 화살표 — 파워에 따라 길이/색.
        final dir = aim.distance == 0 ? Offset.zero : aim / aim.distance;
        final len = side * (0.1 + power * 0.3);
        final tip = c + dir * len;
        final arrowColor = Color.lerp(
            const Color(0xFF86EFAC), const Color(0xFFF87171), power)!;
        canvas.drawLine(
          c,
          tip,
          Paint()
            ..color = arrowColor
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round,
        );
        // 화살촉.
        final ang = math.atan2(dir.dy, dir.dx);
        for (final da in [2.6, -2.6]) {
          canvas.drawLine(
            tip,
            tip + Offset(math.cos(ang + da), math.sin(ang + da)) * 10,
            Paint()
              ..color = arrowColor
              ..strokeWidth = 3.4
              ..strokeCap = StrokeCap.round,
          );
        }
        // 파워 링.
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: stoneR * side * 1.55),
          -math.pi / 2,
          2 * math.pi * power,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = arrowColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AlkkagiBoardPainter oldDelegate) => true;
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
            Text(won ? '🏆' : '🪨', style: const TextStyle(fontSize: 44)),
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
