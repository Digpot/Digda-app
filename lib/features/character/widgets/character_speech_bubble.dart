import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

/// 말풍선 꼬리 방향 — 꼬리는 항상 말하는 캐릭터(머리) 쪽을 가리킨다.
enum BubbleTailDirection { bottomLeft, bottomCenter, bottomRight }

/// 모찌·디코 공용 말풍선.
///
/// 기존에는 화면마다 각자 말풍선을 그렸고 꼬리도 왼쪽 고정이라, 말풍선이
/// 캐릭터 어느 쪽에 뜨든 늘 같은 모양이었다. 이 위젯은:
/// - [tail] 로 꼬리 방향을 바꿔 캐릭터 위 어느 자리에 떠도 화자를 가리키고,
/// - [accent] 틴트 그라디언트·그림자로 화자 색을 입히고,
/// - 떠 있는 동안 살짝 둥실거리는 idle 애니메이션으로 생동감을 준다.
class CharacterSpeechBubble extends StatefulWidget {
  const CharacterSpeechBubble({
    super.key,
    required this.text,
    this.speakerLabel,
    this.accent = AppColors.primary,
    this.tail = BubbleTailDirection.bottomCenter,
    this.maxWidth = 168,
  });

  final String text;

  /// 화자 이름 칩(예: '모찌'). null 이면 본문만 노출.
  final String? speakerLabel;

  /// 화자 색 — 테두리·라벨·그림자 틴트에 쓰인다.
  final Color accent;

  final BubbleTailDirection tail;
  final double maxWidth;

  @override
  State<CharacterSpeechBubble> createState() => _CharacterSpeechBubbleState();
}

class _CharacterSpeechBubbleState extends State<CharacterSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    // 떠 있는 동안 ±2.5px 둥실거림 — 말풍선이 박제된 느낌을 없앤다.
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final border = accent.withValues(alpha: 0.28);
    // 그라디언트 하단 색 — 꼬리 채움색도 이 색과 맞춰 이음새가 안 보이게 한다.
    final bottomTint = Color.lerp(Colors.white, accent, 0.07)!;
    final crossAlign = switch (widget.tail) {
      BubbleTailDirection.bottomLeft => CrossAxisAlignment.start,
      BubbleTailDirection.bottomCenter => CrossAxisAlignment.center,
      BubbleTailDirection.bottomRight => CrossAxisAlignment.end,
    };
    return AnimatedBuilder(
      animation: _bob,
      builder: (_, child) {
        final dy = math.sin(_bob.value * math.pi) * 2.5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAlign,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, bottomTint],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.speakerLabel != null) ...[
                    Text(
                      widget.speakerLabel!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.4,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    widget.text,
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
          // 꼬리 — 본체 아래 살짝 안쪽에서 화자 쪽을 가리킨다.
          Padding(
            padding: switch (widget.tail) {
              BubbleTailDirection.bottomLeft =>
                const EdgeInsets.only(left: 18),
              BubbleTailDirection.bottomCenter => EdgeInsets.zero,
              BubbleTailDirection.bottomRight =>
                const EdgeInsets.only(right: 18),
            },
            child: CustomPaint(
              size: const Size(14, 9),
              painter: _BubbleTailPainter(
                borderColor: border,
                fillColor: bottomTint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.borderColor, required this.fillColor});

  final Color borderColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
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
      old.borderColor != borderColor || old.fillColor != fillColor;
}
