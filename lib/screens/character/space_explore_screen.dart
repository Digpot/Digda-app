import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';

/// 모찌 우주 탐험 (v1) — 레벨 5 해금 콘텐츠.
///
/// 행성을 골라 워프로 이동하고, 도착 연출과 탐험 일지를 보는 가벼운 1탄.
/// 서버 연동 없는 순수 클라이언트 콘텐츠 — 이후 업데이트에서 행성/보상/기록을
/// 계속 확장한다(행성은 [_planets] 리스트에 추가하면 된다).
class SpaceExploreScreen extends StatefulWidget {
  const SpaceExploreScreen({super.key, required this.character});

  final CharacterState character;

  @override
  State<SpaceExploreScreen> createState() => _SpaceExploreScreenState();
}

/// 화면 상태 — 목적지 선택 → 워프 이동 연출 → 도착.
enum _Phase { select, warp, arrived }

class _SpaceExploreScreenState extends State<SpaceExploreScreen>
    with TickerProviderStateMixin {
  // 별 반짝임·모찌 부유 등 상시 앰비언트 루프.
  late final AnimationController _ambientCtrl;
  // 워프(하이퍼스페이스) 이동 연출.
  late final AnimationController _warpCtrl;

  _Phase _phase = _Phase.select;
  _Planet? _destination;
  // 이번 세션에서 탐험을 마친 행성 id — 카드에 '탐험 완료' 뱃지를 띄운다.
  final Set<String> _visited = <String>{};

  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _ambientCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();
    _warpCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _warpCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _phase = _Phase.arrived;
          final d = _destination;
          if (d != null) _visited.add(d.id);
        });
      }
    });
    // 별밭은 시드 고정 — 리빌드마다 위치가 바뀌지 않게 한다.
    final rand = math.Random(20260719);
    _stars = List.generate(90, (_) => _Star.random(rand));
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    _warpCtrl.dispose();
    super.dispose();
  }

  void _travelTo(_Planet planet) {
    if (_phase == _Phase.warp) return;
    setState(() {
      _destination = planet;
      _phase = _Phase.warp;
    });
    _warpCtrl.forward(from: 0);
  }

  void _backToSelect() {
    setState(() => _phase = _Phase.select);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1026),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 우주 배경 — 딥 네이비 그라디언트 + 성운 + 반짝이는 별.
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (_, __) => CustomPaint(
              painter: _SpacePainter(
                stars: _stars,
                t: _ambientCtrl.value,
                nebulaTint: _phase == _Phase.arrived
                    ? _destination?.glow
                    : null,
              ),
            ),
          ),
          SafeArea(
            child: switch (_phase) {
              _Phase.select => _buildSelect(),
              _Phase.warp => _buildSelect(),
              _Phase.arrived => _buildArrived(),
            },
          ),
          // 워프 연출 오버레이 — 별이 길게 늘어지는 하이퍼스페이스.
          if (_phase == _Phase.warp)
            AnimatedBuilder(
              animation: _warpCtrl,
              builder: (_, __) => _WarpOverlay(
                stars: _stars,
                progress: _warpCtrl.value,
                destination: _destination!,
              ),
            ),
        ],
      ),
    );
  }

  // ── 목적지 선택 ────────────────────────────────────────────────────

  Widget _buildSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildMochiShip(),
                const SizedBox(height: 18),
                const _SpeechBubble(text: '우주선 타고 태양계 한 바퀴, 어디부터 갈까?'),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Text(
                        '목적지 선택',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_visited.length}/${_planets.length} 탐험',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Color(0xFFB9C3E8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 208,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _planets.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      if (i == _planets.length) {
                        return const _ComingSoonCard();
                      }
                      final p = _planets[i];
                      return _PlanetCard(
                        planet: p,
                        visited: _visited.contains(p.id),
                        onTap: () => _travelTo(p),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Row(
                      children: [
                        Text('🛰️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '우주 탐험은 이제 시작이에요.\n새로운 행성과 모험이 계속 업데이트될 예정!',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF8B95B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 24, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Colors.white),
          ),
          const Text(
            '우주 탐험',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'BETA',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 우주선(UFO) 을 타고 두둥실 떠 있는 모찌 — 유리 돔 + 새턴형 몸체 + 엔진 광.
  Widget _buildMochiShip({double scale = 1.0}) {
    final domeSize = 118.0 * scale;
    final saucerW = 196.0 * scale;
    final saucerH = 54.0 * scale;
    final totalW = saucerW + 20 * scale;
    final totalH = domeSize + saucerH + 26 * scale;
    return AnimatedBuilder(
      animation: _ambientCtrl,
      builder: (context, child) {
        final t = _ambientCtrl.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(math.sin(t) * 4 * scale, math.sin(t * 2) * 7 * scale),
          child: child,
        );
      },
      child: SizedBox(
        width: totalW,
        height: totalH,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 우주선 뒤 은은한 보랏빛 글로우.
            Positioned(
              top: domeSize * 0.3,
              child: Container(
                width: saucerW,
                height: saucerW * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 46,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            // 유리 돔 콕핏 — 모찌 탑승.
            Positioned(
              top: 0,
              child: Container(
                width: domeSize,
                height: domeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.38),
                    width: 1.4,
                  ),
                ),
                child: ClipOval(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 6 * scale),
                      child: MochiCharacterView(
                        appearance:
                            MochiAppearance.fromState(widget.character),
                        stage: widget.character.stage,
                        size: domeSize * 0.72,
                        part: MochiCharacterPart.body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 돔 하이라이트.
            Positioned(
              top: domeSize * 0.14,
              left: (totalW - domeSize) / 2 + domeSize * 0.14,
              child: Container(
                width: domeSize * 0.3,
                height: domeSize * 0.15,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // 새턴형 몸체 — 돔 하단을 덮는 메탈릭 접시.
            Positioned(
              top: domeSize * 0.78,
              child: Container(
                width: saucerW,
                height: saucerH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF818CF8),
                      Color(0xFF4F46E5),
                      Color(0xFF312E81),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF312E81).withValues(alpha: 0.6),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                // 몸체 라이트 — 순서대로 깜빡인다.
                child: AnimatedBuilder(
                  animation: _ambientCtrl,
                  builder: (_, __) {
                    final t = _ambientCtrl.value * 2 * math.pi;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (i) {
                        final on =
                            0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 3 + i * 1.6));
                        return Container(
                          width: 10 * scale,
                          height: 10 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFDE68A)
                                .withValues(alpha: on),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFDE68A)
                                    .withValues(alpha: on * 0.7),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
            // 엔진 광 — 접시 아래 은은한 빔.
            Positioned(
              top: domeSize * 0.78 + saucerH - 6 * scale,
              child: Container(
                width: saucerW * 0.42,
                height: 22 * scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF67E8F9).withValues(alpha: 0.55),
                      const Color(0xFF67E8F9).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 도착 화면 ─────────────────────────────────────────────────────

  Widget _buildArrived() {
    final p = _destination!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // 행성 + 모찌가 함께 있는 도착 씬.
                SizedBox(
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _ambientCtrl,
                        builder: (_, __) {
                          final t = _ambientCtrl.value * 2 * math.pi;
                          return Transform.translate(
                            offset: Offset(0, math.sin(t) * 4),
                            child: _PlanetVisual(planet: p, size: 170),
                          );
                        },
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _buildMochiShip(scale: 0.62),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.glow.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: p.glow.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    '🚀 ${p.distance} 이동 완료',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: p.glow,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${p.name} 도착!',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.tagline,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFFB9C3E8),
                  ),
                ),
                const SizedBox(height: 18),
                // 행성 정보 칩 — 박물관 안내판 느낌의 스탯 3개.
                Row(
                  children: [
                    for (final (i, stat) in p.stats.indexed) ...[
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
                                  color: Color(0xFF8B95B8),
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
                // 탐험 일지 카드.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('📖', style: TextStyle(fontSize: 15)),
                          SizedBox(width: 7),
                          Text(
                            '모찌의 탐험 일지',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        p.story,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                          height: 1.65,
                          color: Color(0xFFD4DAF0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 행성 연대기 — 인류의 탐사 역사를 타임라인으로 감상.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('📜', style: TextStyle(fontSize: 15)),
                          SizedBox(width: 7),
                          Text(
                            '행성 연대기',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (final (i, h) in p.history.indexed)
                        _HistoryTimelineRow(
                          year: h.$1,
                          title: h.$2,
                          desc: h.$3,
                          accent: p.glow,
                          isLast: i == p.history.length - 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _backToSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '다른 행성도 탐험하기',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 데이터 ───────────────────────────────────────────────────────────

class _Planet {
  const _Planet({
    required this.id,
    required this.name,
    required this.tagline,
    required this.story,
    required this.base,
    required this.shade,
    required this.glow,
    required this.distance,
    required this.stats,
    required this.history,
    this.hasRing = false,
    this.ringVertical = false,
    this.craters = false,
    this.bands = false,
    this.clouds = false,
    this.continents = false,
  });

  final String id;
  final String name;
  final String tagline;
  final String story;
  final Color base; // 구체 밝은 톤
  final Color shade; // 구체 어두운 톤
  final Color glow; // 주변 발광/포인트 색
  final String distance;
  final List<(String, String)> stats; // (라벨, 값) — 박물관 안내판 느낌의 칩 3개
  final List<(String, String, String)> history; // (연도, 사건, 설명) 연대기
  final bool hasRing; // 토성 고리
  final bool ringVertical; // 천왕성 — 누워서 도는 세로 고리
  final bool craters; // 달/수성 크레이터
  final bool bands; // 목성/해왕성 줄무늬
  final bool clouds; // 금성 — 두꺼운 구름 소용돌이
  final bool continents; // 지구 — 대륙 + 구름
}

/// 태양계 전 행성 + 달 — 태양에서 가까운 순서. 새 목적지는 여기에 추가하면
/// 카드/도착 연출/연대기가 함께 생긴다.
const List<_Planet> _planets = [
  _Planet(
    id: 'mercury',
    name: '수성',
    tagline: '태양과 가장 가까운 행성',
    story: '태양이 바로 옆이라 낮엔 펄펄 끓고 밤엔 꽁꽁 얼어요. 모찌가 그늘과 '
        '햇빛 사이를 폴짝폴짝 오가며 놀았어요. 온통 크레이터투성이라 달이랑 '
        '쌍둥이 같대요.',
    base: Color(0xFFC9BFB4),
    shade: Color(0xFF6B5F55),
    glow: Color(0xFFD8CDBE),
    distance: '9,100만 km',
    stats: [
      ('지름', '4,879km'),
      ('1년', '88일'),
      ('온도', '-173~427℃'),
    ],
    history: [
      ('1631', '가상디', '수성이 태양 앞을 지나는 모습을 처음 관측했어요.'),
      ('1974', '마리너 10호', '처음으로 수성을 가까이에서 촬영했어요.'),
      ('2011', '메신저', '처음으로 수성 궤도에 진입해 지도를 만들었어요.'),
      ('2018', '베피콜롬보', '유럽과 일본이 함께 수성 탐사선을 발사했어요.'),
    ],
    craters: true,
  ),
  _Planet(
    id: 'venus',
    name: '금성',
    tagline: '새벽하늘에서 가장 밝은 별',
    story: '두꺼운 구름 담요를 덮고 있어 표면이 하나도 안 보여요. 모찌는 구름 위를 '
        '푹신푹신 트램펄린처럼 뛰어다녔어요. 지구에서 보면 제일 밝게 빛나는 '
        '"샛별"이 바로 여기래요!',
    base: Color(0xFFFDE8B0),
    shade: Color(0xFFC2841B),
    glow: Color(0xFFFBBF24),
    distance: '4,100만 km',
    stats: [
      ('지름', '12,104km'),
      ('하루', '243일'),
      ('온도', '약 465℃'),
    ],
    history: [
      ('1610', '갈릴레이', '금성도 달처럼 모양이 변한다는 걸 발견했어요.'),
      ('1962', '마리너 2호', '인류 최초로 다른 행성 근접 통과에 성공했어요.'),
      ('1970', '베네라 7호', '처음으로 다른 행성 표면에 착륙했어요.'),
      ('1990', '마젤란', '레이더로 구름 아래 지형 지도를 완성했어요.'),
    ],
    clouds: true,
  ),
  _Planet(
    id: 'earth',
    name: '지구',
    tagline: '우리 모두의 푸른 고향',
    story: '우주에서 바라보니 지구는 반짝이는 파란 구슬 같아요. 흰 구름, 초록 대륙, '
        '넓고 푸른 바다까지! 모찌가 한참을 바라보다가 말했어요. "역시 우리 집이 '
        '우주에서 제일 예뻐."',
    base: Color(0xFF60A5FA),
    shade: Color(0xFF1D4ED8),
    glow: Color(0xFF93C5FD),
    distance: '궤도 한 바퀴',
    stats: [
      ('지름', '12,742km'),
      ('바다', '표면의 71%'),
      ('나이', '약 45억 년'),
    ],
    history: [
      ('1957', '스푸트니크 1호', '첫 인공위성이 지구 주위를 돌기 시작했어요.'),
      ('1961', '가가린', '인류가 처음으로 우주에서 지구를 봤어요.'),
      ('1968', '아폴로 8호', '달에서 떠오르는 "지구돋이" 사진을 찍었어요.'),
      ('1990', '보이저 1호', '61억 km 밖에서 "창백한 푸른 점"을 남겼어요.'),
    ],
    continents: true,
  ),
  _Planet(
    id: 'moon',
    name: '달',
    tagline: '지구에서 가장 가까운 이웃',
    story: '모찌가 사뿐사뿐 뛰어다녀요. 중력이 약해서 한 번 점프하면 여섯 배나 '
        '높이 떠올라요! 발자국이 아주 오래 남는대요. 모찌도 살짝 발도장을 찍고 왔어요.',
    base: Color(0xFFE2E8F0),
    shade: Color(0xFF94A3B8),
    glow: Color(0xFFCBD5E1),
    distance: '38만 km',
    stats: [
      ('지름', '3,475km'),
      ('중력', '지구의 1/6'),
      ('온도', '-173~127℃'),
    ],
    history: [
      ('1959', '루나 2호', '인류의 탐사선이 처음으로 달 표면에 도달했어요.'),
      ('1969', '아폴로 11호', '닐 암스트롱이 인류 최초로 달에 발을 디뎠어요.'),
      ('1972', '아폴로 17호', '지금까지 마지막이 된 유인 달 착륙이었어요.'),
      ('2019', '창어 4호', '처음으로 달의 뒷면에 착륙했어요.'),
    ],
    craters: true,
  ),
  _Planet(
    id: 'mars',
    name: '화성',
    tagline: '붉은 모래의 행성',
    story: '온통 붉은 모래언덕이에요. 모찌가 언덕 위에서 데굴데굴 굴렀더니 온몸이 '
        '주황빛이 됐어요. 태양계에서 가장 큰 화산 올림푸스 몬스도 멀리서 구경했답니다.',
    base: Color(0xFFFB923C),
    shade: Color(0xFFB91C1C),
    glow: Color(0xFFF87171),
    distance: '2억 2천만 km',
    stats: [
      ('지름', '6,779km'),
      ('하루', '24시간 37분'),
      ('온도', '평균 -63℃'),
    ],
    history: [
      ('1965', '마리너 4호', '처음으로 화성을 가까이에서 촬영했어요.'),
      ('1976', '바이킹 1호', '처음으로 화성 표면 착륙에 성공했어요.'),
      ('1997', '소저너', '첫 로버가 화성 위를 굴러다니기 시작했어요.'),
      ('2021', '인저뉴어티', '작은 헬리콥터가 다른 행성에서 처음 날았어요.'),
    ],
  ),
  _Planet(
    id: 'jupiter',
    name: '목성',
    tagline: '태양계에서 가장 큰 행성',
    story: '구름 소용돌이가 그림처럼 흘러가요. 모찌보다 1,300배나 큰 행성이라 '
        '아무리 둘러봐도 끝이 안 보여요. 거대한 붉은 점(폭풍)은 멀리서만 살짝 봤어요.',
    base: Color(0xFFFCD34D),
    shade: Color(0xFFB45309),
    glow: Color(0xFFFBBF24),
    distance: '6억 3천만 km',
    stats: [
      ('지름', '139,820km'),
      ('위성', '95개+'),
      ('하루', '9시간 56분'),
    ],
    history: [
      ('1610', '갈릴레이', '망원경으로 목성의 4대 위성을 발견했어요.'),
      ('1979', '보이저 1호', '목성에도 얇은 고리가 있다는 걸 알아냈어요.'),
      ('1995', '갈릴레오호', '처음으로 목성 궤도를 도는 데 성공했어요.'),
      ('2016', '주노', '목성의 극지방 소용돌이를 처음 관측했어요.'),
    ],
    bands: true,
  ),
  _Planet(
    id: 'saturn',
    name: '토성',
    tagline: '아름다운 고리의 행성',
    story: '얼음 알갱이로 만들어진 고리가 반짝반짝 빛나요. 모찌가 고리 위에서 '
        '미끄럼틀을 타고 놀았어요. 우주에서 가장 멋진 놀이터라며 또 오고 싶대요!',
    base: Color(0xFFFDE68A),
    shade: Color(0xFFD97706),
    glow: Color(0xFFFCD34D),
    distance: '12억 8천만 km',
    stats: [
      ('지름', '116,460km'),
      ('위성', '146개+'),
      ('고리 폭', '약 28만 km'),
    ],
    history: [
      ('1610', '갈릴레이', '토성을 처음 관측했지만 고리인 줄 몰랐어요.'),
      ('1655', '하위헌스', '토성의 "귀"가 사실은 고리라는 걸 밝혔어요.'),
      ('2004', '카시니', '토성 궤도에 도착해 13년간 탐사했어요.'),
      ('2005', '하위헌스 착륙선', '위성 타이탄에 착륙했어요.'),
    ],
    hasRing: true,
  ),
  _Planet(
    id: 'uranus',
    name: '천왕성',
    tagline: '누워서 도는 얼음 거인',
    story: '자전축이 98도나 기울어져 옆으로 데굴데굴 구르듯 돌아요. 모찌도 따라서 '
        '옆으로 굴러봤대요. 민트색 얼음 대기가 사르르 반짝여서 우주에서 제일 '
        '시원해 보이는 행성이에요.',
    base: Color(0xFF99E9F2),
    shade: Color(0xFF0E7490),
    glow: Color(0xFF67E8F9),
    distance: '27억 km',
    stats: [
      ('지름', '50,724km'),
      ('자전축', '98° 기움'),
      ('온도', '약 -224℃'),
    ],
    history: [
      ('1781', '허셜', '망원경으로 발견된 최초의 행성이 됐어요.'),
      ('1787', '허셜', '위성 티타니아와 오베론을 찾아냈어요.'),
      ('1977', '고리 발견', '별빛 가림 관측으로 가는 고리를 찾았어요.'),
      ('1986', '보이저 2호', '처음이자 마지막으로 가까이 지나갔어요.'),
    ],
    hasRing: true,
    ringVertical: true,
  ),
  _Planet(
    id: 'neptune',
    name: '해왕성',
    tagline: '수학이 찾아낸 푸른 행성',
    story: '태양계 가장 바깥의 짙푸른 행성이에요. 시속 2,100km 초강풍이 불어서 '
        '모찌 볼이 파도처럼 출렁거렸어요. 망원경보다 수학 계산이 먼저 찾아낸 '
        '신기한 행성이랍니다.',
    base: Color(0xFF5B8DF6),
    shade: Color(0xFF1E3A8A),
    glow: Color(0xFF818CF8),
    distance: '43억 km',
    stats: [
      ('지름', '49,244km'),
      ('바람', '시속 2,100km'),
      ('1년', '165년'),
    ],
    history: [
      ('1846', '르베리에·갈레', '계산으로 위치를 예측해 발견했어요.'),
      ('1846', '라셀', '17일 만에 위성 트리톤까지 찾아냈어요.'),
      ('1989', '보이저 2호', '근접 통과하며 대암점 폭풍을 발견했어요.'),
      ('2011', '한 바퀴', '발견 후 165년 만에 첫 공전을 마쳤어요.'),
    ],
    bands: true,
  ),
];

// ── 배경/연출 페인터 ─────────────────────────────────────────────────

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.phase,
    required this.speed,
  });

  factory _Star.random(math.Random rand) => _Star(
        x: rand.nextDouble(),
        y: rand.nextDouble(),
        r: 0.6 + rand.nextDouble() * 1.6,
        phase: rand.nextDouble() * 2 * math.pi,
        speed: 1 + rand.nextDouble() * 2,
      );

  final double x; // 0~1 화면 비율 좌표
  final double y;
  final double r;
  final double phase;
  final double speed;
}

/// 딥 네이비 그라디언트 + 성운 + 반짝이는 별밭.
class _SpacePainter extends CustomPainter {
  _SpacePainter({required this.stars, required this.t, this.nebulaTint});

  final List<_Star> stars;
  final double t;
  final Color? nebulaTint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 베이스 그라디언트.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1026), Color(0xFF141A3C), Color(0xFF23124D)],
        ).createShader(rect),
    );
    // 성운 — 은은한 radial 두 덩어리. 도착한 행성 톤을 살짝 섞는다.
    void nebula(Offset c, double radius, Color color, double alpha) {
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    final tint = nebulaTint ?? const Color(0xFF7C3AED);
    nebula(Offset(size.width * 0.85, size.height * 0.18),
        size.width * 0.55, tint, 0.16);
    nebula(Offset(size.width * 0.08, size.height * 0.62),
        size.width * 0.5, const Color(0xFF2563EB), 0.12);

    // 별 — 각자 위상으로 반짝인다.
    final starPaint = Paint();
    for (final s in stars) {
      final tw =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(s.phase + t * 2 * math.pi * s.speed));
      starPaint.color = Colors.white.withValues(alpha: tw);
      canvas.drawCircle(
          Offset(s.x * size.width, s.y * size.height), s.r, starPaint);
    }
  }

  @override
  bool shouldRepaint(_SpacePainter old) =>
      old.t != t || old.nebulaTint != nebulaTint;
}

/// 워프 이동 연출 — 별이 화면 중심에서 길게 늘어지는 하이퍼스페이스 + 안내 문구.
class _WarpOverlay extends StatelessWidget {
  const _WarpOverlay({
    required this.stars,
    required this.progress,
    required this.destination,
  });

  final List<_Star> stars;
  final double progress;
  final _Planet destination;

  @override
  Widget build(BuildContext context) {
    // 연출 마지막 15% 구간은 도착 화면으로 밝게 페이드.
    final fade = progress > 0.85 ? (progress - 0.85) / 0.15 : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _WarpPainter(stars: stars, progress: progress)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🚀',
                style: TextStyle(fontSize: 40 + progress * 14),
              ),
              const SizedBox(height: 14),
              Text(
                '${destination.name}(으)로 이동 중...',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (fade > 0)
          Container(color: Colors.white.withValues(alpha: fade * 0.9)),
      ],
    );
  }
}

class _WarpPainter extends CustomPainter {
  _WarpPainter({required this.stars, required this.progress});

  final List<_Star> stars;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // 어두운 베일 위에 중심에서 바깥으로 뻗는 별 궤적.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B1026).withValues(alpha: 0.72),
    );
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..strokeCap = StrokeCap.round;
    // ease-in — 갈수록 빨라지는 느낌.
    final speed = Curves.easeIn.transform(progress.clamp(0.0, 1.0));
    for (final s in stars) {
      final pos = Offset(s.x * size.width, s.y * size.height);
      final dir = pos - center;
      if (dir.distance < 24) continue; // 중심 근처는 궤적 생략
      final unit = dir / dir.distance;
      final len = 10 + dir.distance * speed * 0.9;
      paint
        ..color = Colors.white.withValues(alpha: 0.25 + 0.55 * speed)
        ..strokeWidth = s.r * (0.8 + speed);
      canvas.drawLine(pos, pos + unit * len, paint);
    }
  }

  @override
  bool shouldRepaint(_WarpPainter old) => old.progress != progress;
}

// ── 행성 비주얼/카드 ─────────────────────────────────────────────────

/// 그라디언트 구체 + 크레이터/줄무늬/고리로 행성을 그린다.
class _PlanetVisual extends StatelessWidget {
  const _PlanetVisual({required this.planet, required this.size});

  final _Planet planet;
  final double size;

  @override
  Widget build(BuildContext context) {
    // 가로 고리는 더 넓은 캔버스, 세로 고리는 더 높은 캔버스가 필요하다.
    final horizontalRing = planet.hasRing && !planet.ringVertical;
    final w = horizontalRing ? size * 1.6 : size * 1.05;
    final h = planet.ringVertical ? size * 1.3 : size * 1.1;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(painter: _PlanetPainter(planet)),
    );
  }
}

class _PlanetPainter extends CustomPainter {
  _PlanetPainter(this.p);

  final _Planet p;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final sphere = Rect.fromCircle(center: center, radius: radius);

    // 발광.
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.glow.withValues(alpha: 0.35),
            p.glow.withValues(alpha: 0),
          ],
        ).createShader(
            Rect.fromCircle(center: center, radius: radius * 1.25)),
    );

    // 고리 뒤쪽 절반 — 구체 뒤로 지나가게 먼저 그린다.
    if (p.hasRing) {
      _drawRing(canvas, center, radius, back: true);
    }

    // 구체 — 좌상단 광원 그라디언트.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.45),
          radius: 1.1,
          colors: [p.base, p.shade],
        ).createShader(sphere),
    );

    // 목성 줄무늬.
    if (p.bands) {
      canvas.save();
      canvas.clipPath(Path()..addOval(sphere));
      final band = Paint()..color = p.shade.withValues(alpha: 0.35);
      for (final dy in [-0.45, -0.1, 0.28, 0.6]) {
        final y = center.dy + radius * dy;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, y),
            width: radius * 2.2,
            height: radius * 0.24,
          ),
          band,
        );
      }
      // 대적점.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + radius * 0.38, center.dy + radius * 0.4),
          width: radius * 0.5,
          height: radius * 0.3,
        ),
        Paint()..color = const Color(0xFFDC2626).withValues(alpha: 0.55),
      );
      canvas.restore();
    }

    // 금성 — 두꺼운 구름 소용돌이(밝은 톤의 부드러운 줄).
    if (p.clouds) {
      canvas.save();
      canvas.clipPath(Path()..addOval(sphere));
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.30);
      for (final (dy, w, tilt) in [
        (-0.42, 1.6, -0.12),
        (-0.05, 2.0, 0.10),
        (0.35, 1.7, -0.08),
        (0.65, 1.2, 0.14),
      ]) {
        canvas.save();
        canvas.translate(center.dx, center.dy + radius * dy);
        canvas.rotate(tilt);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * w,
            height: radius * 0.22,
          ),
          cloud,
        );
        canvas.restore();
      }
      canvas.restore();
    }

    // 지구 — 초록 대륙 + 흰 구름.
    if (p.continents) {
      canvas.save();
      canvas.clipPath(Path()..addOval(sphere));
      final land = Paint()
        ..color = const Color(0xFF34D399).withValues(alpha: 0.85);
      // 대륙 — 불규칙한 느낌을 내려고 타원 여러 개를 겹쳐 그린다.
      for (final (dx, dy, w, h, tilt) in [
        (-0.35, -0.30, 0.75, 0.55, -0.4),
        (-0.10, -0.05, 0.40, 0.30, 0.3),
        (0.35, 0.15, 0.60, 0.75, 0.5),
        (0.10, 0.55, 0.45, 0.28, -0.2),
        (-0.45, 0.40, 0.35, 0.25, 0.1),
      ]) {
        canvas.save();
        canvas.translate(center.dx + radius * dx, center.dy + radius * dy);
        canvas.rotate(tilt);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * w,
            height: radius * h,
          ),
          land,
        );
        canvas.restore();
      }
      // 구름 — 가늘고 밝은 줄 몇 가닥.
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.45);
      for (final (dx, dy, w, tilt) in [
        (-0.15, -0.55, 1.0, -0.15),
        (0.25, -0.15, 0.8, 0.20),
        (-0.30, 0.30, 0.9, 0.10),
      ]) {
        canvas.save();
        canvas.translate(center.dx + radius * dx, center.dy + radius * dy);
        canvas.rotate(tilt);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * w,
            height: radius * 0.14,
          ),
          cloud,
        );
        canvas.restore();
      }
      canvas.restore();
    }

    // 달/수성 크레이터.
    if (p.craters) {
      final crater = Paint()..color = p.shade.withValues(alpha: 0.45);
      canvas.save();
      canvas.clipPath(Path()..addOval(sphere));
      canvas.drawCircle(
          center + Offset(-radius * 0.3, -radius * 0.25), radius * 0.16, crater);
      canvas.drawCircle(
          center + Offset(radius * 0.32, radius * 0.1), radius * 0.12, crater);
      canvas.drawCircle(
          center + Offset(-radius * 0.05, radius * 0.42), radius * 0.10, crater);
      canvas.drawCircle(
          center + Offset(radius * 0.12, -radius * 0.42), radius * 0.07, crater);
      canvas.restore();
    }

    // 우측 하단 셰이딩 — 입체감.
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    canvas.drawCircle(
      center + Offset(radius * 0.45, radius * 0.45),
      radius * 1.05,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0.55, 1],
        ).createShader(
            Rect.fromCircle(center: center, radius: radius * 1.5)),
    );
    canvas.restore();

    // 고리 앞쪽 절반.
    if (p.hasRing) {
      _drawRing(canvas, center, radius, back: false);
    }
  }

  /// 고리 — 타원 스트로크를 절반씩 나눠 구체 앞뒤에 그린다.
  /// 토성은 가로 고리(위=뒤/아래=앞), 천왕성은 세로 고리(왼쪽=뒤/오른쪽=앞).
  void _drawRing(Canvas canvas, Offset center, double radius,
      {required bool back}) {
    final vertical = p.ringVertical;
    final ringRect = Rect.fromCenter(
      center: center,
      width: vertical ? radius * 1.05 : radius * 3.1,
      height: vertical ? radius * 2.5 : radius * 1.05,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * (vertical ? 0.10 : 0.22)
      ..color = p.glow.withValues(alpha: back ? 0.5 : 0.85);
    canvas.save();
    final Rect clip;
    if (vertical) {
      clip = back
          ? Rect.fromLTRB(ringRect.left - 20, ringRect.top - 20, center.dx,
              ringRect.bottom + 20)
          : Rect.fromLTRB(center.dx, ringRect.top - 20, ringRect.right + 20,
              ringRect.bottom + 20);
    } else {
      clip = back
          ? Rect.fromLTRB(ringRect.left - 20, ringRect.top - 20,
              ringRect.right + 20, center.dy)
          : Rect.fromLTRB(ringRect.left - 20, center.dy, ringRect.right + 20,
              ringRect.bottom + 20);
    }
    canvas.clipRect(clip);
    canvas.drawOval(ringRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanetPainter old) => old.p != p;
}

class _PlanetCard extends StatelessWidget {
  const _PlanetCard({
    required this.planet,
    required this.visited,
    required this.onTap,
  });

  final _Planet planet;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: visited
                ? planet.glow.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 82,
              child: Center(
                child: _PlanetVisual(planet: planet, size: 64),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              planet.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              planet.distance,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Color(0xFF8B95B8),
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: visited
                    ? planet.glow.withValues(alpha: 0.18)
                    : const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                visited ? '탐험 완료 ✓' : '출발!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: visited ? planet.glow : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 다음 업데이트 예고 카드.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1.2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔭', style: TextStyle(fontSize: 34)),
          SizedBox(height: 12),
          Text(
            '새로운 행성\n준비 중',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF8B95B8),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'COMING SOON',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 1.2,
              color: Color(0xFF6B7394),
            ),
          ),
        ],
      ),
    );
  }
}

/// 행성 연대기 타임라인 한 줄 — 발광 도트 + 세로줄 + 연도 뱃지 + 사건 설명.
class _HistoryTimelineRow extends StatelessWidget {
  const _HistoryTimelineRow({
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
          // 도트 + 세로 연결선.
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
                      color: Color(0xFFB9C3E8),
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

/// 모찌 말풍선 — 어두운 우주 배경 위의 반투명 화이트 버블.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
