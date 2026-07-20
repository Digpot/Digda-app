import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/character/models/character_models.dart';
import 'jungle_explore_screen.dart';
import 'space_explore_screen.dart';
import 'undersea_explore_screen.dart';

/// 모찌 탐험대 허브 — 탐험 콘텐츠(우주/해저/…) 를 고르는 관문 화면.
/// 새 탐험이 추가되면 [_destinations] 에 카드를 추가한다.
class ExploreHubScreen extends StatefulWidget {
  const ExploreHubScreen({super.key, required this.character});

  final CharacterState character;

  @override
  State<ExploreHubScreen> createState() => _ExploreHubScreenState();
}

class _ExploreHubScreenState extends State<ExploreHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _ambientCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  void _openSpace() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SpaceExploreScreen(character: widget.character),
      ),
    );
  }

  void _openUndersea() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UnderseaExploreScreen(character: widget.character),
      ),
    );
  }

  void _openJungle() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JungleExploreScreen(character: widget.character),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1230),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 은은한 배경 — 위(우주)에서 아래(심해)로 이어지는 그라디언트 + 입자.
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (_, __) =>
                CustomPaint(painter: _HubBgPainter(t: _ambientCtrl.value)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: Colors.white),
                      ),
                      const Text(
                        '모찌 탐험대',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Text(
                    '오늘은 어디로 떠나볼까요?\n모찌와 함께라면 어디든 갈 수 있어요.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xFF9BA3C7),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    children: [
                      _ExploreCard(
                        emoji: '🚀',
                        title: '우주 탐험',
                        subtitle: '태양계 9곳을 자유비행으로',
                        chips: const ['자유비행', '행성 연대기', '9곳'],
                        gradient: const [Color(0xFF312E81), Color(0xFF7C3AED)],
                        glow: const Color(0xFF8B5CF6),
                        ambient: _ambientCtrl,
                        scene: _CardScene.space,
                        onTap: _openSpace,
                      ),
                      const SizedBox(height: 14),
                      _ExploreCard(
                        emoji: '🌊',
                        title: '해저 탐험',
                        subtitle: '산호초부터 마리아나 해구까지',
                        chips: const ['잠수함', '심해 연대기', '6곳'],
                        gradient: const [Color(0xFF0E7490), Color(0xFF1E3A8A)],
                        glow: const Color(0xFF22D3EE),
                        ambient: _ambientCtrl,
                        scene: _CardScene.sea,
                        onTap: _openUndersea,
                      ),
                      const SizedBox(height: 14),
                      _ExploreCard(
                        emoji: '🌿',
                        title: '정글 탐험',
                        subtitle: '잊혀진 신전부터 거대 꽃까지',
                        chips: const ['열기구', '밀림 연대기', '6곳'],
                        gradient: const [Color(0xFF166534), Color(0xFF3F6212)],
                        glow: const Color(0xFF86EFAC),
                        ambient: _ambientCtrl,
                        scene: _CardScene.jungle,
                        onTap: _openJungle,
                      ),
                      const SizedBox(height: 14),
                      // 다음 탐험 예고.
                      Container(
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🧭', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 10),
                            Text(
                              '새로운 탐험지 준비 중\nCOMING SOON',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                height: 1.5,
                                color: Color(0xFF7B84AC),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CardScene { space, sea, jungle }

/// 탐험지 카드 — 그라디언트 씬(별밭/기포) + 타이틀 + 태그 칩.
class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.gradient,
    required this.glow,
    required this.ambient,
    required this.scene,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final List<String> chips;
  final List<Color> gradient;
  final Color glow;
  final Animation<double> ambient;
  final _CardScene scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: ambient,
              builder: (_, __) => CustomPaint(
                painter: _CardScenePainter(scene: scene, t: ambient.value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final c in chips) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 배경 씬 — space: 별밭+행성 실루엣 / sea: 기포+빛내림.
class _CardScenePainter extends CustomPainter {
  _CardScenePainter({required this.scene, required this.t});

  final _CardScene scene;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(switch (scene) {
      _CardScene.space => 7,
      _CardScene.sea => 11,
      _CardScene.jungle => 23,
    });
    if (scene == _CardScene.jungle) {
      // 깊이별로 겹치는 나무 실루엣 — 안개에 잠긴 밀림.
      for (var layer = 0; layer < 3; layer++) {
        final depth = layer / 2; // 0=가까움, 1=멂
        final color = Color.lerp(const Color(0xFF052E16),
            const Color(0xFF86EFAC), depth * 0.55)!;
        final baseY = size.height * (0.98 - depth * 0.12);
        final treeH = size.height * (0.55 - depth * 0.14);
        for (var i = 0; i < 7; i++) {
          final x = size.width * ((i + (layer * 0.4)) / 6.2) +
              math.sin(t * 2 * math.pi + layer) * 3;
          final h = treeH * (0.7 + rand.nextDouble() * 0.5);
          canvas.drawPath(
            Path()
              ..moveTo(x, baseY)
              ..lineTo(x - h * 0.22, baseY)
              ..lineTo(x, baseY - h)
              ..lineTo(x + h * 0.22, baseY)
              ..close(),
            Paint()..color = color.withValues(alpha: 0.85),
          );
        }
      }
      // 반딧불 몇 마리.
      for (var i = 0; i < 9; i++) {
        final x = rand.nextDouble() * size.width;
        final y = size.height * (0.3 + rand.nextDouble() * 0.55);
        final blink = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + i));
        canvas.drawCircle(Offset(x, y), 2.0,
            Paint()..color = const Color(0xFFFDE047).withValues(alpha: blink));
      }
      return;
    }
    if (scene == _CardScene.space) {
      // 별 반짝임.
      final star = Paint();
      for (var i = 0; i < 26; i++) {
        final x = rand.nextDouble() * size.width;
        final y = rand.nextDouble() * size.height;
        final ph = rand.nextDouble() * 2 * math.pi;
        final a = 0.25 +
            0.6 * (0.5 + 0.5 * math.sin(ph + t * 2 * math.pi * 2));
        star.color = Colors.white.withValues(alpha: a);
        canvas.drawCircle(Offset(x, y), 0.8 + rand.nextDouble() * 1.2, star);
      }
      // 우측 상단 행성 실루엣 + 고리.
      final c = Offset(size.width * 0.82, size.height * 0.30);
      canvas.drawCircle(
        c,
        30,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
          ).createShader(Rect.fromCircle(center: c, radius: 30)),
      );
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFFCD34D).withValues(alpha: 0.7);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: 96, height: 26), ring);
    } else {
      // 빛내림(god ray).
      for (var i = 0; i < 3; i++) {
        final x = size.width * (0.25 + i * 0.28);
        final sway = math.sin(t * 2 * math.pi + i) * 8;
        final path = Path()
          ..moveTo(x + sway - 14, -8)
          ..lineTo(x + sway + 14, -8)
          ..lineTo(x + sway + 42, size.height + 8)
          ..lineTo(x + sway - 2, size.height + 8)
          ..close();
        canvas.drawPath(
          path,
          Paint()..color = Colors.white.withValues(alpha: 0.05),
        );
      }
      // 상승 기포.
      final bubble = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (var i = 0; i < 14; i++) {
        final x = rand.nextDouble() * size.width;
        final speed = 0.4 + rand.nextDouble() * 0.8;
        final y = size.height -
            ((rand.nextDouble() + t * speed) % 1.0) * (size.height + 20);
        final r = 1.5 + rand.nextDouble() * 3;
        bubble.color = Colors.white.withValues(alpha: 0.35);
        canvas.drawCircle(Offset(x, y), r, bubble);
      }
    }
  }

  @override
  bool shouldRepaint(_CardScenePainter old) => old.t != t;
}

/// 허브 배경 — 딥 네이비 그라디언트 + 떠다니는 입자.
class _HubBgPainter extends CustomPainter {
  _HubBgPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141A3C), Color(0xFF0E1230), Color(0xFF0B1C33)],
        ).createShader(rect),
    );
    final rand = math.Random(3);
    final p = Paint();
    for (var i = 0; i < 30; i++) {
      final x = rand.nextDouble() * size.width;
      final baseY = rand.nextDouble() * size.height;
      final drift = math.sin(t * 2 * math.pi + i) * 6;
      p.color = Colors.white.withValues(alpha: 0.05 + rand.nextDouble() * 0.08);
      canvas.drawCircle(
          Offset(x, baseY + drift), 1 + rand.nextDouble() * 1.6, p);
    }
  }

  @override
  bool shouldRepaint(_HubBgPainter old) => old.t != t;
}
