import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import 'explore_3d.dart';
import 'explore_rewards.dart';

/// 모찌 정글 탐험 — 탐험 허브에서 진입하는 자유비행 밀림 콘텐츠.
///
/// 화면을 꾹 누르면 모찌가 탄 열기구가 그 방향으로 나아가고, 떼면 바람에
/// 실려 천천히 멈춘다. 화면은 [Depth3D] 로 여러 깊이 평면을 겹쳐 그린다:
/// 먼 산등성이와 안개 낀 나무숲(z>0), 열기구와 유적이 있는 게임 평면(z=0),
/// 그리고 화면 앞을 스치는 커다란 잎사귀(z<0). 원근 바닥면과 나무 그림자까지
/// 얹어 날아다닐 때 깊이가 실제로 읽히게 했다.
class JungleExploreScreen extends StatefulWidget {
  const JungleExploreScreen({super.key, required this.character});

  final CharacterState character;

  @override
  State<JungleExploreScreen> createState() => _JungleExploreScreenState();
}

class _JungleExploreScreenState extends State<JungleExploreScreen>
    with TickerProviderStateMixin {
  // ── 월드/물리 ─────────────────────────────────────────────────────
  static const double _worldW = 4600;
  static const double _worldH = 2200;
  static const double _accel = 900;
  static const double _maxSpeed = 500;
  static const double _drag = 1.9; // 공기 저항

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _time = 0;

  Offset _balloon = const Offset(420, 900);
  Offset _vel = Offset.zero;
  Offset? _pointer;
  Size _viewport = Size.zero;

  final Set<String> _visited = <String>{};
  bool _showHint = true;
  bool _panelOpen = false;
  bool _celebrated = false;

  // 깊이별 장식 — 안개 포자(먼 배경)와 반딧불(가까운 전경).
  late final List<Depth3DMote> _spores;
  late final List<Depth3DMote> _fireflies;
  // 배경 나무숲 3겹(깊이별) + 전경 잎사귀.
  late final List<_Tree> _canopy;
  late final List<_Leaf> _foreLeaves;
  late final List<_Bird> _birds;

  @override
  void initState() {
    super.initState();
    final rand = math.Random(20260721);
    _spores = List.generate(
      52,
      (_) => Depth3DMote.random(rand,
          minZ: 500, maxZ: 2400, minR: 1.4, maxR: 3.4, twinkle: 0.4),
    );
    _fireflies = List.generate(
      26,
      (_) => Depth3DMote.random(rand,
          minZ: -260, maxZ: 380, minR: 1.6, maxR: 3.0),
    );
    _canopy = List.generate(46, (_) => _Tree.random(rand));
    _foreLeaves = List.generate(7, (_) => _Leaf.random(rand));
    _birds = List.generate(5, (_) => _Bird.random(rand));
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.05) dt = 0.016;
    _time = elapsed.inMicroseconds / 1e6;

    if (!_panelOpen) {
      final pointer = _pointer;
      if (pointer != null) {
        final target = pointer + _camera;
        final dir = target - _balloon;
        final dist = dir.distance;
        if (dist > 12) _vel += dir / dist * _accel * dt;
      }
      final damp = (1 - _drag * dt).clamp(0.0, 1.0);
      _vel = _vel * damp;
      final speed = _vel.distance;
      if (speed > _maxSpeed) _vel = _vel / speed * _maxSpeed;
      _balloon += _vel * dt;
      final cx = _balloon.dx.clamp(80.0, _worldW - 80.0);
      final cy = _balloon.dy.clamp(150.0, _worldH - 120.0);
      if (cx != _balloon.dx) _vel = Offset(0, _vel.dy);
      if (cy != _balloon.dy) _vel = Offset(_vel.dx, 0);
      _balloon = Offset(cx, cy);
    }
    if (mounted) setState(() {});
  }

  Offset get _camera {
    final dx = (_balloon.dx - _viewport.width / 2)
        .clamp(0.0, math.max(0.0, _worldW - _viewport.width))
        .toDouble();
    final dy = (_balloon.dy - _viewport.height / 2)
        .clamp(0.0, math.max(0.0, _worldH - _viewport.height))
        .toDouble();
    return Offset(dx, dy);
  }

  _JungleSpot? get _nearbySpot {
    for (final s in _spots) {
      if (((s.pos - _balloon).distance) < s.size / 2 + 120) return s;
    }
    return null;
  }

  _JungleSpot? get _nearestUnvisited {
    _JungleSpot? best;
    double bestD = double.infinity;
    for (final s in _spots) {
      if (_visited.contains(s.id)) continue;
      final d = (s.pos - _balloon).distance;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  Future<void> _openSpot(_JungleSpot s) async {
    if (_panelOpen) return;
    setState(() {
      _panelOpen = true;
      _vel = Offset.zero;
      _pointer = null;
      _visited.add(s.id);
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JungleSpotSheet(
        spot: s,
        collected: _visited.length,
        total: _spots.length,
      ),
    );
    if (!mounted) return;
    setState(() => _panelOpen = false);
    _maybeCelebrate();
  }

  void _maybeCelebrate() {
    if (_celebrated || _visited.length < _spots.length) return;
    _celebrated = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF14301C),
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
              color: const Color(0xFF86EFAC).withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                '정글 완전 정복!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '모찌가 밀림의 모든 비밀을\n찾아냈어요. 진짜 탐험가네요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  height: 1.55,
                  color: Color(0xFFB7D9C0),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '최고야!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 빌드 ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A10),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final camera = _camera;
          final nearby = _nearbySpot;
          return Stack(
            fit: StackFit.expand,
            children: [
              // 배경 평면(z>0) — 하늘·먼 산·안개 숲·원근 바닥.
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  if (_panelOpen) return;
                  setState(() {
                    _showHint = false;
                    _pointer = e.localPosition;
                  });
                },
                onPointerMove: (e) {
                  if (_pointer != null) _pointer = e.localPosition;
                },
                onPointerUp: (_) => _pointer = null,
                onPointerCancel: (_) => _pointer = null,
                child: CustomPaint(
                  painter: _JungleWorldPainter(
                    camera: camera,
                    t: _time,
                    spores: _spores,
                    canopy: _canopy,
                    birds: _birds,
                    worldH: _worldH,
                  ),
                ),
              ),
              // 게임 평면(z=0) — 유적/명소.
              for (final s in _spots) ..._buildSpot(s, camera),
              _buildComingSoonSign(camera),
              _buildBalloon(camera),
              // 전경 평면(z<0) — 반딧불과 스치는 잎사귀.
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _JungleForegroundPainter(
                    camera: camera,
                    t: _time,
                    fireflies: _fireflies,
                    leaves: _foreLeaves,
                  ),
                ),
              ),
              if (nearby != null && !_panelOpen)
                _buildExplorePrompt(nearby, camera),
              _buildHud(),
              if (!_panelOpen) ..._buildCompass(camera),
              if (_showHint) _buildHint(),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSpot(_JungleSpot s, Offset camera) {
    final sp = s.pos - camera;
    if (sp.dx < -340 ||
        sp.dx > _viewport.width + 340 ||
        sp.dy < -340 ||
        sp.dy > _viewport.height + 340) {
      return const [];
    }
    final visited = _visited.contains(s.id);
    return [
      Positioned(
        left: sp.dx - s.size / 2,
        top: sp.dy - s.size / 2,
        child: IgnorePointer(
          child: SizedBox(
            width: s.size,
            height: s.size,
            child: CustomPaint(painter: _JungleSpotPainter(s, t: _time)),
          ),
        ),
      ),
      Positioned(
        left: sp.dx - 80,
        top: sp.dy + s.size / 2 + 2,
        child: IgnorePointer(
          child: SizedBox(
            width: 160,
            child: Column(
              children: [
                Text(
                  s.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
                if (visited)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: s.glow.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: s.glow.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '탐험 완료 ✓',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: s.glow,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildComingSoonSign(Offset camera) {
    final sp = const Offset(_worldW - 210, 1000) - camera;
    return Positioned(
      left: sp.dx - 90,
      top: sp.dy - 50,
      child: IgnorePointer(
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Column(
            children: [
              Text('🦜', style: TextStyle(fontSize: 26)),
              SizedBox(height: 6),
              Text(
                '다음 업데이트에서\n더 깊은 밀림이 열려요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  height: 1.4,
                  color: Color(0xFFA7C4AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalloon(Offset camera) {
    final sp = _balloon - camera;
    final speed = _vel.distance;
    // 진행 방향으로 기울고(롤), 상하 이동으로 피치가 생긴다.
    final roll = (_vel.dx / 1100).clamp(-0.26, 0.26).toDouble();
    final pitch = (-_vel.dy / 1700).clamp(-0.24, 0.24).toDouble();
    final bob = speed < 30 ? math.sin(_time * 1.7) * 6 : 0.0;
    const w = 150.0;
    const h = 190.0;
    return Positioned(
      left: sp.dx - w / 2,
      top: sp.dy - h / 2 + bob,
      child: IgnorePointer(
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0013)
            ..rotateX(pitch)
            ..rotateZ(roll),
          alignment: Alignment.center,
          child: _MochiBalloon(
            character: widget.character,
            t: _time,
            burning: _pointer != null,
          ),
        ),
      ),
    );
  }

  Widget _buildExplorePrompt(_JungleSpot s, Offset camera) {
    final sp = s.pos - camera;
    final bounce = math.sin(_time * 4) * 4;
    final left = (sp.dx - 86)
        .clamp(8.0, math.max(8.0, _viewport.width - 180))
        .toDouble();
    final top = (sp.dy - s.size / 2 - 54 + bounce)
        .clamp(90.0, math.max(90.0, _viewport.height - 60))
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: 172,
        child: Center(
          child: GestureDetector(
            onTap: () => _openSpot(s),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF65A30D)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '🔍 ${s.name} 탐험하기',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    final done = _visited.length;
    final total = _spots.length;
    // 고도 — 위로 올라갈수록 커진다(월드 y 반전).
    final altitude =
        (((_worldH - _balloon.dy) / _worldH) * 1200).clamp(0, 1200).round();
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '정글 탐험',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
              const Spacer(),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: done >= total
                            ? const Color(0xFFFCD34D).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '${done >= total ? '🏆' : '🌿'} $done/$total · ${altitude}m',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: done >= total
                            ? const Color(0xFFFCD34D)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCompass(Offset camera) {
    final target = _nearestUnvisited;
    if (target == null) return const [];
    final sp = target.pos - camera;
    final inView = sp.dx > 0 &&
        sp.dx < _viewport.width &&
        sp.dy > 0 &&
        sp.dy < _viewport.height;
    if (inView) return const [];
    final dir = target.pos - _balloon;
    final angle = math.atan2(dir.dy, dir.dx);
    final cx =
        sp.dx.clamp(64.0, math.max(64.0, _viewport.width - 64.0)).toDouble();
    final cy =
        sp.dy.clamp(120.0, math.max(120.0, _viewport.height - 90.0)).toDouble();
    return [
      Positioned(
        left: cx - 55,
        top: cy - 24,
        child: IgnorePointer(
          child: Container(
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B2416).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: target.glow.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: angle,
                  child: Icon(Icons.navigation_rounded,
                      size: 15, color: target.glow),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    target.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: target.glow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildHint() {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0B2416).withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👆🎈', style: TextStyle(fontSize: 30)),
              SizedBox(height: 10),
              Text(
                '열기구 조종법',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '화면을 꾹 누르고 있으면\n모찌 열기구가 그쪽으로 날아가요!\n밀림 속 유적에 다가가면 탐험할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFFB7D9C0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 모찌 열기구 ──────────────────────────────────────────────────────

/// 모찌가 탄 정글 열기구 — 구체 풍선(입체 셰이딩) + 바구니 + 버너 불꽃.
class _MochiBalloon extends StatelessWidget {
  const _MochiBalloon({
    required this.character,
    required this.t,
    this.burning = false,
  });

  final CharacterState character;
  final double t;
  final bool burning;

  @override
  Widget build(BuildContext context) {
    const w = 150.0;
    const h = 190.0;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 풍선 — 좌상단 광원 그라디언트 + 세로 스트라이프로 곡면감.
          Positioned(
            top: 0,
            child: SizedBox(
              width: 118,
              height: 128,
              child: CustomPaint(painter: _BalloonPainter(t: t)),
            ),
          ),
          // 버너 불꽃 — 추진 중이면 커진다.
          Positioned(
            top: 118,
            child: Container(
              width: burning ? 22 : 13,
              height: burning ? 26 : 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFEF08A)
                        .withValues(alpha: burning ? 0.95 : 0.6),
                    const Color(0xFFF97316).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // 줄 2가닥.
          Positioned(
            top: 112,
            child: SizedBox(
              width: 82,
              height: 34,
              child: CustomPaint(painter: _RopePainter()),
            ),
          ),
          // 모찌 — 바구니보다 먼저 그려서 상반신이 바구니 위로 올라오게 한다.
          // (모찌 아트는 캔버스 아래쪽에 그려지므로 박스를 크게 잡고 위로 올린다)
          Positioned(
            top: 96,
            child: MochiCharacterView(
              appearance: MochiAppearance.fromState(character),
              stage: character.stage,
              size: 86,
              part: MochiCharacterPart.body,
            ),
          ),
          // 바구니 — 모찌 하반신을 가려 "타고 있는" 모습이 된다.
          Positioned(
            top: 156,
            child: Container(
              width: 74,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFD8A25E), Color(0xFF7C4A1E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              // 등나무 결 — 가로줄 두 가닥.
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                      height: 1.4,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: const Color(0xFF5B3A1A).withValues(alpha: 0.5),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalloonPainter extends CustomPainter {
  _BalloonPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.46);
    final rx = size.width * 0.5;
    final ry = size.height * 0.5;
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);

    // 본체 — 좌상단에서 빛을 받는 구체.
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.42, -0.5),
          radius: 1.05,
          colors: [Color(0xFFFDE68A), Color(0xFFEF4444), Color(0xFF7F1D1D)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    // 세로 스트라이프 — 가운데는 넓고 가장자리로 갈수록 좁아져 곡면으로 읽힌다.
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final stripe = Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: 0.30);
    for (final f in [-0.62, -0.2, 0.22, 0.64]) {
      final w = rx * 0.26 * math.cos(f * 1.35); // 원통 투영 → 가장자리 압축
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx + rx * f, c.dy),
          width: w.abs() * 2,
          height: ry * 2,
        ),
        stripe,
      );
    }
    // 아래쪽 그림자 — 구체 볼륨.
    canvas.drawOval(
      rect.translate(rx * 0.3, ry * 0.42),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.34),
          ],
          stops: const [0.5, 1],
        ).createShader(rect.translate(rx * 0.3, ry * 0.42)),
    );
    canvas.restore();

    // 하이라이트.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - rx * 0.34, c.dy - ry * 0.44),
        width: rx * 0.5,
        height: ry * 0.3,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.5),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCenter(
          center: Offset(c.dx - rx * 0.34, c.dy - ry * 0.44),
          width: rx * 0.5,
          height: ry * 0.3,
        )),
    );

    // 아래 주둥이.
    final neck = Path()
      ..moveTo(c.dx - rx * 0.19, c.dy + ry * 0.9)
      ..lineTo(c.dx + rx * 0.19, c.dy + ry * 0.9)
      ..lineTo(c.dx + rx * 0.1, size.height)
      ..lineTo(c.dx - rx * 0.1, size.height)
      ..close();
    canvas.drawPath(neck, Paint()..color = const Color(0xFF7F1D1D));
  }

  @override
  bool shouldRepaint(_BalloonPainter old) => false;
}

class _RopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rope = Paint()
      ..color = const Color(0xFF5B3A1A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.12, 0),
        Offset(size.width * 0.28, size.height), rope);
    canvas.drawLine(Offset(size.width * 0.88, 0),
        Offset(size.width * 0.72, size.height), rope);
  }

  @override
  bool shouldRepaint(_RopePainter old) => false;
}

// ── 배경 요소 ────────────────────────────────────────────────────────

/// 깊이가 있는 배경 나무. z 가 클수록 멀고 작고 안개에 잠긴다.
class _Tree {
  _Tree({
    required this.x,
    required this.z,
    required this.h,
    required this.phase,
    required this.kind,
  });

  factory _Tree.random(math.Random rand) => _Tree(
        x: rand.nextDouble(),
        // 3개 깊이 대역에 흩뿌린다 — 겹치면서 숲의 두께가 생긴다.
        z: [260.0, 720.0, 1500.0][rand.nextInt(3)] +
            rand.nextDouble() * 240,
        h: 0.55 + rand.nextDouble() * 0.5,
        phase: rand.nextDouble() * 2 * math.pi,
        kind: rand.nextInt(3),
      );

  final double x;
  final double z;
  final double h;
  final double phase;
  final int kind; // 0=야자수, 1=둥근수관, 2=원뿔
}

class _Leaf {
  _Leaf({
    required this.x,
    required this.y,
    required this.z,
    required this.scale,
    required this.rot,
    required this.phase,
  });

  factory _Leaf.random(math.Random rand) => _Leaf(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        z: -420 + rand.nextDouble() * 260, // 카메라 앞
        scale: 0.8 + rand.nextDouble() * 0.9,
        rot: rand.nextDouble() * math.pi,
        phase: rand.nextDouble() * 2 * math.pi,
      );

  final double x;
  final double y;
  final double z;
  final double scale;
  final double rot;
  final double phase;
}

class _Bird {
  _Bird({
    required this.lane,
    required this.speed,
    required this.z,
    required this.phase,
  });

  factory _Bird.random(math.Random rand) => _Bird(
        lane: rand.nextDouble() * 0.5,
        speed: 22 + rand.nextDouble() * 34,
        z: 600 + rand.nextDouble() * 1400,
        phase: rand.nextDouble() * 2 * math.pi,
      );

  final double lane;
  final double speed;
  final double z;
  final double phase;
}

/// 정글 월드 배경 — 하늘·태양·먼 산·안개 숲 3겹·원근 바닥·새·포자.
class _JungleWorldPainter extends CustomPainter {
  _JungleWorldPainter({
    required this.camera,
    required this.t,
    required this.spores,
    required this.canopy,
    required this.birds,
    required this.worldH,
  });

  final Offset camera;
  final double t;
  final List<Depth3DMote> spores;
  final List<_Tree> canopy;
  final List<_Bird> birds;
  final double worldH;

  static const Color _fog = Color(0xFF9FC4A8);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 하늘 — 아침 햇살이 스미는 밀림 상공.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF7DD3FC),
            Color(0xFFBBF7D0),
            Color(0xFF4D9A63),
            Color(0xFF14532D),
          ],
          stops: [0, 0.34, 0.62, 1],
        ).createShader(rect),
    );

    // 태양 — 카메라 y 에 살짝만 반응(아주 먼 평면).
    final sun = Offset(size.width * 0.78, 120 - camera.dy * 0.06);
    canvas.drawCircle(
      sun,
      190,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFEF9C3).withValues(alpha: 0.55),
            const Color(0xFFFEF9C3).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 190)),
    );
    canvas.drawCircle(
        sun, 42, Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: 0.9));

    // 먼 산등성이 2겹 — 깊이별 시차.
    _ridge(canvas, size, z: 2200, baseY: 0.42, amp: 26, color: const Color(0xFF7FB98C));
    _ridge(canvas, size, z: 1700, baseY: 0.48, amp: 34, color: const Color(0xFF5E9E72));

    // 원근 바닥 — 지평선 아래로 누운 숲 바닥.
    final horizon = size.height * 0.52 - camera.dy * Depth3D.scaleOf(900) * 0.12;
    PerspectiveGroundPainter(
      horizonY: horizon,
      near: const Color(0xFF14532D),
      far: const Color(0xFF4D9A63),
      lineColor: Colors.white.withValues(alpha: 0.30),
      rows: 8,
      cols: 12,
    ).paint(canvas, size, cameraX: camera.dx * 0.35);

    // 새 — 먼 하늘을 가로지른다.
    for (final b in birds) {
      final k = Depth3D.scaleOf(b.z);
      final travel = size.width + 120;
      final x = (b.phase * 90 + t * b.speed) % travel - 60;
      final y = size.height * (0.12 + b.lane * 0.3) - camera.dy * k * 0.5;
      _bird(canvas, Offset(x, y), 9 * k + 3, t + b.phase,
          Colors.black.withValues(alpha: 0.28 * (1 - Depth3D.hazeOf(b.z))));
    }

    // 안개 숲 — 깊이별 나무. 먼 대역부터 그려 앞쪽이 위로 겹치게 한다.
    final sorted = [...canopy]..sort((a, b) => b.z.compareTo(a.z));
    for (final tree in sorted) {
      final k = Depth3D.scaleOf(tree.z);
      final tileW = size.width * 2.2;
      final x = (tree.x * tileW - camera.dx * k) % tileW - size.width * 0.6;
      // 나무 밑동은 지평선보다 아래(가까울수록 더 아래).
      final baseY = horizon + (size.height - horizon) * (0.12 + (1 - k) * 0.1) +
          camera.dy * k * 0.06;
      _tree(canvas, Offset(x, baseY), 150 * k * tree.h, tree.kind, tree.z,
          t + tree.phase);
    }

    // 떠다니는 포자 — 깊이별 시차로 공기의 두께를 만든다.
    paintDepthMotes(
      canvas,
      size,
      motes: spores,
      camera: camera,
      t: t,
      color: const Color(0xFFF0FDF4),
      drift: -12,
      baseAlpha: 0.5,
    );

    // 상단 캐노피 그림자 — 잎 사이로 스미는 빛 느낌.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.22),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF052E16).withValues(alpha: 0.5),
            const Color(0xFF052E16).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.22)),
    );
    paintVignette(canvas, size, strength: 0.30);
  }

  /// 능선 실루엣 — 깊이 [z] 의 시차로 흐른다.
  void _ridge(Canvas canvas, Size size,
      {required double z,
      required double baseY,
      required double amp,
      required Color color}) {
    final k = Depth3D.scaleOf(z);
    final y = size.height * baseY - camera.dy * k * 0.5;
    final shift = camera.dx * k * 0.5;
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, y);
    for (double x = 0; x <= size.width; x += 14) {
      final n = math.sin((x + shift) / 160) * amp +
          math.sin((x + shift) / 61) * amp * 0.4;
      path.lineTo(x, y + n);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = Depth3D.fogged(color, _fog, z),
    );
  }

  void _bird(Canvas canvas, Offset c, double s, double phase, Color color) {
    final flap = math.sin(phase * 6) * 0.4;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.16)
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawLine(c, c + Offset(-s, -s * (0.5 + flap)), p);
    canvas.drawLine(c, c + Offset(s, -s * (0.5 - flap)), p);
  }

  /// 나무 한 그루 — 깊이에 따라 안개에 잠기고, 바람에 수관이 흔들린다.
  void _tree(Canvas canvas, Offset base, double h, int kind, double z,
      double phase) {
    if (h < 6) return;
    final sway = math.sin(phase * 0.8) * h * 0.02;
    final trunk = Depth3D.fogged(const Color(0xFF3F2A15), _fog, z);
    final leafDark = Depth3D.fogged(const Color(0xFF14532D), _fog, z);
    final leafLight = Depth3D.fogged(const Color(0xFF3F9D52), _fog, z);
    final top = Offset(base.dx + sway, base.dy - h);

    // 줄기.
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - h * 0.045, base.dy)
        ..lineTo(top.dx - h * 0.022, top.dy)
        ..lineTo(top.dx + h * 0.022, top.dy)
        ..lineTo(base.dx + h * 0.045, base.dy)
        ..close(),
      Paint()..color = trunk,
    );

    switch (kind) {
      case 0: // 야자수 — 잎이 방사형으로 늘어진다.
        for (var i = 0; i < 6; i++) {
          final a = math.pi + i * math.pi / 5 + math.sin(phase + i) * 0.05;
          final tip = top + Offset(math.cos(a), math.sin(a) * 0.75) * h * 0.42;
          final mid = Offset(
              (top.dx + tip.dx) / 2, (top.dy + tip.dy) / 2 - h * 0.08);
          canvas.drawPath(
            Path()
              ..moveTo(top.dx, top.dy)
              ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy)
              ..quadraticBezierTo(mid.dx, mid.dy + h * 0.06, top.dx, top.dy)
              ..close(),
            Paint()..color = i.isEven ? leafDark : leafLight,
          );
        }
      case 1: // 둥근 수관 — 덩어리 3개를 겹쳐 볼륨을 만든다.
        canvas.drawCircle(
            top + Offset(-h * 0.14, h * 0.06), h * 0.24, Paint()..color = leafDark);
        canvas.drawCircle(
            top + Offset(h * 0.16, h * 0.04), h * 0.21, Paint()..color = leafDark);
        canvas.drawCircle(top + Offset(0, -h * 0.06), h * 0.27,
            Paint()..color = leafLight);
      case 2: // 원뿔 — 층이 진 침엽수 느낌.
        for (var i = 0; i < 3; i++) {
          final f = i / 3;
          final cy = top.dy + h * (0.10 + f * 0.24);
          final w = h * (0.20 + f * 0.14);
          canvas.drawPath(
            Path()
              ..moveTo(top.dx, cy - h * 0.20)
              ..lineTo(top.dx - w, cy + h * 0.08)
              ..lineTo(top.dx + w, cy + h * 0.08)
              ..close(),
            Paint()..color = i.isEven ? leafDark : leafLight,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_JungleWorldPainter old) =>
      old.t != t || old.camera != camera;
}

/// 전경 평면(z<0) — 카메라 앞을 빠르게 스치는 잎사귀와 반딧불.
class _JungleForegroundPainter extends CustomPainter {
  _JungleForegroundPainter({
    required this.camera,
    required this.t,
    required this.fireflies,
    required this.leaves,
  });

  final Offset camera;
  final double t;
  final List<Depth3DMote> fireflies;
  final List<_Leaf> leaves;

  @override
  void paint(Canvas canvas, Size size) {
    // 반딧불 — 노랑 글로우 + 코어.
    for (final f in fireflies) {
      final k = Depth3D.scaleOf(f.z);
      final tileW = size.width + 200;
      final tileH = size.height + 200;
      final px = (f.x * tileW - camera.dx * k) % tileW - 100;
      final py = (f.y * tileH - camera.dy * k) % tileH - 100;
      final blink = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(f.phase + t * 3));
      final wob = Offset(math.sin(t * 1.6 + f.phase) * 7,
          math.cos(t * 1.3 + f.phase) * 5);
      final c = Offset(px, py) + wob;
      final r = math.max(1.2, f.r * k);
      canvas.drawCircle(
        c,
        r * 4.5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFDE047).withValues(alpha: 0.42 * blink),
              const Color(0xFFFDE047).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 4.5)),
      );
      canvas.drawCircle(
          c, r, Paint()..color = const Color(0xFFFFFBEB).withValues(alpha: blink));
    }

    // 전경 잎 — 카메라보다 앞이라 크고 빠르게 흐르며 화면을 살짝 가린다.
    for (final leaf in leaves) {
      final k = Depth3D.scaleOf(leaf.z); // z<0 → k>1
      final tileW = size.width * 1.6;
      final tileH = size.height * 1.6;
      final px = (leaf.x * tileW - camera.dx * k) % tileW - size.width * 0.3;
      final py = (leaf.y * tileH - camera.dy * k) % tileH - size.height * 0.3;
      final sway = math.sin(t * 0.9 + leaf.phase) * 0.12;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(leaf.rot + sway);
      final s = 120 * leaf.scale * k;
      // 잎사귀 — 두 개의 곡선으로 감싼 타원.
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(s * 0.34, -s * 0.30, s, 0)
        ..quadraticBezierTo(s * 0.34, s * 0.30, 0, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF052E16), Color(0xFF166534)],
          ).createShader(Rect.fromLTWH(0, -s * 0.3, s, s * 0.6))
          ..color = const Color(0xFF052E16),
      );
      // 잎맥.
      canvas.drawLine(
        Offset.zero,
        Offset(s, 0),
        Paint()
          ..color = const Color(0xFF86EFAC).withValues(alpha: 0.22)
          ..strokeWidth = 1.6,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_JungleForegroundPainter old) =>
      old.t != t || old.camera != camera;
}

// ── 데이터 ───────────────────────────────────────────────────────────

enum _SpotKind { temple, waterfall, tree, cave, village, flower }

class _JungleSpot {
  const _JungleSpot({
    required this.id,
    required this.name,
    required this.tagline,
    required this.story,
    required this.glow,
    required this.stats,
    required this.history,
    required this.pos,
    required this.size,
    required this.kind,
  });

  final String id;
  final String name;
  final String tagline;
  final String story;
  final Color glow;
  final List<(String, String)> stats;
  final List<(String, String, String)> history;
  final Offset pos;
  final double size;
  final _SpotKind kind;
}

/// 정글 명소 6곳.
const List<_JungleSpot> _spots = [
  _JungleSpot(
    id: 'temple',
    name: '잊혀진 신전',
    tagline: '덩굴에 잠긴 돌계단',
    story: '나무뿌리가 돌담을 꽉 끌어안고 있어요. 모찌가 이끼 낀 계단을 하나씩 '
        '오르자 새들이 후드득 날아올랐어요. 천 년 전 사람들도 여기서 하늘을 '
        '봤을까요?',
    glow: Color(0xFFFCD34D),
    stats: [
      ('나이', '약 1,100년'),
      ('높이', '65m'),
      ('재료', '사암 블록'),
    ],
    history: [
      ('802', '건립 시작', '밀림 한가운데 거대한 석조 신전이 세워졌어요.'),
      ('1431', '버려짐', '사람들이 떠나고 밀림이 신전을 삼켰어요.'),
      ('1860', '재발견', '탐험가가 덩굴 속 첨탑을 우연히 발견했어요.'),
      ('1992', '세계유산', '인류가 함께 지키는 유산이 됐어요.'),
    ],
    pos: Offset(760, 980),
    size: 190,
    kind: _SpotKind.temple,
  ),
  _JungleSpot(
    id: 'waterfall',
    name: '천둥 폭포',
    tagline: '소리가 먼저 도착하는 곳',
    story: '가까이 가기도 전에 우르릉 소리가 들려요. 물보라에 무지개가 걸리고, '
        '모찌 털이 촉촉해졌어요. 폭포 뒤에 작은 동굴이 숨어 있대요!',
    glow: Color(0xFF67E8F9),
    stats: [
      ('낙차', '82m'),
      ('폭', '150m'),
      ('물보라', '1km 밖까지'),
    ],
    history: [
      ('1541', '첫 기록', '탐험대가 "천둥 같은 물소리"를 일지에 남겼어요.'),
      ('1855', '이름 붙음', '지도에 처음으로 폭포 이름이 실렸어요.'),
      ('1934', '보호구역', '주변 밀림이 함께 보호되기 시작했어요.'),
      ('2009', '무지개 관측', '1년에 200일 무지개가 뜨는 게 확인됐어요.'),
    ],
    pos: Offset(1520, 1320),
    size: 180,
    kind: _SpotKind.waterfall,
  ),
  _JungleSpot(
    id: 'giant-tree',
    name: '거대 나무',
    tagline: '숲을 떠받치는 기둥',
    story: '한 그루가 작은 숲만큼 커요. 뿌리 사이가 방처럼 넓어서 모찌가 그 안에 '
        '들어가 낮잠을 잤어요. 나뭇잎 사이로 떨어지는 햇빛이 별처럼 반짝였대요.',
    glow: Color(0xFF86EFAC),
    stats: [
      ('높이', '88m'),
      ('나이', '1,200살'),
      ('둘레', '16m'),
    ],
    history: [
      ('1200s', '싹 틈', '작은 씨앗 하나가 흙을 뚫고 나왔어요.'),
      ('1900', '벌목 위기', '베어질 뻔했지만 마을 사람들이 지켰어요.'),
      ('1978', '보호수 지정', '법으로 보호받는 나무가 됐어요.'),
      ('2015', '캐노피 연구', '나무 위에서만 사는 생물 40종이 발견됐어요.'),
    ],
    pos: Offset(2280, 900),
    size: 210,
    kind: _SpotKind.tree,
  ),
  _JungleSpot(
    id: 'cave',
    name: '수정 동굴',
    tagline: '어둠 속에서 빛나는 방',
    story: '동굴 천장에 수정이 별처럼 박혀 있어요. 모찌가 손전등을 비추자 온 벽이 '
        '반짝반짝! 조용히 물방울 떨어지는 소리만 들려요.',
    glow: Color(0xFFC4B5FD),
    stats: [
      ('길이', '3.2km'),
      ('수정', '최대 11m'),
      ('습도', '99%'),
    ],
    history: [
      ('1910', '갱도 발견', '광산을 파다 우연히 입구가 열렸어요.'),
      ('2000', '수정 방', '거대 수정으로 가득한 공간이 발견됐어요.'),
      ('2007', '탐사 중단', '너무 뜨거워 오래 머물 수 없다는 게 밝혀졌어요.'),
      ('2017', '보존 결정', '동굴을 다시 닫아 수정을 보호하기로 했어요.'),
    ],
    pos: Offset(3000, 1450),
    size: 175,
    kind: _SpotKind.cave,
  ),
  _JungleSpot(
    id: 'village',
    name: '나무 위 마을',
    tagline: '땅에 내려오지 않는 사람들',
    story: '나무 꼭대기에 집이 줄지어 있고, 흔들다리가 집과 집을 잇고 있어요. '
        '모찌가 다리를 건널 때마다 출렁출렁! 아래를 안 보는 게 좋대요.',
    glow: Color(0xFFFDBA74),
    stats: [
      ('높이', '지상 35m'),
      ('가구', '18채'),
      ('다리', '총 400m'),
    ],
    history: [
      ('1600s', '정착', '홍수를 피해 나무 위에 집을 짓기 시작했어요.'),
      ('1974', '첫 방문', '외부인이 처음으로 마을을 방문했어요.'),
      ('1998', '학교 개교', '나무 위에 작은 학교가 생겼어요.'),
      ('2020', '생태 관광', '마을이 직접 숲 안내를 시작했어요.'),
    ],
    pos: Offset(3680, 1000),
    size: 190,
    kind: _SpotKind.village,
  ),
  _JungleSpot(
    id: 'flower',
    name: '거대 꽃',
    tagline: '세상에서 가장 큰 꽃',
    story: '꽃 한 송이가 모찌보다 커요! 향기는… 음, 조금 특이하대요. 몇 년을 '
        '기다려 딱 며칠만 피는 귀한 꽃이라 운이 좋았어요.',
    glow: Color(0xFFFB7185),
    stats: [
      ('지름', '106cm'),
      ('무게', '11kg'),
      ('개화', '단 5일'),
    ],
    history: [
      ('1818', '발견', '탐험대가 밀림에서 거대한 꽃을 처음 봤어요.'),
      ('1928', '생태 규명', '다른 식물에 붙어 사는 기생식물임이 밝혀졌어요.'),
      ('1993', '보호 시작', '서식지 파괴로 보호가 시작됐어요.'),
      ('2020', '최대 기록', '지름 111cm 짜리 꽃이 발견됐어요.'),
    ],
    pos: Offset(4200, 1500),
    size: 170,
    kind: _SpotKind.flower,
  ),
];

// ── 명소 비주얼 ──────────────────────────────────────────────────────

class _JungleSpotPainter extends CustomPainter {
  _JungleSpotPainter(this.s, {required this.t});

  final _JungleSpot s;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 접지 그림자 — 게임 평면 위에 놓인 느낌.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.95), width: w * 0.78, height: h * 0.1),
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );
    switch (s.kind) {
      case _SpotKind.temple:
        _temple(canvas, w, h);
      case _SpotKind.waterfall:
        _waterfall(canvas, w, h);
      case _SpotKind.tree:
        _giantTree(canvas, w, h);
      case _SpotKind.cave:
        _cave(canvas, w, h);
      case _SpotKind.village:
        _village(canvas, w, h);
      case _SpotKind.flower:
        _flower(canvas, w, h);
    }
  }

  /// 위에서 빛을 받는 돌 블록 — 윗면은 밝고 옆면은 어둡게 해 입체로 보인다.
  void _block(Canvas canvas, Rect r, {Color base = const Color(0xFF9CA3AF)}) {
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.35)!,
            Color.lerp(base, Colors.black, 0.35)!,
          ],
        ).createShader(r),
    );
    // 윗면 하이라이트.
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, math.max(1.5, r.height * 0.16)),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  void _temple(Canvas canvas, double w, double h) {
    // 계단식 피라미드 — 위로 갈수록 좁아지는 4단.
    for (var i = 0; i < 4; i++) {
      final f = i / 4;
      final tierW = w * (0.82 - f * 0.46);
      final y = h * (0.86 - i * 0.16);
      _block(
        canvas,
        Rect.fromCenter(
            center: Offset(w / 2, y), width: tierW, height: h * 0.14),
      );
    }
    // 꼭대기 사당.
    _block(canvas,
        Rect.fromCenter(center: Offset(w / 2, h * 0.26), width: w * 0.2, height: h * 0.16),
        base: const Color(0xFFB8A88A));
    // 중앙 계단.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.72), width: w * 0.14, height: h * 0.4),
      Paint()..color = const Color(0xFF6B7280),
    );
    // 덩굴 — 돌 위로 늘어진다.
    final vine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF16A34A);
    for (final fx in [0.22, 0.42, 0.68, 0.82]) {
      final path = Path()..moveTo(w * fx, h * 0.34);
      for (var i = 1; i <= 4; i++) {
        final f = i / 4;
        path.lineTo(
          w * fx + math.sin(t * 1.1 + fx * 8 + f * 3) * w * 0.03,
          h * (0.34 + f * 0.5),
        );
      }
      canvas.drawPath(path, vine);
    }
    // 신비로운 빛.
    final glowC = Offset(w / 2, h * 0.26);
    canvas.drawCircle(
      glowC,
      w * 0.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            s.glow.withValues(alpha: 0.28 + 0.1 * math.sin(t * 2)),
            s.glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowC, radius: w * 0.2)),
    );
  }

  void _waterfall(Canvas canvas, double w, double h) {
    // 절벽 — 좌우 바위.
    final cliff = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6B7280), Color(0xFF1F2937)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.1)
        ..lineTo(w * 0.32, h * 0.16)
        ..lineTo(w * 0.30, h * 0.92)
        ..lineTo(0, h * 0.92)
        ..close(),
      cliff,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h * 0.1)
        ..lineTo(w * 0.68, h * 0.16)
        ..lineTo(w * 0.70, h * 0.92)
        ..lineTo(w, h * 0.92)
        ..close(),
      cliff,
    );
    // 물줄기 — 흐르는 결.
    final water = Rect.fromLTWH(w * 0.30, h * 0.14, w * 0.40, h * 0.66);
    canvas.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0369A1)],
        ).createShader(water),
    );
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final x = w * (0.33 + i * 0.085);
      final off = (t * 120 + i * 40) % (h * 0.66);
      canvas.drawLine(Offset(x, h * 0.14 + off),
          Offset(x, h * 0.14 + math.min(off + h * 0.12, h * 0.66)), streak);
    }
    // 물보라.
    for (var i = 0; i < 6; i++) {
      final f = (t * 0.9 + i / 6) % 1.0;
      canvas.drawCircle(
        Offset(w * (0.36 + (i % 3) * 0.14), h * 0.80 - f * h * 0.12),
        w * (0.03 + f * 0.05),
        Paint()..color = Colors.white.withValues(alpha: 0.30 * (1 - f)),
      );
    }
    // 아래 웅덩이.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.86), width: w * 0.72, height: h * 0.14),
      Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.75),
    );
  }

  void _giantTree(Canvas canvas, double w, double h) {
    // 판근(뿌리 판) — 아래가 넓게 퍼진다.
    final trunk = Path()
      ..moveTo(w * 0.20, h * 0.92)
      ..quadraticBezierTo(w * 0.40, h * 0.70, w * 0.42, h * 0.34)
      ..lineTo(w * 0.58, h * 0.34)
      ..quadraticBezierTo(w * 0.60, h * 0.70, w * 0.80, h * 0.92)
      ..close();
    canvas.drawPath(
      trunk,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF8B5E34), Color(0xFF4A2E12)],
        ).createShader(Rect.fromLTWH(w * 0.2, 0, w * 0.6, h)),
    );
    // 수관 — 겹친 덩어리로 볼륨.
    final crown = [
      (0.5, 0.20, 0.30, const Color(0xFF15803D)),
      (0.28, 0.26, 0.22, const Color(0xFF166534)),
      (0.72, 0.26, 0.22, const Color(0xFF166534)),
      (0.42, 0.13, 0.19, const Color(0xFF22C55E)),
      (0.62, 0.15, 0.17, const Color(0xFF22C55E)),
    ];
    for (final (fx, fy, r, color) in crown) {
      final sway = math.sin(t * 0.9 + fx * 6) * w * 0.012;
      canvas.drawCircle(
          Offset(w * fx + sway, h * fy), w * r, Paint()..color = color);
    }
    // 잎 사이 햇살.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.2),
      w * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFEF9C3).withValues(alpha: 0.22),
            const Color(0xFFFEF9C3).withValues(alpha: 0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(w * 0.5, h * 0.2), radius: w * 0.34)),
    );
  }

  void _cave(Canvas canvas, double w, double h) {
    // 바위 언덕.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.04, h * 0.92)
        ..quadraticBezierTo(w * 0.2, h * 0.24, w * 0.5, h * 0.20)
        ..quadraticBezierTo(w * 0.8, h * 0.24, w * 0.96, h * 0.92)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF78716C), Color(0xFF292524)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // 입구 — 안쪽이 깊어 보이도록 중심이 어두운 그라디언트.
    final mouth = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.72), width: w * 0.44, height: h * 0.44);
    canvas.drawOval(
      mouth,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF020617),
            const Color(0xFF1E1B4B).withValues(alpha: 0.9),
          ],
        ).createShader(mouth),
    );
    // 수정 — 입구 주변에서 반짝인다.
    for (final (fx, fy, fs, rot) in [
      (0.30, 0.62, 0.10, -0.3),
      (0.70, 0.58, 0.12, 0.35),
      (0.50, 0.46, 0.09, 0.05),
      (0.62, 0.78, 0.07, -0.15),
    ]) {
      final blink = 0.55 + 0.45 * math.sin(t * 2.4 + fx * 9);
      canvas.save();
      canvas.translate(w * fx, h * fy);
      canvas.rotate(rot);
      final cw = w * fs;
      canvas.drawPath(
        Path()
          ..moveTo(0, -cw * 1.5)
          ..lineTo(cw * 0.6, 0)
          ..lineTo(0, cw * 1.2)
          ..lineTo(-cw * 0.6, 0)
          ..close(),
        Paint()..color = s.glow.withValues(alpha: blink),
      );
      canvas.restore();
    }
    // 동굴 속 은은한 빛.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.72),
      w * 0.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            s.glow.withValues(alpha: 0.30),
            s.glow.withValues(alpha: 0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(w * 0.5, h * 0.72), radius: w * 0.18)),
    );
  }

  void _village(Canvas canvas, double w, double h) {
    // 나무 기둥 2그루.
    for (final fx in [0.22, 0.78]) {
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w * fx, h * 0.62), width: w * 0.09, height: h * 0.66),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF8B5E34), Color(0xFF4A2E12)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      // 잎.
      canvas.drawCircle(Offset(w * fx, h * 0.22), w * 0.17,
          Paint()..color = const Color(0xFF166534));
    }
    // 흔들다리 — 살짝 처진 곡선 + 널판.
    final sag = h * 0.06 + math.sin(t * 1.3) * h * 0.012;
    final bridge = Path()
      ..moveTo(w * 0.24, h * 0.50)
      ..quadraticBezierTo(w * 0.5, h * 0.50 + sag, w * 0.76, h * 0.50);
    canvas.drawPath(
      bridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF7C4A1E),
    );
    for (var i = 0; i <= 8; i++) {
      final f = i / 8;
      final x = w * (0.24 + f * 0.52);
      final y = h * 0.50 + math.sin(f * math.pi) * sag;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: w * 0.045, height: 3),
        Paint()..color = const Color(0xFFB07A3E),
      );
    }
    // 나무집 2채 — 지붕은 밝게, 벽은 어둡게.
    for (final fx in [0.22, 0.78]) {
      final body = Rect.fromCenter(
          center: Offset(w * fx, h * 0.40), width: w * 0.22, height: h * 0.14);
      canvas.drawRect(body, Paint()..color = const Color(0xFF8B5E34));
      canvas.drawPath(
        Path()
          ..moveTo(w * fx - w * 0.15, h * 0.33)
          ..lineTo(w * fx, h * 0.24)
          ..lineTo(w * fx + w * 0.15, h * 0.33)
          ..close(),
        Paint()..color = const Color(0xFFD8A25E),
      );
      // 창문 불빛.
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w * fx, h * 0.40), width: w * 0.06, height: h * 0.06),
        Paint()
          ..color = s.glow
              .withValues(alpha: 0.6 + 0.3 * math.sin(t * 2 + fx * 5)),
      );
    }
  }

  void _flower(Canvas canvas, double w, double h) {
    final c = Offset(w / 2, h * 0.58);
    // 잎사귀 바닥.
    for (final a in [2.4, 3.5, 0.4, 5.6]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(math.cos(a), math.sin(a) * 0.5) * w * 0.34,
          width: w * 0.3,
          height: w * 0.14,
        ),
        Paint()..color = const Color(0xFF166534),
      );
    }
    // 꽃잎 5장 — 숨쉬듯 아주 살짝 벌어진다.
    final breathe = 1 + math.sin(t * 1.1) * 0.02;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final pc = c + Offset(math.cos(a), math.sin(a) * 0.78) * w * 0.20 * breathe;
      canvas.save();
      canvas.translate(pc.dx, pc.dy);
      canvas.rotate(a + math.pi / 2);
      final petal = Rect.fromCenter(
          center: Offset.zero, width: w * 0.26, height: w * 0.34);
      canvas.drawOval(
        petal,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFDA4AF), Color(0xFF9F1239)],
          ).createShader(petal),
      );
      // 반점 무늬.
      final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
      canvas.drawCircle(Offset(-w * 0.04, -w * 0.05), w * 0.014, dot);
      canvas.drawCircle(Offset(w * 0.03, w * 0.02), w * 0.012, dot);
      canvas.restore();
    }
    // 가운데 컵 — 안쪽이 깊어 보이게.
    final cup = Rect.fromCenter(
        center: c, width: w * 0.26, height: w * 0.20);
    canvas.drawOval(
      cup,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF450A0A),
            const Color(0xFF7F1D1D).withValues(alpha: 0.9),
          ],
        ).createShader(cup),
    );
    canvas.drawOval(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFECDD3).withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_JungleSpotPainter old) => old.t != t || old.s != s;
}

// ── 착륙(탐험) 시트 ──────────────────────────────────────────────────

class _JungleSpotSheet extends StatelessWidget {
  const _JungleSpotSheet({
    required this.spot,
    required this.collected,
    required this.total,
  });

  final _JungleSpot spot;
  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = spot;
    final maxH = MediaQuery.of(context).size.height * 0.82;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: const Color(0xFF14301C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: s.glow.withValues(alpha: 0.5), width: 1.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 96,
                        height: 88,
                        child: CustomPaint(
                            painter: _JungleSpotPainter(s, t: 1.2)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: s.glow.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '🌿 정글 탐험',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: s.glow,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '${s.name} 도착!',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 21,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.tagline,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFFB7D9C0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final (i, stat) in s.stats.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  stat.$1,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Color(0xFF8FB89A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  stat.$2,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _JungleCard(
                    title: '모찌의 탐험 일지',
                    emoji: '📖',
                    child: Text(
                      s.story,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                        height: 1.65,
                        color: Color(0xFFDCEFE1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _JungleCard(
                    title: '밀림 연대기',
                    emoji: '📜',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, hRow) in s.history.indexed)
                          _JungleTimelineRow(
                            year: hRow.$1,
                            title: hRow.$2,
                            desc: hRow.$3,
                            accent: s.glow,
                            isLast: i == s.history.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ExploreSpotExtras(
                    realmKey: 'jungle',
                    realmEmoji: '🌿',
                    spotId: s.id,
                    spotName: s.name,
                    accent: s.glow,
                    collected: collected,
                    total: total,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '계속 탐험하기',
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
          ),
        ],
      ),
    );
  }
}

class _JungleCard extends StatelessWidget {
  const _JungleCard({
    required this.title,
    required this.emoji,
    required this.child,
  });

  final String title;
  final String emoji;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _JungleTimelineRow extends StatelessWidget {
  const _JungleTimelineRow({
    required this.year,
    required this.title,
    required this.desc,
    required this.accent,
    required this.isLast,
  });

  final String year;
  final String title;
  final String desc;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.6,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          year,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                      height: 1.5,
                      color: Color(0xFFB7D9C0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
