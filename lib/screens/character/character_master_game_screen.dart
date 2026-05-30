import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/mochi_character_view.dart';
import '../../theme/colors.dart';

/// 마스터 챔피언 챌린지 — 모찌가 3×3 그리드의 무작위 셀에 잠시 튀어나오는 동안
/// 빠르게 두드리는 30초 미니게임.
///
/// - 진짜 모찌(그룹 외형) 탭: +1점
/// - 가짜 모찌(회색·시무룩 표정) 탭: -1점 (점수 0 미만 X)
/// - 빈 셀은 인터랙션 없음
///
/// 끝나면 서버에 점수 제출 → 등급(도전/우수/훌륭/전설) + 코인 보상.
/// Navigator.pop(reward) 로 호출자에게 결과 전달.
/// 마스터 게임의 결과 — 점수 보상 + 입장료 차감 후 잔액 등 호출자에 돌려준다.
class MasterGameSessionResult {
  const MasterGameSessionResult({this.reward, this.latestCharacter});

  /// 보상 데이터 (한 번이라도 끝까지 도전한 적이 있으면 마지막 도전 결과).
  final MasterGameReward? reward;

  /// 입장료 차감만 일어났을 때 등, 보상은 없지만 잔액이 갱신된 캐릭터 상태.
  final CharacterState? latestCharacter;
}

class CharacterMasterGameScreen extends StatefulWidget {
  const CharacterMasterGameScreen({
    super.key,
    required this.appearance,
    required this.stage,
    required this.initialCoin,
  });

  final MochiAppearance appearance;
  final CharacterStage stage;
  final int initialCoin;

  static const int entryFee = 20;

  static Future<MasterGameSessionResult?> open(
    BuildContext context, {
    required MochiAppearance appearance,
    required CharacterStage stage,
    required int initialCoin,
  }) {
    return Navigator.of(context).push<MasterGameSessionResult>(
      MaterialPageRoute(
        builder: (_) => CharacterMasterGameScreen(
          appearance: appearance,
          stage: stage,
          initialCoin: initialCoin,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<CharacterMasterGameScreen> createState() =>
      _CharacterMasterGameScreenState();
}

enum _GamePhase { intro, countdown, playing, ended }

class _CharacterMasterGameScreenState extends State<CharacterMasterGameScreen> {
  static const int _gameDuration = 30; // seconds
  static const int _gridSize = 9;
  static const Duration _spawnInterval = Duration(milliseconds: 850);
  static const Duration _mochiVisible = Duration(milliseconds: 1000);
  static const double _fakeChance = 0.22;

  _GamePhase _phase = _GamePhase.intro;
  int _score = 0;
  int _remaining = _gameDuration;
  int _countdown = 3;
  int? _activeCell;
  bool _isFakeActive = false;
  int _lastCell = -1;

  Timer? _spawnTimer;
  Timer? _tickTimer;
  Timer? _despawnTimer;
  Timer? _countdownTimer;

  bool _claiming = false;
  bool _starting = false;
  MasterGameReward? _reward;
  CharacterState? _latestCharacter;
  late int _currentCoin = widget.initialCoin;
  String? _error;
  String? _startError;

  final _rng = math.Random();

  static const MochiAppearance _fakeAppearance = MochiAppearance(
    skinHex: '#B5B8BD',
    skinAssetKey: 'skin/coral',
    overlays: [],
  );

  int? get _activeGroupId {
    final raw = Di.activeGroup.groupRoomId;
    return raw == null ? null : int.tryParse(raw);
  }

  /// 마스터 진화 전(레벨 20·GLOW)에 응시하면 이 게임이 "진화 시험" 으로 동작한다.
  bool get _isEvolutionExam => widget.stage != CharacterStage.master;

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    _despawnTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ─── 게임 흐름 ────────────────────────────────────────────

  Future<void> _startCountdown() async {
    if (_starting) return;
    if (_currentCoin < CharacterMasterGameScreen.entryFee) {
      setState(() => _startError = '코인이 부족해요. 퀴즈로 모아주세요.');
      return;
    }
    setState(() {
      _starting = true;
      _startError = null;
    });

    final groupId = _activeGroupId;
    if (groupId == null) {
      setState(() {
        _starting = false;
        _startError = '그룹에 들어간 뒤 다시 시도해주세요.';
      });
      return;
    }

    try {
      final updated = await Di.characterRepository.startMasterGame(
        groupRoomId: groupId,
      );
      if (!mounted) return;
      setState(() {
        _currentCoin = updated.coin;
        _latestCharacter = updated;
        _starting = false;
        _phase = _GamePhase.countdown;
        _countdown = 3;
        _score = 0;
        _activeCell = null;
        _reward = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = errorMessageOf(e);
      });
      return;
    }

    HapticFeedback.lightImpact();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_countdown <= 1) {
        _countdownTimer?.cancel();
        _beginPlay();
      } else {
        setState(() => _countdown -= 1);
        HapticFeedback.selectionClick();
      }
    });
  }

  void _beginPlay() {
    setState(() {
      _phase = _GamePhase.playing;
      _remaining = _gameDuration;
    });
    HapticFeedback.mediumImpact();
    _spawnMochi();
    _spawnTimer = Timer.periodic(_spawnInterval, (_) => _spawnMochi());
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        setState(() => _remaining = 0);
        _endGame();
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  void _spawnMochi() {
    if (_phase != _GamePhase.playing || !mounted) return;
    int cell;
    do {
      cell = _rng.nextInt(_gridSize);
    } while (cell == _lastCell);
    _lastCell = cell;
    final isFake = _rng.nextDouble() < _fakeChance;
    setState(() {
      _activeCell = cell;
      _isFakeActive = isFake;
    });
    _despawnTimer?.cancel();
    _despawnTimer = Timer(_mochiVisible, () {
      if (!mounted) return;
      if (_activeCell == cell) {
        setState(() => _activeCell = null);
      }
    });
  }

  void _onTapCell(int cell) {
    if (_phase != _GamePhase.playing) return;
    if (_activeCell != cell) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_isFakeActive) {
        _score = math.max(0, _score - 1);
      } else {
        _score += 1;
      }
      _activeCell = null;
    });
    _despawnTimer?.cancel();
  }

  Future<void> _endGame() async {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    _despawnTimer?.cancel();
    setState(() {
      _phase = _GamePhase.ended;
      _activeCell = null;
      _claiming = true;
    });

    final groupId = _activeGroupId;
    if (groupId == null) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _error = '그룹에 들어간 뒤 다시 시도해주세요.';
      });
      return;
    }
    try {
      final reward = await Di.characterRepository.claimMasterGameReward(
        groupRoomId: groupId,
        score: _score,
      );
      if (!mounted) return;
      setState(() {
        _reward = reward;
        _latestCharacter = reward.character;
        _currentCoin = reward.character.coin;
        _claiming = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _error = errorMessageOf(e);
      });
    }
  }

  void _retryClaim() {
    setState(() {
      _claiming = true;
      _error = null;
    });
    _endGame();
  }

  void _retryGame() {
    // intro 단계로 돌아가 잔액 확인 + 입장료 재차감을 거치도록 한다.
    setState(() {
      _phase = _GamePhase.intro;
      _reward = null;
      _error = null;
      _score = 0;
      _starting = false;
      _startError = null;
    });
  }

  // ─── UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF4F1),
              Color(0xFFFDFAF6),
              Color(0xFFFEF1F7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: switch (_phase) {
                  _GamePhase.intro => _buildIntro(),
                  _GamePhase.countdown => _buildCountdown(),
                  _GamePhase.playing => _buildPlaying(),
                  _GamePhase.ended => _buildEnded(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  MasterGameSessionResult get _sessionResult => MasterGameSessionResult(
        reward: _reward,
        latestCharacter: _latestCharacter,
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.gray900),
            onPressed: () => Navigator.of(context).pop(_sessionResult),
          ),
          Expanded(
            child: Center(
              child: Text(
                _isEvolutionExam ? '마스터 진화 시험' : '마스터 챔피언 챌린지',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.gray900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    final canAfford = _currentCoin >= CharacterMasterGameScreen.entryFee;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        children: [
          Text(_isEvolutionExam ? '✨' : '🏆',
              style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 10),
          Text(
            _isEvolutionExam ? '마스터 진화 시험' : '챔피언 챌린지',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isEvolutionExam
                ? '30초 동안 3×3 칸에서 튀어나오는\n모찌를 빠르게 두드려요.\n"훌륭"(11점) 이상이면 마스터로 진화해요!'
                : '30초 동안 3×3 칸에서 튀어나오는\n모찌를 빠르게 두드려요.\n회색 가짜 모찌는 두드리면 -1점!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.55,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: 22),
          _CoinStatusCard(
            balance: _currentCoin,
            entryFee: CharacterMasterGameScreen.entryFee,
          ),
          const SizedBox(height: 18),
          const _RewardTable(),
          if (_startError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF6B6B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _startError!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFFA23838),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed:
                  (_starting || !canAfford) ? null : _startCountdown,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.gray300,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _starting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      canAfford
                          ? '도전 시작! (-${CharacterMasterGameScreen.entryFee} 코인)'
                          : '코인 부족',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('countdown-$_countdown'),
        tween: Tween(begin: 0.6, end: 1.4),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale.clamp(0.6, 1.4), child: child),
        child: Text(
          '$_countdown',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 110,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaying() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(child: _MetricCard(label: '남은 시간', value: '${_remaining}s', accent: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(label: '점수', value: '$_score', accent: const Color(0xFFFFB347))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, c) {
                final cellSize = ((c.maxWidth - 24) / 3).clamp(70.0, 140.0);
                return Center(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: _gridSize,
                    itemBuilder: (_, i) => _buildCell(i, cellSize),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(int index, double size) {
    final active = _activeCell == index;
    return GestureDetector(
      onTap: active ? () => _onTapCell(index) : null,
      child: Container(
        decoration: BoxDecoration(
          color: active ? Colors.white : AppColors.gray100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: active
            ? AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: MochiCharacterView(
                  key: ValueKey('mochi-$index-$_isFakeActive'),
                  appearance: _isFakeActive ? _fakeAppearance : widget.appearance,
                  stage: widget.stage,
                  size: size * 0.78,
                  expression: _isFakeActive
                      ? MochiEmotion.sleepy
                      : MochiEmotion.happy,
                ),
              )
            : Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
      ),
    );
  }

  Widget _buildEnded() {
    if (_claiming) {
      return const Center(child: CircularProgressIndicator());
    }
    final reward = _reward;
    if (reward == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.gray400),
            const SizedBox(height: 10),
            Text(
              _error ?? '보상을 받지 못했어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TierBadge(tier: reward.tier),
          const SizedBox(height: 18),
          Text(
            '${reward.score}점',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 60,
              color: AppColors.gray900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '오늘의 챔피언 기록',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Text(
                  '+${reward.coinReward} 코인',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.gray900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '잔액: ${reward.character.coin} 코인',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(_sessionResult),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gray700,
                    side: const BorderSide(color: AppColors.gray200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '나가기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _retryGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '한 번 더!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinStatusCard extends StatelessWidget {
  const _CoinStatusCard({required this.balance, required this.entryFee});

  final int balance;
  final int entryFee;

  @override
  Widget build(BuildContext context) {
    final canAfford = balance >= entryFee;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: canAfford
            ? const Color(0xFFFFF7E2)
            : const Color(0xFFFFEDED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canAfford
              ? const Color(0xFFFCD34D)
              : const Color(0xFFFFB1B1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: canAfford
                  ? const Color(0xFFFCD34D)
                  : const Color(0xFFFF8A8A),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'C',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 잔액: $balance 코인',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canAfford
                      ? '입장료: $entryFee 코인'
                      : '입장료 $entryFee 코인이 부족해요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: canAfford
                        ? AppColors.gray700
                        : const Color(0xFFA23838),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTable extends StatelessWidget {
  const _RewardTable();

  static const _rows = [
    ('전설', '16점 이상', '+200 코인', Color(0xFFFFD700)),
    ('훌륭', '11–15점', '+100 코인', Color(0xFFB45CF6)),
    ('우수', '6–10점', '+50 코인', Color(0xFF34D399)),
    ('도전', '1–5점', '+20 코인', Color(0xFF7CB1F5)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0)
              const Divider(
                color: AppColors.gray100,
                height: 12,
                thickness: 1,
              ),
            Row(
              children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: _rows[i].$4.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _rows[i].$1,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: _rows[i].$4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _rows[i].$2,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: AppColors.gray700,
                    ),
                  ),
                ),
                Text(
                  _rows[i].$3,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.gray900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final (icon, colors) = switch (tier) {
      '전설' => ('👑', [const Color(0xFFFFD700), const Color(0xFFFFB347)]),
      '훌륭' => ('🌟', [const Color(0xFFB45CF6), const Color(0xFF7C3AED)]),
      '우수' => ('✨', [const Color(0xFF34D399), const Color(0xFF059669)]),
      '도전' => ('🎯', [const Color(0xFF7CB1F5), const Color(0xFF2C5BA6)]),
      _ => ('🤝', [AppColors.gray400, AppColors.gray500]),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            tier,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
