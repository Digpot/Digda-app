import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/colors.dart';

/// 2인 반응속도 대결 — 한 폰을 마주 보고 잡고, 초록불이 켜지는 순간 자기
/// 영역을 먼저 탭한 사람이 라운드 승리. 3라운드 먼저 이기면 최종 승리.
/// 초록불 전에 탭하면(부정출발) 상대가 라운드를 가져간다.
class ReactionDuelScreen extends StatefulWidget {
  const ReactionDuelScreen({super.key});

  @override
  State<ReactionDuelScreen> createState() => _ReactionDuelScreenState();
}

enum _Phase { ready, waiting, go, roundEnd, matchEnd }

class _ReactionDuelScreenState extends State<ReactionDuelScreen> {
  static const int _winsNeeded = 3;

  final _rng = math.Random();
  _Phase _phase = _Phase.ready;
  Timer? _goTimer;
  DateTime? _goAt;

  int _score1 = 0; // 위쪽(상대편을 향해 회전된) 플레이어
  int _score2 = 0; // 아래쪽 플레이어
  int _round = 1;

  /// 직전 라운드 결과 안내 문구 (플레이어별).
  String _msg1 = '';
  String _msg2 = '';

  @override
  void dispose() {
    _goTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    _goTimer?.cancel();
    setState(() {
      _phase = _Phase.waiting;
      _msg1 = '';
      _msg2 = '';
    });
    // 1.2~3.6초 사이 랜덤 대기 후 초록불.
    final delayMs = 1200 + _rng.nextInt(2400);
    _goTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _phase = _Phase.go;
        _goAt = DateTime.now();
      });
    });
  }

  void _tap(int player) {
    switch (_phase) {
      case _Phase.waiting:
        // 부정출발 — 상대가 라운드를 가져간다.
        _goTimer?.cancel();
        _finishRound(
          winner: player == 1 ? 2 : 1,
          winnerMsg: '상대가 너무 급했어요! 😎',
          loserMsg: '앗, 부정출발! 🙈',
        );
      case _Phase.go:
        final ms = DateTime.now().difference(_goAt!).inMilliseconds;
        _finishRound(
          winner: player,
          winnerMsg: '승리! ⚡ ${ms}ms',
          loserMsg: '아깝다! 다음 판에!',
        );
      case _Phase.ready:
      case _Phase.roundEnd:
      case _Phase.matchEnd:
        break;
    }
  }

  void _finishRound({
    required int winner,
    required String winnerMsg,
    required String loserMsg,
  }) {
    HapticFeedback.lightImpact();
    setState(() {
      if (winner == 1) {
        _score1++;
        _msg1 = winnerMsg;
        _msg2 = loserMsg;
      } else {
        _score2++;
        _msg2 = winnerMsg;
        _msg1 = loserMsg;
      }
      final matchOver = _score1 >= _winsNeeded || _score2 >= _winsNeeded;
      _phase = matchOver ? _Phase.matchEnd : _Phase.roundEnd;
      if (!matchOver) _round++;
    });
  }

  void _restart() {
    _goTimer?.cancel();
    setState(() {
      _score1 = 0;
      _score2 = 0;
      _round = 1;
      _msg1 = '';
      _msg2 = '';
      _phase = _Phase.ready;
    });
  }

  Color _zoneColor(int player) {
    return switch (_phase) {
      _Phase.go => const Color(0xFF34D399),
      _Phase.waiting => const Color(0xFFFF8A80),
      _ => player == 1 ? const Color(0xFFFFF1F1) : const Color(0xFFF0F7FF),
    };
  }

  String _zoneText(int player) {
    final msg = player == 1 ? _msg1 : _msg2;
    return switch (_phase) {
      _Phase.ready => '준비되면 가운데 시작을 눌러요',
      _Phase.waiting => '초록불이 켜지면 탭! 🚦',
      _Phase.go => '지금이야! 탭!!',
      _Phase.roundEnd || _Phase.matchEnd => msg,
    };
  }

  @override
  Widget build(BuildContext context) {
    final winner = _score1 >= _winsNeeded ? 1 : (_score2 >= _winsNeeded ? 2 : 0);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 위쪽 플레이어 — 마주 본 상대가 읽을 수 있게 180도 회전.
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: _PlayerZone(
                      label: '플레이어 1',
                      color: _zoneColor(1),
                      text: _zoneText(1),
                      score: _score1,
                      winsNeeded: _winsNeeded,
                      accent: AppColors.primary,
                      onTap: () => _tap(1),
                    ),
                  ),
                ),
                const SizedBox(height: 92), // 센터 밴드 자리
                Expanded(
                  child: _PlayerZone(
                    label: '플레이어 2',
                    color: _zoneColor(2),
                    text: _zoneText(2),
                    score: _score2,
                    winsNeeded: _winsNeeded,
                    accent: const Color(0xFF45B7D1),
                    onTap: () => _tap(2),
                  ),
                ),
              ],
            ),
            // 센터 밴드 — 라운드/시작/나가기. 게임 영역과 겹치지 않게 중앙 고정.
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
                      _phase == _Phase.matchEnd
                          ? (winner == 1 ? '🏆 플레이어 1 승리!' : '🏆 플레이어 2 승리!')
                          : '라운드 $_round · $_score1 : $_score2',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (_phase == _Phase.ready || _phase == _Phase.roundEnd)
                      _CenterAction(label: '시작', onTap: _startRound)
                    else if (_phase == _Phase.matchEnd)
                      _CenterAction(label: '다시하기', onTap: _restart),
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

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PlayerZone extends StatelessWidget {
  const _PlayerZone({
    required this.label,
    required this.color,
    required this.text,
    required this.score,
    required this.winsNeeded,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color color;
  final String text;
  final int score;
  final int winsNeeded;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTap(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
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
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                height: 1.35,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 14),
            // 라운드 승수 — 별로 표시.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < winsNeeded; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      i < score ? '⭐' : '☆',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
