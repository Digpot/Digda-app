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

  /// 돌봄 액션(물주기·간식 등) 리액션 — 감정 + 점프 + 전용 파티클 + 대사.
  void triggerCare(MochiCareAction action) => _state?.triggerCare(action);
}

/// 홈 씬 하단 돌봄 툴바의 액션 종류. 각자 고유한 파티클/대사 리액션을 가진다.
enum MochiCareAction { water, snack, play, bubble }

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
    this.heightFactor = 1.0,
    this.clipRadius = 48,
    this.bubbleInBounds = false,
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

  /// 씬 세로 확장 배율 — 홈 화면 직사각형 씬은 1.3. [MochiCharacterView.heightFactor].
  final double heightFactor;

  /// 씬 클리핑 모서리 반경 — 홈 카드는 28 권장. [MochiCharacterView.clipRadius].
  final double clipRadius;

  /// true 면 말풍선을 위젯 위 추가 밴드 대신 씬 캔버스 안(하늘 영역)에 띄운다.
  /// 세로 확장 씬에서 하늘 여백이 충분할 때 사용.
  final bool bubbleInBounds;

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

  // ── 돌봄 연출 ──
  _CareShowData? _careShow;
  int _careSeq = 0;
  Timer? _careReactTimer;

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
    _careReactTimer?.cancel();
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

  /// 돌봄 액션 리액션 — 이모지 파티클 한 줌으로 끝나던 걸 액션별 연출
  /// 시퀀스([_CareShow])로 바꿨다: 공이 굴러와 모찌가 차올리고, 구름이 와서
  /// 비를 뿌리고, 간식이 떨어져 냠냠 사라지고, 비눗방울이 차오른다.
  /// 감정 변화·점프·대사는 연출 타이밍에 맞춰 지연 트리거된다.
  /// 말풍선은 showBubble 여부와 무관하게 강제로 띄워, 디코 채팅 모드에서도
  /// 반응이 보이게 한다.
  void triggerCare(MochiCareAction action) {
    _lastInteraction = DateTime.now();
    final (MochiEmotion emotion, List<String> lines) = switch (action) {
      MochiCareAction.water => (
          MochiEmotion.happy,
          const ['시원해~! 고마워', '물 최고야!', '쑥쑥 자랄게!'],
        ),
      MochiCareAction.snack => (
          MochiEmotion.excited,
          const ['냠냠 맛있어!', '간식 최고~!', '한 입만 더...!'],
        ),
      MochiCareAction.play => (
          MochiEmotion.excited,
          const ['슛~ 골인!', '재밌다! 한 번 더!', '공놀이 좋아!'],
        ),
      MochiCareAction.bubble => (
          MochiEmotion.happy,
          const ['보글보글~', '간지러워 히히', '반짝반짝 목욕시간!'],
        ),
    };
    // 연출 시작 — 같은 액션 연타 시 새 시퀀스로 교체.
    setState(() => _careShow = _CareShowData(id: _careSeq++, action: action));
    // 리액션(감정+점프+대사)은 소품이 모찌에 닿는 순간에 맞춘다.
    _careReactTimer?.cancel();
    _careReactTimer = Timer(_CareShow.reactDelay(action), () {
      if (!mounted) return;
      _setEmotion(emotion, resetAfter: const Duration(seconds: 3));
      _jump();
      _spawnParticles(
        Offset(widget.size / 2, widget.size * 0.5),
        count: 3,
        forceEmoji: _CareShow.burstEmoji(action),
      );
      _showBubbleMessage(lines[_rng.nextInt(lines.length)], forced: true);
    });
    _tryPetCallback();
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
    _showBubbleMessage(messages[index]);
  }

  /// [message] 말풍선을 띄운다. [forced]=true 면 showBubble=false 여도 띄운다
  /// (돌봄 리액션 등 1회성 강제 대사용).
  void _showBubbleMessage(String message, {bool forced = false}) {
    if (!mounted || (!widget.showBubble && !forced)) return;
    _bubbleHideTimer?.cancel();
    setState(() {
      _bubbleSeq++;
      _bubbleMessage = message;
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
      heightFactor: widget.heightFactor,
      clipRadius: widget.clipRadius,
    );

    // 말풍선이 활성화돼 있으면 위쪽 영역을 추가로 확보한다.
    // (bubbleInBounds 면 씬 캔버스 안 하늘 영역에 띄우므로 추가 밴드 불필요)
    final topPad =
        (widget.showBubble && !widget.bubbleInBounds) ? 56.0 : 0.0;
    final canvasHeight = widget.size * widget.heightFactor;

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
                  heightFactor: widget.heightFactor,
                  clipRadius: widget.clipRadius,
                ),
              ),
            ),
            // 돌봄 연출 소품 — 공/구름/간식/비눗방울이 씬 안에서 살아 움직인다.
            if (_careShow != null)
              _CareShow(
                key: ValueKey('care-${_careShow!.id}'),
                action: _careShow!.action,
                size: widget.size,
                onDone: () {
                  if (!mounted) return;
                  setState(() => _careShow = null);
                },
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
        height: canvasHeight + 24 + topPad,
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
            if (widget.showBubble || _bubbleMessage != null)
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
// 돌봄 연출 — 액션별 스크립트 애니메이션 소품
// ─────────────────────────────────────────────

class _CareShowData {
  const _CareShowData({required this.id, required this.action});
  final int id;
  final MochiCareAction action;
}

/// 돌봄 액션의 소품 연출. 이모지 소품이 씬 안에서 경로를 따라 움직인다:
/// - 공놀이: 공이 왼쪽에서 굴러와 튀어오르고, 모찌가 차올려 오른쪽 하늘로 날아간다
/// - 물주기: 구름이 머리 위로 흘러와 빗방울을 뿌리고 지나간다
/// - 간식: 간식이 톡 떨어져 통통 튀고, 한 입씩 사라진다
/// - 목욕: 비눗방울들이 아래에서 차올라 흔들리며 톡톡 터진다
///
/// 좌표계는 씬 상단 정사각형(폭 [size]) 기준 — 지면 y≈0.80·size, 모찌 중심
/// x=0.5·size. 시퀀스가 끝나면 [onDone] 으로 자신을 제거한다.
class _CareShow extends StatefulWidget {
  const _CareShow({
    super.key,
    required this.action,
    required this.size,
    required this.onDone,
  });

  final MochiCareAction action;
  final double size;
  final VoidCallback onDone;

  /// 소품이 모찌에 닿아 리액션(감정/점프/대사)을 시작할 시점.
  static Duration reactDelay(MochiCareAction action) => switch (action) {
        MochiCareAction.play => const Duration(milliseconds: 850),
        MochiCareAction.snack => const Duration(milliseconds: 720),
        MochiCareAction.water => const Duration(milliseconds: 800),
        MochiCareAction.bubble => const Duration(milliseconds: 700),
      };

  /// 리액션 순간 터지는 파티클 이모지.
  static String burstEmoji(MochiCareAction action) => switch (action) {
        MochiCareAction.play => '⭐',
        MochiCareAction.snack => '❤️',
        MochiCareAction.water => '✨',
        MochiCareAction.bubble => '✨',
      };

  static Duration _duration(MochiCareAction action) => switch (action) {
        MochiCareAction.play => const Duration(milliseconds: 1700),
        MochiCareAction.snack => const Duration(milliseconds: 1900),
        MochiCareAction.water => const Duration(milliseconds: 2100),
        MochiCareAction.bubble => const Duration(milliseconds: 2100),
      };

  @override
  State<_CareShow> createState() => _CareShowState();
}

class _CareShowState extends State<_CareShow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _CareShow._duration(widget.action),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// [t] 를 [a, b] 구간에서 0→1 로 정규화. 구간 밖은 0/1 로 클램프.
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final props = switch (widget.action) {
          MochiCareAction.play => _play(t, w),
          MochiCareAction.snack => _snack(t, w),
          MochiCareAction.water => _water(t, w),
          MochiCareAction.bubble => _bubble(t, w),
        };
        return Stack(clipBehavior: Clip.none, children: props);
      },
    );
  }

  Widget _prop(
    double x,
    double y,
    String emoji, {
    double scale = 1.0,
    double angle = 0.0,
    double opacity = 1.0,
    double fontSize = 30,
  }) {
    return Positioned(
      left: x - fontSize / 2,
      top: y - fontSize / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: Text(emoji, style: TextStyle(fontSize: fontSize)),
          ),
        ),
      ),
    );
  }

  /// 공놀이 — 굴러오기(0~0.38) → 튀어오르기(0.38~0.52) → 슛(0.52~1).
  List<Widget> _play(double t, double w) {
    final ground = w * 0.80;
    double x;
    double y;
    double angle;
    var opacity = 1.0;
    if (t < 0.38) {
      final p = Curves.easeOut.transform(_seg(t, 0.0, 0.38));
      x = -w * 0.12 + p * w * 0.48; // → 0.36w
      // 굴러오며 낮게 두 번 통통.
      y = ground - (math.sin(p * math.pi * 2).abs() * w * 0.05);
      angle = p * math.pi * 3;
    } else if (t < 0.52) {
      final p = Curves.easeOut.transform(_seg(t, 0.38, 0.52));
      x = w * 0.36 + p * w * 0.10;
      y = ground - p * w * 0.16; // 모찌 발치로 살짝 떠오름
      angle = math.pi * 3 + p * math.pi;
    } else {
      // 슛! 오른쪽 하늘로 포물선 비행 + 빠른 회전.
      final p = Curves.easeIn.transform(_seg(t, 0.52, 1.0));
      x = w * 0.46 + p * w * 0.72;
      y = ground - w * 0.16 - math.sin(p * math.pi * 0.5) * w * 0.62;
      angle = math.pi * 4 + p * math.pi * 5;
      opacity = 1.0 - _seg(p, 0.85, 1.0);
    }
    return [
      // 지면 그림자 — 공 높이에 따라 작아진다.
      if (opacity > 0)
        Positioned(
          left: x - 12,
          top: ground + 8,
          child: Opacity(
            opacity: 0.18 * opacity * (1.0 - _seg(ground - y, 0, w * 0.5)),
            child: Container(
              width: 24,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      _prop(x, y, '⚽', angle: angle, opacity: opacity, fontSize: 26),
    ];
  }

  /// 간식 — 낙하(0~0.32) → 착지 바운스(0.32~0.45) → 한 입씩 냠냠(0.45~0.95).
  List<Widget> _snack(double t, double w) {
    final landY = w * 0.64; // 모찌 입가 근처
    const x0 = 0.50;
    if (t < 0.32) {
      final p = Curves.easeIn.transform(_seg(t, 0.0, 0.32));
      return [_prop(w * x0, -w * 0.06 + p * (landY + w * 0.06), '🍡')];
    }
    if (t < 0.45) {
      final p = _seg(t, 0.32, 0.45);
      final squash = 1.0 + math.sin(p * math.pi) * 0.18;
      final hop = math.sin(p * math.pi) * w * 0.03;
      return [_prop(w * x0, landY - hop, '🍡', scale: squash)];
    }
    // 세 입에 나눠 먹기 — 단계적으로 작아지며 좌우로 옴찔.
    final p = _seg(t, 0.45, 0.95);
    final bite = (p * 3).floor().clamp(0, 2);
    final scale = (1.0 - (bite + 1) * 0.3) + 0.3 * (1.0 - (p * 3 - bite));
    final wiggle = math.sin(p * math.pi * 6) * w * 0.012;
    final fade = 1.0 - _seg(p, 0.92, 1.0);
    return [
      _prop(w * x0 + wiggle, landY, '🍡',
          scale: scale.clamp(0.0, 1.0), opacity: fade),
    ];
  }

  /// 물주기 — 구름 등장(0~0.25) → 비 뿌리기(0.25~0.8) → 퇴장(0.8~1).
  List<Widget> _water(double t, double w) {
    final cloudY = w * 0.20;
    double cloudX;
    if (t < 0.25) {
      cloudX = -w * 0.15 + Curves.easeOut.transform(_seg(t, 0, 0.25)) * w * 0.65;
    } else if (t < 0.80) {
      cloudX = w * 0.50 + math.sin(_seg(t, 0.25, 0.80) * math.pi * 2) * w * 0.03;
    } else {
      cloudX = w * 0.50 + Curves.easeIn.transform(_seg(t, 0.80, 1.0)) * w * 0.70;
    }
    final props = <Widget>[
      _prop(cloudX, cloudY, '🌧️', fontSize: 40,
          opacity: 1.0 - _seg(t, 0.92, 1.0)),
    ];
    // 빗방울 4줄 — 구름에서 모찌 정수리까지 시차 낙하.
    for (var i = 0; i < 4; i++) {
      final start = 0.28 + i * 0.11;
      final p = _seg(t, start, start + 0.22);
      if (p <= 0 || p >= 1) continue;
      final dx = (i - 1.5) * w * 0.07;
      props.add(_prop(
        cloudX * 0.4 + w * 0.5 * 0.6 + dx, // 구름과 모찌 사이 보간 위치
        cloudY + w * 0.06 + p * w * 0.30,
        '💧',
        fontSize: 16,
        opacity: 1.0 - _seg(p, 0.7, 1.0),
      ));
    }
    return props;
  }

  /// 목욕 — 비눗방울 3개가 차올라 흔들리다 톡 터진다 (시차).
  List<Widget> _bubble(double t, double w) {
    final props = <Widget>[];
    const xs = [0.30, 0.52, 0.70];
    for (var i = 0; i < xs.length; i++) {
      final start = i * 0.12;
      final p = _seg(t, start, start + 0.66);
      if (p <= 0) continue;
      final rise = Curves.easeOut.transform(p);
      final y = w * 0.82 - rise * w * 0.44;
      final sway = math.sin(p * math.pi * 3 + i) * w * 0.035;
      // 마지막 12% 구간에서 팝 — 커지며 사라지고 반짝이가 남는다.
      final popP = _seg(p, 0.88, 1.0);
      final scale = 0.7 + rise * 0.5 + popP * 0.6;
      final opacity = 1.0 - popP;
      props.add(_prop(
        w * xs[i] + sway,
        y,
        '🫧',
        scale: scale,
        opacity: opacity,
        fontSize: 24 + i * 4.0,
      ));
      if (popP > 0 && popP < 1) {
        props.add(_prop(w * xs[i] + sway, y, '✨',
            scale: 0.5 + popP * 0.7, opacity: 1.0 - popP, fontSize: 18));
      }
    }
    return props;
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
