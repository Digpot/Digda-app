import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/character_models.dart';
import '../../../theme/colors.dart';
import 'animated_mochi_widget.dart';
import 'character_speech_bubble.dart';
import 'diko_character_view.dart';
import 'mochi_character_view.dart';

/// 메인 화면의 모찌 홈 씬 — 세로 직사각형 "키우기 방" 카드.
///
/// 폭을 가득 채우는 배경 씬(하늘~언덕) 안에 모찌가 서 있고, 하단 잔디 위에
/// 돌봄 툴바(물주기·간식·공놀이·목욕)가 떠 있다. 각 버튼은 모찌의 전용
/// 리액션(감정+점프+파티클+대사)을 트리거하고 쓰다듬기와 같은 경험치 콜백을
/// 공유한다. 디코([state.dikoUnlocked])는 카드 우하단에 함께 산다.
class MochiHomeScene extends StatelessWidget {
  const MochiHomeScene({
    super.key,
    required this.state,
    required this.mochiController,
    required this.onPet,
    this.onDikoTap,
    this.showChat = true,
  });

  final CharacterState state;
  final MochiAnimationController mochiController;
  final VoidCallback onPet;

  /// 디코를 탭했을 때 부모에 알리는 콜백 (선택). 디코 자체의 반응 애니메이션은
  /// [_DikoIdleFloat] 내부에서 처리되며, 이 콜백은 부가 동작(예: 메시지)용.
  final VoidCallback? onDikoTap;
  final bool showChat;

  /// 씬 세로 비율 — 200×260 직사각형 (정사각형 대비 1.3배).
  static const double _heightFactor = 1.3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final canvasH = w * _heightFactor;
        final dikoSize = w * 0.28;
        // AnimatedMochiWidget 은 캔버스 아래 24px 여유(점프/파티클용)를 갖는다 —
        // 카드 안 요소들의 bottom 좌표는 그만큼 보정한다.
        const extraBottom = 24.0;
        return SizedBox(
          width: w,
          height: canvasH + extraBottom,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedMochiWidget(
                appearance: MochiAppearance.fromState(state),
                stage: state.stage,
                size: w,
                heightFactor: _heightFactor,
                clipRadius: 28,
                bubbleInBounds: true,
                happiness: state.progress,
                controller: mochiController,
                onPet: onPet,
                // 디코 등장 후엔 둘이 대화하는 채팅(_MochiDikoChat)이 하늘에 떠
                // 있으므로 모찌 단독 자동 말풍선은 끈다 (돌봄 대사는 강제 표시됨).
                showBubble: !state.dikoUnlocked,
              ),
              if (state.dikoUnlocked)
                // 디코는 카드 우하단 잔디 위 — 돌봄 툴바 위쪽에 떠 있는다.
                Positioned(
                  right: 12,
                  bottom: extraBottom + 74,
                  child: _DikoIdleFloat(size: dikoSize, onTap: onDikoTap),
                ),
              if (state.dikoUnlocked && showChat)
                // 말풍선은 각자 머리 위 — 장식이라 IgnorePointer 로 감싸 아래
                // 캐릭터 탭(쓰다듬기·디코 반응)을 막지 않는다.
                Positioned.fill(
                  child: IgnorePointer(
                    child: _MochiDikoChat(
                      stage: state.stage,
                      mochiSize: w,
                      dikoSize: dikoSize,
                      dikoBottom: extraBottom + 74,
                    ),
                  ),
                ),
              // 돌봄 툴바 — 카드 하단 잔디 위.
              Positioned(
                left: 0,
                right: 0,
                bottom: extraBottom + 10,
                child: _CareToolbar(
                  onAction: mochiController.triggerCare,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 홈 씬 하단의 돌봄 버튼 줄 — 물주기/간식/공놀이/목욕.
class _CareToolbar extends StatelessWidget {
  const _CareToolbar({required this.onAction});

  final void Function(MochiCareAction) onAction;

  static const _actions = [
    (MochiCareAction.water, '💧', '물주기'),
    (MochiCareAction.snack, '🍡', '간식'),
    (MochiCareAction.play, '⚽', '공놀이'),
    (MochiCareAction.bubble, '🫧', '목욕'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (action, emoji, label) in _actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: _CareButton(
              emoji: emoji,
              label: label,
              onTap: () => onAction(action),
            ),
          ),
      ],
    );
  }
}

class _CareButton extends StatefulWidget {
  const _CareButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  State<_CareButton> createState() => _CareButtonState();
}

class _CareButtonState extends State<_CareButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(widget.emoji, style: const TextStyle(fontSize: 21)),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: AppColors.gray700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 디코는 가볍게 위아래로 떠 있는다. 모찌 본체와는 다른 페이즈(주기 1.6s)라 둘이
/// 같이 호흡하면서도 안 겹치는 리듬을 만든다.
///
/// 모찌처럼 탭하면 반응한다 — 윙크/하트 표정으로 바뀌며 통통 튀어오르는 한 번짜리
/// 바운스. [onTap] 으로 부모에 알려 부가 동작(메시지 등)도 트리거할 수 있다.
class _DikoIdleFloat extends StatefulWidget {
  const _DikoIdleFloat({required this.size, this.onTap});
  final double size;
  final VoidCallback? onTap;

  @override
  State<_DikoIdleFloat> createState() => _DikoIdleFloatState();
}

class _DikoIdleFloatState extends State<_DikoIdleFloat>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _popCtrl;
  late final Animation<double> _pop;
  DikoMood _mood = DikoMood.idle;
  Timer? _moodTimer;
  Timer? _reactTimer;

  static const _moods = [
    DikoMood.idle,
    DikoMood.happy,
    DikoMood.curious,
    DikoMood.wink,
  ];
  // 탭했을 때 번갈아 보여줄 반응 표정.
  static const _reactMoods = [DikoMood.wink, DikoMood.happy];
  int _reactIdx = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // 탭 시 한 번 재생되는 통통 바운스 (1 → 1.22 → 1).
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_popCtrl);
    // 4~7초 간격으로 mood 변주
    _moodTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _reactTimer != null) return;
      setState(() {
        _mood = _moods[(_moods.indexOf(_mood) + 1) % _moods.length];
      });
    });
  }

  void _handleTap() {
    if (!mounted) return;
    // 반응 표정 + 바운스 한 번. 1.2초 후 idle 변주로 복귀.
    setState(() {
      _mood = _reactMoods[_reactIdx % _reactMoods.length];
      _reactIdx++;
    });
    _popCtrl.forward(from: 0);
    _reactTimer?.cancel();
    _reactTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _mood = DikoMood.idle);
      _reactTimer = null;
    });
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _popCtrl.dispose();
    _moodTimer?.cancel();
    _reactTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ctrl, _popCtrl]),
        builder: (_, __) {
          final dy = math.sin(_ctrl.value * math.pi) * 5.0;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: _pop.value,
              child: DikoCharacterView(size: widget.size, mood: _mood),
            ),
          );
        },
      ),
    );
  }
}

/// 모찌 ↔ 디코 가 번갈아 띄우는 말풍선. 회전 주기 4초, 자연스러운 잡담 톤.
///
/// 진화 단계에 따라 모찌가 더 어른스러운 톤으로 말하도록 [_corpus] 가 단계별로
/// 분기된다.
class _MochiDikoChat extends StatefulWidget {
  const _MochiDikoChat({
    required this.stage,
    required this.mochiSize,
    required this.dikoSize,
    this.dikoBottom = 16,
  });
  final CharacterStage stage;
  final double mochiSize;
  final double dikoSize;

  /// 디코 본체가 컨테이너 하단에서 떠 있는 높이 — 디코 말풍선의 기준점.
  final double dikoBottom;

  @override
  State<_MochiDikoChat> createState() => _MochiDikoChatState();
}

class _MochiDikoChatState extends State<_MochiDikoChat> {
  Timer? _ticker;
  Timer? _firstShowTimer;
  // null 이면 아직 첫 라인 등장 전이라 빈 화면. 1200ms 후 0 으로 전환되며
  // 주기적 ticker 가 그 뒤를 이어받는다 — Mochi/Diko 가 먼저 등장한 다음 대화가
  // 시작되는 느낌을 준다.
  int? _index;

  // 말풍선 위치 변주 — 매 라인마다 머리 위 기준으로 조금씩 다른 자리에 떠서
  // 항상 같은 자리에 박혀 보이지 않게 한다(2.0.0). 캐릭터 본체를 가리지 않도록
  // 각자 머리 위 범위 안에서만 흔들되, 꼬리는 항상 화자 쪽을 가리킨다.
  final math.Random _rng = math.Random();
  double _mochiLeftFactor = 0.04; // mochiSize 대비 0.02~0.38
  double _mochiTop = 0; // 0~12px
  BubbleTailDirection _mochiTail = BubbleTailDirection.bottomCenter;
  double _dikoRightFactor = 0.03; // dikoSize 대비 0.03~0.28
  double _dikoLift = 0; // 0~12px 추가로 띄움

  void _shuffleSlots() {
    _mochiLeftFactor = 0.02 + _rng.nextDouble() * 0.36;
    _mochiTop = _rng.nextDouble() * 12;
    // 말풍선이 모찌 머리 중심(≈0.5)보다 왼쪽으로 치우칠수록 꼬리를 오른쪽에 둬
    // 머리를 가리키게 한다.
    _mochiTail = _mochiLeftFactor < 0.16
        ? BubbleTailDirection.bottomRight
        : BubbleTailDirection.bottomCenter;
    _dikoRightFactor = 0.03 + _rng.nextDouble() * 0.25;
    _dikoLift = _rng.nextDouble() * 12;
  }

  @override
  void initState() {
    super.initState();
    _firstShowTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _shuffleSlots();
        _index = 0;
      });
    });
    _ticker = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _index == null) return;
      setState(() {
        _shuffleSlots();
        _index = (_index! + 1) % _corpus(widget.stage).length;
      });
    });
  }

  @override
  void didUpdateWidget(_MochiDikoChat old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      // 단계가 변하면 인덱스 초기화 — 다른 톤의 라인으로 즉시 갈아치움.
      // 단, 아직 첫 라인 등장 전(null) 이면 null 을 유지해 1200ms 지연을 보장.
      setState(() {
        if (_index != null) _index = 0;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _firstShowTimer?.cancel();
    super.dispose();
  }

  /// 단계별 대사 리스트. 짝수 index = 모찌 발화, 홀수 index = 디코 응답.
  ///
  /// 디코는 Lv.10(BLOSSOM) 이상에서만 등장하므로 실제로는 blossom/glow/master 의
  /// 세 톤이 쓰인다 — 단계가 오를수록 모찌가 더 의젓한 톤으로 말한다.
  static List<_ChatLine> _corpus(CharacterStage stage) {
    return switch (stage) {
      // 디코 등장 전 단계 — race 안전용 fallback.
      CharacterStage.egg ||
      CharacterStage.sprout ||
      CharacterStage.bloom =>
        const [
          _ChatLine.mochi('만나서 반가워!'),
          _ChatLine.diko('나도 잘 부탁해 ✨'),
        ],
      // BLOSSOM (Lv.10) — 디코를 막 만난 풋풋하고 들뜬 톤.
      CharacterStage.blossom => const [
          _ChatLine.mochi('디코! 우리 이제 같이 다니는 거야?'),
          _ChatLine.diko('응! 잘 부탁해 ☺'),
          _ChatLine.mochi('퀴즈 하나 풀어볼까?'),
          _ChatLine.diko('좋아! 내가 응원할게 ✨'),
          _ChatLine.mochi('오늘은 사진 퀴즈도 풀 수 있대.'),
          _ChatLine.diko('우와, 재밌겠다!'),
          _ChatLine.mochi('같이 산책 갈래?'),
          _ChatLine.diko('따라갈게! 후후~'),
        ],
      // GLOW (Lv.15) — 한층 자라 차분하고 다정해진 톤.
      CharacterStage.glow => const [
          _ChatLine.mochi('디코, 우리 꽤 멀리 왔다 그치?'),
          _ChatLine.diko('맞아, 네가 반짝반짝해졌어 ✨'),
          _ChatLine.mochi('다 같이 만든 추억 덕분이야.'),
          _ChatLine.diko('앞으로가 더 기대돼!'),
          _ChatLine.mochi('오늘도 한 문제 풀어볼까?'),
          _ChatLine.diko('좋지! 천천히 가자 ☺'),
          _ChatLine.diko('모찌, 정말 의젓해졌어.'),
          _ChatLine.mochi('헤헤, 디코 덕분이지.'),
        ],
      // MASTER (Lv.20) — 든든하고 어른스러운 마스터의 톤.
      CharacterStage.master => const [
          _ChatLine.mochi('여기까지 함께 와줘서 고마워, 디코.'),
          _ChatLine.diko('우리 진짜 마스터가 됐네! 🏆'),
          _ChatLine.mochi('이제 챔피언 챌린지도 도전해보자.'),
          _ChatLine.diko('네 곁이라면 어디든 든든해 ✨'),
          _ChatLine.mochi('앞으로도 잘 부탁해.'),
          _ChatLine.diko('당연하지, 우린 한 팀이니까!'),
          _ChatLine.diko('모찌, 넌 최고의 마스터야.'),
          _ChatLine.mochi('히히, 너도 최고의 친구야.'),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final lines = _corpus(widget.stage);
    // 첫 라인 지연 중에는 빈 영역으로 두고, 1200ms 후 첫 라인이 fade-in.
    // 인덱스가 corpus 길이를 넘는 비정상 케이스(이론상 없음)도 안전하게 모듈로.
    final idx = _index;
    final line = idx == null ? null : lines[idx % lines.length];
    final isMochi = line?.speaker == _Speaker.mochi;
    final isDiko = line?.speaker == _Speaker.diko;
    final mochiSize = widget.mochiSize;
    final dikoSize = widget.dikoSize;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 모찌 말풍선 — 모찌 머리 위(상단 밴드). 라인마다 좌우/상하로 살짝 변주.
        Positioned(
          top: _mochiTop,
          left: mochiSize * _mochiLeftFactor,
          child: _slot(
            show: isMochi,
            line: line,
            keyId: 'mochi-$idx',
            maxWidth: mochiSize * 0.78,
            tail: _mochiTail,
          ),
        ),
        // 디코 말풍선 — 디코 머리 위(우측). 디코는 bottom:16, 높이 dikoSize 로 컨테이너
        // 오른쪽에 매달려 있다. 버블을 디코 쪽으로 더 붙이고(우측) 위로 더 띄워(상단)
        // 모찌 본체와 덜 겹치게 한다. 단 버블 오른쪽 끝이 디코 오른쪽 끝(≈ +dikoSize*0.65)
        // 을 넘으면 작은 화면에서 ListView 가 가로로 잘라먹으므로 그 안쪽으로 둔다.
        Positioned(
          // 컨테이너가 오른쪽으로 dikoPeek(=dikoSize*0.65) 넓어졌으므로, 디코 말풍선이
          // 기존(폭 mochiSize 기준 right:-dikoSize*0.62)과 동일한 화면 위치 부근에 오도록
          // dikoPeek 만큼 안쪽으로 당긴 지점(+0.03)을 기준으로 라인마다 살짝 변주한다.
          right: dikoSize * _dikoRightFactor,
          bottom: widget.dikoBottom + dikoSize + 14 + _dikoLift,
          child: _slot(
            show: isDiko,
            line: line,
            keyId: 'diko-$idx',
            maxWidth: mochiSize * 0.58,
            // 디코는 항상 버블 오른쪽 아래에 있으므로 꼬리도 오른쪽.
            tail: BubbleTailDirection.bottomRight,
          ),
        ),
      ],
    );
  }

  /// 한쪽 화자의 말풍선 슬롯. 현재 라인이 그 화자의 것이 아니면 빈 위젯으로 접힌다.
  Widget _slot({
    required bool show,
    required _ChatLine? line,
    required String keyId,
    required double maxWidth,
    required BubbleTailDirection tail,
  }) {
    final alignment = switch (tail) {
      BubbleTailDirection.bottomLeft => Alignment.bottomLeft,
      BubbleTailDirection.bottomCenter => Alignment.bottomCenter,
      BubbleTailDirection.bottomRight => Alignment.bottomRight,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
            alignment: alignment,
            child: child,
          ),
        );
      },
      child: (show && line != null)
          ? CharacterSpeechBubble(
              key: ValueKey(keyId),
              text: line.text,
              speakerLabel:
                  line.speaker == _Speaker.mochi ? '모찌' : '디코',
              accent: line.speaker == _Speaker.mochi
                  ? AppColors.primary
                  : const Color(0xFFA78BFA),
              tail: tail,
              maxWidth: maxWidth,
            )
          : const SizedBox.shrink(),
    );
  }
}

class _ChatLine {
  const _ChatLine.mochi(this.text) : speaker = _Speaker.mochi;
  const _ChatLine.diko(this.text) : speaker = _Speaker.diko;
  final String text;
  final _Speaker speaker;
}

enum _Speaker { mochi, diko }
