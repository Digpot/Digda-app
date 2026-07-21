import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import 'explore_3d.dart';
import 'explore_rewards.dart';

/// 모찌 해저 탐험 — 탐험 허브에서 진입하는 자유비행 심해 콘텐츠.
///
/// 화면을 꾹 누르면 모찌 잠수함이 그 방향으로 추진하고, 떼면 물의 저항으로
/// 미끄러지다 멈춘다. 수심이 깊어질수록 화면이 어두워지고 잠수함의 서치라이트가
/// 켜진다. 산호초 정원부터 마리아나 해구까지 6곳의 심해 명소에 다가가면
/// '탐험하기' 프롬프트가 떠오르고, 착륙하면 스탯·탐험 일지·심해 연대기를 감상한다.
///
/// 서버 연동 없는 순수 클라이언트 콘텐츠 — 새 명소는 [_spots] 에 추가하면 된다.
class UnderseaExploreScreen extends StatefulWidget {
  const UnderseaExploreScreen({super.key, required this.character});

  final CharacterState character;

  @override
  State<UnderseaExploreScreen> createState() => _UnderseaExploreScreenState();
}

class _UnderseaExploreScreenState extends State<UnderseaExploreScreen>
    with TickerProviderStateMixin {
  // ── 월드/물리 상수 ────────────────────────────────────────────────
  static const double _worldW = 4400;
  static const double _worldH = 2400;
  static const double _surfaceY = 150; // 수면 월드 y
  static const double _maxDepthM = 10935; // 마리아나 해구 깊이(m)
  static const double _accel = 880;
  static const double _maxSpeed = 470; // 물속이라 우주보다 느리다
  static const double _drag = 2.2; // 물의 저항

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _time = 0;

  Offset _ship = const Offset(460, 330);
  Offset _vel = Offset.zero;
  Offset? _pointer;
  Size _viewport = Size.zero;
  bool _facingLeft = false;

  final Set<String> _visited = <String>{};
  bool _showHint = true;
  bool _panelOpen = false;
  bool _celebrated = false;

  /// 깊이가 제각각인 부유 입자/기포 — 원근 시차로 물의 두께를 만든다.
  late final List<Depth3DMote> _motes;
  late final List<_Fish> _fishes;

  @override
  void initState() {
    super.initState();
    final rand = math.Random(20260720);
    _motes = List.generate(
      92,
      (_) => Depth3DMote.random(rand,
          minZ: -160, maxZ: 2200, minR: 1.2, maxR: 3.6, twinkle: 0.3),
    );
    _fishes = List.generate(7, (_) => _Fish.random(rand));
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── 게임 루프 ─────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.05) dt = 0.016;
    _time = elapsed.inMicroseconds / 1e6;

    if (!_panelOpen) {
      final pointer = _pointer;
      if (pointer != null) {
        final target = pointer + _camera;
        final dir = target - _ship;
        final dist = dir.distance;
        if (dist > 12) {
          _vel += dir / dist * _accel * dt;
        }
      }
      final damp = (1 - _drag * dt).clamp(0.0, 1.0);
      _vel = _vel * damp;
      final speed = _vel.distance;
      if (speed > _maxSpeed) _vel = _vel / speed * _maxSpeed;
      if (_vel.dx.abs() > 24) _facingLeft = _vel.dx < 0;
      _ship += _vel * dt;
      // 수면 아래 ~ 해저 바닥, 월드 좌우 안에서만.
      final cx = _ship.dx.clamp(80.0, _worldW - 80.0);
      final cy = _ship.dy.clamp(_surfaceY + 90.0, _worldH - 80.0);
      if (cx != _ship.dx) _vel = Offset(0, _vel.dy);
      if (cy != _ship.dy) _vel = Offset(_vel.dx, 0);
      _ship = Offset(cx, cy);
    }
    if (mounted) setState(() {});
  }

  Offset get _camera {
    final dx = (_ship.dx - _viewport.width / 2)
        .clamp(0.0, math.max(0.0, _worldW - _viewport.width))
        .toDouble();
    final dy = (_ship.dy - _viewport.height / 2)
        .clamp(0.0, math.max(0.0, _worldH - _viewport.height))
        .toDouble();
    return Offset(dx, dy);
  }

  /// 현재 수심(m) — 월드 y 를 0~10,935m 로 사상.
  int get _depthMeters => ((_ship.dy - _surfaceY - 90) /
          (_worldH - _surfaceY - 170) *
          _maxDepthM)
      .clamp(0, _maxDepthM)
      .round();

  /// 0(수면)~1(해구 바닥) — 배경 어둡기/서치라이트 판단용.
  double get _depthFrac =>
      ((_ship.dy - _surfaceY) / (_worldH - _surfaceY)).clamp(0.0, 1.0);

  _SeaSpot? get _nearbySpot {
    for (final s in _spots) {
      if (((s.pos - _ship).distance) < s.size / 2 + 120) return s;
    }
    return null;
  }

  _SeaSpot? get _nearestUnvisited {
    _SeaSpot? best;
    double bestD = double.infinity;
    for (final s in _spots) {
      if (_visited.contains(s.id)) continue;
      final d = (s.pos - _ship).distance;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  Future<void> _openSpot(_SeaSpot s) async {
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
      builder: (_) => _SeaSpotSheet(
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
        backgroundColor: const Color(0xFF0B2434),
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                '심해 완전 정복!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '모찌가 수면부터 마리아나 해구까지\n모든 심해 명소를 탐험했어요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  height: 1.55,
                  color: Color(0xFFA5C8DB),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
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
      backgroundColor: const Color(0xFF04263B),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final camera = _camera;
          final nearby = _nearbySpot;
          return Stack(
            fit: StackFit.expand,
            children: [
              // 조종 입력 + 물속 배경(수심 그라디언트·빛내림·기포·물고기).
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
                  painter: _SeaWorldPainter(
                    camera: camera,
                    t: _time,
                    motes: _motes,
                    fishes: _fishes,
                    depthFrac: (camera.dy / (_worldH - _viewport.height))
                        .clamp(0.0, 1.0),
                    surfaceScreenY: _surfaceY - camera.dy,
                    worldH: _worldH,
                  ),
                ),
              ),
              // 심해 명소들.
              for (final s in _spots) ..._buildSpot(s, camera),
              // 다음 업데이트 예고 표지판.
              _buildComingSoonSign(camera),
              // 모찌 잠수함.
              _buildSub(camera),
              // 심해 어둠 + 서치라이트 — 잠수함 주변만 밝힌다.
              if (_depthFrac > 0.45)
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DarknessPainter(
                      hole: _ship - camera,
                      strength:
                          (((_depthFrac - 0.45) / 0.55) * 0.6).clamp(0.0, 0.6),
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

  List<Widget> _buildSpot(_SeaSpot s, Offset camera) {
    final sp = s.pos - camera;
    if (sp.dx < -320 ||
        sp.dx > _viewport.width + 320 ||
        sp.dy < -320 ||
        sp.dy > _viewport.height + 320) {
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
            child: CustomPaint(painter: _SeaSpotPainter(s, t: _time)),
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
                  ),
                ),
                Text(
                  s.depthLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.65),
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
                      border:
                          Border.all(color: s.glow.withValues(alpha: 0.5)),
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
    final sp = const Offset(_worldW - 210, 700) - camera;
    return Positioned(
      left: sp.dx - 90,
      top: sp.dy - 50,
      child: IgnorePointer(
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Column(
            children: [
              Text('🐙', style: TextStyle(fontSize: 26)),
              SizedBox(height: 6),
              Text(
                '다음 업데이트에서\n새로운 바다가 열려요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  height: 1.4,
                  color: Color(0xFF9DBFD1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSub(Offset camera) {
    final sp = _ship - camera;
    final speed = _vel.distance;
    // 하강/상승 방향으로 뱃머리가 기울고, 정지 시 물결에 두둥실.
    final dir = _facingLeft ? -1.0 : 1.0;
    final pitch = (_vel.dy / 1500 * dir).clamp(-0.22, 0.22).toDouble();
    final bob = speed < 30 ? math.sin(_time * 1.8) * 5 : 0.0;
    const subW = 150.0;
    const subH = 110.0;
    return Positioned(
      left: sp.dx - subW / 2,
      top: sp.dy - subH / 2 + bob,
      child: IgnorePointer(
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateZ(pitch)
            ..scaleByDouble(dir, 1.0, 1.0, 1.0),
          alignment: Alignment.center,
          child: _MochiSub(
            character: widget.character,
            t: _time,
            thrusting: _pointer != null,
            lightOn: _depthFrac > 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildExplorePrompt(_SeaSpot s, Offset camera) {
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
                  colors: [Color(0xFF0891B2), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '🤿 ${s.name} 탐험하기',
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
    final depth = _depthMeters;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '해저 탐험',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 8),
              // 진행도 + 수심계 — 좁은 화면에선 축소되도록 Flexible+FittedBox.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: done >= total
                            ? const Color(0xFFFCD34D).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      '${done >= total ? '🏆' : '🐚'} $done/$total · ${depth}m',
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
    final dir = target.pos - _ship;
    final angle = math.atan2(dir.dy, dir.dx);
    final cx = sp.dx.clamp(64.0, math.max(64.0, _viewport.width - 64.0))
        .toDouble();
    final cy = sp.dy.clamp(120.0, math.max(120.0, _viewport.height - 90.0))
        .toDouble();
    return [
      Positioned(
        left: cx - 55,
        top: cy - 24,
        child: IgnorePointer(
          child: Container(
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B2434).withValues(alpha: 0.85),
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
            color: const Color(0xFF0B2434).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👆🛥️', style: TextStyle(fontSize: 30)),
              SizedBox(height: 10),
              Text(
                '잠수함 조종법',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '화면을 꾹 누르고 있으면\n모찌 잠수함이 그쪽으로 헤엄쳐요!\n깊이 내려갈수록 어두워지니 조심하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFFA5C8DB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 모찌 잠수함 ──────────────────────────────────────────────────────

/// 노란 잠수함을 탄 모찌 — 유리 돔 + 프로펠러 + 서치라이트 + 기포 트레일.
class _MochiSub extends StatelessWidget {
  const _MochiSub({
    required this.character,
    required this.t,
    this.thrusting = false,
    this.lightOn = false,
  });

  final CharacterState character;
  final double t;
  final bool thrusting;
  final bool lightOn;

  @override
  Widget build(BuildContext context) {
    const hullW = 128.0;
    const hullH = 52.0;
    const domeSize = 62.0;
    return SizedBox(
      width: 150,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 서치라이트 — 뱃머리(오른쪽)에서 앞으로 퍼지는 광추.
          if (lightOn)
            Positioned(
              left: 118,
              top: 34,
              child: CustomPaint(
                size: const Size(70, 60),
                painter: _BeamPainter(),
              ),
            ),
          // 기포 트레일 — 추진 중 꼬리(왼쪽)에서 보글보글.
          if (thrusting)
            Positioned(
              left: 0,
              top: 40,
              child: CustomPaint(
                size: const Size(26, 40),
                painter: _TrailBubblePainter(t: t),
              ),
            ),
          // 선체 — 노란 캡슐, 위에서 빛을 받는 3단 그라디언트.
          Positioned(
            left: 14,
            top: 40,
            child: Container(
              width: hullW,
              height: hullH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFEF08A),
                    Color(0xFFF59E0B),
                    Color(0xFF92400E),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF92400E).withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              // 현창(둥근 창) 2개.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF7DD3FC), Color(0xFF0369A1)],
                        ),
                        border: Border.all(
                          color: const Color(0xFF92400E), width: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 꼬리 프로펠러 — 회전.
          Positioned(
            left: 2,
            top: 52,
            child: Transform.rotate(
              angle: t * (thrusting ? 16 : 7),
              child: CustomPaint(
                size: const Size(26, 26),
                painter: _PropellerPainter(),
              ),
            ),
          ),
          // 등 지느러미.
          Positioned(
            left: 34,
            top: 30,
            child: Container(
              width: 20,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(3),
                ),
              ),
            ),
          ),
          // 유리 돔 콕핏 — 모찌 탑승.
          Positioned(
            left: 60,
            top: 8,
            child: Container(
              width: domeSize,
              height: domeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1.4,
                ),
              ),
              child: ClipOval(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: MochiCharacterView(
                      appearance: MochiAppearance.fromState(character),
                      stage: character.stage,
                      size: domeSize * 0.74,
                      part: MochiCharacterPart.body,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 돔 하이라이트.
          Positioned(
            left: 68,
            top: 14,
            child: Container(
              width: 20,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropellerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final blade = Paint()
      ..color = const Color(0xFF78350F)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * math.pi / 3;
      canvas.drawLine(
          c, c + Offset(math.cos(a), math.sin(a)) * size.width * 0.42, blade);
    }
    canvas.drawCircle(c, 3.4, Paint()..color = const Color(0xFF451A03));
  }

  @override
  bool shouldRepaint(_PropellerPainter old) => false;
}

/// 서치라이트 광추 — 앞으로 퍼지는 반투명 원뿔.
class _BeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.42)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height * 0.58)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFEF9C3).withValues(alpha: 0.5),
            const Color(0xFFFEF9C3).withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) => false;
}

/// 추진 기포 트레일.
class _TrailBubblePainter extends CustomPainter {
  _TrailBubblePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < 3; i++) {
      final f = (t * 2 + i / 3) % 1.0;
      final x = size.width * (1 - f);
      final y = size.height * 0.5 + math.sin(t * 6 + i * 2) * 8;
      canvas.drawCircle(Offset(x, y), 2 + f * 3, paint);
    }
  }

  @override
  bool shouldRepaint(_TrailBubblePainter old) => old.t != t;
}

// ── 데이터 ───────────────────────────────────────────────────────────

enum _SpotKind { coral, kelp, wreck, volcano, vent, trench }

class _SeaSpot {
  const _SeaSpot({
    required this.id,
    required this.name,
    required this.tagline,
    required this.story,
    required this.glow,
    required this.depthLabel,
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
  final String depthLabel;
  final List<(String, String)> stats;
  final List<(String, String, String)> history;
  final Offset pos;
  final double size;
  final _SpotKind kind;
}

/// 심해 명소 6곳 — 얕은 곳부터 깊은 곳 순서로 월드에 배치.
const List<_SeaSpot> _spots = [
  _SeaSpot(
    id: 'coral',
    name: '산호초 정원',
    tagline: '바닷속 무지개 도시',
    story: '알록달록 산호 사이로 물고기 떼가 강물처럼 흘러가요. 모찌가 니모 닮은 '
        '물고기와 숨바꼭질을 했는데, 말미잘 속에 숨는 바람에 결국 찾지 못했대요.',
    glow: Color(0xFFFB7185),
    depthLabel: '수심 ~30m',
    stats: [
      ('수심', '0~30m'),
      ('주민', '해양생물 25%'),
      ('온도', '23~29℃'),
    ],
    history: [
      ('1842', '다윈', '산호초가 만들어지는 원리를 처음 밝혔어요.'),
      ('1943', '아쿠아렁', '쿠스토가 발명해 잠수 탐험 시대가 열렸어요.'),
      ('1981', '대보초', '세계에서 가장 큰 산호초가 세계유산이 됐어요.'),
      ('2020', '산호 이식', '하얗게 아픈 산호를 되살리는 노력이 계속돼요.'),
    ],
    pos: Offset(700, 430),
    size: 170,
    kind: _SpotKind.coral,
  ),
  _SeaSpot(
    id: 'kelp',
    name: '자이언트 켈프 숲',
    tagline: '바닷속 마천루 숲',
    story: '하루에 50cm 씩 자라는 거대 해조류가 숲을 이뤄요. 모찌가 켈프 줄기를 '
        '타고 미끄럼을 탔더니 해달 가족이 박수를 쳐줬어요. 물속 숲은 바람 대신 '
        '물결에 흔들린대요.',
    glow: Color(0xFF34D399),
    depthLabel: '수심 ~40m',
    stats: [
      ('성장', '하루 50cm'),
      ('높이', '최대 45m'),
      ('주민', '해달·물개'),
    ],
    history: [
      ('1872', '챌린저호', '바다 전체를 조사한 첫 탐사가 시작됐어요.'),
      ('1911', '켈프 수확', '사람들이 켈프의 가치를 알게 됐어요.'),
      ('1980', '해달의 귀환', '해달을 지키자 켈프 숲이 되살아났어요.'),
      ('2007', '위성 지도', '우주에서 켈프 숲 지도를 그리기 시작했어요.'),
    ],
    pos: Offset(1450, 650),
    size: 180,
    kind: _SpotKind.kelp,
  ),
  _SeaSpot(
    id: 'wreck',
    name: '침몰선 타이타닉',
    tagline: '깊은 바다의 타임캡슐',
    story: '100년 넘게 잠들어 있는 거대한 배예요. 모찌가 살금살금 갑판 위를 '
        '걸어봤어요. 물고기들이 창문으로 드나드는 모습이 꼭 바닷속 아파트 같았대요.',
    glow: Color(0xFFFCD34D),
    depthLabel: '수심 3,800m',
    stats: [
      ('수심', '3,800m'),
      ('침몰', '1912년'),
      ('발견', '1985년'),
    ],
    history: [
      ('1912', '타이타닉 침몰', '빙산과 부딪혀 대서양에 가라앉았어요.'),
      ('1985', '밸러드 탐사대', '수중 로봇으로 73년 만에 찾아냈어요.'),
      ('1986', '앨빈호', '유인 잠수정이 처음으로 선체를 둘러봤어요.'),
      ('2012', '수중 유산', '유네스코가 수중 문화유산으로 보호해요.'),
    ],
    pos: Offset(2200, 1000),
    size: 190,
    kind: _SpotKind.wreck,
  ),
  _SeaSpot(
    id: 'volcano',
    name: '해저 화산',
    tagline: '바다가 끓어오르는 곳',
    story: '바닷속에서도 화산이 폭발해요! 보글보글 끓는 바위 틈에서 김이 모락모락 '
        '올라와요. 모찌는 안전거리에서 심해 온천욕(?)을 즐기고 왔답니다.',
    glow: Color(0xFFFB923C),
    depthLabel: '수심 ~1,000m',
    stats: [
      ('해저 화산', '100만 개+'),
      ('최대', '태무 산괴'),
      ('새 섬', '수르트세이'),
    ],
    history: [
      ('1963', '수르트세이', '해저 분화로 새로운 섬이 태어났어요.'),
      ('2013', '태무 산괴', '지구 최대 화산이 바닷속에서 확인됐어요.'),
      ('2015', '새 화산섬', '일본 니시노시마가 계속 자라났어요.'),
      ('2022', '통가 분화', '우주에서도 보인 대분화가 일어났어요.'),
    ],
    pos: Offset(2950, 1400),
    size: 180,
    kind: _SpotKind.volcano,
  ),
  _SeaSpot(
    id: 'vent',
    name: '심해 열수분출공',
    tagline: '심해의 검은 굴뚝',
    story: '햇빛이 하나도 없는데 굴뚝 주변에 생물이 바글바글해요! 새하얀 게와 '
        '거대한 관벌레가 400℃ 물줄기 옆에서 살아가요. 모찌는 심해 생물 친구를 '
        '잔뜩 사귀었어요.',
    glow: Color(0xFF22D3EE),
    depthLabel: '수심 2,500m',
    stats: [
      ('수온', '최대 400℃'),
      ('수심', '~2,500m'),
      ('생존', '햇빛 없이'),
    ],
    history: [
      ('1977', '갈라파고스', '앨빈호가 처음으로 발견했어요.'),
      ('1979', '블랙스모커', '검은 연기 굴뚝을 확인했어요.'),
      ('1981', '관벌레', '햇빛 없이 사는 생태계가 밝혀졌어요.'),
      ('2000', '로스트시티', '새하얀 굴뚝 열수지대를 찾았어요.'),
    ],
    pos: Offset(3550, 1800),
    size: 160,
    kind: _SpotKind.vent,
  ),
  _SeaSpot(
    id: 'trench',
    name: '마리아나 해구',
    tagline: '지구에서 가장 깊은 곳',
    story: '에베레스트를 거꾸로 넣어도 잠기는 깊이예요. 칠흑 같은 어둠 속에서 '
        '스스로 빛나는 물고기들이 별처럼 반짝여요. 모찌가 지구의 가장 깊은 바닥에 '
        '발도장을 찍었어요!',
    glow: Color(0xFFA78BFA),
    depthLabel: '수심 10,935m',
    stats: [
      ('수심', '10,935m'),
      ('수압', '지상의 1,000배'),
      ('온도', '1~4℃'),
    ],
    history: [
      ('1875', '챌린저호', '밧줄을 내려 깊이를 처음 쟀어요.'),
      ('1960', '트리에스테', '피카르와 월시가 처음 바닥에 닿았어요.'),
      ('2012', '제임스 캐머런', '52년 만에 혼자서 다시 내려갔어요.'),
      ('2019', '베스코보', '10,928m — 가장 깊은 기록을 세웠어요.'),
    ],
    pos: Offset(4050, 2200),
    size: 200,
    kind: _SpotKind.trench,
  ),
];

// ── 배경/파티클 ──────────────────────────────────────────────────────

class _Fish {
  _Fish({
    required this.lane,
    required this.speed,
    required this.size,
    required this.phase,
    required this.toRight,
  });

  factory _Fish.random(math.Random rand) => _Fish(
        lane: rand.nextDouble(),
        speed: 26 + rand.nextDouble() * 40,
        size: 9 + rand.nextDouble() * 9,
        phase: rand.nextDouble() * 2 * math.pi,
        toRight: rand.nextBool(),
      );

  final double lane; // 0~1 화면 세로 비율
  final double speed;
  final double size;
  final double phase;
  final bool toRight;
}

/// 물속 배경 — 수심 그라디언트 + 수면 물결 + 빛내림 + 기포 + 물고기 실루엣.
class _SeaWorldPainter extends CustomPainter {
  _SeaWorldPainter({
    required this.camera,
    required this.t,
    required this.motes,
    required this.fishes,
    required this.depthFrac,
    required this.surfaceScreenY,
    required this.worldH,
  });

  final Offset camera;
  final double t;
  final List<Depth3DMote> motes;
  final List<_Fish> fishes;
  final double depthFrac; // 0(수면)~1(바닥) — 카메라 기준
  final double surfaceScreenY;
  final double worldH;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 수심 그라디언트 — 내려갈수록 빛이 사라진다.
    final top = Color.lerp(
        const Color(0xFF0EA5E9), const Color(0xFF05243D), depthFrac)!;
    final mid = Color.lerp(
        const Color(0xFF0369A1), const Color(0xFF031A30), depthFrac)!;
    final bottom = Color.lerp(
        const Color(0xFF0C4A6E), const Color(0xFF010A14), depthFrac)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, mid, bottom],
        ).createShader(rect),
    );

    // 수면 — 화면 근처일 때만: 물결 라인 + 위쪽 밝은 띠.
    if (surfaceScreenY > -80 && surfaceScreenY < size.height + 40) {
      final sky = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF7DD3FC).withValues(alpha: 0.9),
            const Color(0xFF38BDF8).withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromLTWH(0, surfaceScreenY - 60, size.width, 130));
      canvas.drawRect(
          Rect.fromLTWH(0, surfaceScreenY - 60, size.width, 130), sky);
      final wave = Path()..moveTo(0, surfaceScreenY);
      for (double x = 0; x <= size.width; x += 8) {
        wave.lineTo(
          x,
          surfaceScreenY +
              math.sin(x / 46 + t * 1.6) * 5 +
              math.sin(x / 21 - t * 2.3) * 2.4,
        );
      }
      canvas.drawPath(
        wave,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = Colors.white.withValues(alpha: 0.75),
      );
    }

    // 빛내림(god rays) — 얕은 수심에서만 보인다.
    final rayAlpha = (1 - depthFrac * 1.8).clamp(0.0, 1.0) * 0.09;
    if (rayAlpha > 0.005) {
      for (var i = 0; i < 4; i++) {
        final x =
            size.width * (0.12 + i * 0.26) - camera.dx * 0.18 % size.width;
        final sway = math.sin(t * 0.7 + i * 1.7) * 26;
        final path = Path()
          ..moveTo(x + sway - 20, -10)
          ..lineTo(x + sway + 26, -10)
          ..lineTo(x + sway + 110, size.height + 10)
          ..lineTo(x + sway + 30, size.height + 10)
          ..close();
        canvas.drawPath(
            path, Paint()..color = Colors.white.withValues(alpha: rayAlpha));
      }
    }

    // 먼 바위 능선 — 깊은 평면이라 아주 느리게 흐르고 물빛에 잠긴다.
    for (final ridge in [
      (2100.0, 0.70, const Color(0xFF0B3B57)),
      (1300.0, 0.80, const Color(0xFF07263A)),
    ]) {
      final (z, baseY, color) = ridge;
      final k = Depth3D.scaleOf(z);
      final y = size.height * baseY - camera.dy * k * 0.5;
      final shift = camera.dx * k * 0.5;
      final path = Path()
        ..moveTo(0, size.height)
        ..lineTo(0, y);
      for (double x = 0; x <= size.width; x += 16) {
        path.lineTo(
          x,
          y +
              math.sin((x + shift) / 150) * 30 +
              math.sin((x + shift) / 57) * 12,
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.75 * (1 - Depth3D.hazeOf(z))),
      );
    }

    // 부유 입자/기포 — 깊이(z)별 시차로 물의 두께를 만든다. 위로 상승.
    paintDepthMotes(
      canvas,
      size,
      motes: motes,
      camera: camera,
      t: t,
      color: Colors.white,
      drift: 26,
      baseAlpha: 0.34,
      stroke: true,
    );

    // 물고기 실루엣 — 화면 공간을 가로질러 헤엄친다(깊은 곳에선 드물게).
    final fishAlpha = (1 - depthFrac * 1.3).clamp(0.15, 1.0) * 0.4;
    for (final f in fishes) {
      final travel = size.width + 80;
      final raw = (f.phase * 60 + t * f.speed) % travel;
      final x = f.toRight ? raw - 40 : size.width + 40 - raw;
      final y = f.lane * size.height +
          math.sin(t * 2 + f.phase) * 7 -
          camera.dy * 0.1 % 40;
      _drawFish(canvas, Offset(x, y), f.size, f.toRight, fishAlpha);
    }
  }

  void _drawFish(
      Canvas canvas, Offset c, double s, bool toRight, double alpha) {
    final dir = toRight ? 1.0 : -1.0;
    final body = Paint()..color = const Color(0xFF0B3B57).withValues(alpha: alpha);
    canvas.drawOval(
        Rect.fromCenter(center: c, width: s * 1.7, height: s * 0.8), body);
    final tail = Path()
      ..moveTo(c.dx - dir * s * 0.8, c.dy)
      ..lineTo(c.dx - dir * s * 1.35, c.dy - s * 0.42)
      ..lineTo(c.dx - dir * s * 1.35, c.dy + s * 0.42)
      ..close();
    canvas.drawPath(tail, body);
  }

  @override
  bool shouldRepaint(_SeaWorldPainter old) =>
      old.t != t || old.camera != camera;
}

/// 심해 어둠 — 잠수함 주변만 서치라이트로 밝힌 방사형 비네트.
class _DarknessPainter extends CustomPainter {
  _DarknessPainter({required this.hole, required this.strength});

  final Offset hole;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.max(size.width, size.height) * 1.1;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (hole.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
            (hole.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
          ),
          radius: 1.15,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: strength * 0.4),
            Colors.black.withValues(alpha: strength),
          ],
          stops: const [0.16, 0.4, 1],
        ).createShader(
            Rect.fromCircle(center: hole, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_DarknessPainter old) =>
      old.hole != hole || old.strength != strength;
}

// ── 심해 명소 비주얼 ─────────────────────────────────────────────────

/// 명소를 종류별로 3D 느낌(위에서 오는 빛·입체 그라디언트·애니메이션)으로 그린다.
class _SeaSpotPainter extends CustomPainter {
  _SeaSpotPainter(this.s, {required this.t});

  final _SeaSpot s;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 바닥 접지 그림자 — 모든 명소 공통.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.94), width: w * 0.8, height: h * 0.1),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    switch (s.kind) {
      case _SpotKind.coral:
        _paintCoral(canvas, w, h);
      case _SpotKind.kelp:
        _paintKelp(canvas, w, h);
      case _SpotKind.wreck:
        _paintWreck(canvas, w, h);
      case _SpotKind.volcano:
        _paintVolcano(canvas, w, h);
      case _SpotKind.vent:
        _paintVent(canvas, w, h);
      case _SpotKind.trench:
        _paintTrench(canvas, w, h);
    }
  }

  /// 모래 언덕 — 위에서 빛을 받는 그라디언트 반타원.
  void _sand(Canvas canvas, double w, double h, {double top = 0.72}) {
    final rect = Rect.fromLTWH(w * 0.04, h * top, w * 0.92, h * (1 - top));
    canvas.drawOval(
      rect.inflate(2),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDE68A), Color(0xFF92400E)],
        ).createShader(rect),
    );
  }

  void _paintCoral(Canvas canvas, double w, double h) {
    _sand(canvas, w, h);
    // 산호 가지 3덩어리 — 물결 따라 잔잔히 흔들린다.
    final corals = [
      (0.24, const Color(0xFFFB7185), const Color(0xFF9F1239)),
      (0.50, const Color(0xFFFB923C), const Color(0xFF9A3412)),
      (0.76, const Color(0xFFA78BFA), const Color(0xFF5B21B6)),
    ];
    for (final (i, (fx, bright, dark)) in corals.indexed) {
      final sway = math.sin(t * 1.4 + i * 2.1) * 0.05;
      final baseX = w * fx;
      final stemTop = h * (0.30 + 0.06 * i);
      canvas.save();
      canvas.translate(baseX, h * 0.78);
      canvas.rotate(sway);
      canvas.translate(-baseX, -h * 0.78);
      // 줄기.
      final stem = Rect.fromLTWH(baseX - w * 0.030, stemTop, w * 0.06,
          h * 0.78 - stemTop);
      canvas.drawRRect(
        RRect.fromRectAndRadius(stem, Radius.circular(w * 0.03)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bright, dark],
          ).createShader(stem),
      );
      // 가지 끝 몽글이 3개 — 좌상단 광원 그라디언트로 입체감.
      for (final (dx, dy, r) in [
        (-0.075, 0.02, 0.062),
        (0.0, -0.05, 0.075),
        (0.075, 0.03, 0.058),
      ]) {
        final c = Offset(baseX + w * dx, stemTop + h * dy);
        canvas.drawCircle(
          c,
          w * r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.5),
              colors: [Color.lerp(bright, Colors.white, 0.45)!, dark],
            ).createShader(Rect.fromCircle(center: c, radius: w * r)),
        );
      }
      canvas.restore();
    }
    // 잔 물고기 반짝임.
    final spark = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 3; i++) {
      final a = t * 1.1 + i * 2.1;
      canvas.drawCircle(
        Offset(w * (0.5 + 0.32 * math.cos(a)), h * (0.42 + 0.16 * math.sin(a))),
        1.8,
        spark,
      );
    }
  }

  void _paintKelp(Canvas canvas, double w, double h) {
    _sand(canvas, w, h, top: 0.78);
    for (var i = 0; i < 5; i++) {
      final fx = 0.15 + i * 0.175;
      final tall = h * (0.62 + (i % 2) * 0.12);
      final bright = i.isEven
          ? const Color(0xFF34D399)
          : const Color(0xFF10B981);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.028
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bright, const Color(0xFF065F46)],
        ).createShader(Rect.fromLTWH(0, h - tall, w, tall));
      final path = Path()..moveTo(w * fx, h * 0.82);
      const segs = 6;
      for (var sIdx = 1; sIdx <= segs; sIdx++) {
        final f = sIdx / segs;
        final y = h * 0.82 - tall * f;
        final sway = math.sin(t * 1.6 + i * 1.3 + f * 3.2) * w * 0.05 * f;
        path.lineTo(w * fx + sway, y);
        // 잎 — 줄기 좌우로 번갈아.
        if (sIdx < segs) {
          final leafC = Offset(
              w * fx + sway + (sIdx.isEven ? w * 0.045 : -w * 0.045), y);
          canvas.drawOval(
            Rect.fromCenter(
                center: leafC, width: w * 0.075, height: w * 0.03),
            Paint()..color = bright.withValues(alpha: 0.8),
          );
        }
      }
      canvas.drawPath(path, stroke);
    }
  }

  void _paintWreck(Canvas canvas, double w, double h) {
    _sand(canvas, w, h, top: 0.8);
    canvas.save();
    canvas.translate(w / 2, h * 0.62);
    canvas.rotate(-0.10);
    canvas.translate(-w / 2, -h * 0.62);
    // 선체 — 위(빛)는 밝고 아래는 짙은 갈색.
    final hull = Rect.fromLTWH(w * 0.10, h * 0.42, w * 0.80, h * 0.34);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        hull,
        topLeft: Radius.circular(w * 0.05),
        topRight: Radius.circular(w * 0.14),
        bottomLeft: Radius.circular(w * 0.16),
        bottomRight: Radius.circular(w * 0.24),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB45309), Color(0xFF451A03)],
        ).createShader(hull),
    );
    // 갑판 상부 구조.
    final cabin = Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.26, h * 0.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cabin, Radius.circular(w * 0.02)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF92400E), Color(0xFF57290A)],
        ).createShader(cabin),
    );
    // 부러진 마스트.
    final mast = Paint()
      ..color = const Color(0xFF57290A)
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.62, h * 0.42), Offset(w * 0.70, h * 0.12), mast);
    canvas.drawLine(
        Offset(w * 0.66, h * 0.22), Offset(w * 0.80, h * 0.20), mast);
    // 현창 — 은은히 빛난다.
    for (var i = 0; i < 3; i++) {
      final c = Offset(w * (0.24 + i * 0.18), h * 0.55);
      final glow = 0.35 + 0.2 * math.sin(t * 1.3 + i);
      canvas.drawCircle(
          c, w * 0.035, Paint()..color = const Color(0xFF0B3B57));
      canvas.drawCircle(
        c,
        w * 0.025,
        Paint()..color = const Color(0xFFFCD34D).withValues(alpha: glow),
      );
    }
    // 갑판 윗면 림라이트.
    canvas.drawLine(
      Offset(w * 0.10, h * 0.42),
      Offset(w * 0.90, h * 0.42),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.restore();
  }

  void _paintVolcano(Canvas canvas, double w, double h) {
    // 화산체 — 어두운 현무암 원뿔.
    final cone = Path()
      ..moveTo(w * 0.06, h * 0.92)
      ..quadraticBezierTo(w * 0.30, h * 0.55, w * 0.40, h * 0.24)
      ..lineTo(w * 0.60, h * 0.24)
      ..quadraticBezierTo(w * 0.70, h * 0.55, w * 0.94, h * 0.92)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF57534E), Color(0xFF1C1917)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // 분화구 발광.
    final crater = Offset(w * 0.5, h * 0.24);
    canvas.drawOval(
      Rect.fromCenter(center: crater, width: w * 0.22, height: h * 0.06),
      Paint()..color = const Color(0xFFF97316),
    );
    canvas.drawCircle(
      crater,
      w * 0.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF97316)
                .withValues(alpha: 0.5 + 0.15 * math.sin(t * 3)),
            const Color(0xFFF97316).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: crater, radius: w * 0.2)),
    );
    // 용암 줄기.
    final lava = Paint()
      ..color = const Color(0xFFFB923C)
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.44, h * 0.27), Offset(w * 0.36, h * 0.52), lava);
    canvas.drawLine(
        Offset(w * 0.58, h * 0.27), Offset(w * 0.64, h * 0.44), lava);
    // 연기(기포 섞인 열수) — 위로 올라가며 커지고 옅어진다.
    for (var i = 0; i < 3; i++) {
      final f = (t * 0.35 + i / 3) % 1.0;
      final c = Offset(
        w * 0.5 + math.sin(t + i * 2) * w * 0.06 * f,
        h * 0.20 - f * h * 0.24,
      );
      canvas.drawCircle(
        c,
        w * (0.035 + f * 0.055),
        Paint()
          ..color = const Color(0xFF9CA3AF).withValues(alpha: 0.35 * (1 - f)),
      );
    }
  }

  void _paintVent(Canvas canvas, double w, double h) {
    _sand(canvas, w, h, top: 0.82);
    // 굴뚝 2개 — 위로 갈수록 가늘어지는 검은 기둥.
    for (final (fx, fh) in [(0.36, 0.62), (0.62, 0.48)]) {
      final chimney = Path()
        ..moveTo(w * (fx - 0.085), h * 0.85)
        ..lineTo(w * (fx - 0.035), h * (0.85 - fh))
        ..lineTo(w * (fx + 0.035), h * (0.85 - fh))
        ..lineTo(w * (fx + 0.085), h * 0.85)
        ..close();
      canvas.drawPath(
        chimney,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF57534E), Color(0xFF0C0A09)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      // 분출구 발광.
      canvas.drawCircle(
        Offset(w * fx, h * (0.85 - fh)),
        w * 0.035,
        Paint()
          ..color = const Color(0xFFF97316)
              .withValues(alpha: 0.5 + 0.2 * math.sin(t * 4 + fx * 9)),
      );
      // 검은 연기 — 흔들리며 상승.
      for (var i = 0; i < 4; i++) {
        final f = (t * 0.4 + i / 4 + fx) % 1.0;
        final c = Offset(
          w * fx + math.sin(t * 1.5 + i + fx * 7) * w * 0.05 * f,
          h * (0.85 - fh) - f * h * 0.34,
        );
        canvas.drawCircle(
          c,
          w * (0.03 + f * 0.06),
          Paint()
            ..color =
                const Color(0xFF1C1917).withValues(alpha: 0.5 * (1 - f)),
        );
      }
    }
    // 새하얀 심해 게 반짝임.
    final crab = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(w * 0.5, h * 0.83), 2.4, crab);
    canvas.drawCircle(Offset(w * 0.44, h * 0.86), 1.8, crab);
  }

  void _paintTrench(Canvas canvas, double w, double h) {
    // 해구 절벽 — V자로 갈라진 심연.
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.34, 0)
      ..lineTo(w * 0.46, h)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(w, 0)
      ..lineTo(w * 0.66, 0)
      ..lineTo(w * 0.54, h)
      ..lineTo(w, h)
      ..close();
    final wall = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E3A5F), Color(0xFF020617)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(left, wall);
    canvas.drawPath(right, wall);
    // 절벽 단층 라인.
    final ledge = Paint()
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 1; i <= 3; i++) {
      canvas.drawLine(Offset(w * (0.34 + 0.03 * i), h * (i / 3.6)),
          Offset(w * (0.10 - 0.02 * i), h * (i / 3.6)), ledge);
      canvas.drawLine(Offset(w * (0.66 - 0.03 * i), h * (i / 3.6)),
          Offset(w * (0.90 + 0.02 * i), h * (i / 3.6)), ledge);
    }
    // 심연의 신비로운 발광.
    final glowC = Offset(w * 0.5, h * 0.88);
    canvas.drawCircle(
      glowC,
      w * 0.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFA78BFA)
                .withValues(alpha: 0.24 + 0.1 * math.sin(t * 1.8)),
            const Color(0xFFA78BFA).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowC, radius: w * 0.2)),
    );
    // 초롱아귀 불빛 — 깜빡이며 떠다닌다.
    final lure = Offset(
      w * 0.5 + math.sin(t * 0.9) * w * 0.05,
      h * 0.62 + math.sin(t * 1.7) * h * 0.03,
    );
    canvas.drawCircle(
      lure,
      2.6,
      Paint()
        ..color = const Color(0xFF67E8F9)
            .withValues(alpha: 0.6 + 0.4 * math.sin(t * 5)),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: lure + Offset(w * 0.02, h * 0.02),
          width: w * 0.07,
          height: w * 0.045),
      Paint()..color = const Color(0xFF0B1B2B).withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SeaSpotPainter old) => old.t != t || old.s != s;
}

// ── 착륙(탐험) 시트 ──────────────────────────────────────────────────

class _SeaSpotSheet extends StatelessWidget {
  const _SeaSpotSheet({
    required this.spot,
    required this.collected,
    required this.total,
  });

  final _SeaSpot spot;
  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = spot;
    final maxH = MediaQuery.of(context).size.height * 0.82;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2434),
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
                            painter: _SeaSpotPainter(s, t: 1.2)),
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
                                '🤿 ${s.depthLabel}',
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
                                color: Color(0xFFA5C8DB),
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
                                  color:
                                      Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  stat.$1,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Color(0xFF7FA8BC),
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
                  _SeaGlassCard(
                    title: '모찌의 탐험 일지',
                    emoji: '📖',
                    child: Text(
                      s.story,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                        height: 1.65,
                        color: Color(0xFFD2E6EF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SeaGlassCard(
                    title: '심해 연대기',
                    emoji: '📜',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, hRow) in s.history.indexed)
                          _SeaTimelineRow(
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
                    realmKey: 'undersea',
                    realmEmoji: '🌊',
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
                        backgroundColor: const Color(0xFF0891B2),
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

class _SeaGlassCard extends StatelessWidget {
  const _SeaGlassCard({
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

class _SeaTimelineRow extends StatelessWidget {
  const _SeaTimelineRow({
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
                      color: Color(0xFFA5C8DB),
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
