import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 대공지(전광판) 배너 — 게임 전광판처럼 한 줄 공지가 우→좌로 흐른다.
/// 메시지가 폭보다 짧으면 흐르지 않고 가운데 정렬로 보여준다.
class NoticeBanner extends StatefulWidget {
  const NoticeBanner({super.key, required this.message});

  final String message;

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  static const _textStyle = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 13,
    color: Color(0xFFFFE08A), // LED 앰버
    height: 1.0,
  );

  // 스크롤 속도(px/초). 메시지 길이에 무관하게 일정 속도 유지.
  static const double _speed = 70;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF24222A),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.campaign_rounded, size: 18, color: Color(0xFFFFC24D)),
          const SizedBox(width: 8),
          Expanded(child: _buildMarquee()),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildMarquee() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final tp = TextPainter(
          text: TextSpan(text: widget.message, style: _textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final textW = tp.width;

        // 폭 안에 다 들어오면 스크롤하지 않는다.
        if (textW <= maxW) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.message, style: _textStyle, maxLines: 1),
          );
        }

        // 길이에 맞춰 일정 속도가 되도록 주기 조정.
        final total = maxW + textW;
        final ms = (total / _speed * 1000).round();
        if (_ctrl.duration?.inMilliseconds != ms) {
          _ctrl.duration = Duration(milliseconds: ms);
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final dx = maxW - _ctrl.value * total;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Text(
                  widget.message,
                  style: _textStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
