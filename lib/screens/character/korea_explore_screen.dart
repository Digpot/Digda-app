import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import 'explore_3d.dart';
import 'explore_rewards.dart';

/// 모찌 한국의 역사 탐험 — 방패연을 타고 오천 년 역사를 시대순으로 나는 시간여행.
///
/// 월드는 왼쪽(고조선)에서 오른쪽(대한민국)으로 시대순 배치되어 있고,
/// 날아가는 위치에 따라 하늘빛이 시대의 색(청동기 새벽 → 삼국 아침 →
/// 고려 옥빛 → 조선 노을 → 현대 하늘)으로 서서히 물든다. 각 시대에서는
/// 인물·전쟁·문화재 연대기와 깜짝 퀴즈, 기념품 스탬프를 만날 수 있다.
class KoreaExploreScreen extends StatefulWidget {
  const KoreaExploreScreen({super.key, required this.character});

  final CharacterState character;

  @override
  State<KoreaExploreScreen> createState() => _KoreaExploreScreenState();
}

class _KoreaExploreScreenState extends State<KoreaExploreScreen>
    with TickerProviderStateMixin {
  // ── 월드/물리 ─────────────────────────────────────────────────────
  static const double _worldW = 5400;
  static const double _worldH = 2200;
  static const double _accel = 900;
  static const double _maxSpeed = 500;
  static const double _drag = 1.9;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _time = 0;
  int _tickCount = 0;

  Offset _kite = const Offset(420, 950);
  Offset _vel = Offset.zero;
  Offset? _pointer;
  Size _viewport = Size.zero;

  final Set<String> _visited = <String>{};
  bool _showHint = true;
  bool _panelOpen = false;
  bool _celebrated = false;

  late final List<Depth3DMote> _dust;
  late final List<Depth3DMote> _sparks;
  late final List<_Pine> _pines;
  late final List<_Petal> _petals;
  late final List<_Crane> _cranes;

  @override
  void initState() {
    super.initState();
    final rand = math.Random(20260721);
    _dust = List.generate(
      46,
      (_) => Depth3DMote.random(rand,
          minZ: 500, maxZ: 2400, minR: 1.2, maxR: 3.0, twinkle: 0.4),
    );
    _sparks = List.generate(
      18,
      (_) => Depth3DMote.random(rand,
          minZ: -260, maxZ: 380, minR: 1.4, maxR: 2.6),
    );
    _pines = List.generate(40, (_) => _Pine.random(rand));
    _petals = List.generate(14, (_) => _Petal.random(rand));
    _cranes = List.generate(4, (_) => _Crane.random(rand));
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
    _tickCount += 1;

    if (!_panelOpen) {
      final pointer = _pointer;
      if (pointer != null) {
        final target = pointer + _camera;
        final dir = target - _kite;
        final dist = dir.distance;
        if (dist > 12) _vel += dir / dist * _accel * dt;
      }
      final damp = (1 - _drag * dt).clamp(0.0, 1.0);
      _vel = _vel * damp;
      final speed = _vel.distance;
      if (speed > _maxSpeed) _vel = _vel / speed * _maxSpeed;
      _kite += _vel * dt;
      final cx = _kite.dx.clamp(80.0, _worldW - 80.0);
      final cy = _kite.dy.clamp(150.0, _worldH - 120.0);
      if (cx != _kite.dx) _vel = Offset(0, _vel.dy);
      if (cy != _kite.dy) _vel = Offset(_vel.dx, 0);
      _kite = Offset(cx, cy);
    } else if (_tickCount % 4 != 0) {
      // 시트가 열려 배경이 대부분 가려진 동안엔 리페인트를 1/4 로 줄인다(배터리).
      return;
    }
    if (mounted) setState(() {});
  }

  Offset get _camera {
    final dx = (_kite.dx - _viewport.width / 2)
        .clamp(0.0, math.max(0.0, _worldW - _viewport.width))
        .toDouble();
    final dy = (_kite.dy - _viewport.height / 2)
        .clamp(0.0, math.max(0.0, _worldH - _viewport.height))
        .toDouble();
    return Offset(dx, dy);
  }

  _KoreaEra? get _nearbySpot {
    for (final s in _eras) {
      if (((s.pos - _kite).distance) < s.size / 2 + 120) return s;
    }
    return null;
  }

  _KoreaEra? get _nearestUnvisited {
    _KoreaEra? best;
    double bestD = double.infinity;
    for (final s in _eras) {
      if (_visited.contains(s.id)) continue;
      final d = (s.pos - _kite).distance;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  /// 현재 위치의 시대 — x 축 기준 가장 가까운 시대. HUD 표시용.
  _KoreaEra get _currentEra {
    _KoreaEra best = _eras.first;
    double bestD = double.infinity;
    for (final s in _eras) {
      final d = (s.pos.dx - _kite.dx).abs();
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  Future<void> _openSpot(_KoreaEra s) async {
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
      builder: (_) => _EraSheet(
        era: s,
        collected: _visited.length,
        total: _eras.length,
      ),
    );
    if (!mounted) return;
    setState(() => _panelOpen = false);
    _maybeCelebrate();
  }

  void _maybeCelebrate() {
    if (_celebrated || _visited.length < _eras.length) return;
    _celebrated = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF2C1810),
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
              color: const Color(0xFFFCD34D).withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                '오천 년 역사 완전 정복!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '고조선부터 대한민국까지,\n모찌가 시간여행을 완주했어요.\n진짜 역사 박사네요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  height: 1.55,
                  color: Color(0xFFE7CBA9),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2410C),
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
      backgroundColor: const Color(0xFF1C120A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final camera = _camera;
          final nearby = _nearbySpot;
          return Stack(
            fit: StackFit.expand,
            children: [
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
                  painter: _KoreaWorldPainter(
                    camera: camera,
                    t: _time,
                    dust: _dust,
                    pines: _pines,
                    cranes: _cranes,
                    viewportW: _viewport.width,
                  ),
                ),
              ),
              for (final s in _eras) ..._buildSpot(s, camera),
              _buildKite(camera),
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _KoreaForegroundPainter(
                    camera: camera,
                    t: _time,
                    sparks: _sparks,
                    petals: _petals,
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

  List<Widget> _buildSpot(_KoreaEra s, Offset camera) {
    final sp = s.pos - camera;
    if (sp.dx < -360 ||
        sp.dx > _viewport.width + 360 ||
        sp.dy < -360 ||
        sp.dy > _viewport.height + 360) {
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
            child: CustomPaint(painter: _EraSpotPainter(s, t: _time)),
          ),
        ),
      ),
      Positioned(
        left: sp.dx - 90,
        top: sp.dy + s.size / 2 + 2,
        child: IgnorePointer(
          child: SizedBox(
            width: 180,
            child: Column(
              children: [
                Text(
                  s.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
                Text(
                  s.period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: s.glow.withValues(alpha: 0.95),
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 5),
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

  Widget _buildKite(Offset camera) {
    final sp = _kite - camera;
    final speed = _vel.distance;
    final roll = (_vel.dx / 1100).clamp(-0.28, 0.28).toDouble();
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
          child: _MochiKite(
            character: widget.character,
            t: _time,
            windy: _pointer != null,
          ),
        ),
      ),
    );
  }

  Widget _buildExplorePrompt(_KoreaEra s, Offset camera) {
    final sp = s.pos - camera;
    final bounce = math.sin(_time * 4) * 4;
    final left = (sp.dx - 92)
        .clamp(8.0, math.max(8.0, _viewport.width - 192))
        .toDouble();
    final top = (sp.dy - s.size / 2 - 54 + bounce)
        .clamp(90.0, math.max(90.0, _viewport.height - 60))
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: 184,
        child: Center(
          child: GestureDetector(
            onTap: () => _openSpot(s),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC2410C), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
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
    final total = _eras.length;
    final era = _currentEra;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Column(
            children: [
              Row(
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
                    '한국의 역사 탐험',
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
                                ? const Color(0xFFFCD34D)
                                    .withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          '${done >= total ? '🏆' : '📜'} $done/$total',
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
              const SizedBox(height: 6),
              // 지금 나는 시대 — 시간여행 감각의 핵심 HUD.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(era.id),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: era.glow.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: era.glow.withValues(alpha: 0.55)),
                  ),
                  child: Text(
                    '🕰 지금은 ${era.name} · ${era.period}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: era.glow,
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 6),
                      ],
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
    final dir = target.pos - _kite;
    final angle = math.atan2(dir.dy, dir.dx);
    final cx =
        sp.dx.clamp(64.0, math.max(64.0, _viewport.width - 64.0)).toDouble();
    final cy = sp.dy
        .clamp(150.0, math.max(150.0, _viewport.height - 90.0))
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
              color: const Color(0xFF2C1810).withValues(alpha: 0.88),
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
            color: const Color(0xFF2C1810).withValues(alpha: 0.93),
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
              Text('👆🪁', style: TextStyle(fontSize: 30)),
              SizedBox(height: 10),
              Text(
                '시간여행 조종법',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '화면을 꾹 누르면 방패연이 그쪽으로 날아가요!\n'
                '왼쪽이 옛날, 오른쪽으로 갈수록 현재예요.\n'
                '고조선부터 대한민국까지 일곱 시대를 찾아가 보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFFE7CBA9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 모찌 방패연 ──────────────────────────────────────────────────────

/// 모찌가 탄 방패연 — 한지 연 + 태극 방구멍 + 십자 살 + 꼬리 리본.
class _MochiKite extends StatelessWidget {
  const _MochiKite({
    required this.character,
    required this.t,
    this.windy = false,
  });

  final CharacterState character;
  final double t;
  final bool windy;

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
          Positioned(
            top: 0,
            child: SizedBox(
              width: 128,
              height: 150,
              child: CustomPaint(painter: _KitePainter(t: t, windy: windy)),
            ),
          ),
          Positioned(
            top: 26,
            child: MochiCharacterView(
              appearance: MochiAppearance.fromState(character),
              stage: character.stage,
              size: 84,
              part: MochiCharacterPart.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _KitePainter extends CustomPainter {
  _KitePainter({required this.t, required this.windy});

  final double t;
  final bool windy;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(w * 0.1, h * 0.34, w * 0.8, h * 0.52);

    final wind = windy ? 1.6 : 1.0;
    for (final (i, color) in const [
      (0, Color(0xFFDC2626)),
      (1, Color(0xFF2563EB)),
      (2, Color(0xFFF59E0B)),
    ]) {
      final sx = w * (0.35 + i * 0.15);
      final path = Path()..moveTo(sx, rect.bottom - 4);
      for (var k = 1; k <= 4; k++) {
        final yy = rect.bottom + k * h * 0.055;
        final sway = math.sin(t * 5 * wind + i * 1.7 + k) * 7 * wind;
        path.lineTo(sx + sway, yy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.9),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(2, 5), const Radius.circular(10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFDE9C8)],
        ).createShader(rect),
    );

    final c = rect.center;
    final r = rect.width * 0.2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1C120A));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.72),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.72),
      0,
      math.pi,
      true,
      Paint()..color = const Color(0xFF2563EB),
    );

    final rib = Paint()
      ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.65)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(rect.left, c.dy), Offset(rect.right, c.dy), rib);
    canvas.drawLine(Offset(c.dx, rect.top), Offset(c.dx, rect.bottom), rib);
    canvas.drawLine(rect.topLeft, rect.bottomRight, rib);
    canvas.drawLine(rect.topRight, rect.bottomLeft, rib);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF8B5A2B),
    );

    canvas.drawLine(
      Offset(c.dx, rect.top),
      Offset(c.dx + math.sin(t * 2) * 6, 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_KitePainter old) => old.t != t || old.windy != windy;
}

// ── 배경 요소 ────────────────────────────────────────────────────────

class _Pine {
  _Pine({
    required this.x,
    required this.z,
    required this.h,
    required this.phase,
    required this.roof,
  });

  factory _Pine.random(math.Random rand) => _Pine(
        x: rand.nextDouble(),
        z: [260.0, 720.0, 1500.0][rand.nextInt(3)] + rand.nextDouble() * 240,
        h: 0.55 + rand.nextDouble() * 0.5,
        phase: rand.nextDouble() * 2 * math.pi,
        roof: rand.nextInt(4) == 0,
      );

  final double x;
  final double z;
  final double h;
  final double phase;
  final bool roof;
}

class _Petal {
  _Petal({
    required this.x,
    required this.y,
    required this.z,
    required this.scale,
    required this.phase,
  });

  factory _Petal.random(math.Random rand) => _Petal(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        z: -420 + rand.nextDouble() * 500,
        scale: 0.7 + rand.nextDouble() * 0.8,
        phase: rand.nextDouble() * 2 * math.pi,
      );

  final double x;
  final double y;
  final double z;
  final double scale;
  final double phase;
}

class _Crane {
  _Crane(
      {required this.lane,
      required this.speed,
      required this.z,
      required this.phase});

  factory _Crane.random(math.Random rand) => _Crane(
        lane: rand.nextDouble() * 0.5,
        speed: 20 + rand.nextDouble() * 30,
        z: 600 + rand.nextDouble() * 1400,
        phase: rand.nextDouble() * 2 * math.pi,
      );

  final double lane;
  final double speed;
  final double z;
  final double phase;
}

/// 한국 산하 배경 — **시대에 따라 하늘빛이 변하는** 수묵 산수.
///
/// 카메라 x 진행도로 인접 시대의 하늘색을 보간해, 왼쪽(고조선)에서
/// 오른쪽(대한민국)으로 날수록 청동기 새벽 → 삼국 아침 → 고려 옥빛 →
/// 조선 노을 → 현대 하늘로 물든다. 각 시대 상공엔 시대 이름이 워터마크로
/// 떠 있어 "지금 어느 시대를 나는지"가 배경만 봐도 읽힌다.
class _KoreaWorldPainter extends CustomPainter {
  _KoreaWorldPainter({
    required this.camera,
    required this.t,
    required this.dust,
    required this.pines,
    required this.cranes,
    required this.viewportW,
  });

  final Offset camera;
  final double t;
  final List<Depth3DMote> dust;
  final List<_Pine> pines;
  final List<_Crane> cranes;
  final double viewportW;

  static const Color _fog = Color(0xFFD9C4A5);

  /// 화면 중앙의 월드 x 에서 인접 시대 하늘색을 보간한다.
  (Color, Color) _skyAt(double worldX) {
    if (worldX <= _eras.first.pos.dx) {
      return (_eras.first.skyTop, _eras.first.skyMid);
    }
    for (var i = 0; i < _eras.length - 1; i++) {
      final a = _eras[i];
      final b = _eras[i + 1];
      if (worldX <= b.pos.dx) {
        final f =
            ((worldX - a.pos.dx) / (b.pos.dx - a.pos.dx)).clamp(0.0, 1.0);
        return (
          Color.lerp(a.skyTop, b.skyTop, f)!,
          Color.lerp(a.skyMid, b.skyMid, f)!,
        );
      }
    }
    return (_eras.last.skyTop, _eras.last.skyMid);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centerX = camera.dx + viewportW / 2;
    final (skyTop, skyMid) = _skyAt(centerX);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            skyTop,
            skyMid,
            const Color(0xFF9C6644),
            const Color(0xFF3B2417),
          ],
          stops: const [0, 0.34, 0.62, 1],
        ).createShader(rect),
    );

    // 해 — 시간의 해.
    final sun = Offset(size.width * 0.76, 130 - camera.dy * 0.06);
    canvas.drawCircle(
      sun,
      170,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF97316).withValues(alpha: 0.35),
            const Color(0xFFF97316).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 170)),
    );
    canvas.drawCircle(sun, 38,
        Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.8));

    // 시대 이름 워터마크 — 각 시대 상공에 큰 반투명 한글. 살짝 느린 시차.
    for (final era in _eras) {
      final wx = era.pos.dx - camera.dx * 0.85;
      if (wx < -320 || wx > size.width + 320) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: era.name,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 64,
            letterSpacing: 8,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(wx - tp.width / 2, 140 - camera.dy * 0.1));
    }

    _ridge(canvas, size,
        z: 2200, baseY: 0.40, amp: 30, color: const Color(0xFFB08D6A));
    _ridge(canvas, size,
        z: 1700, baseY: 0.47, amp: 38, color: const Color(0xFF8A6748));

    final horizon =
        size.height * 0.52 - camera.dy * Depth3D.scaleOf(900) * 0.12;
    PerspectiveGroundPainter(
      horizonY: horizon,
      near: const Color(0xFF3B2417),
      far: const Color(0xFF9C6644),
      lineColor: Colors.white.withValues(alpha: 0.24),
      rows: 8,
      cols: 12,
    ).paint(canvas, size, cameraX: camera.dx * 0.35);

    for (final b in cranes) {
      final k = Depth3D.scaleOf(b.z);
      final travel = size.width + 120;
      final x = (b.phase * 90 + t * b.speed) % travel - 60;
      final y = size.height * (0.10 + b.lane * 0.3) - camera.dy * k * 0.5;
      _crane(canvas, Offset(x, y), 11 * k + 4, t + b.phase,
          1 - Depth3D.hazeOf(b.z));
    }

    final sorted = [...pines]..sort((a, b) => b.z.compareTo(a.z));
    for (final p in sorted) {
      final k = Depth3D.scaleOf(p.z);
      final tileW = size.width * 2.2;
      final x = (p.x * tileW - camera.dx * k) % tileW - size.width * 0.6;
      final baseY = horizon +
          (size.height - horizon) * (0.12 + (1 - k) * 0.1) +
          camera.dy * k * 0.06;
      if (p.roof) {
        _hanok(canvas, Offset(x, baseY), 120 * k * p.h, p.z);
      } else {
        _pine(canvas, Offset(x, baseY), 150 * k * p.h, p.z, t + p.phase);
      }
    }

    paintDepthMotes(
      canvas,
      size,
      motes: dust,
      camera: camera,
      t: t,
      color: const Color(0xFFFFF7ED),
      drift: -10,
      baseAlpha: 0.45,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3B2417).withValues(alpha: 0.35),
            const Color(0xFF3B2417).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.2)),
    );
    paintVignette(canvas, size, strength: 0.30);
  }

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
      final n = math.sin((x + shift) / 150) * amp +
          math.sin((x + shift) / 57) * amp * 0.4;
      path.lineTo(x, y + n);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = Depth3D.fogged(color, _fog, z),
    );
  }

  void _crane(Canvas canvas, Offset c, double s, double phase, double alpha) {
    final flap = math.sin(phase * 5) * 0.5;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.14)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.75 * alpha);
    canvas.drawLine(c, c + Offset(-s, -s * (0.5 + flap)), p);
    canvas.drawLine(c, c + Offset(s * 0.6, -s * (0.5 - flap)), p);
    canvas.drawLine(c, c + Offset(s * 1.1, -s * 0.05), p);
  }

  void _pine(Canvas canvas, Offset base, double h, double z, double phase) {
    if (h < 6) return;
    final sway = math.sin(phase * 0.8) * h * 0.015;
    final trunk = Depth3D.fogged(const Color(0xFF4A2E17), _fog, z);
    final leafDark = Depth3D.fogged(const Color(0xFF1E3A2A), _fog, z);
    final leafLight = Depth3D.fogged(const Color(0xFF3E6B4A), _fog, z);
    final top = Offset(base.dx + sway + h * 0.1, base.dy - h);

    canvas.drawPath(
      Path()
        ..moveTo(base.dx - h * 0.04, base.dy)
        ..quadraticBezierTo(
            base.dx - h * 0.12, base.dy - h * 0.5, top.dx, top.dy)
        ..quadraticBezierTo(base.dx - h * 0.06, base.dy - h * 0.5,
            base.dx + h * 0.05, base.dy)
        ..close(),
      Paint()..color = trunk,
    );
    for (var i = 0; i < 3; i++) {
      final f = i / 3;
      final cy = top.dy + h * (0.02 + f * 0.16);
      final wRad = h * (0.16 + f * 0.13);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(top.dx - h * 0.02 + f * h * 0.05, cy),
            width: wRad * 2,
            height: h * 0.12),
        Paint()..color = i.isEven ? leafLight : leafDark,
      );
    }
  }

  void _hanok(Canvas canvas, Offset base, double s, double z) {
    if (s < 8) return;
    final wall = Depth3D.fogged(const Color(0xFF5C4630), _fog, z);
    final roof = Depth3D.fogged(const Color(0xFF26201A), _fog, z);
    final w = s * 1.5;
    final wallH = s * 0.5;
    canvas.drawRect(
      Rect.fromLTWH(base.dx - w / 2, base.dy - wallH, w, wallH),
      Paint()..color = wall,
    );
    final path = Path()
      ..moveTo(base.dx - w * 0.68, base.dy - wallH + 2)
      ..quadraticBezierTo(base.dx - w * 0.5, base.dy - wallH - s * 0.14,
          base.dx, base.dy - wallH - s * 0.42)
      ..quadraticBezierTo(base.dx + w * 0.5, base.dy - wallH - s * 0.14,
          base.dx + w * 0.68, base.dy - wallH + 2)
      ..close();
    canvas.drawPath(path, Paint()..color = roof);
  }

  @override
  bool shouldRepaint(_KoreaWorldPainter old) =>
      old.t != t || old.camera != camera;
}

/// 전경 — 흩날리는 꽃잎과 반짝임.
class _KoreaForegroundPainter extends CustomPainter {
  _KoreaForegroundPainter({
    required this.camera,
    required this.t,
    required this.sparks,
    required this.petals,
  });

  final Offset camera;
  final double t;
  final List<Depth3DMote> sparks;
  final List<_Petal> petals;

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in sparks) {
      final k = Depth3D.scaleOf(f.z);
      final tileW = size.width + 200;
      final tileH = size.height + 200;
      final px = (f.x * tileW - camera.dx * k) % tileW - 100;
      final py = (f.y * tileH - camera.dy * k) % tileH - 100;
      final blink = 0.2 + 0.6 * (0.5 + 0.5 * math.sin(f.phase + t * 2.4));
      canvas.drawCircle(
          Offset(px, py),
          math.max(1.0, f.r * k),
          Paint()
            ..color = const Color(0xFFFDE68A).withValues(alpha: blink * 0.7));
    }

    for (final petal in petals) {
      final k = Depth3D.scaleOf(petal.z);
      final tileW = size.width * 1.6;
      final tileH = size.height * 1.6;
      final drift = t * 26 * petal.scale;
      final px = (petal.x * tileW -
                  camera.dx * k +
                  math.sin(t * 1.2 + petal.phase) * 30) %
              tileW -
          size.width * 0.3;
      final py =
          (petal.y * tileH - camera.dy * k + drift) % tileH - size.height * 0.3;
      final rot = petal.phase + t * 1.4;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      final s = 7.0 * petal.scale * k;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s),
        Paint()..color = const Color(0xFFFBCFE8).withValues(alpha: 0.8),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_KoreaForegroundPainter old) =>
      old.t != t || old.camera != camera;
}

// ── 데이터 ───────────────────────────────────────────────────────────

enum _EraKind { dolmen, goguryeo, baekje, silla, goryeo, joseon, modern }

/// 시대 하나 — 인물·전쟁·문화재·퀴즈까지 담는 역사 캡슐.
class _KoreaEra {
  const _KoreaEra({
    required this.id,
    required this.name,
    required this.period,
    required this.tagline,
    required this.story,
    required this.glow,
    required this.skyTop,
    required this.skyMid,
    required this.stats,
    required this.people,
    required this.events,
    required this.heritage,
    required this.quiz,
    required this.pos,
    required this.size,
    required this.kind,
  });

  final String id;
  final String name;

  /// 존속 기간 표기. 예: '기원전 2333~기원전 108'.
  final String period;
  final String tagline;
  final String story;
  final Color glow;

  /// 이 시대 상공의 하늘색 — 시대별 보간에 쓰인다.
  final Color skyTop;
  final Color skyMid;
  final List<(String, String)> stats;

  /// 시대의 인물 — (이모지, 이름, 한 줄 설명).
  final List<(String, String, String)> people;

  /// 연대기 — (연도, 제목, 설명, 전쟁 여부). 전쟁은 ⚔️ 로 강조된다.
  final List<(String, String, String, bool)> events;

  /// 대표 문화재 칩 목록.
  final List<String> heritage;

  /// 깜짝 퀴즈 — (질문, 보기들, 정답 인덱스).
  final (String, List<String>, int) quiz;
  final Offset pos;
  final double size;
  final _EraKind kind;
}

/// 일곱 시대 — 왼쪽(옛날)에서 오른쪽(현재)으로.
const List<_KoreaEra> _eras = [
  _KoreaEra(
    id: 'gojoseon',
    name: '고조선',
    period: '기원전 2333~기원전 108',
    tagline: '우리 역사의 첫 나라',
    story: '커다란 고인돌 앞에 모닥불이 타오르고 있어요. 단군왕검이 세운 우리 '
        '역사의 첫 나라래요! 모찌가 고인돌을 만져보며 "이 큰 돌을 어떻게 '
        '올렸지?" 하고 깜짝 놀랐어요. 하늘에 제사를 지내던 사람들의 노랫소리가 '
        '들리는 것 같아요.',
    glow: Color(0xFFC4B5FD),
    skyTop: Color(0xFF4C3A6E),
    skyMid: Color(0xFF8A6FA8),
    stats: [
      ('건국', '기원전 2333년'),
      ('법', '8조법'),
      ('상징', '고인돌'),
    ],
    people: [
      ('🐻', '단군왕검', '하늘의 자손으로 고조선을 세운 첫 임금'),
      ('🌿', '웅녀', '쑥과 마늘을 먹고 사람이 된 곰 이야기의 주인공'),
    ],
    events: [
      ('BC 2333', '고조선 건국', '단군왕검이 아사달에 나라를 세웠어요.', false),
      ('BC 8세기', '비파형 동검', '악기 비파를 닮은 청동 검을 만들었어요.', false),
      ('BC 194', '위만의 등장', '위만이 왕이 되어 철기 문화가 퍼졌어요.', false),
      ('BC 108', '멸망', '한나라와의 전쟁 끝에 막을 내렸어요.', true),
    ],
    heritage: ['고인돌', '비파형 동검', '미송리식 토기'],
    quiz: (
      '단군 신화에서 곰이 사람이 되려고 먹은 것은?',
      ['쑥과 마늘', '사과와 딸기', '피자와 콜라'],
      0
    ),
    pos: Offset(650, 1000),
    size: 185,
    kind: _EraKind.dolmen,
  ),
  _KoreaEra(
    id: 'goguryeo',
    name: '고구려',
    period: '기원전 37~서기 668',
    tagline: '만주 벌판을 달린 최강의 기상',
    story: '거대한 돌무덤 장군총 위로 세발 까마귀(삼족오) 깃발이 펄럭여요! '
        '고구려는 말을 타고 만주 벌판을 누비던 용감한 나라였대요. 모찌도 '
        '기마무사처럼 "이랴!" 하고 외쳐봤어요. 수나라 113만 대군도 물리친 '
        '나라라니, 정말 대단하죠?',
    glow: Color(0xFFF87171),
    skyTop: Color(0xFF7C3A2D),
    skyMid: Color(0xFFC97B4A),
    stats: [
      ('전성기', '광개토대왕'),
      ('영토', '만주~한강'),
      ('상징', '삼족오'),
    ],
    people: [
      ('🏇', '광개토대왕', '영토를 가장 넓게 넓힌 정복왕'),
      ('🛡', '을지문덕', '살수대첩으로 수나라 대군을 물리친 명장'),
      ('🏹', '주몽', '활을 잘 쏘던 고구려의 첫 임금'),
    ],
    events: [
      ('BC 37', '고구려 건국', '주몽이 졸본에 나라를 세웠어요.', false),
      ('391', '광개토대왕 즉위', '만주까지 영토를 크게 넓혔어요.', false),
      ('612', '살수대첩', '을지문덕이 수나라 113만 대군을 살수에서 크게 무찔렀어요.', true),
      ('645', '안시성 싸움', '작은 성 하나가 당나라 대군을 막아냈어요.', true),
      ('668', '멸망', '나당 연합군에 의해 역사 속으로.', true),
    ],
    heritage: ['무용총 벽화', '광개토대왕릉비', '장군총'],
    quiz: ('살수대첩에서 수나라 대군을 물리친 장군은?', ['을지문덕', '이순신', '김유신'], 0),
    pos: Offset(1400, 1350),
    size: 195,
    kind: _EraKind.goguryeo,
  ),
  _KoreaEra(
    id: 'baekje',
    name: '백제',
    period: '기원전 18~서기 660',
    tagline: '바다 건너 문화를 전한 예술의 나라',
    story: '봉황이 날개를 편 금동대향로에서 향긋한 연기가 피어올라요. 백제는 '
        '멋진 물건을 잘 만들고, 바다 건너 일본에 한자와 불교까지 전해준 문화 '
        '선생님이었대요. 모찌가 향로를 요리조리 살펴보며 "어떻게 이렇게 '
        '섬세하지?" 하고 감탄했어요.',
    glow: Color(0xFFFCD34D),
    skyTop: Color(0xFF9A6A2F),
    skyMid: Color(0xFFD9A15C),
    stats: [
      ('전성기', '근초고왕'),
      ('수도', '한성→웅진→사비'),
      ('특기', '문화 수출'),
    ],
    people: [
      ('👑', '근초고왕', '백제의 전성기를 이끈 정복왕'),
      ('📚', '왕인', '일본에 천자문과 논어를 전한 학자'),
      ('⚔️', '계백', '황산벌에서 오천 결사대와 함께 싸운 장군'),
    ],
    events: [
      ('BC 18', '백제 건국', '온조가 한강 유역에 나라를 세웠어요.', false),
      ('4세기', '근초고왕 전성기', '고구려 평양성까지 진격했어요.', true),
      ('538', '사비 천도', '수도를 사비(부여)로 옮기고 문화를 꽃피웠어요.', false),
      ('660', '황산벌 전투', '계백의 오천 결사대가 마지막까지 싸웠어요.', true),
    ],
    heritage: ['금동대향로', '무령왕릉', '칠지도'],
    quiz: ('백제가 한자와 불교를 전해준 이웃 나라는?', ['일본', '이집트', '프랑스'], 0),
    pos: Offset(2150, 950),
    size: 185,
    kind: _EraKind.baekje,
  ),
  _KoreaEra(
    id: 'silla',
    name: '신라',
    period: '기원전 57~서기 935',
    tagline: '황금의 나라, 천년의 왕국',
    story: '반짝반짝 빛나는 금관이 눈부셔요! 신라는 금을 다루는 솜씨가 뛰어나 '
        '"황금의 나라"로 불렸고, 천 년이나 이어진 왕국이래요. 화랑 오빠들이 '
        '말을 타고 지나가고, 저 멀리 첨성대가 보여요. 모찌도 금관을 살짝 '
        '써보고 싶어졌어요.',
    glow: Color(0xFFFDE68A),
    skyTop: Color(0xFF3D6EA8),
    skyMid: Color(0xFF8FB8D9),
    stats: [
      ('존속', '992년'),
      ('통일', '676년'),
      ('상징', '금관·화랑'),
    ],
    people: [
      ('👸', '선덕여왕', '첨성대를 세운 우리 역사 첫 여왕'),
      ('🗡', '김유신', '삼국통일을 이끈 화랑 출신 대장군'),
      ('⛵', '장보고', '바다를 지배한 해상왕'),
    ],
    events: [
      ('BC 57', '신라 건국', '박혁거세가 경주에 나라를 세웠어요.', false),
      ('632', '선덕여왕 즉위', '첨성대를 세우고 인재를 길렀어요.', false),
      ('660·668', '백제·고구려 통합', '김유신과 나당 연합군의 승리.', true),
      ('676', '삼국통일 완성', '당나라까지 몰아내고 통일을 이뤘어요.', true),
      ('751', '불국사·석굴암', '돌로 빚은 최고의 걸작이 완성됐어요.', false),
    ],
    heritage: ['금관', '첨성대', '석굴암', '에밀레종'],
    quiz: ('삼국을 통일한 나라는 어디일까요?', ['신라', '백제', '고구려'], 0),
    pos: Offset(2900, 1400),
    size: 190,
    kind: _EraKind.silla,
  ),
  _KoreaEra(
    id: 'goryeo',
    name: '고려',
    period: '918~1392',
    tagline: '코리아라는 이름이 시작된 나라',
    story: '비취빛 고려청자가 은은하게 빛나요. 학이 구름 사이를 나는 무늬가 '
        '새겨져 있어요! "코리아(Korea)"라는 이름이 바로 고려에서 나왔대요. '
        '몽골이 쳐들어왔을 때는 팔만대장경을 만들어 이겨내려 했다니, 모찌는 '
        '목판 팔만 장에 입이 떡 벌어졌어요.',
    glow: Color(0xFF6EE7B7),
    skyTop: Color(0xFF2E6E5E),
    skyMid: Color(0xFF7FB8A4),
    stats: [
      ('건국', '왕건'),
      ('이름', 'Korea 의 어원'),
      ('발명', '금속활자'),
    ],
    people: [
      ('👑', '왕건', '후삼국을 통일하고 고려를 세운 임금'),
      ('🛡', '강감찬', '귀주대첩으로 거란을 물리친 명장'),
      ('🖨', '고려 장인들', '세계 최초 금속활자를 만든 사람들'),
    ],
    events: [
      ('918', '고려 건국', '왕건이 후삼국을 하나로 모았어요.', false),
      ('1019', '귀주대첩', '강감찬이 거란 10만 대군을 귀주에서 크게 이겼어요.', true),
      ('1236', '팔만대장경 시작', '몽골 침입을 이겨내려 목판 8만 장을 새겼어요.', true),
      ('1377', '직지 인쇄', '세계에서 가장 오래된 금속활자 책을 찍었어요.', false),
    ],
    heritage: ['고려청자', '팔만대장경', '직지심체요절'],
    quiz: ('세계 최초의 금속활자 인쇄물 이름은?', ['직지심체요절', '해리포터', '훈민정음'], 0),
    pos: Offset(3650, 1000),
    size: 185,
    kind: _EraKind.goryeo,
  ),
  _KoreaEra(
    id: 'joseon',
    name: '조선',
    period: '1392~1897',
    tagline: '한글과 거북선의 500년 왕조',
    story: '웅장한 경복궁 근정전이 노을에 물들어요. 세종대왕이 백성을 위해 '
        '한글을 만들고, 이순신 장군이 거북선으로 바다를 지킨 나라예요. 모찌가 '
        '근정전 앞마당에서 "모찌"라고 한글로 써봤어요. 지금 우리가 쓰는 글자가 '
        '여기서 태어났다니 신기해요!',
    glow: Color(0xFFFDBA74),
    skyTop: Color(0xFF8A3A2A),
    skyMid: Color(0xFFD97A4A),
    stats: [
      ('존속', '505년'),
      ('한글 반포', '1446년'),
      ('궁궐', '경복궁'),
    ],
    people: [
      ('📖', '세종대왕', '백성을 위해 한글을 만든 성군'),
      ('⚓', '이순신', '한산도·명량에서 나라를 구한 성웅'),
      ('🏗', '정조', '과학 기술로 수원 화성을 쌓은 개혁 군주'),
    ],
    events: [
      ('1392', '조선 건국', '이성계가 새 왕조를 열었어요.', false),
      ('1446', '훈민정음 반포', '세종대왕이 한글을 세상에 알렸어요.', false),
      ('1592', '임진왜란·한산도대첩', '이순신이 학익진으로 왜군을 크게 무찔렀어요.', true),
      ('1597', '명량해전', '단 13척으로 133척을 상대해 이겼어요.', true),
      ('1796', '수원 화성 완공', '거중기로 과학적인 성을 쌓았어요.', false),
    ],
    heritage: ['경복궁', '훈민정음', '거북선', '수원 화성'],
    quiz: ('백성을 위해 한글을 만든 임금은?', ['세종대왕', '광개토대왕', '단군왕검'], 0),
    pos: Offset(4400, 1400),
    size: 200,
    kind: _EraKind.joseon,
  ),
  _KoreaEra(
    id: 'daehanminguk',
    name: '대한민국',
    period: '1919 임시정부~오늘',
    tagline: '함께 만들어 가는 우리의 시대',
    story: '푸른 하늘에 태극기가 힘차게 펄럭여요! 나라를 잃었을 때 사람들은 '
        '"대한독립만세"를 외쳤고, 광복 후 폐허에서 시작해 온 세계가 놀란 나라를 '
        '만들었어요. 이제 한글 노래와 이야기가 지구 반대편까지 울려 퍼져요. '
        '모찌가 말했어요. "다음 역사는 우리가 쓰는 거야!"',
    glow: Color(0xFF93C5FD),
    skyTop: Color(0xFF2563EB),
    skyMid: Color(0xFF93C5FD),
    stats: [
      ('3·1운동', '1919년'),
      ('광복', '1945년 8월 15일'),
      ('오늘', 'K-문화 세계로'),
    ],
    people: [
      ('🕊', '유관순', '열일곱 나이로 만세를 외친 독립운동가'),
      ('🇰🇷', '김구', '평생을 독립에 바친 임시정부의 주석'),
      ('💪', '우리 모두', '한강의 기적을 만든 평범한 사람들'),
    ],
    events: [
      ('1919', '3·1운동', '온 나라가 "대한독립만세"를 외쳤어요.', false),
      ('1945', '광복', '빼앗겼던 나라를 되찾았어요.', false),
      ('1950', '6·25전쟁', '아픈 전쟁을 겪고도 다시 일어섰어요.', true),
      ('1988·2002', '올림픽·월드컵', '온 세계를 초대해 함께 즐겼어요.', false),
      ('오늘', 'K-문화 시대', '한글·음악·이야기가 세계로 뻗어가요.', false),
    ],
    heritage: ['태극기', '한글', '무궁화'],
    quiz: ('3·1운동 때 사람들이 다 함께 외친 말은?', ['대한독립만세', '생일 축하해', '밥 먹자'], 0),
    pos: Offset(5050, 950),
    size: 190,
    kind: _EraKind.modern,
  ),
];

// ── 시대 비주얼 ──────────────────────────────────────────────────────

class _EraSpotPainter extends CustomPainter {
  _EraSpotPainter(this.s, {required this.t});

  final _KoreaEra s;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.95), width: w * 0.78, height: h * 0.1),
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );
    switch (s.kind) {
      case _EraKind.dolmen:
        _dolmen(canvas, w, h);
      case _EraKind.goguryeo:
        _goguryeo(canvas, w, h);
      case _EraKind.baekje:
        _baekje(canvas, w, h);
      case _EraKind.silla:
        _silla(canvas, w, h);
      case _EraKind.goryeo:
        _goryeo(canvas, w, h);
      case _EraKind.joseon:
        _joseon(canvas, w, h);
      case _EraKind.modern:
        _modern(canvas, w, h);
    }
  }

  void _roof(Canvas canvas, Offset center, double width, double height,
      {Color color = const Color(0xFF3F3A34)}) {
    final path = Path()
      ..moveTo(center.dx - width / 2, center.dy + 2)
      ..quadraticBezierTo(center.dx - width * 0.32, center.dy - height * 0.4,
          center.dx, center.dy - height)
      ..quadraticBezierTo(center.dx + width * 0.32, center.dy - height * 0.4,
          center.dx + width / 2, center.dy + 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ).createShader(Rect.fromCenter(
            center: center, width: width, height: height * 2)),
    );
  }

  /// 고조선 — 탁자식 고인돌 + 모닥불.
  void _dolmen(Canvas canvas, double w, double h) {
    final stone = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB8AFA0), Color(0xFF6F675B)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(w * 0.24, h * 0.5, w * 0.12, h * 0.4), stone);
    canvas.drawRect(Rect.fromLTWH(w * 0.64, h * 0.5, w * 0.12, h * 0.4), stone);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.1, h * 0.5)
        ..lineTo(w * 0.16, h * 0.32)
        ..lineTo(w * 0.86, h * 0.3)
        ..lineTo(w * 0.92, h * 0.48)
        ..close(),
      stone,
    );
    final fx = w * 0.5;
    final fy = h * 0.86;
    for (var i = 0; i < 3; i++) {
      final flick = math.sin(t * 6 + i * 2.1) * 3;
      canvas.drawPath(
        Path()
          ..moveTo(fx - 8 + i * 6, fy)
          ..quadraticBezierTo(fx - 10 + i * 6 + flick, fy - 16 - i * 5,
              fx - 4 + i * 6, fy - 22 - i * 4)
          ..quadraticBezierTo(fx + i * 6 + flick, fy - 12, fx - 2 + i * 6, fy)
          ..close(),
        Paint()
          ..color = [
            const Color(0xFFF97316),
            const Color(0xFFFBBF24),
            const Color(0xFFEF4444)
          ][i]
              .withValues(alpha: 0.85),
      );
    }
    canvas.drawLine(
      Offset(fx - 14, fy + 2),
      Offset(fx + 14, fy - 2),
      Paint()
        ..color = const Color(0xFF5C4630)
        ..strokeWidth = 4,
    );
  }

  /// 고구려 — 장군총(계단 돌무덤) + 삼족오 깃발.
  void _goguryeo(Canvas canvas, double w, double h) {
    final stone = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC9BBA4), Color(0xFF7A6C55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    for (var i = 0; i < 7; i++) {
      final f = i / 7;
      final tierW = w * (0.82 - f * 0.6);
      final y = h * (0.88 - i * 0.075);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w / 2, y), width: tierW, height: h * 0.075),
        stone,
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w / 2, y - h * 0.03), width: tierW, height: 1.4),
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }
    final poleX = w * 0.78;
    canvas.drawLine(
      Offset(poleX, h * 0.14),
      Offset(poleX, h * 0.5),
      Paint()
        ..color = const Color(0xFF5C4630)
        ..strokeWidth = 3,
    );
    final wave = math.sin(t * 4) * 3;
    final flag = Path()
      ..moveTo(poleX, h * 0.14)
      ..quadraticBezierTo(
          poleX + w * 0.14, h * 0.16 + wave, poleX + w * 0.24, h * 0.15)
      ..lineTo(poleX + w * 0.24, h * 0.3)
      ..quadraticBezierTo(poleX + w * 0.14, h * 0.31 - wave, poleX, h * 0.3)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFB91C1C));
    final bc = Offset(poleX + w * 0.12, h * 0.22);
    canvas.drawCircle(bc, w * 0.035, Paint()..color = const Color(0xFF1C120A));
    final wing = Paint()
      ..color = const Color(0xFF1C120A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(bc, bc + Offset(-w * 0.045, -h * 0.02), wing);
    canvas.drawLine(bc, bc + Offset(w * 0.045, -h * 0.02), wing);
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(bc + Offset(i * 4.0, w * 0.03),
          bc + Offset(i * 5.0, w * 0.055), wing);
    }
  }

  /// 백제 — 금동대향로(봉황 + 연꽃) + 향 연기.
  void _baekje(Canvas canvas, double w, double h) {
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDE68A), Color(0xFFB4832A)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.42, h * 0.9)
        ..quadraticBezierTo(w * 0.5, h * 0.78, w * 0.46, h * 0.68)
        ..lineTo(w * 0.54, h * 0.68)
        ..quadraticBezierTo(w * 0.5, h * 0.78, w * 0.58, h * 0.9)
        ..close(),
      gold,
    );
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.56),
            width: w * 0.34,
            height: h * 0.26),
        gold);
    final petalLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF8A5A18).withValues(alpha: 0.7);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(w * (0.38 + i * 0.08), h * 0.6),
            width: w * 0.1,
            height: h * 0.14),
        -math.pi * 0.8,
        math.pi * 0.6,
        false,
        petalLine,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.34, h * 0.45)
        ..lineTo(w * 0.4, h * 0.34)
        ..lineTo(w * 0.45, h * 0.4)
        ..lineTo(w * 0.5, h * 0.3)
        ..lineTo(w * 0.55, h * 0.4)
        ..lineTo(w * 0.6, h * 0.34)
        ..lineTo(w * 0.66, h * 0.45)
        ..close(),
      gold,
    );
    final pc = Offset(w * 0.5, h * 0.24);
    canvas.drawCircle(pc, w * 0.03, gold);
    canvas.drawPath(
      Path()
        ..moveTo(pc.dx, pc.dy)
        ..quadraticBezierTo(pc.dx + w * 0.08, pc.dy - h * 0.05,
            pc.dx + w * 0.1, pc.dy - h * 0.1)
        ..quadraticBezierTo(pc.dx + w * 0.04, pc.dy - h * 0.04, pc.dx, pc.dy)
        ..close(),
      gold,
    );
    for (var i = 0; i < 3; i++) {
      final f = ((t * 0.4 + i / 3) % 1.0);
      canvas.drawCircle(
        Offset(w * (0.5 + math.sin(f * 6 + i) * 0.05), h * (0.2 - f * 0.16)),
        2 + f * 5,
        Paint()..color = Colors.white.withValues(alpha: 0.4 * (1 - f)),
      );
    }
  }

  /// 신라 — 出자 금관 + 곡옥 + 반짝임.
  void _silla(Canvas canvas, double w, double h) {
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFEF3C7), Color(0xFFD4A017)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(w * 0.22, h * 0.62, w * 0.56, h * 0.1), gold);
    for (final fx in [0.32, 0.5, 0.68]) {
      final x = w * fx;
      canvas.drawRect(Rect.fromLTWH(x - 2.5, h * 0.3, 5, h * 0.34), gold);
      for (var i = 0; i < 3; i++) {
        final y = h * (0.36 + i * 0.09);
        canvas.drawRect(Rect.fromLTWH(x - w * 0.05, y, w * 0.05, 4), gold);
        canvas.drawRect(Rect.fromLTWH(x, y + h * 0.045, w * 0.05, 4), gold);
      }
      canvas.drawCircle(Offset(x, h * 0.29), 4, gold);
    }
    for (final (fx, fy) in const [(0.3, 0.68), (0.5, 0.7), (0.7, 0.68)]) {
      canvas.drawCircle(Offset(w * fx, h * fy), 4,
          Paint()..color = const Color(0xFF10B981));
    }
    for (final (i, (fx, fy)) in const [
      (0, (0.26, 0.36)),
      (1, (0.74, 0.32)),
      (2, (0.5, 0.2)),
    ]) {
      final blink = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 3.4 + i * 2.0));
      final c = Offset(w * fx, h * fy);
      final sp = Paint()
        ..color = Colors.white.withValues(alpha: blink)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + const Offset(-5, 0), c + const Offset(5, 0), sp);
      canvas.drawLine(c + const Offset(0, -5), c + const Offset(0, 5), sp);
    }
  }

  /// 고려 — 학 무늬 고려청자 + 팔만대장경 목판.
  void _goryeo(Canvas canvas, double w, double h) {
    final wood = Paint()..color = const Color(0xFF6B4E2E);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.6, h * (0.62 + i * 0.09), w * 0.3, h * 0.055),
        wood,
      );
      canvas.drawRect(
        Rect.fromLTWH(w * 0.6, h * (0.62 + i * 0.09), w * 0.3, h * 0.012),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }
    final celadon = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB8E0CE), Color(0xFF5E9E86)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.3, h * 0.34)
        ..quadraticBezierTo(w * 0.24, h * 0.36, w * 0.24, h * 0.44)
        ..quadraticBezierTo(w * 0.24, h * 0.62, w * 0.32, h * 0.9)
        ..lineTo(w * 0.48, h * 0.9)
        ..quadraticBezierTo(w * 0.56, h * 0.62, w * 0.56, h * 0.44)
        ..quadraticBezierTo(w * 0.56, h * 0.36, w * 0.5, h * 0.34)
        ..quadraticBezierTo(w * 0.44, h * 0.3, w * 0.44, h * 0.26)
        ..lineTo(w * 0.36, h * 0.26)
        ..quadraticBezierTo(w * 0.36, h * 0.3, w * 0.3, h * 0.34)
        ..close(),
      celadon,
    );
    final craneP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.9);
    for (final (fx, fy, s) in const [(0.36, 0.5, 5.0), (0.44, 0.62, 4.0)]) {
      final c = Offset(w * fx, h * fy);
      canvas.drawLine(c, c + Offset(-s, -s * 0.7), craneP);
      canvas.drawLine(c, c + Offset(s * 0.7, -s * 0.5), craneP);
      canvas.drawLine(c, c + Offset(s * 1.1, 0), craneP);
    }
    canvas.drawCircle(Offset(w * 0.33, h * 0.72), 3.4,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(w * 0.47, h * 0.44), 3.0,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.32, h * 0.46),
          width: w * 0.05,
          height: h * 0.22),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  /// 조선 — 경복궁 근정전.
  void _joseon(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(w * 0.14, h * 0.78, w * 0.72, h * 0.14),
      Paint()..color = const Color(0xFF9CA3AF),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.2, h * 0.58, w * 0.6, h * 0.2),
      Paint()..color = const Color(0xFFFDE9C8),
    );
    for (final fx in [0.24, 0.38, 0.5, 0.62, 0.74]) {
      canvas.drawRect(
        Rect.fromLTWH(w * fx - 2.5, h * 0.58, 5, h * 0.2),
        Paint()..color = const Color(0xFF9F1D1D),
      );
    }
    _roof(canvas, Offset(w / 2, h * 0.58), w * 0.84, h * 0.16);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, h * 0.36, w * 0.44, h * 0.08),
      Paint()..color = const Color(0xFFFDE9C8),
    );
    _roof(canvas, Offset(w / 2, h * 0.36), w * 0.62, h * 0.15);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.66, w * 0.12, h * 0.12),
      Paint()..color = const Color(0xFF7C2D12),
    );
  }

  /// 대한민국 — 휘날리는 태극기 + 무궁화.
  void _modern(Canvas canvas, double w, double h) {
    canvas.drawLine(
      Offset(w * 0.2, h * 0.16),
      Offset(w * 0.2, h * 0.9),
      Paint()
        ..color = const Color(0xFF9CA3AF)
        ..strokeWidth = 4,
    );
    canvas.drawCircle(Offset(w * 0.2, h * 0.14), 4,
        Paint()..color = const Color(0xFFFCD34D));
    final wave1 = math.sin(t * 4) * h * 0.02;
    final wave2 = math.sin(t * 4 + 1.4) * h * 0.03;
    final flag = Path()
      ..moveTo(w * 0.2, h * 0.2)
      ..cubicTo(w * 0.4, h * 0.18 + wave1, w * 0.6, h * 0.22 + wave2,
          w * 0.82, h * 0.2 + wave1)
      ..lineTo(w * 0.82, h * 0.52 + wave1)
      ..cubicTo(w * 0.6, h * 0.54 + wave2, w * 0.4, h * 0.5 + wave1, w * 0.2,
          h * 0.52)
      ..close();
    canvas.drawPath(flag, Paint()..color = Colors.white);
    canvas.drawPath(
      flag,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF9CA3AF).withValues(alpha: 0.6),
    );
    final tc = Offset(w * 0.51, h * 0.36 + wave1);
    final tr = w * 0.09;
    canvas.drawArc(Rect.fromCircle(center: tc, radius: tr), math.pi, math.pi,
        true, Paint()..color = const Color(0xFFDC2626));
    canvas.drawArc(Rect.fromCircle(center: tc, radius: tr), 0, math.pi, true,
        Paint()..color = const Color(0xFF2563EB));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(tc.dx - tr / 2, tc.dy), radius: tr / 2),
      0,
      math.pi,
      true,
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(tc.dx + tr / 2, tc.dy), radius: tr / 2),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF2563EB),
    );
    final gua = Paint()
      ..color = const Color(0xFF1C120A)
      ..strokeWidth = 2.4;
    for (final (fx, fy) in const [
      (0.33, 0.26),
      (0.69, 0.26),
      (0.33, 0.44),
      (0.69, 0.44)
    ]) {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(w * fx - 6, h * fy + i * 4),
          Offset(w * fx + 6, h * fy + i * 4),
          gua,
        );
      }
    }
    final mc = Offset(w * 0.72, h * 0.76);
    for (var i = 0; i < 5; i++) {
      final a = 2 * math.pi * i / 5 - math.pi / 2;
      canvas.drawOval(
        Rect.fromCenter(
          center: mc + Offset(math.cos(a), math.sin(a)) * w * 0.05,
          width: w * 0.08,
          height: w * 0.06,
        ),
        Paint()..color = const Color(0xFFF9A8D4),
      );
    }
    canvas.drawCircle(mc, w * 0.025, Paint()..color = const Color(0xFFBE185D));
  }

  @override
  bool shouldRepaint(_EraSpotPainter old) => old.t != t;
}

// ── 시대 상세 시트 ───────────────────────────────────────────────────

class _EraSheet extends StatelessWidget {
  const _EraSheet({
    required this.era,
    required this.collected,
    required this.total,
  });

  final _KoreaEra era;
  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = era;
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1810),
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
                        child:
                            CustomPaint(painter: _EraSpotPainter(s, t: 1.2)),
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
                                '🕰 ${s.period}',
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
                                color: Color(0xFFE7CBA9),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
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
                                    color: Color(0xFFC9A87F),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  stat.$2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
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
                  _EraCard(
                    title: '모찌의 시간여행 일지',
                    emoji: '📖',
                    child: Text(
                      s.story,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                        height: 1.65,
                        color: Color(0xFFF3E3CE),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 시대의 인물 — 이 시대를 만든 사람들.
                  _EraCard(
                    title: '시대의 인물',
                    emoji: '🎎',
                    child: Column(
                      children: [
                        for (final (i, p) in s.people.indexed) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: s.glow.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: s.glow.withValues(alpha: 0.4)),
                                ),
                                child: Text(p.$1,
                                    style: const TextStyle(fontSize: 19)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.$2,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.$3,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Color(0xFFE7CBA9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 역사 연대기 — 전쟁은 ⚔️ 뱃지로 강조.
                  _EraCard(
                    title: '역사 연대기',
                    emoji: '📜',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, e) in s.events.indexed)
                          _EraTimelineRow(
                            year: e.$1,
                            title: e.$2,
                            desc: e.$3,
                            war: e.$4,
                            accent: s.glow,
                            isLast: i == s.events.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 시대의 보물 — 대표 문화재 칩.
                  _EraCard(
                    title: '시대의 보물',
                    emoji: '🏺',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in s.heritage)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: s.glow.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: s.glow.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: s.glow,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 깜짝 퀴즈.
                  _EraQuizCard(
                    question: s.quiz.$1,
                    options: s.quiz.$2,
                    answerIndex: s.quiz.$3,
                    accent: s.glow,
                  ),
                  const SizedBox(height: 14),
                  ExploreSpotExtras(
                    realmKey: 'korea',
                    realmEmoji: '🏯',
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
                        backgroundColor: const Color(0xFFC2410C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '다음 시대로!',
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

class _EraCard extends StatelessWidget {
  const _EraCard({
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

class _EraTimelineRow extends StatelessWidget {
  const _EraTimelineRow({
    required this.year,
    required this.title,
    required this.desc,
    required this.war,
    required this.accent,
    required this.isLast,
  });

  final String year;
  final String title;
  final String desc;
  final bool war;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = war ? const Color(0xFFF87171) : accent;
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
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.6),
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
                          color: dotColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          year,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: dotColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          war ? '⚔️ $title' : title,
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
                      color: Color(0xFFE7CBA9),
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

/// 깜짝 역사 퀴즈 — 시대마다 1문제. 맞히면 ✨, 틀리면 정답을 알려준다.
class _EraQuizCard extends StatefulWidget {
  const _EraQuizCard({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.accent,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
  final Color accent;

  @override
  State<_EraQuizCard> createState() => _EraQuizCardState();
}

class _EraQuizCardState extends State<_EraQuizCard> {
  int? _selected;

  bool get _answered => _selected != null;
  bool get _correct => _selected == widget.answerIndex;

  void _choose(int i) {
    if (_answered) return;
    setState(() => _selected = i);
    if (i == widget.answerIndex) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 7),
              Text(
                '깜짝 역사 퀴즈',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.question,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, opt) in widget.options.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _choose(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _answered
                      ? i == widget.answerIndex
                          ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                          : i == _selected
                              ? const Color(0xFFDC2626).withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _answered
                        ? i == widget.answerIndex
                            ? const Color(0xFF4ADE80)
                            : i == _selected
                                ? const Color(0xFFF87171)
                                : Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_answered && i == widget.answerIndex)
                      const Text('✅', style: TextStyle(fontSize: 14))
                    else if (_answered && i == _selected)
                      const Text('❌', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
          if (_answered) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                _correct ? '🎉 정답! 역사 박사 모찌 인정!' : '아쉬워요! 정답을 확인해 보세요.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _correct
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFCA5A5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
