import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/colors.dart';
import '../../../widgets/center_title_header.dart';

/// 기억력 카드 게임 — 4×4 카드에서 같은 그림 짝을 찾는다.
/// 2~4인 턴제: 짝을 맞추면 1점 + 한 번 더, 틀리면 다음 사람 차례.
/// 모든 짝이 열리면 점수 순위로 마무리.
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  static const _emojiPool = [
    '🍓', '🌸', '⭐', '🍀', '🌙', '🔥', '💎', '🐹',
    '🍩', '🎈', '🌈', '🧀', '🍉', '🐳', '🎵', '🍄',
  ];
  static const _playerColors = [
    AppColors.primary,
    Color(0xFF45B7D1),
    Color(0xFF34D399),
    Color(0xFFA78BFA),
  ];

  final _rng = math.Random();

  /// 0 이면 아직 인원 선택 전(설정 화면).
  int _playerCount = 0;
  late List<String> _cards; // 16장 (8쌍)
  late List<bool> _matched;
  late List<int> _scores;
  int _turn = 0; // 현재 차례 플레이어 index
  int? _firstPick; // 이번 턴에 먼저 뒤집은 카드 index
  int? _secondPick;
  bool _locked = false; // 미스매치 연출 동안 입력 잠금
  Timer? _flipBackTimer;

  bool get _finished => _playerCount > 0 && _matched.every((m) => m);

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    super.dispose();
  }

  void _setup(int players) {
    _flipBackTimer?.cancel();
    final picks = List.of(_emojiPool)..shuffle(_rng);
    final chosen = picks.take(8).toList();
    setState(() {
      _playerCount = players;
      _cards = [...chosen, ...chosen]..shuffle(_rng);
      _matched = List.filled(16, false);
      _scores = List.filled(players, 0);
      _turn = 0;
      _firstPick = null;
      _secondPick = null;
      _locked = false;
    });
  }

  void _flip(int index) {
    if (_locked || _matched[index] || _finished) return;
    if (index == _firstPick) return;
    HapticFeedback.selectionClick();
    if (_firstPick == null) {
      setState(() => _firstPick = index);
      return;
    }
    // 두 번째 카드.
    setState(() => _secondPick = index);
    final a = _firstPick!;
    if (_cards[a] == _cards[index]) {
      // 매치 — 점수 +1, 같은 사람이 한 번 더.
      setState(() {
        _matched[a] = true;
        _matched[index] = true;
        _scores[_turn]++;
        _firstPick = null;
        _secondPick = null;
      });
      if (_finished) HapticFeedback.heavyImpact();
    } else {
      // 미스매치 — 잠깐 보여주고 덮은 뒤 턴 넘김.
      _locked = true;
      _flipBackTimer = Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          _firstPick = null;
          _secondPick = null;
          _turn = (_turn + 1) % _playerCount;
          _locked = false;
        });
      });
    }
  }

  /// 최종 순위 문자열 — 동점은 공동 우승 처리.
  String _resultText() {
    final best = _scores.reduce(math.max);
    final winners = [
      for (var i = 0; i < _playerCount; i++)
        if (_scores[i] == best) 'P${i + 1}',
    ];
    return winners.length == 1
        ? '🏆 ${winners.first} 승리!'
        : '🏆 ${winners.join(' · ')} 공동 우승!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CenterTitleHeader(title: '기억력 카드'),
            Expanded(
              child: _playerCount == 0 ? _buildSetup() : _buildGame(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🃏', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            '몇 명이서 할까요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '같은 그림 짝을 찾으면 1점과 한 번 더!\n틀리면 다음 사람에게 차례가 넘어가요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              height: 1.5,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 28),
          for (final n in [2, 3, 4]) ...[
            GestureDetector(
              onTap: () => _setup(n),
              child: Container(
                height: 52,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _playerColors[n - 2].withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _playerColors[n - 2].withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$n인 플레이',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _playerColors[n - 2],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGame() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        children: [
          // 점수판 — 현재 차례 플레이어를 강조.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _playerCount; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: i == _turn && !_finished
                          ? _playerColors[i]
                          : _playerColors[i].withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'P${i + 1} · ${_scores[i]}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: i == _turn && !_finished
                            ? Colors.white
                            : _playerColors[i],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _finished ? _resultText() : 'P${_turn + 1} 차례예요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _finished ? AppColors.gray900 : _playerColors[_turn],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 16,
              itemBuilder: (_, i) {
                final revealed =
                    _matched[i] || i == _firstPick || i == _secondPick;
                return GestureDetector(
                  onTap: () => _flip(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: _matched[i]
                          ? const Color(0xFFE9FBF3)
                          : revealed
                              ? AppColors.white
                              : AppColors.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _matched[i]
                            ? const Color(0xFF34D399)
                            : revealed
                                ? AppColors.gray200
                                : AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      revealed ? _cards[i] : '?',
                      style: TextStyle(
                        fontSize: revealed ? 30 : 20,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_finished) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => setState(() => _playerCount = 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '다시하기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
