import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../../../widgets/center_title_header.dart';
import 'memory_match_screen.dart';
import 'reaction_duel_screen.dart';
import 'tap_battle_screen.dart';

/// 그룹원들이 한 폰으로 함께 즐기는 미니게임 목록.
///
/// 전부 로컬(패스&플레이) 게임이라 서버·소켓 없이 동작한다 — 실시간 온라인
/// 대전이 필요해지면 그때 별도 인프라를 붙인다.
class GroupGameListScreen extends StatelessWidget {
  const GroupGameListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CenterTitleHeader(title: '게임하기'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const Text(
                    '폰 하나로 그룹원들과 바로 대결해요!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GameCard(
                    emoji: '⚡',
                    title: '반응속도 대결',
                    subtitle: '초록불이 켜지면 먼저 탭! 3판 먼저 이기면 승리',
                    players: '2인 · 한 폰',
                    gradient: const [Color(0xFFFFD700), Color(0xFFFF8A65)],
                    onTap: () => _push(context, const ReactionDuelScreen()),
                  ),
                  const SizedBox(height: 12),
                  _GameCard(
                    emoji: '👆',
                    title: '탭 배틀',
                    subtitle: '10초 동안 더 많이 탭하는 사람이 승리',
                    players: '2인 · 한 폰',
                    gradient: const [Color(0xFFFF6B6B), Color(0xFFB794F6)],
                    onTap: () => _push(context, const TapBattleScreen()),
                  ),
                  const SizedBox(height: 12),
                  _GameCard(
                    emoji: '🃏',
                    title: '기억력 카드',
                    subtitle: '같은 그림 카드를 찾아요. 맞추면 한 번 더!',
                    players: '2~4인 · 턴제',
                    gradient: const [Color(0xFF45B7D1), Color(0xFF34D399)],
                    onTap: () => _push(context, const MemoryMatchScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => screen),
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
