import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/character_models.dart';
import '../../../theme/colors.dart';
import 'animated_mochi_widget.dart';
import 'diko_character_view.dart';
import 'mochi_character_view.dart';

/// 메인 화면에서 모찌(중앙)와 디코(우측 작게)를 함께 보여주는 스테이지.
///
/// 디코는 [state.dikoUnlocked]==true 일 때만 렌더. 두 캐릭터 사이에는 둘이 번갈아
/// 대화하는 듯한 [_MochiDikoChat] 말풍선이 떠 있는다 (showChat).
class MochiDikoStage extends StatelessWidget {
  const MochiDikoStage({
    super.key,
    required this.state,
    required this.mochiController,
    required this.onPet,
    this.mochiSize = 220,
    this.dikoSize = 96,
    this.showChat = true,
  });

  final CharacterState state;
  final MochiAnimationController mochiController;
  final VoidCallback onPet;
  final double mochiSize;
  final double dikoSize;
  final bool showChat;

  @override
  Widget build(BuildContext context) {
    // 디코가 추가되더라도 메인은 모찌 — Mochi 본체 사이즈는 그대로 두고, 디코를 우측
    // 하단 외곽에 약간 겹쳐 배치한다. 가로 폭은 모찌 size + 디코 size*0.45 만큼 잡는다.
    final containerWidth = mochiSize + (state.dikoUnlocked ? dikoSize * 0.45 : 0);
    // 상단 영역(말풍선용) 56px:
    //   - 디코 해금 전: 모찌 자체의 자동 말풍선(showBubble=true)이 위쪽 56px 를 사용.
    //   - 디코 해금 후: 모찌 자동 말풍선은 끄고(showBubble=false) 같은 56px 를
    //     Mochi↔Diko 채팅 밴드가 사용. 두 경우 모두 모찌 본체는 56만큼 내려 그려야
    //     상단 말풍선과 겹치지 않는다.
    const topBand = 56.0;
    // AnimatedMochiWidget 의 자체 높이 = size + 24 + (말풍선 활성 시 56).
    // showBubble 값에 맞춰 정확한 컨테이너 높이를 계산해 ListView 가 자식을 잘리지
    // 않게 배치하도록 한다 (이전엔 mochiSize+56 만 잡아 모찌 단독 모드에서 24px 오버플로).
    final mochiSelfHeight =
        mochiSize + 24 + (state.dikoUnlocked ? 0 : topBand);
    final totalHeight = state.dikoUnlocked
        ? (topBand + mochiSize + 24)
        : mochiSelfHeight;
    return SizedBox(
      width: containerWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            // 디코 해금 후 모찌 자체의 자동 말풍선을 끄면 모찌가 컨테이너 최상단부터
            // 그려지므로, 상단 56px 채팅 밴드를 위해 명시적으로 내려준다.
            top: state.dikoUnlocked ? topBand : 0,
            child: AnimatedMochiWidget(
              appearance: MochiAppearance.fromState(state),
              stage: state.stage,
              size: mochiSize,
              happiness: state.progress,
              controller: mochiController,
              onPet: onPet,
              // 디코가 등장한 뒤로는 둘이 함께 대화하는 새 말풍선 시스템(_MochiDikoChat)이
              // 그 위에 떠 있으므로 모찌 단독 자동 말풍선은 끈다.
              showBubble: !state.dikoUnlocked,
            ),
          ),
          if (state.dikoUnlocked)
            Positioned(
              right: -dikoSize * 0.05,
              bottom: 8,
              child: _DikoIdleFloat(size: dikoSize),
            ),
          if (state.dikoUnlocked && showChat)
            Positioned(
              top: 0,
              left: mochiSize * 0.18,
              right: 0,
              // height 를 강제하면 2줄 버블이 잘려 보일 수 있어 컨테이너 의도(56)를
              // 살리는 align 만 두고 실제 높이는 버블이 자유롭게 잡게 둔다.
              child: _MochiDikoChat(stage: state.stage),
            ),
        ],
      ),
    );
  }
}

/// 디코는 가볍게 위아래로 떠 있는다. 모찌 본체와는 다른 페이즈(주기 1.6s)라 둘이
/// 같이 호흡하면서도 안 겹치는 리듬을 만든다.
class _DikoIdleFloat extends StatefulWidget {
  const _DikoIdleFloat({required this.size});
  final double size;

  @override
  State<_DikoIdleFloat> createState() => _DikoIdleFloatState();
}

class _DikoIdleFloatState extends State<_DikoIdleFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  DikoMood _mood = DikoMood.idle;
  Timer? _moodTimer;

  static const _moods = [
    DikoMood.idle,
    DikoMood.happy,
    DikoMood.curious,
    DikoMood.wink,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // 4~7초 간격으로 mood 변주
    _moodTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _mood = _moods[(_moods.indexOf(_mood) + 1) % _moods.length];
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _moodTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final dy = math.sin(_ctrl.value * math.pi) * 5.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: DikoCharacterView(size: widget.size, mood: _mood),
        );
      },
    );
  }
}

/// 모찌 ↔ 디코 가 번갈아 띄우는 말풍선. 회전 주기 4초, 자연스러운 잡담 톤.
///
/// 진화 단계에 따라 모찌가 더 어른스러운 톤으로 말하도록 [_corpus] 가 단계별로
/// 분기된다.
class _MochiDikoChat extends StatefulWidget {
  const _MochiDikoChat({required this.stage});
  final CharacterStage stage;

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

  @override
  void initState() {
    super.initState();
    _firstShowTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _index = 0);
    });
    _ticker = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _index == null) return;
      setState(() {
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
  static List<_ChatLine> _corpus(CharacterStage stage) {
    final isYoung =
        stage == CharacterStage.egg || stage == CharacterStage.sprout;
    if (isYoung) {
      // 디코는 Lv.10 이상에서만 등장하므로 보통은 안 쓰이지만, race 안전용으로 둔다.
      return const [
        _ChatLine.mochi('만나서 반가워!'),
        _ChatLine.diko('나도 잘 부탁해 ✨'),
      ];
    }
    return const [
      _ChatLine.mochi('디코, 오늘도 같이 있어줘서 고마워.'),
      _ChatLine.diko('당연하지! 우리 한 팀이잖아 ☺'),
      _ChatLine.mochi('퀴즈 하나 풀어볼까?'),
      _ChatLine.diko('좋아! 내가 응원할게 ✨'),
      _ChatLine.mochi('오늘은 사진 퀴즈도 풀 수 있대.'),
      _ChatLine.diko('우와, 재밌겠다!'),
      _ChatLine.mochi('같이 산책 갈래?'),
      _ChatLine.diko('따라갈게! 후후~'),
      _ChatLine.diko('모찌, 잘하고 있어 :)'),
      _ChatLine.mochi('히히, 디코 덕분이야.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lines = _corpus(widget.stage);
    // 첫 라인 지연 중에는 빈 영역(같은 슬롯 유지) 으로 두고, 1200ms 후 첫 라인이 fade-in.
    // 인덱스가 corpus 길이를 넘는 비정상 케이스(이론상 없음)도 안전하게 모듈로.
    final idx = _index;
    final line = idx == null ? null : lines[idx % lines.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: line == null
          ? const SizedBox.shrink(key: ValueKey('chat-empty'))
          : _ChatBubble(
              key: ValueKey('chat-$idx'),
              line: line,
            ),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({super.key, required this.line});
  final _ChatLine line;

  @override
  Widget build(BuildContext context) {
    final isMochi = line.speaker == _Speaker.mochi;
    final bg = isMochi ? Colors.white : const Color(0xFFF3EBFF);
    final border = isMochi
        ? AppColors.primary.withValues(alpha: 0.22)
        : const Color(0xFFA78BFA).withValues(alpha: 0.35);
    final speakerLabel = isMochi ? '모찌' : '디코';
    final speakerColor =
        isMochi ? AppColors.primary : const Color(0xFFA78BFA);
    return Align(
      alignment: isMochi ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                speakerLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.4,
                  color: speakerColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                line.text,
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
            ],
          ),
        ),
      ),
    );
  }
}
