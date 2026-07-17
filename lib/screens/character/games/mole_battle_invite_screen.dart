import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/membership/models/membership_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/center_title_header.dart';
import 'mole_battle_screen.dart';

/// 두더지 잡기 상대 고르기 — 그룹 멤버(나 제외) 1명을 초대한다.
class MoleBattleInviteScreen extends StatefulWidget {
  const MoleBattleInviteScreen({super.key});

  @override
  State<MoleBattleInviteScreen> createState() =>
      _MoleBattleInviteScreenState();
}

class _MoleBattleInviteScreenState extends State<MoleBattleInviteScreen> {
  List<Membership> _members = const [];
  bool _loading = true;
  String? _errorMessage;
  bool _inviting = false;

  String get _myId => Di.userSession.profile?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '그룹에 들어간 뒤 두더지 잡기를 즐길 수 있어요.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final members =
          await Di.membershipRepository.list(groupId, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _members = members.where((m) => m.userId != _myId).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = errorMessageOf(e);
      });
    }
  }

  void _confirmInvite(Membership member) {
    if (_inviting) return;
    showConfirmDialog(
      context,
      title: '${member.name}님에게 초대 보내기',
      message: '두더지 잡기 대결을 신청할까요?\n30초 동안 같은 두더지 판에서 점수 대결!\n황금 두더지 +3 · 폭탄은 -2 조심!',
      confirmLabel: '초대',
      onConfirm: () => _invite(member),
    );
  }

  Future<void> _invite(Membership member) async {
    final groupIdRaw = Di.activeGroup.groupRoomId;
    final groupId = groupIdRaw == null ? null : int.tryParse(groupIdRaw);
    if (groupId == null || _inviting) return;
    setState(() => _inviting = true);
    try {
      final game = await Di.minigameRepository.createMoleBattle(
        groupRoomId: groupId,
        inviteeUserId: member.userId,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              MoleBattleScreen(gameId: game.gameId, initialGame: game),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inviting = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CenterTitleHeader(title: '두더지 잡기 상대 고르기'),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    if (_members.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '아직 함께할 그룹원이 없어요.\n그룹에 멤버를 초대한 뒤 대결해 보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.5,
              color: AppColors.gray500,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      itemCount: _members.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '대결할 그룹원을 골라주세요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
          );
        }
        final m = _members[i - 1];
        return _MemberTile(
          member: m,
          disabled: _inviting,
          onTap: () => _confirmInvite(m),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.disabled,
    required this.onTap,
  });

  final Membership member;
  final bool disabled;
  final VoidCallback onTap;

  Color get _accent {
    final hex = member.color.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    return v == null ? AppColors.primary : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gray50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  member.name.isEmpty ? '?' : member.name.characters.first,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.gray900,
                  ),
                ),
              ),
              const Icon(Icons.gavel_rounded,
                  size: 20, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}
