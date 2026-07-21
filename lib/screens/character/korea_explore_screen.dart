import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import 'explore_3d.dart';
import 'explore_rewards.dart';

/// 모찌 한국의 역사 탐험 — 탐험 허브에서 진입하는 자유비행 역사 콘텐츠.
///
/// 화면을 꾹 누르면 모찌가 탄 방패연이 그 방향으로 날아가고, 떼면 바람에
/// 실려 천천히 멈춘다. 수묵화 톤의 새벽 산하 위로 소나무·기와마을·학이
/// 깊이별 시차로 흐르고, 경복궁부터 훈민정음까지 역사 명소 6곳을 찾아가면
/// 연대기와 함께 기념품 스탬프를 모을 수 있다.
class KoreaExploreScreen extends StatefulWidget {
  const KoreaExploreScreen({super.key, required this.character});

  final CharacterState character;

  @override
  State<KoreaExploreScreen> createState() => _KoreaExploreScreenState();
}

class _KoreaExploreScreenState extends State<KoreaExploreScreen>
    with TickerProviderStateMixin {
  // ── 월드/물리 ─────────────────────────────────────────────────────
  static const double _worldW = 4600;
  static const double _worldH = 2200;
  static const double _accel = 900;
  static const double _maxSpeed = 500;
  static const double _drag = 1.9;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _time = 0;
  int _tickCount = 0;

  Offset _kite = const Offset(420, 900);
  Offset _vel = Offset.zero;
  Offset? _pointer;
  Size _viewport = Size.zero;

  final Set<String> _visited = <String>{};
  bool _showHint = true;
  bool _panelOpen = false;
  bool _celebrated = false;

  late final List<Depth3DMote> _dust; // 안개 속 햇살 입자(먼 배경)
  late final List<Depth3DMote> _sparks; // 전경 반짝임
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

  _KoreaSpot? get _nearbySpot {
    for (final s in _spots) {
      if (((s.pos - _kite).distance) < s.size / 2 + 120) return s;
    }
    return null;
  }

  _KoreaSpot? get _nearestUnvisited {
    _KoreaSpot? best;
    double bestD = double.infinity;
    for (final s in _spots) {
      if (_visited.contains(s.id)) continue;
      final d = (s.pos - _kite).distance;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  Future<void> _openSpot(_KoreaSpot s) async {
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
      builder: (_) => _KoreaSpotSheet(
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
                '역사 탐험 완전 정복!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '모찌가 오천 년 역사의 보물을\n모두 만났어요. 진짜 역사가네요!',
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
                    worldH: _worldH,
                  ),
                ),
              ),
              for (final s in _spots) ..._buildSpot(s, camera),
              _buildComingSoonSign(camera),
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

  List<Widget> _buildSpot(_KoreaSpot s, Offset camera) {
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
            child: CustomPaint(painter: _KoreaSpotPainter(s, t: _time)),
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
              Text('🏮', style: TextStyle(fontSize: 26)),
              SizedBox(height: 6),
              Text(
                '다음 업데이트에서\n더 깊은 역사가 열려요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  height: 1.4,
                  color: Color(0xFFD8B98F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildExplorePrompt(_KoreaSpot s, Offset camera) {
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
    final total = _spots.length;
    final altitude =
        (((_worldH - _kite.dy) / _worldH) * 1200).clamp(0, 1200).round();
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
                            ? const Color(0xFFFCD34D).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '${done >= total ? '🏆' : '🏯'} $done/$total · ${altitude}m',
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
    final dir = target.pos - _kite;
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
                '방패연 조종법',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '화면을 꾹 누르고 있으면\n모찌 방패연이 그쪽으로 날아가요!\n역사 명소에 다가가면 탐험할 수 있어요.',
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
          // 연 본체 + 꼬리.
          Positioned(
            top: 0,
            child: SizedBox(
              width: 128,
              height: 150,
              child: CustomPaint(painter: _KitePainter(t: t, windy: windy)),
            ),
          ),
          // 모찌 — 연 위에 올라탄 모습(하반신은 연이 가린다).
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

    // 꼬리 리본 3가닥 — 바람에 흔들린다.
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

    // 그림자.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(2, 5), const Radius.circular(10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 한지 연 본체.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFDE9C8)],
        ).createShader(rect),
    );

    // 태극 방구멍 — 가운데 원(빨강/파랑 반원).
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

    // 십자 살 + 대각 살.
    final rib = Paint()
      ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.65)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(rect.left, c.dy), Offset(rect.right, c.dy), rib);
    canvas.drawLine(Offset(c.dx, rect.top), Offset(c.dx, rect.bottom), rib);
    canvas.drawLine(rect.topLeft, rect.bottomRight, rib);
    canvas.drawLine(rect.topRight, rect.bottomLeft, rib);

    // 테두리.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF8B5A2B),
    );

    // 연줄 — 위로 뻗는 실.
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

/// 깊이가 있는 소나무 — z 가 클수록 멀고 안개에 잠긴다.
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
        // 일부는 기와지붕 — 산기슭 마을 실루엣.
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
  _Crane({required this.lane, required this.speed, required this.z, required this.phase});

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

/// 한국 산하 배경 — 새벽 한지 하늘·수묵 능선·소나무·기와마을·학·원근 바닥.
class _KoreaWorldPainter extends CustomPainter {
  _KoreaWorldPainter({
    required this.camera,
    required this.t,
    required this.dust,
    required this.pines,
    required this.cranes,
    required this.worldH,
  });

  final Offset camera;
  final double t;
  final List<Depth3DMote> dust;
  final List<_Pine> pines;
  final List<_Crane> cranes;
  final double worldH;

  static const Color _fog = Color(0xFFD9C4A5);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 하늘 — 한지 크림에서 노을 주황, 아래는 깊은 먹빛.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFDE9C8),
            Color(0xFFF3B884),
            Color(0xFF9C6644),
            Color(0xFF3B2417),
          ],
          stops: [0, 0.32, 0.62, 1],
        ).createShader(rect),
    );

    // 해 — 붉은 아침 해.
    final sun = Offset(size.width * 0.76, 130 - camera.dy * 0.06);
    canvas.drawCircle(
      sun,
      170,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF97316).withValues(alpha: 0.4),
            const Color(0xFFF97316).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 170)),
    );
    canvas.drawCircle(
        sun, 38, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.85));

    // 수묵 능선 2겹.
    _ridge(canvas, size, z: 2200, baseY: 0.40, amp: 30, color: const Color(0xFFB08D6A));
    _ridge(canvas, size, z: 1700, baseY: 0.47, amp: 38, color: const Color(0xFF8A6748));

    // 원근 바닥 — 논밭 들판.
    final horizon = size.height * 0.52 - camera.dy * Depth3D.scaleOf(900) * 0.12;
    PerspectiveGroundPainter(
      horizonY: horizon,
      near: const Color(0xFF3B2417),
      far: const Color(0xFF9C6644),
      lineColor: Colors.white.withValues(alpha: 0.24),
      rows: 8,
      cols: 12,
    ).paint(canvas, size, cameraX: camera.dx * 0.35);

    // 학 — 먼 하늘을 우아하게 가로지른다.
    for (final b in cranes) {
      final k = Depth3D.scaleOf(b.z);
      final travel = size.width + 120;
      final x = (b.phase * 90 + t * b.speed) % travel - 60;
      final y = size.height * (0.10 + b.lane * 0.3) - camera.dy * k * 0.5;
      _crane(canvas, Offset(x, y), 11 * k + 4, t + b.phase,
          1 - Depth3D.hazeOf(b.z));
    }

    // 소나무 숲 + 기와마을 — 깊이별. 먼 대역부터.
    final sorted = [...pines]..sort((a, b) => b.z.compareTo(a.z));
    for (final p in sorted) {
      final k = Depth3D.scaleOf(p.z);
      final tileW = size.width * 2.2;
      final x = (p.x * tileW - camera.dx * k) % tileW - size.width * 0.6;
      final baseY = horizon + (size.height - horizon) * (0.12 + (1 - k) * 0.1) +
          camera.dy * k * 0.06;
      if (p.roof) {
        _hanok(canvas, Offset(x, baseY), 120 * k * p.h, p.z);
      } else {
        _pine(canvas, Offset(x, baseY), 150 * k * p.h, p.z, t + p.phase);
      }
    }

    // 안개 입자.
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

    // 상단 먹 번짐 — 수묵화 느낌.
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

  /// 학 — 긴 목과 날개짓.
  void _crane(Canvas canvas, Offset c, double s, double phase, double alpha) {
    final flap = math.sin(phase * 5) * 0.5;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.14)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.75 * alpha);
    // 날개.
    canvas.drawLine(c, c + Offset(-s, -s * (0.5 + flap)), p);
    canvas.drawLine(c, c + Offset(s * 0.6, -s * (0.5 - flap)), p);
    // 목 + 부리 방향.
    canvas.drawLine(c, c + Offset(s * 1.1, -s * 0.05), p);
  }

  /// 소나무 — 굽은 줄기 + 층진 납작 수관.
  void _pine(Canvas canvas, Offset base, double h, double z, double phase) {
    if (h < 6) return;
    final sway = math.sin(phase * 0.8) * h * 0.015;
    final trunk = Depth3D.fogged(const Color(0xFF4A2E17), _fog, z);
    final leafDark = Depth3D.fogged(const Color(0xFF1E3A2A), _fog, z);
    final leafLight = Depth3D.fogged(const Color(0xFF3E6B4A), _fog, z);
    final top = Offset(base.dx + sway + h * 0.1, base.dy - h);

    // 굽은 줄기.
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - h * 0.04, base.dy)
        ..quadraticBezierTo(
            base.dx - h * 0.12, base.dy - h * 0.5, top.dx, top.dy)
        ..quadraticBezierTo(
            base.dx - h * 0.06, base.dy - h * 0.5, base.dx + h * 0.05, base.dy)
        ..close(),
      Paint()..color = trunk,
    );
    // 납작한 수관 3층.
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

  /// 기와지붕 실루엣 — 처마 끝이 살짝 올라간다.
  void _hanok(Canvas canvas, Offset base, double s, double z) {
    if (s < 8) return;
    final wall = Depth3D.fogged(const Color(0xFF5C4630), _fog, z);
    final roof = Depth3D.fogged(const Color(0xFF26201A), _fog, z);
    final w = s * 1.5;
    final wallH = s * 0.5;
    // 벽체.
    canvas.drawRect(
      Rect.fromLTWH(base.dx - w / 2, base.dy - wallH, w, wallH),
      Paint()..color = wall,
    );
    // 지붕 — 위로 휘는 처마.
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
    // 반짝임 — 은은한 금빛.
    for (final f in sparks) {
      final k = Depth3D.scaleOf(f.z);
      final tileW = size.width + 200;
      final tileH = size.height + 200;
      final px = (f.x * tileW - camera.dx * k) % tileW - 100;
      final py = (f.y * tileH - camera.dy * k) % tileH - 100;
      final blink = 0.2 + 0.6 * (0.5 + 0.5 * math.sin(f.phase + t * 2.4));
      final c = Offset(px, py);
      canvas.drawCircle(
          c,
          math.max(1.0, f.r * k),
          Paint()
            ..color = const Color(0xFFFDE68A).withValues(alpha: blink * 0.7));
    }

    // 꽃잎 — 살랑살랑 떨어지며 흐른다.
    for (final petal in petals) {
      final k = Depth3D.scaleOf(petal.z);
      final tileW = size.width * 1.6;
      final tileH = size.height * 1.6;
      final drift = t * 26 * petal.scale;
      final px = (petal.x * tileW - camera.dx * k + math.sin(t * 1.2 + petal.phase) * 30) %
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

enum _SpotKind { palace, observatory, turtleShip, grotto, fortress, hangul }

class _KoreaSpot {
  const _KoreaSpot({
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

/// 역사 명소 6곳.
const List<_KoreaSpot> _spots = [
  _KoreaSpot(
    id: 'gyeongbokgung',
    name: '경복궁',
    tagline: '조선의 첫 번째 궁궐',
    story: '커다란 문을 지나자 넓은 마당과 웅장한 근정전이 나타났어요. 모찌가 '
        '왕이 앉던 자리를 바라보며 "여기서 나라의 큰일을 정했구나!" 하고 '
        '감탄했어요. 처마 끝 색색의 단청이 정말 고왔어요.',
    glow: Color(0xFFFCD34D),
    stats: [
      ('창건', '1395년'),
      ('전각', '500여 채'),
      ('뜻', '큰 복을 누리라'),
    ],
    history: [
      ('1395', '창건', '조선을 세운 태조가 새 수도 한양에 지었어요.'),
      ('1592', '소실', '임진왜란 때 불타 오랫동안 폐허로 남았어요.'),
      ('1867', '중건', '흥선대원군이 다시 크게 지어 올렸어요.'),
      ('1990~', '복원', '지금도 옛 모습을 되찾는 공사가 이어지고 있어요.'),
    ],
    pos: Offset(760, 980),
    size: 200,
    kind: _SpotKind.palace,
  ),
  _KoreaSpot(
    id: 'cheomseongdae',
    name: '첨성대',
    tagline: '별을 보던 천년의 탑',
    story: '병 모양의 돌탑이 밤하늘을 향해 서 있어요. 신라 사람들은 여기서 별을 '
        '보고 농사지을 때를 정했대요. 모찌가 꼭대기 창문으로 별을 올려다보며 '
        '"천 년 전 별도 지금이랑 같았을까?" 궁금해했어요.',
    glow: Color(0xFFC4B5FD),
    stats: [
      ('높이', '9.17m'),
      ('돌', '약 362개'),
      ('나이', '약 1,400살'),
    ],
    history: [
      ('632', '건립', '신라 선덕여왕 때 세워진 것으로 전해져요.'),
      ('1962', '국보 지정', '동양에서 가장 오래된 천문대로 인정받았어요.'),
      ('2016', '지진 견딤', '경주 지진에도 살짝 기울기만 하고 버텼어요.'),
      ('오늘', '경주의 별', '밤이면 조명이 켜져 더 신비로워요.'),
    ],
    pos: Offset(1520, 1320),
    size: 175,
    kind: _SpotKind.observatory,
  ),
  _KoreaSpot(
    id: 'geobukseon',
    name: '거북선',
    tagline: '바다를 지킨 철갑 거북',
    story: '등에 뾰족한 철심이 박힌 배가 파도를 가르고 있어요! 용머리에서 연기를 '
        '뿜으며 나아가는 모습에 모찌 눈이 휘둥그레졌어요. 이순신 장군과 수군이 '
        '이 배로 바다를 지켰대요.',
    glow: Color(0xFF67E8F9),
    stats: [
      ('길이', '약 27m'),
      ('노', '좌우 8~10개'),
      ('대포', '사방 발사'),
    ],
    history: [
      ('1592', '첫 출전', '사천 바다에서 처음 싸움에 나섰어요.'),
      ('1592', '한산도 대첩', '학익진과 함께 큰 승리를 거뒀어요.'),
      ('1795', '기록 정리', '거북선 그림과 설명이 책으로 남았어요.'),
      ('오늘', '복원 전시', '여러 도시에서 실물 크기로 만날 수 있어요.'),
    ],
    pos: Offset(2280, 900),
    size: 195,
    kind: _SpotKind.turtleShip,
  ),
  _KoreaSpot(
    id: 'seokguram',
    name: '석굴암',
    tagline: '돌 속에 깃든 천년의 미소',
    story: '돔 모양 석굴 안에 커다란 부처님이 고요히 앉아 있어요. 모찌도 덩달아 '
        '숨을 죽이고 살금살금 걸었어요. 돌을 하나하나 쌓아 둥근 천장을 만들다니, '
        '신라 장인들은 정말 대단해요!',
    glow: Color(0xFFD8CDBE),
    stats: [
      ('완성', '774년'),
      ('본존불 높이', '3.4m'),
      ('천장', '돔형 궁륭'),
    ],
    history: [
      ('751', '공사 시작', '김대성이 불국사와 함께 짓기 시작했어요.'),
      ('774', '완성', '20여 년 만에 석굴이 완성됐어요.'),
      ('1913', '수리', '일제강점기에 크게 손보며 모습이 바뀌었어요.'),
      ('1995', '세계유산', '유네스코 세계문화유산이 됐어요.'),
    ],
    pos: Offset(3000, 1450),
    size: 180,
    kind: _SpotKind.grotto,
  ),
  _KoreaSpot(
    id: 'hwaseong',
    name: '수원 화성',
    tagline: '과학으로 쌓은 성곽',
    story: '성벽이 산과 들을 따라 구불구불 이어져요. 거중기라는 기계로 무거운 '
        '돌을 번쩍 들어 올려 지었대요. 모찌가 성벽 위를 걸으며 "옛날 사람들도 '
        '과학자였네!" 하고 놀랐어요.',
    glow: Color(0xFFFDBA74),
    stats: [
      ('길이', '5.7km'),
      ('공사 기간', '2년 9개월'),
      ('시설물', '48개'),
    ],
    history: [
      ('1794', '착공', '정조가 아버지를 기리며 짓기 시작했어요.'),
      ('1796', '완공', '거중기 덕분에 빠르고 튼튼하게 완성됐어요.'),
      ('1801', '의궤 편찬', '공사 과정을 책으로 꼼꼼히 남겼어요.'),
      ('1997', '세계유산', '유네스코 세계문화유산이 됐어요.'),
    ],
    pos: Offset(3680, 1000),
    size: 195,
    kind: _SpotKind.fortress,
  ),
  _KoreaSpot(
    id: 'hunminjeongeum',
    name: '훈민정음',
    tagline: '백성을 위한 스물여덟 글자',
    story: '책장이 스르륵 넘어가며 ㄱ, ㄴ, ㄷ 글자들이 반짝반짝 떠올라요! '
        '세종대왕이 백성 누구나 쉽게 읽고 쓰라고 만든 글자래요. 모찌도 제 이름을 '
        '한글로 또박또박 써 봤어요. "모! 찌!"',
    glow: Color(0xFF86EFAC),
    stats: [
      ('반포', '1446년'),
      ('처음 글자 수', '28자'),
      ('배우는 시간', '슬기로우면 하루'),
    ],
    history: [
      ('1443', '창제', '세종대왕이 새 글자를 만들었어요.'),
      ('1446', '반포', '훈민정음 해례본과 함께 세상에 알렸어요.'),
      ('1997', '세계기록유산', '해례본이 유네스코에 등재됐어요.'),
      ('오늘', '한글날', '10월 9일, 온 나라가 한글을 기념해요.'),
    ],
    pos: Offset(4200, 1500),
    size: 175,
    kind: _SpotKind.hangul,
  ),
];

// ── 명소 비주얼 ──────────────────────────────────────────────────────

class _KoreaSpotPainter extends CustomPainter {
  _KoreaSpotPainter(this.s, {required this.t});

  final _KoreaSpot s;
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
      case _SpotKind.palace:
        _palace(canvas, w, h);
      case _SpotKind.observatory:
        _observatory(canvas, w, h);
      case _SpotKind.turtleShip:
        _turtleShip(canvas, w, h);
      case _SpotKind.grotto:
        _grotto(canvas, w, h);
      case _SpotKind.fortress:
        _fortress(canvas, w, h);
      case _SpotKind.hangul:
        _hangul(canvas, w, h);
    }
  }

  /// 기와지붕 — 처마가 위로 휘는 곡선 지붕.
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

  void _palace(Canvas canvas, double w, double h) {
    // 석축 기단.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.14, h * 0.78, w * 0.72, h * 0.14),
      Paint()..color = const Color(0xFF9CA3AF),
    );
    // 1층 벽 — 붉은 기둥.
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
    // 큰 지붕 2층.
    _roof(canvas, Offset(w / 2, h * 0.58), w * 0.84, h * 0.16);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, h * 0.36, w * 0.44, h * 0.08),
      Paint()..color = const Color(0xFFFDE9C8),
    );
    _roof(canvas, Offset(w / 2, h * 0.36), w * 0.62, h * 0.15);
    // 단청 포인트.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.66, w * 0.12, h * 0.12),
      Paint()..color = const Color(0xFF7C2D12),
    );
  }

  void _observatory(Canvas canvas, double w, double h) {
    // 병 모양 몸체 — 돌단 쌓기.
    final body = Path()
      ..moveTo(w * 0.32, h * 0.9)
      ..cubicTo(w * 0.36, h * 0.55, w * 0.42, h * 0.42, w * 0.42, h * 0.3)
      ..lineTo(w * 0.58, h * 0.3)
      ..cubicTo(w * 0.58, h * 0.42, w * 0.64, h * 0.55, w * 0.68, h * 0.9)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5DDD0), Color(0xFF9B8F7D)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // 돌단 줄.
    final line = Paint()
      ..color = const Color(0xFF6B6152).withValues(alpha: 0.5)
      ..strokeWidth = 1.6;
    for (var i = 0; i < 9; i++) {
      final y = h * (0.33 + i * 0.065);
      final squeeze = (1 - (i / 9)) * 0.06 + 0.06;
      canvas.drawLine(
          Offset(w * (0.36 + squeeze), y), Offset(w * (0.64 - squeeze), y), line);
    }
    // 상단 우물 정(井)자.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.40, h * 0.24, w * 0.2, h * 0.06),
      Paint()..color = const Color(0xFF7A7062),
    );
    // 창문.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.46, h * 0.52, w * 0.08, h * 0.1),
      Paint()..color = const Color(0xFF2C2620),
    );
    // 별 반짝임.
    for (final (fx, fy) in const [(0.2, 0.16), (0.78, 0.12), (0.66, 0.24)]) {
      final blink = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 3 + fx * 10));
      canvas.drawCircle(Offset(w * fx, h * fy), 2.2,
          Paint()..color = const Color(0xFFFDE68A).withValues(alpha: blink));
    }
  }

  void _turtleShip(Canvas canvas, double w, double h) {
    final bob = math.sin(t * 1.6) * h * 0.012;
    canvas.save();
    canvas.translate(0, bob);
    // 파도.
    final wave = Paint()..color = const Color(0xFF155E75).withValues(alpha: 0.8);
    final wpath = Path()..moveTo(0, h * 0.84);
    for (double x = 0; x <= w; x += 10) {
      wpath.lineTo(x, h * 0.84 + math.sin(x / 14 + t * 3) * 3);
    }
    wpath
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    // 선체.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.12, h * 0.66)
        ..lineTo(w * 0.88, h * 0.66)
        ..lineTo(w * 0.8, h * 0.84)
        ..lineTo(w * 0.2, h * 0.84)
        ..close(),
      Paint()..color = const Color(0xFF5C4630),
    );
    // 등껍질 덮개.
    final shellRect = Rect.fromLTWH(w * 0.16, h * 0.38, w * 0.68, h * 0.42);
    canvas.drawArc(
      shellRect,
      math.pi,
      math.pi,
      true,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A6248), Color(0xFF463726)],
        ).createShader(shellRect),
    );
    // 철심.
    final spike = Paint()..color = const Color(0xFFB8BCC4);
    for (var i = 0; i < 7; i++) {
      final f = 0.22 + i * 0.095;
      final sy = h * (0.585 - math.sin((i / 6) * math.pi) * 0.145);
      canvas.drawPath(
        Path()
          ..moveTo(w * f - 3, sy + 6)
          ..lineTo(w * f, sy - 4)
          ..lineTo(w * f + 3, sy + 6)
          ..close(),
        spike,
      );
    }
    // 용머리.
    canvas.drawCircle(
        Offset(w * 0.1, h * 0.6), w * 0.06, Paint()..color = const Color(0xFF3F6212));
    canvas.drawCircle(Offset(w * 0.085, h * 0.585), 2.2,
        Paint()..color = const Color(0xFFFCD34D));
    // 연기.
    for (var i = 0; i < 3; i++) {
      final f = ((t * 0.5 + i / 3) % 1.0);
      canvas.drawCircle(
        Offset(w * (0.06 - f * 0.05), h * (0.55 - f * 0.2)),
        2 + f * 5,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * (1 - f)),
      );
    }
    // 노.
    final oar = Paint()
      ..color = const Color(0xFF3B2E1E)
      ..strokeWidth = 2.4;
    for (final fx in [0.3, 0.45, 0.6, 0.75]) {
      canvas.drawLine(Offset(w * fx, h * 0.8),
          Offset(w * (fx - 0.05), h * 0.92), oar);
    }
    canvas.drawPath(wpath, wave);
    canvas.restore();
  }

  void _grotto(Canvas canvas, double w, double h) {
    // 흙 둔덕.
    canvas.drawArc(
      Rect.fromLTWH(w * 0.06, h * 0.3, w * 0.88, h * 1.2),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF4E6B3E),
    );
    // 석굴 입구 아치.
    final arch = Rect.fromLTWH(w * 0.28, h * 0.42, w * 0.44, h * 0.9);
    canvas.drawArc(arch, math.pi, math.pi, true,
        Paint()..color = const Color(0xFF262019));
    // 안쪽 은은한 빛.
    final glowC = Offset(w * 0.5, h * 0.76);
    canvas.drawCircle(
      glowC,
      w * 0.16,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFCD34D).withValues(alpha: 0.5),
            const Color(0xFFFCD34D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glowC, radius: w * 0.16)),
    );
    // 본존불 실루엣 — 좌불.
    final buddha = Paint()..color = const Color(0xFF8A7B65);
    canvas.drawCircle(Offset(w * 0.5, h * 0.62), w * 0.055, buddha); // 머리
    canvas.drawArc(
      Rect.fromLTWH(w * 0.41, h * 0.65, w * 0.18, h * 0.24),
      math.pi,
      math.pi,
      true,
      buddha,
    ); // 몸
    canvas.drawOval(
      Rect.fromLTWH(w * 0.38, h * 0.82, w * 0.24, h * 0.07),
      buddha,
    ); // 가부좌
    // 석축 테두리.
    canvas.drawArc(
      arch.deflate(1),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF9B8F7D),
    );
  }

  void _fortress(Canvas canvas, double w, double h) {
    // 성벽 — 완만한 능선을 따라.
    final wall = Path()
      ..moveTo(w * 0.04, h * 0.9)
      ..lineTo(w * 0.04, h * 0.62)
      ..lineTo(w * 0.96, h * 0.62)
      ..lineTo(w * 0.96, h * 0.9)
      ..close();
    canvas.drawPath(
      wall,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBCB2A0), Color(0xFF877C69)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // 여장(총안 구멍 있는 담).
    for (var i = 0; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w * (0.06 + i * 0.155), h * 0.54, w * 0.11, h * 0.08),
        Paint()..color = const Color(0xFFA99D89),
      );
    }
    // 팔달문풍 2층 문루.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.34, h * 0.40, w * 0.32, h * 0.14),
      Paint()..color = const Color(0xFFFDE9C8),
    );
    _roof(canvas, Offset(w * 0.5, h * 0.40), w * 0.44, h * 0.11);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, h * 0.24, w * 0.24, h * 0.09),
      Paint()..color = const Color(0xFFFDE9C8),
    );
    _roof(canvas, Offset(w * 0.5, h * 0.24), w * 0.34, h * 0.1);
    // 홍예문(아치 통로).
    canvas.drawArc(
      Rect.fromLTWH(w * 0.42, h * 0.66, w * 0.16, h * 0.4),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF2C2620),
    );
  }

  void _hangul(Canvas canvas, double w, double h) {
    // 펼쳐진 책.
    final page = Paint()..color = const Color(0xFFFFF7ED);
    final left = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..quadraticBezierTo(w * 0.3, h * 0.44, w * 0.12, h * 0.52)
      ..lineTo(w * 0.14, h * 0.82)
      ..quadraticBezierTo(w * 0.32, h * 0.74, w * 0.5, h * 0.8)
      ..close();
    final right = Path()
      ..moveTo(w * 0.5, h * 0.5)
      ..quadraticBezierTo(w * 0.7, h * 0.44, w * 0.88, h * 0.52)
      ..lineTo(w * 0.86, h * 0.82)
      ..quadraticBezierTo(w * 0.68, h * 0.74, w * 0.5, h * 0.8)
      ..close();
    canvas.drawPath(left, page);
    canvas.drawPath(right, page);
    canvas.drawPath(
      left,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFB08D6A),
    );
    canvas.drawPath(
      right,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFB08D6A),
    );
    // 글줄.
    final line = Paint()
      ..color = const Color(0xFF8A6748).withValues(alpha: 0.4)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 3; i++) {
      final y = h * (0.56 + i * 0.07);
      canvas.drawLine(Offset(w * 0.2, y + 4), Offset(w * 0.42, y), line);
      canvas.drawLine(Offset(w * 0.58, y), Offset(w * 0.8, y + 4), line);
    }
    // 떠오르는 한글 자모 — 위로 두둥실.
    final glyphs = ['ㄱ', 'ㄴ', 'ㄷ', 'ㅁ', 'ㅅ'];
    for (final (i, g) in glyphs.indexed) {
      final f = ((t * 0.35 + i / glyphs.length) % 1.0);
      final gx = w * (0.24 + i * 0.13);
      final gy = h * (0.46 - f * 0.3);
      final alpha = (1 - f) * 0.95;
      final tp = TextPainter(
        text: TextSpan(
          text: g,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: w * 0.13 * (0.8 + f * 0.3),
            color: const Color(0xFF86EFAC).withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(gx - tp.width / 2, gy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_KoreaSpotPainter old) => old.t != t;
}

// ── 명소 상세 시트 ───────────────────────────────────────────────────

class _KoreaSpotSheet extends StatelessWidget {
  const _KoreaSpotSheet({
    required this.spot,
    required this.collected,
    required this.total,
  });

  final _KoreaSpot spot;
  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = spot;
    final maxH = MediaQuery.of(context).size.height * 0.82;
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
                        child: CustomPaint(
                            painter: _KoreaSpotPainter(s, t: 1.2)),
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
                                '🏯 한국의 역사 탐험',
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
                  _KoreaCard(
                    title: '모찌의 탐험 일지',
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
                  _KoreaCard(
                    title: '역사 연대기',
                    emoji: '📜',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, hRow) in s.history.indexed)
                          _KoreaTimelineRow(
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

class _KoreaCard extends StatelessWidget {
  const _KoreaCard({
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

class _KoreaTimelineRow extends StatelessWidget {
  const _KoreaTimelineRow({
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
