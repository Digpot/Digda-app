import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character_models.dart';
import 'character_speech_bubble.dart';
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

/// 자동/터치 시 모찌가 띄우는 말풍선 후보 — 진화 단계에 따라 톤/내용이 달라진다.
/// 어린 단계(알·새싹)는 아기 같은 옹알이, 자란 단계는 또렷하고 어른스러운 톤.
List<String> _bubbleMessagesFor(CharacterStage stage) {
  return switch (stage) {
    CharacterStage.egg => const [
        'zZ...',
        '쿨... 쿨...',
        '응애!',
        '아직 졸려...',
        '꿈꾸는 중~',
        '음냐음냐',
        '따뜻해...',
      ],
    CharacterStage.sprout => const [
        '쑥쑥 자랄래!',
        '햇빛 좋아 ☀',
        '오늘도 자랐어!',
        '간질간질~',
        '새싹이 났어!',
        '물 줘~',
        '안녕!',
      ],
    CharacterStage.bloom => const [
        '꽃 폈다! 🌸',
        '예쁘지?',
        '향기 맡아봐~',
        '기분 좋아 ☺',
        '같이 놀자!',
        '오늘 뭐했어?',
        '쓰담쓰담 좋아~',
      ],
    CharacterStage.blossom => const [
        '활짝 폈어!',
        '봄바람 좋다~',
        '디코랑 같이 있어 ☺',
        '오늘도 고마워!',
        '우리 잘 어울리지?',
      ],
    CharacterStage.glow => const [
        '반짝반짝 ✨',
        '왕관 멋지지?',
        '한 단계 더 컸어!',
        '빛이 나는 것 같아!',
        '늘 곁에 있어줘서 고마워.',
      ],
    CharacterStage.master => const [
        '드디어 마스터야! 🏆',
        '여기까지 함께 와줘서 고마워.',
        '우리 정말 멋진 팀이야.',
        '앞으로도 잘 부탁해!',
        '챔피언 챌린지 도전해볼까?',
      ],
  };
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

  // ── 말풍선 ──
  String? _bubbleMessage;
  int _bubbleSeq = 0;
  Timer? _bubbleAutoTimer;
  Timer? _bubbleHideTimer;
  int _lastBubbleIndex = -1;

  // 말풍선 슬롯 — 머리 위 좌/중/우 + 머리 옆 좌/우까지 5개 자리를 돌아가며 떠서
  // 캐릭터 주변 곳곳에서 말을 거는 느낌을 준다. 꼬리는 항상 모찌 쪽을 가리킨다.
  _BubbleSlot _bubbleSlot = const _BubbleSlot(
    left: 0,
    top: 0,
    tail: BubbleTailDirection.bottomCenter,
  );
  int _lastSlotIndex = -1;

  /// 다음 말풍선이 뜰 자리를 고른다 — 직전과 같은 슬롯은 피한다.
  void _pickBubbleSlot() {
    final s = widget.size;
    final slots = <_BubbleSlot>[
      // 머리 위 왼쪽 끝 — 꼬리가 오른쪽 아래(머리)로.
      _BubbleSlot(
        left: -6,
        top: _rng.nextDouble() * 10,
        tail: BubbleTailDirection.bottomRight,
      ),
      // 머리 바로 위 — 꼬리 중앙.
      _BubbleSlot(
        left: s * (0.14 + _rng.nextDouble() * 0.12),
        top: _rng.nextDouble() * 10,
        tail: BubbleTailDirection.bottomCenter,
      ),
      // 머리 위 오른쪽 끝 — 꼬리가 왼쪽 아래(머리)로.
      _BubbleSlot(
        right: -6,
        top: _rng.nextDouble() * 10,
        tail: BubbleTailDirection.bottomLeft,
      ),
      // 머리 옆 왼쪽(배경 상단 모서리에 살짝 걸침).
      _BubbleSlot(
        left: -12,
        top: 34 + _rng.nextDouble() * 12,
        tail: BubbleTailDirection.bottomRight,
      ),
      // 머리 옆 오른쪽.
      _BubbleSlot(
        right: -12,
        top: 34 + _rng.nextDouble() * 12,
        tail: BubbleTailDirection.bottomLeft,
      ),
    ];
    int idx;
    do {
      idx = _rng.nextInt(slots.length);
    } while (idx == _lastSlotIndex);
    _lastSlotIndex = idx;
    _bubbleSlot = slots[idx];
  }

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
    final messages = _bubbleMessagesFor(widget.stage);
    int index;
    if (messages.length == 1) {
      index = 0;
    } else {
      do {
        index = _rng.nextInt(messages.length);
      } while (index == _lastBubbleIndex);
    }
    _lastBubbleIndex = index;
    _bubbleHideTimer?.cancel();
    setState(() {
      _bubbleSeq++;
      _bubbleMessage = messages[index];
      _pickBubbleSlot();
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
                top: _bubbleSlot.top,
                left: _bubbleSlot.left,
                right: _bubbleSlot.right,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) {
                    // 팝 스케일은 꼬리(캐릭터를 가리키는 지점)를 기준으로 커진다.
                    final alignment = switch (_bubbleSlot.tail) {
                      BubbleTailDirection.bottomLeft => Alignment.bottomLeft,
                      BubbleTailDirection.bottomCenter =>
                        Alignment.bottomCenter,
                      BubbleTailDirection.bottomRight => Alignment.bottomRight,
                    };
                    return FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.7, end: 1.0).animate(anim),
                        alignment: alignment,
                        child: child,
                      ),
                    );
                  },
                  child: _bubbleMessage == null
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : CharacterSpeechBubble(
                          key: ValueKey('bubble-$_bubbleSeq'),
                          text: _bubbleMessage!,
                          tail: _bubbleSlot.tail,
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
// 말풍선 슬롯 — 캐릭터 주변에서 말풍선이 뜨는 자리
// ─────────────────────────────────────────────

class _BubbleSlot {
  const _BubbleSlot({this.left, this.right, required this.top, required this.tail});

  /// left/right 중 하나만 설정 — 나머지 쪽은 내용 크기에 맞게 열어둔다.
  final double? left;
  final double? right;
  final double top;
  final BubbleTailDirection tail;
}
