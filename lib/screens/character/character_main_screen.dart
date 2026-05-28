import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/character/models/character_models.dart';
import '../../features/character/widgets/animated_mochi_widget.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/notification_bell_icon.dart';
import 'character_stage_tree_screen.dart';
import 'character_color_shop_screen.dart';
import 'character_dex_screen.dart';
import 'character_intro_screen.dart';
import 'quiz/character_quiz_play_screen.dart';
import 'quiz/character_quiz_list_screen.dart';

/// 모찌 키우기 탭의 메인 화면.
/// - 캐릭터 시각화 + 레벨/EXP 진행도 + 코인
/// - 진화 트리·색상 상점 진입
/// - 첫 진입은 서버가 캐릭터를 lazy 생성
class CharacterMainScreen extends StatefulWidget {
  const CharacterMainScreen({super.key});

  @override
  State<CharacterMainScreen> createState() => _CharacterMainScreenState();
}

class _CharacterMainScreenState extends State<CharacterMainScreen> {
  CharacterState? _state;
  bool _loading = true;
  String? _errorMessage;
  bool _hasLoadedOnce = false;
  final _mochiCtrl = MochiAnimationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  Future<void> _maybeShowIntro() async {
    final seen = await CharacterIntroScreen.isAlreadySeen();
    if (!mounted) return;
    if (!seen) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const CharacterIntroScreen(),
          fullscreenDialog: true,
        ),
      );
    }
    if (!mounted) return;
    _load();
  }

  // silent: 이미 데이터가 있는 경우 스피너 없이 백그라운드 갱신
  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent || _state == null) _loading = true;
      _errorMessage = null;
    });
    try {
      final state = await Di.characterRepository.getMyState();
      if (!mounted) return;
      final isFirst = !_hasLoadedOnce;
      setState(() {
        _state = state;
        _loading = false;
        _hasLoadedOnce = true;
      });
      if (isFirst) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _mochiCtrl.triggerHappy();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = errorMessageOf(e);
      });
    }
  }

  void _openInfoSheet() {
    if (_state == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CharacterInfoSheet(state: _state!),
    );
  }

  Future<void> _openStageTree() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterStageTreeScreen()),
    );
    // 트리 화면 진입 중 레벨업이 일어나지 않더라도, 돌아왔을 때 최신 상태로 새로고침
    // (탭 전환 패턴과 일관)
    _load();
  }

  Future<void> _openShop() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CharacterColorShopScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _openDex() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterDexScreen()),
    );
    _load();
  }

  Future<void> _openQuizPlay() async {
    final prevLevel = _state?.level;
    final prevStage = _state?.stage;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterQuizPlayScreen()),
    );
    await _load(silent: true);
    if (!mounted || _state == null) return;
    if (_state!.stage != prevStage) {
      _mochiCtrl.triggerProud();
    } else if (prevLevel != null && _state!.level > prevLevel) {
      _mochiCtrl.triggerHappy();
    }
  }

  Future<void> _openQuizList() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CharacterQuizListScreen()),
    );
  }

  void _handlePet() {
    Di.characterRepository
        .addExp(amount: 5, source: 'pet')
        .then((result) {
          if (!mounted) return;
          setState(() => _state = result.character);
          if (result.stageChanged) {
            _mochiCtrl.triggerProud();
            showAppSnackBar(context, '진화! ${result.character.stageDisplayName} 달성 🌟');
          } else if (result.levelGained > 0) {
            _mochiCtrl.triggerHappy();
            showAppSnackBar(context, '레벨업! Lv. ${result.character.level} 달성!');
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            const Text(
              '캐릭터',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.gray900,
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openInfoSheet,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.info_outline,
                    size: 24, color: AppColors.gray700),
              ),
            ),
            const SizedBox(width: 12),
            const NotificationBellIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorRetry(message: _errorMessage!, onRetry: _load);
    }
    final s = _state!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const SizedBox(height: 12),
          Center(
            child: AnimatedMochiWidget(
              color: s.color,
              colorHex: s.colorHex,
              stage: s.stage,
              size: 220,
              happiness: s.progress,
              controller: _mochiCtrl,
              onPet: _handlePet,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '탭하거나 꾹 눌러서 쓰다듬어 봐요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 20),
          _LevelStageRow(state: s),
          const SizedBox(height: 12),
          _ExpProgress(state: s),
          const SizedBox(height: 28),
          _CoinChip(coin: s.coin),
          const SizedBox(height: 24),
          // 핵심 CTA — 퀴즈 풀어서 EXP/코인 얻기
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _openQuizPlay,
              icon: const Icon(Icons.psychology_outlined, size: 22),
              label: const Text(
                '퀴즈 풀기',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 부가 기능 — 2x2 그리드
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: [
              _MiniTile(
                icon: Icons.edit_note,
                label: '퀴즈 목록',
                onTap: _openQuizList,
              ),
              _MiniTile(
                icon: Icons.trending_up,
                label: '진화 트리',
                onTap: _openStageTree,
              ),
              _MiniTile(
                icon: Icons.collections_bookmark_outlined,
                label: '도감',
                onTap: _openDex,
              ),
              _MiniTile(
                icon: Icons.palette_outlined,
                label: '색상 상점',
                onTap: _openShop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.gray900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelStageRow extends StatelessWidget {
  const _LevelStageRow({required this.state});
  final CharacterState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Lv. ${state.level}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          state.stageDisplayName,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.gray900,
          ),
        ),
      ],
    );
  }
}

class _ExpProgress extends StatelessWidget {
  const _ExpProgress({required this.state});
  final CharacterState state;

  @override
  Widget build(BuildContext context) {
    final atMax = state.maxLevelReached;
    final label = atMax
        ? '최고 레벨 달성!'
        : 'EXP ${state.exp} / ${state.expForNextLevel}';
    return Column(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: state.progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.gray700,
          ),
        ),
      ],
    );
  }
}

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coin});
  final int coin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFCD34D), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFFCD34D),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'C',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$coin 코인',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.gray900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.gray400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterInfoSheet extends StatelessWidget {
  const _CharacterInfoSheet({required this.state});
  final CharacterState state;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bottomSheetBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '모찌 키우기란?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '디그팟 안에서 함께 키우는 작은 마스코트, 모찌예요.\n'
              '경험치를 모아 레벨업하면 진화 단계가 바뀌고,\n'
              '코인을 모아 색상 상점에서 새 색을 해금할 수 있어요.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.6,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 20),
            const _InfoRow(
              icon: Icons.bolt_outlined,
              title: '경험치',
              body: '활동에 참여하면 EXP가 쌓이고, 임계치에 닿으면 자동으로 레벨업해요.',
            ),
            const _InfoRow(
              icon: Icons.auto_awesome,
              title: '진화',
              body: '레벨이 3·6·10·15에 도달할 때마다 모찌가 새로운 모습으로 자라요.',
            ),
            const _InfoRow(
              icon: Icons.palette_outlined,
              title: '색상',
              body: '상점에서 코인을 사용해 색을 해금하고 언제든 바꿔 적용할 수 있어요.',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    height: 1.55,
                    color: AppColors.gray700,
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
