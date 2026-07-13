import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/colors.dart';

/// 2인 탭 배틀 — 한 폰을 마주 보고 잡고, 10초 동안 자기 영역을 더 많이
/// 탭한 사람이 승리. 가운데 줄다리기 바가 실시간 우세를 보여준다.
class TapBattleScreen extends StatefulWidget {
  const TapBattleScreen({super.key});

  @override
  State<TapBattleScreen> createState() => _TapBattleScreenState();
}

enum _Phase { ready, countdown, playing, done }

class _TapBattleScreenState extends State<TapBattleScreen> {
  static const int _durationSec = 10;

  _Phase _phase = _Phase.ready;
  int _countdown = 3;
  int _remaining = _durationSec;
  int _taps1 = 0;
  int _taps2 = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.countdown;
      _countdown = 3;
      _remaining = _durationSec;
      _taps1 = 0;
      _taps2 = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_phase == _Phase.countdown) {
          _countdown--;
          if (_countdown <= 0) {
            HapticFeedback.mediumImpact();
            _phase = _Phase.playing;
          }
        } else if (_phase == _Phase.playing) {
          _remaining--;
          if (_remaining <= 0) {
            HapticFeedback.heavyImpact();
            _phase = _Phase.done;
            t.cancel();
          }
        }
      });
    });
  }

  void _tap(int player) {
    if (_phase != _Phase.playing) return;
    setState(() {
      if (player == 1) {
        _taps1++;
      } else {
        _taps2++;
      }
    });
  }

  /// 줄다리기 바에서 플레이어1(위) 이 차지하는 비율 0.0~1.0.
  double get _ratio1 {
    final total = _taps1 + _taps2;
    if (total == 0) return 0.5;
    return _taps1 / total;
  }

  String _centerLabel() {
    return switch (_phase) {
      _Phase.ready => '준비되면 시작!',
      _Phase.countdown => '$_countdown',
      _Phase.playing => '$_remaining초',
      _Phase.done => _taps1 == _taps2
          ? '무승부! 🤝'
          : (_taps1 > _taps2 ? '🏆 플레이어 1 승리!' : '🏆 플레이어 2 승리!'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: _TapZone(
                      label: '플레이어 1',
                      taps: _taps1,
                      accent: AppColors.primary,
                      active: _phase == _Phase.playing,
                      onTap: () => _tap(1),
                    ),
                  ),
                ),
                // 줄다리기 바 — 탭 비율만큼 각 진영 색이 밀고 당긴다.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (_ratio1 * 1000).round().clamp(1, 999),
                            child: Container(color: AppColors.primary),
                          ),
                          Expanded(
                            flex: ((1 - _ratio1) * 1000).round().clamp(1, 999),
                            child: Container(color: const Color(0xFF45B7D1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 92), // 센터 밴드 자리
                Expanded(
                  child: _TapZone(
                    label: '플레이어 2',
                    taps: _taps2,
                    accent: const Color(0xFF45B7D1),
                    active: _phase == _Phase.playing,
                    onTap: () => _tap(2),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.gray100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close,
                          size: 20, color: AppColors.gray500),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _centerLabel(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (_phase == _Phase.ready || _phase == _Phase.done)
                      GestureDetector(
                        onTap: _start,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _phase == _Phase.ready ? '시작' : '다시하기',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.label,
    required this.taps,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int taps;
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTap(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.14)
              : accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: accent.withValues(alpha: active ? 0.5 : 0.15),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
                color: accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$taps',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 56,
                color: accent,
              ),
            ),
            Text(
              active ? '미친 듯이 탭!!' : '탭 수',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
