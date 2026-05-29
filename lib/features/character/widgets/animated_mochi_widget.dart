import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character_models.dart';
import 'mochi_character_view.dart';

// ─────────────────────────────────────────────
// 외부 컨트롤러 — 다른 화면에서 리액션 트리거 용
// ─────────────────────────────────────────────

class MochiAnimationController {
  _AnimatedMochiWidgetState? _state;

  void triggerExcited() => _state?.triggerExcited();
  void triggerHappy() => _state?.triggerHappy();
  void triggerProud() => _state?.triggerProud();
}

// ─────────────────────────────────────────────
// 메인 애니메이션 위젯
// ─────────────────────────────────────────────

class AnimatedMochiWidget extends StatefulWidget {
  const AnimatedMochiWidget({
    super.key,
    required this.appearance,
    required this.stage,
    this.size = 220,
    this.happiness = 1.0,
    this.controller,
    this.onPet,
  });

  final MochiAppearance appearance;
  final CharacterStage stage;
  final double size;

  /// 0.0 ~ 1.0. 낮으면 sleepy 표정.
  final double happiness;

  final MochiAnimationController? controller;

  /// 쓰다듬기 쿨다운(10s) 후 콜백.
  final VoidCallback? onPet;

  @override
  State<AnimatedMochiWidget> createState() => _AnimatedMochiWidgetState();
}

class _AnimatedMochiWidgetState extends State<AnimatedMochiWidget>
    with TickerProviderStateMixin {
  // ── 애니메이션 컨트롤러 ──
  late final AnimationController _swayCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _jumpCtrl;
  late final Animation<double> _jumpAnim;

  // ── 눈 깜빡임 ──
  double _eyeOpenness = 1.0;
  Timer? _blinkTimer;

  // ── 감정 상태 ──
  MochiEmotion _emotion = MochiEmotion.idle;
  Timer? _emotionResetTimer;
  Timer? _sleepCheckTimer;
  DateTime _lastInteraction = DateTime.now();

  // ── 파티클 ──
  final List<_ParticleData> _particles = [];
  int _pid = 0;

  // ── 쓰다듬 쿨다운 ──
  DateTime _lastPetCall = DateTime.fromMillisecondsSinceEpoch(0);

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _initControllers();
    _scheduleNextBlink();
    _startSleepCheck();
    _applyHappiness();
  }

  @override
  void didUpdateWidget(AnimatedMochiWidget old) {
    super.didUpdateWidget(old);
    if (old.happiness != widget.happiness) _applyHappiness();
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _swayCtrl.dispose();
    _floatCtrl.dispose();
    _jumpCtrl.dispose();
    _blinkTimer?.cancel();
    _emotionResetTimer?.cancel();
    _sleepCheckTimer?.cancel();
    super.dispose();
  }

  // ── 초기화 ──

  void _initControllers() {
    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    _jumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _jumpAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -22.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -22.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 62,
      ),
    ]).animate(_jumpCtrl);
  }

  // ── 깜빡임 ──

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    final ms = 3000 + _rng.nextInt(3200);
    _blinkTimer = Timer(Duration(milliseconds: ms), () async {
      await _blink();
      if (mounted) _scheduleNextBlink();
    });
  }

  Future<void> _blink() async {
    if (!mounted) return;
    setState(() => _eyeOpenness = 0.0);
    await Future.delayed(const Duration(milliseconds: 110));
    if (!mounted) return;
    setState(() => _eyeOpenness = 1.0);
  }

  // ── 수면 감지 ──

  void _startSleepCheck() {
    _sleepCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final idle = DateTime.now().difference(_lastInteraction);
      if (idle.inSeconds >= 30 && _emotion == MochiEmotion.idle) {
        _setEmotion(MochiEmotion.sleepy);
      }
    });
  }

  // ── 감정 유틸 ──

  void _applyHappiness() {
    if (_emotion == MochiEmotion.happy ||
        _emotion == MochiEmotion.excited ||
        _emotion == MochiEmotion.proud) return;
    _setEmotion(
      widget.happiness < 0.25 ? MochiEmotion.sleepy : MochiEmotion.idle,
    );
  }

  void _setEmotion(MochiEmotion emotion, {Duration? resetAfter}) {
    if (!mounted) return;
    _emotionResetTimer?.cancel();
    setState(() => _emotion = emotion);
    if (resetAfter != null) {
      _emotionResetTimer = Timer(resetAfter, () {
        if (!mounted) return;
        setState(() {
          _emotion = widget.happiness < 0.25
              ? MochiEmotion.sleepy
              : MochiEmotion.idle;
        });
      });
    }
  }

  // ── 외부 트리거 ──

  void triggerExcited() {
    _lastInteraction = DateTime.now();
    _setEmotion(MochiEmotion.excited,
        resetAfter: const Duration(seconds: 3));
    _jump();
    _spawnParticles(
      Offset(widget.size / 2, widget.size / 2),
      count: 3,
    );
  }

  void triggerHappy() {
    _lastInteraction = DateTime.now();
    _setEmotion(MochiEmotion.happy,
        resetAfter: const Duration(seconds: 2));
    _jump();
    _spawnParticles(Offset(widget.size / 2, widget.size / 2));
  }

  void triggerProud() {
    _lastInteraction = DateTime.now();
    _setEmotion(MochiEmotion.proud,
        resetAfter: const Duration(seconds: 4));
    _jump();
    _spawnParticles(
      Offset(widget.size / 2, widget.size / 2),
      count: 4,
      forceEmoji: '⭐',
    );
  }

  // ── 제스처 ──

  void _onTapDown(TapDownDetails d) {
    HapticFeedback.lightImpact();
    _lastInteraction = DateTime.now();
    _setEmotion(MochiEmotion.happy,
        resetAfter: const Duration(seconds: 2));
    _jump();
    _spawnParticles(d.localPosition);
    _tryPetCallback();
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    _lastInteraction = DateTime.now();
    _setEmotion(MochiEmotion.excited,
        resetAfter: const Duration(seconds: 3));
    _jump();
    _spawnParticles(
      Offset(widget.size / 2, widget.size / 2),
      count: 3,
    );
    _tryPetCallback();
  }

  void _tryPetCallback() {
    final now = DateTime.now();
    if (now.difference(_lastPetCall).inSeconds >= 10) {
      _lastPetCall = now;
      widget.onPet?.call();
    }
  }

  void _jump() {
    _jumpCtrl
      ..reset()
      ..forward();
  }

  // ── 파티클 ──

  void _spawnParticles(
    Offset origin, {
    int count = 1,
    String? forceEmoji,
  }) {
    setState(() {
      for (var i = 0; i < count; i++) {
        final emoji = forceEmoji ??
            (_rng.nextInt(4) == 0 ? '⭐' : '❤️');
        _particles.add(_ParticleData(
          id: _pid++,
          origin: origin,
          emoji: emoji,
          dx: (_rng.nextDouble() - 0.5) * 64,
          dy: _rng.nextDouble() * 10,
        ));
      }
    });
  }

  void _removeParticle(int id) {
    if (!mounted) return;
    setState(() => _particles.removeWhere((p) => p.id == id));
  }

  // ── 빌드 ──

  @override
  Widget build(BuildContext context) {
    // 배경 squircle 은 애니메이션을 받지 않으므로 build 마다 한 번만 생성하고,
    // AnimatedBuilder 의 매 tick builder 안에서는 캐싱된 인스턴스를 그대로 사용한다.
    // (SvgPicture.string 의 parse 비용이 매 frame 발생하는 걸 막기 위함)
    final background = MochiCharacterView(
      appearance: widget.appearance,
      stage: widget.stage,
      size: widget.size,
      part: MochiCharacterPart.background,
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onLongPress: _onLongPress,
      child: SizedBox(
        width: widget.size,
        height: widget.size + 24,
        child: AnimatedBuilder(
          animation: Listenable.merge([_swayCtrl, _floatCtrl, _jumpCtrl]),
          builder: (_, __) {
            final sway =
                math.sin(_swayCtrl.value * math.pi) * 0.038;
            final floatY =
                math.sin(_floatCtrl.value * math.pi) * 4.0;
            final jumpY = _jumpAnim.value;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                background,
                // 본체·표정·액세서리 — 캐릭터만 sway/float/jump.
                Transform.translate(
                  offset: Offset(0, floatY + jumpY),
                  child: Transform.rotate(
                    angle: sway,
                    alignment: Alignment.bottomCenter,
                    child: MochiCharacterView(
                      appearance: widget.appearance,
                      stage: widget.stage,
                      size: widget.size,
                      expression: _emotion,
                      eyeOpenness: _eyeOpenness,
                      part: MochiCharacterPart.body,
                    ),
                  ),
                ),
                for (final p in List.of(_particles))
                  _ParticleWidget(
                    key: ValueKey(p.id),
                    data: p,
                    onDone: () => _removeParticle(p.id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 파티클 데이터
// ─────────────────────────────────────────────

class _ParticleData {
  const _ParticleData({
    required this.id,
    required this.origin,
    required this.emoji,
    required this.dx,
    required this.dy,
  });
  final int id;
  final Offset origin;
  final String emoji;
  final double dx;
  final double dy;
}

// ─────────────────────────────────────────────
// 파티클 위젯 — 위로 떠오르며 사라짐
// ─────────────────────────────────────────────

class _ParticleWidget extends StatefulWidget {
  const _ParticleWidget({
    super.key,
    required this.data,
    required this.onDone,
  });
  final _ParticleData data;
  final VoidCallback onDone;

  @override
  State<_ParticleWidget> createState() => _ParticleWidgetState();
}

class _ParticleWidgetState extends State<_ParticleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _dy;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();

    _dy = Tween<double>(begin: widget.data.dy, end: -68).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.2), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 70),
    ]).animate(_ctrl);
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 1.0)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: widget.data.origin.dx + widget.data.dx - 18,
        top: widget.data.origin.dy + _dy.value,
        child: Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scale.value,
            child: Text(
              widget.data.emoji,
              style: const TextStyle(fontSize: 30),
            ),
          ),
        ),
      ),
    );
  }
}
