import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/colors.dart';
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
    this.showBubble = false,
  });

  final MochiAppearance appearance;
  final CharacterStage stage;
  final double size;

  /// 0.0 ~ 1.0. 낮으면 sleepy 표정.
  final double happiness;

  final MochiAnimationController? controller;

  /// 쓰다듬기 쿨다운(10s) 후 콜백.
  final VoidCallback? onPet;

  /// true 면 10초 주기로 자동 말풍선이 뜨고, 터치 시 즉시 새 말풍선이 뜬다.
  /// 위젯 size 위쪽으로 추가 영역(48px)을 차지한다.
  final bool showBubble;

  @override
  State<AnimatedMochiWidget> createState() => _AnimatedMochiWidgetState();
}

/// 자동/터치 시 모찌가 띄우는 말풍선 후보. 진화 단계와 무관하게 공통.
const List<String> _kBubbleMessages = [
  '안녕!',
  '오늘 뭐했어?',
  '쓰담쓰담 좋아~',
  '또 보자!',
  '같이 놀자!',
  '기분 좋아 ☺',
  '졸려...',
  '뭐 먹을까?',
  '히히히',
  '심심해~',
  '사랑해 ♡',
  '고마워!',
  '오늘도 화이팅!',
  '나 멋지지?',
];

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

  // ── 말풍선 ──
  String? _bubbleMessage;
  int _bubbleSeq = 0;
  Timer? _bubbleAutoTimer;
  Timer? _bubbleHideTimer;
  int _lastBubbleIndex = -1;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _initControllers();
    _scheduleNextBlink();
    _startSleepCheck();
    _applyHappiness();
    if (widget.showBubble) {
      // 첫 진입에 잠시 후 인사 — 너무 즉시 떠 있으면 모찌가 안 보이는 느낌이라 1.5s 딜레이.
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) _showRandomBubble();
      });
      _bubbleAutoTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _showRandomBubble(),
      );
    }
  }

  @override
  void didUpdateWidget(AnimatedMochiWidget old) {
    super.didUpdateWidget(old);
    if (old.happiness != widget.happiness) _applyHappiness();
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
    if (old.showBubble != widget.showBubble) {
      _bubbleAutoTimer?.cancel();
      _bubbleHideTimer?.cancel();
      setState(() => _bubbleMessage = null);
      if (widget.showBubble) {
        _bubbleAutoTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => _showRandomBubble(),
        );
      }
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
    _bubbleAutoTimer?.cancel();
    _bubbleHideTimer?.cancel();
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
    _showRandomBubble();
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
    _showRandomBubble();
  }

  void _tryPetCallback() {
    final now = DateTime.now();
    if (now.difference(_lastPetCall).inSeconds >= 10) {
      _lastPetCall = now;
      widget.onPet?.call();
    }
  }

  // ── 말풍선 ──

  /// 랜덤 메시지 1개를 띄우고 4.5초 후 자동으로 사라지게 한다.
  /// showBubble=false 면 no-op (메인 화면 외에서는 동작 안 함).
  void _showRandomBubble() {
    if (!widget.showBubble || !mounted) return;
    int index;
    if (_kBubbleMessages.length == 1) {
      index = 0;
    } else {
      do {
        index = _rng.nextInt(_kBubbleMessages.length);
      } while (index == _lastBubbleIndex);
    }
    _lastBubbleIndex = index;
    _bubbleHideTimer?.cancel();
    setState(() {
      _bubbleSeq++;
      _bubbleMessage = _kBubbleMessages[index];
    });
    _bubbleHideTimer = Timer(const Duration(milliseconds: 4500), () {
      if (!mounted) return;
      setState(() => _bubbleMessage = null);
    });
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

    // 말풍선이 활성화돼 있으면 위쪽 영역을 추가로 확보한다.
    final topPad = widget.showBubble ? 56.0 : 0.0;

    final mochi = AnimatedBuilder(
      animation: Listenable.merge([_swayCtrl, _floatCtrl, _jumpCtrl]),
      builder: (_, __) {
        final sway = math.sin(_swayCtrl.value * math.pi) * 0.038;
        final floatY = math.sin(_floatCtrl.value * math.pi) * 4.0;
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
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onLongPress: _onLongPress,
      child: SizedBox(
        width: widget.size,
        height: widget.size + 24 + topPad,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: topPad,
              left: 0,
              right: 0,
              bottom: 0,
              child: mochi,
            ),
            if (widget.showBubble)
              Positioned(
                top: 0,
                left: widget.size * 0.45,
                right: -8,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.7, end: 1.0).animate(anim),
                        alignment: Alignment.bottomLeft,
                        child: child,
                      ),
                    );
                  },
                  child: _bubbleMessage == null
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : _SpeechBubble(
                          key: ValueKey('bubble-$_bubbleSeq'),
                          message: _bubbleMessage!,
                        ),
                ),
              ),
          ],
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

// ─────────────────────────────────────────────
// 말풍선 — 모찌 머리 위에 떠 있는 코멘트
// ─────────────────────────────────────────────

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.primary.withValues(alpha: 0.22);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 168),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.25,
                color: AppColors.gray900,
              ),
            ),
          ),
        ),
        // 꼬리 — 말풍선 좌하단 살짝 안쪽에서 모찌 쪽을 가리킴
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: CustomPaint(
            size: const Size(14, 9),
            painter: _BubbleTailPainter(borderColor: borderColor),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.borderColor});

  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.55, size.height)
      ..lineTo(size.width, 0);

    // 채움 — 본체와 이어지도록 위쪽은 닫지 않음.
    final fillPath = Path.from(path)..close();
    canvas.drawPath(fillPath, fillPaint);
    // 위쪽(0~size.width 라인) 은 본체 border 와 겹치므로 그리지 않는다.
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) =>
      old.borderColor != borderColor;
}
