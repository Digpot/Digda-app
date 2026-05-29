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
    // 하단 외곽에 약간 겹쳐 배치한다. 가로 폭은 모찌 size + 디코 size*0.5 만큼 잡는다.
    final containerWidth = mochiSize + (state.dikoUnlocked ? dikoSize * 0.45 : 0);
    return SizedBox(
      width: containerWidth,
      height: mochiSize + 56 + (showChat ? 0 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
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
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 첫 라인은 약간 지연 후 표시 — 진입 시 모찌가 먼저 보이게.
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _index = 0);
    });
    _ticker = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _corpus(widget.stage).length;
      });
    });
  }

  @override
  void didUpdateWidget(_MochiDikoChat old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      // 단계가 변하면 인덱스 초기화 — 다른 톤의 라인으로 즉시 갈아치움.
      setState(() => _index = 0);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
    final line = lines[_index];
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
      child: _ChatBubble(
        key: ValueKey(_index),
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
