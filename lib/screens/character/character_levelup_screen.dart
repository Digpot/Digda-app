import 'dart:math';
import 'package:flutter/material.dart';

import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/animated_mochi_widget.dart';
import '../../theme/colors.dart';

class CharacterLevelUpScreen extends StatefulWidget {
  const CharacterLevelUpScreen({
    super.key,
    required this.character,
    required this.levelGained,
    required this.stageChanged,
    required this.stageBefore,
  });

  final CharacterState character;
  final int levelGained;
  final bool stageChanged;
  final CharacterStage stageBefore;

  static Future<void> show(
    BuildContext context, {
    required CharacterState character,
    required int levelGained,
    required bool stageChanged,
    required CharacterStage stageBefore,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => CharacterLevelUpScreen(
          character: character,
          levelGained: levelGained,
          stageChanged: stageChanged,
          stageBefore: stageBefore,
        ),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<CharacterLevelUpScreen> createState() => _CharacterLevelUpScreenState();
}

class _CharacterLevelUpScreenState extends State<CharacterLevelUpScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _starsCtrl;
  final _mochiCtrl = MochiAnimationController();

  late final Animation<double> _badgeScale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _buttonFade;

  late final List<_StarInfo> _stars;

  @override
  void initState() {
    super.initState();

    final rng = Random(12345);
    _stars = List.generate(22, (i) => _StarInfo(
      x: rng.nextDouble(),
      y: rng.nextDouble() * 0.72,
      size: 7.0 + rng.nextDouble() * 16.0,
      delay: rng.nextDouble(),
      type: i % 3,
    ));

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (widget.stageChanged) {
        _mochiCtrl.triggerProud();
      } else {
        _mochiCtrl.triggerHappy();
      }
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _starsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF9580),
              AppColors.primary,
              Color(0xFFB45CF6),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Floating stars
            ..._stars.map((star) => _buildStar(star, size)),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Title badge
                  ScaleTransition(
                    scale: _badgeScale,
                    child: _buildTitleBadge(),
                  ),
                  const SizedBox(height: 32),
                  // Mochi character
                  FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: AnimatedMochiWidget(
                        color: widget.character.color,
                        colorHex: widget.character.colorHex,
                        stage: widget.character.stage,
                        size: 190,
                        controller: _mochiCtrl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Level info
                  FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: _buildLevelInfo(),
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Continue button
                  FadeTransition(
                    opacity: _buttonFade,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '계속하기',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
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

  Widget _buildTitleBadge() {
    final isEvolution = widget.stageChanged;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            isEvolution ? '진화 달성!' : '레벨 UP!',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 23,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          const Text('✨', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildLevelInfo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Text(
            'Lv. ${widget.character.level}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 32,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            widget.stageChanged
                ? '${widget.character.stageDisplayName} 단계로 진화했어요! 🌟'
                : '${widget.character.stageDisplayName} · +${widget.levelGained} 레벨 성장!',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildStar(_StarInfo star, Size size) {
    const icons = [
      Icons.star_rounded,
      Icons.auto_awesome,
      Icons.star_outline_rounded,
    ];
    return AnimatedBuilder(
      animation: _starsCtrl,
      builder: (_, __) {
        final t = ((_starsCtrl.value + star.delay) % 1.0);
        final opacity = (sin(t * pi) * 0.75).clamp(0.05, 0.75);
        final scale = 0.35 + 0.65 * sin(t * pi);
        return Positioned(
          left: star.x * size.width,
          top: star.y * size.height,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Icon(
                icons[star.type],
                size: star.size,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StarInfo {
  const _StarInfo({
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
