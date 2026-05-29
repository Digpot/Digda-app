import 'dart:math';
import 'package:flutter/material.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../theme/colors.dart';

/// 진화 전용 풀스크린 연출.
///
/// 일반 레벨업과 시각 위계를 분리한다 — 진화는 모찌의 모습 자체가 바뀌는 사건이라
/// 이전 단계에서 새 단계로 cross-fade 되는 변신 모션을 중심으로 구성한다.
class CharacterEvolutionScreen extends StatefulWidget {
  const CharacterEvolutionScreen({
    super.key,
    required this.character,
    required this.stageBefore,
  });

  final CharacterState character;
  final CharacterStage stageBefore;

  static Future<void> show(
    BuildContext context, {
    required CharacterState character,
    required CharacterStage stageBefore,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => CharacterEvolutionScreen(
          character: character,
          stageBefore: stageBefore,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<CharacterEvolutionScreen> createState() =>
      _CharacterEvolutionScreenState();
}

class _CharacterEvolutionScreenState extends State<CharacterEvolutionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _starsCtrl;
  late final AnimationController _morphCtrl;
  late final Animation<double> _badgeScale;
  late final Animation<double> _flashOpacity;
  late final Animation<double> _beforeOpacity;
  late final Animation<double> _afterOpacity;
  late final Animation<double> _afterScale;
  late final Animation<double> _stageNameSlide;

  late final List<_Sparkle> _stars;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _stars = List.generate(28, (i) {
      return _Sparkle(
        x: rng.nextDouble(),
        y: rng.nextDouble() * 0.82,
        size: 8.0 + rng.nextDouble() * 18.0,
        delay: rng.nextDouble(),
        type: i % 3,
      );
    });

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _badgeScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
      ),
    );

    // 변신 중간에 흰 플래시
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.28, 0.68)));

    _beforeOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.28, 0.52, curve: Curves.easeIn),
      ),
    );
    _afterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.45, 0.78, curve: Curves.easeOut),
      ),
    );
    _afterScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.45, 0.85, curve: Curves.elasticOut),
      ),
    );

    _stageNameSlide = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _starsCtrl.dispose();
    _morphCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final appearance = MochiAppearance.fromState(widget.character);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFD089), // 황금빛 (진화 강조)
              Color(0xFFFF7B7B), // 코랄
              Color(0xFFB45CF6), // 보라
              Color(0xFF6A89F0), // 파랑
            ],
            stops: [0.0, 0.35, 0.72, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // 별빛
            ..._stars.map((s) => _buildSparkle(s, size)),
            // 변신 플래시 (전체 화면)
            AnimatedBuilder(
              animation: _flashOpacity,
              builder: (_, __) => IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _flashOpacity.value),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // 상단 배지
                  ScaleTransition(
                    scale: _badgeScale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🌟', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text(
                            '진화 달성!',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('🌟', style: TextStyle(fontSize: 22)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // 모찌 변신 — 이전 stage 가 fade-out 되며 새 stage 가 scale-in
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: AnimatedBuilder(
                      animation: _enterCtrl,
                      builder: (_, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          // 후광 펄스
                          Container(
                            width: 240 *
                                (0.7 + 0.3 * sin(_starsCtrl.value * pi * 2)),
                            height: 240 *
                                (0.7 + 0.3 * sin(_starsCtrl.value * pi * 2)),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                          // 이전 단계 모찌
                          Opacity(
                            opacity: _beforeOpacity.value,
                            child: MochiCharacterView(
                              appearance: appearance,
                              stage: widget.stageBefore,
                              size: 200,
                            ),
                          ),
                          // 새 단계 모찌
                          Opacity(
                            opacity: _afterOpacity.value,
                            child: Transform.scale(
                              scale: _afterScale.value,
                              child: MochiCharacterView(
                                appearance: appearance,
                                stage: widget.character.stage,
                                size: 200,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // 단계 이름 큰 텍스트 (이전 → 새 단계)
                  FadeTransition(
                    opacity: _stageNameSlide,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(_stageNameSlide),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StageLabel(
                                text: _stageDisplay(widget.stageBefore),
                                muted: true,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 22,
                                  color:
                                      Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              _StageLabel(
                                text: widget.character.stageDisplayName,
                                muted: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lv. ${widget.character.level}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  // 계속하기 버튼
                  FadeTransition(
                    opacity: _stageNameSlide,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(40, 0, 40, 48),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '계속하기',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparkle(_Sparkle s, Size size) {
    return AnimatedBuilder(
      animation: _starsCtrl,
      builder: (_, __) {
        final t = (_starsCtrl.value + s.delay) % 1.0;
        final opacity = (sin(t * pi) * 0.85).clamp(0.05, 0.85);
        final scale = 0.35 + 0.7 * sin(t * pi);
        const icons = [
          Icons.star_rounded,
          Icons.auto_awesome,
          Icons.bubble_chart,
        ];
        return Positioned(
          left: s.x * size.width,
          top: s.y * size.height,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Icon(icons[s.type], size: s.size, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  String _stageDisplay(CharacterStage stage) => switch (stage) {
        CharacterStage.egg => '알 모찌',
        CharacterStage.sprout => '새싹 모찌',
        CharacterStage.bloom => '꽃 모찌',
        CharacterStage.blossom => '활짝 모찌',
        CharacterStage.glow => '빛나는 모찌',
        CharacterStage.master => '마스터 모찌',
      };
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({required this.text, required this.muted});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
        fontSize: muted ? 16 : 20,
        color: muted
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.white,
        decoration: muted ? TextDecoration.lineThrough : null,
        decorationColor: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}

class _Sparkle {
  const _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.type,
  });
  final double x;
  final double y;
  final double size;
  final double delay;
  final int type;
}
