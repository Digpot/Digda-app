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
    this.onDikoTap,
    this.mochiSize = 220,
    this.dikoSize = 96,
    this.showChat = true,
  });

  final CharacterState state;
  final MochiAnimationController mochiController;
  final VoidCallback onPet;

  /// 디코를 탭했을 때 부모에 알리는 콜백 (선택). 디코 자체의 반응 애니메이션은
  /// [_DikoIdleFloat] 내부에서 처리되며, 이 콜백은 부가 동작(예: 메시지)용.
  final VoidCallback? onDikoTap;
  final double mochiSize;
  final double dikoSize;
  final bool showChat;

  @override
  Widget build(BuildContext context) {
    // 모찌가 시각적으로 화면 정중앙에 오도록 컨테이너 폭은 mochiSize 그대로 유지.
    // 디코는 모찌 오른쪽 옆에 약간 튀어나오게 (Stack clipBehavior: Clip.none) 배치 —
    // 부모 Center 가 모찌를 중심에 맞추고, 디코가 그 옆에 자연스럽게 따라붙는 모양.
    final containerWidth = mochiSize;
    // 상단 영역(말풍선용) 56px:
    //   - 디코 해금 전: 모찌 자체의 자동 말풍선(showBubble=true)이 위쪽 56px 를 사용.
    //   - 디코 해금 후: 모찌 자동 말풍선은 끄고(showBubble=false) 같은 56px 를
    //     Mochi↔Diko 채팅 밴드가 사용. 두 경우 모두 모찌 본체는 56만큼 내려 그려야
    //     상단 말풍선과 겹치지 않는다.
    const topBand = 56.0;
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
            // 모찌 오른쪽 외곽에 디코가 살짝 튀어나오게. 모찌의 발 높이에 맞춰 정렬.
            Positioned(
              right: -dikoSize * 0.65,
              bottom: 16,
              child: _DikoIdleFloat(size: dikoSize, onTap: onDikoTap),
            ),
          if (state.dikoUnlocked && showChat)
            // 말풍선은 각자 자기 머리 위에서 뜬다 — 모찌 대사는 모찌 위(상단),
            // 디코 대사는 디코 위(우측 하단)에 떠서 누가 말하는지 헷갈리지 않게 한다.
            // 채팅 오버레이는 컨테이너 전체를 덮으므로, 버블이 모찌/디코 본체 위에
            // 겹쳐도 탭(쓰다듬기·디코 반응)이 항상 아래 캐릭터로 전달되도록
            // IgnorePointer 로 감싼다 — 말풍선 자체는 장식이라 입력이 필요 없다.
            Positioned.fill(
              child: IgnorePointer(
                child: _MochiDikoChat(
                  stage: state.stage,
                  mochiSize: mochiSize,
                  dikoSize: dikoSize,
                ),
              ),
            ),
        ],
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
  });
  final CharacterStage stage;
  final double mochiSize;
  final double dikoSize;

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
        // 모찌 말풍선 — 모찌 머리 위(상단 밴드).
        Positioned(
          top: 0,
          left: mochiSize * 0.04,
          child: _slot(
            show: isMochi,
            line: line,
            keyId: 'mochi-$idx',
            maxWidth: mochiSize * 0.78,
          ),
        ),
        // 디코 말풍선 — 디코 머리 위(우측). 디코는 bottom:16, 높이 dikoSize 로 컨테이너
        // 오른쪽에 매달려 있다. 버블을 디코 쪽으로 더 붙이고(우측) 위로 더 띄워(상단)
        // 모찌 본체와 덜 겹치게 한다. 단 버블 오른쪽 끝이 디코 오른쪽 끝(≈ +dikoSize*0.65)
        // 을 넘으면 작은 화면에서 ListView 가 가로로 잘라먹으므로 그 안쪽으로 둔다.
        Positioned(
          right: -dikoSize * 0.62,
          bottom: 16 + dikoSize + 14,
          child: _slot(
            show: isDiko,
            line: line,
            keyId: 'diko-$idx',
            maxWidth: mochiSize * 0.58,
          ),
        ),
      ],
    );
  }

  /// 한쪽 화자의 말풍선 슬롯. 현재 라인이 그 화자의 것이 아니면 빈 위젯으로 접힌다.
  /// 슬롯 위치는 고정이라 말풍선이 항상 같은 자리(머리 위)에서 fade-in/out 된다.
  Widget _slot({
    required bool show,
    required _ChatLine? line,
    required String keyId,
    required double maxWidth,
  }) {
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
      child: (show && line != null)
          ? ConstrainedBox(
              key: ValueKey(keyId),
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _ChatBubble(line: line),
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
    // 폭 제약(maxWidth)은 바깥 슬롯에서 화자별로 잡아준다. 여기선 내용 크기에 맞춘다.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
    );
  }
}
