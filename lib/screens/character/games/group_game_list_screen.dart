import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../features/minigame/models/minigame_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/center_title_header.dart';
import 'catchmind_game_screen.dart';
import 'catchmind_invite_screen.dart';
import 'word_chain_invite_screen.dart';
import 'word_chain_game_screen.dart';
import 'omok_game_screen.dart';
import 'omok_invite_screen.dart';
import 'tap_battle_invite_screen.dart';
import 'tap_battle_screen.dart';

/// 그룹원들과 즐기는 미니게임 목록.
///
/// 진입 시 서버에서 "내가 초대받은 게임 / 참여 중인 게임"을 받아 상단에 띄운다 —
/// 알림을 놓쳐도 여기서 초대를 수락하고, 나갔던 게임에 재입장할 수 있다.
class GroupGameListScreen extends StatefulWidget {
  const GroupGameListScreen({super.key});

  @override
  State<GroupGameListScreen> createState() => _GroupGameListScreenState();
}

class _GroupGameListScreenState extends State<GroupGameListScreen> {
  GameInvitesSummary? _summary;
  bool _loadingInvites = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvites());
  }

  Future<void> _loadInvites() async {
    final groupIdRaw = Di.activeGroup.groupRoomId;
    final groupId = groupIdRaw == null ? null : int.tryParse(groupIdRaw);
    if (groupId == null) return;
    setState(() => _loadingInvites = true);
    try {
      final summary =
          await Di.minigameRepository.invites(groupRoomId: groupId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loadingInvites = false;
      });
    } catch (_) {
      // 초대 목록 실패는 게임 목록 표시에 영향 없음 — 새로고침으로 복구 가능.
      if (mounted) setState(() => _loadingInvites = false);
    }
  }

  Future<void> _openGame(GameInviteItem item) async {
    final screen = switch (item.gameType) {
      'OMOK' => OmokGameScreen(gameId: item.gameId),
      'CATCHMIND' => CatchmindGameScreen(gameId: item.gameId),
      'TAP_BATTLE' => TapBattleScreen(gameId: item.gameId),
      'WORD_CHAIN' => WordChainGameScreen(gameId: item.gameId),
      _ => null,
    };
    if (screen == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => screen),
    );
    // 돌아오면 목록 갱신 — 수락/종료로 상태가 변했을 수 있다.
    _loadInvites();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => screen),
    );
    _loadInvites();
  }

  static String _gameName(String type) => switch (type) {
        'OMOK' => '오목',
        'CATCHMIND' => '캐치마인드',
        'TAP_BATTLE' => '탭배틀',
        'WORD_CHAIN' => '끝말잇기',
        _ => '게임',
      };

  static String _gameEmoji(String type) => switch (type) {
        'OMOK' => '⚫',
        'CATCHMIND' => '🎨',
        'TAP_BATTLE' => '👆',
        'WORD_CHAIN' => '🔤',
        _ => '🎮',
      };

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final invites = summary?.invites ?? const <GameInviteItem>[];
    final active = summary?.active ?? const <GameInviteItem>[];
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CenterTitleHeader(title: '게임하기'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInvites,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    // ── 초대받은 게임 ──
                    if (invites.isNotEmpty) ...[
                      _sectionLabel('📨 초대받은 게임', AppColors.primary),
                      const SizedBox(height: 8),
                      for (final item in invites) ...[
                        _InviteCard(
                          emoji: _gameEmoji(item.gameType),
                          title: '${item.title}님의 ${_gameName(item.gameType)} 초대',
                          subtitle: item.gameType == 'CATCHMIND'
                              ? '지금 ${item.playerCount}명 참가 중 — 눌러서 참가하기'
                              : '눌러서 수락/거절하기',
                          accent: AppColors.primary,
                          onTap: () => _openGame(item),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],
                    // ── 진행 중인 게임 ──
                    if (active.isNotEmpty) ...[
                      _sectionLabel('🎯 진행 중인 게임', const Color(0xFF34A0E8)),
                      const SizedBox(height: 8),
                      for (final item in active) ...[
                        _InviteCard(
                          emoji: _gameEmoji(item.gameType),
                          title:
                              '${_gameName(item.gameType)} · ${item.title}',
                          subtitle: '눌러서 이어하기',
                          accent: const Color(0xFF34A0E8),
                          onTap: () => _openGame(item),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Text(
                          '그룹원들과 바로 대결해요!',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: AppColors.gray500,
                          ),
                        ),
                        const Spacer(),
                        if (_loadingInvites)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _GameCard(
                      emoji: '⚫',
                      title: '오목',
                      subtitle: '그룹원을 초대해 실시간 온라인 대국! 5목을 먼저 완성하면 승리',
                      players: '2인 · 온라인',
                      gradient: const [Color(0xFF8D6E63), Color(0xFFEFB261)],
                      onTap: () => _push(const OmokInviteScreen()),
                    ),
                    const SizedBox(height: 12),
                    _GameCard(
                      emoji: '🎨',
                      title: '캐치마인드',
                      subtitle: '한 명이 그리면 나머지가 맞히는 실시간 그림 퀴즈! 여럿이 함께',
                      players: '2~8인 · 온라인',
                      gradient: const [Color(0xFF60A5FA), Color(0xFFA78BFA)],
                      onTap: () => _push(const CatchmindInviteScreen()),
                    ),
                    const SizedBox(height: 12),
                    _GameCard(
                      emoji: '👆',
                      title: '탭배틀',
                      subtitle: '15초 동안 각자 폰에서 연타 대결! 더 많이 탭하면 승리',
                      players: '2인 · 온라인',
                      gradient: const [Color(0xFFFF6B6B), Color(0xFFB794F6)],
                      onTap: () => _push(const TapBattleInviteScreen()),
                    ),
                    const SizedBox(height: 12),
                    _GameCard(
                      emoji: '🔤',
                      title: '끝말잇기',
                      subtitle: '턴 시간 안에 단어를 못 이으면 탈락! 최후의 1인이 우승하는 서든데스',
                      players: '2~8인 · 온라인',
                      gradient: const [Color(0xFF34D399), Color(0xFF60C5A8)],
                      onTap: () => _push(const WordChainInviteScreen()),
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

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: color,
      ),
    );
  }
}

/// 초대/진행 중 카드 — 눌러서 해당 게임 화면으로 진입.
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.players,
    required this.gradient,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String players;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gray100),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.last.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.gray900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            players,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}
