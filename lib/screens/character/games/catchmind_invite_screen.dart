import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/membership/models/membership_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/center_title_header.dart';
import 'catchmind_game_screen.dart';

/// 캐치마인드 초대 — 그룹 멤버(나 제외) 중 여럿을 골라 방을 만든다.
/// 방을 만들면 로비(대기) 화면으로 전환되고 초대받은 사람들에겐 알림이 간다.
class CatchmindInviteScreen extends StatefulWidget {
  const CatchmindInviteScreen({super.key});

  @override
  State<CatchmindInviteScreen> createState() => _CatchmindInviteScreenState();
}

class _CatchmindInviteScreenState extends State<CatchmindInviteScreen> {
  List<Membership> _members = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  String? _errorMessage;
  bool _creating = false;

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
        _errorMessage = '그룹에 들어간 뒤 캐치마인드를 즐길 수 있어요.';
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

  Future<void> _create() async {
    final groupIdRaw = Di.activeGroup.groupRoomId;
    final groupId = groupIdRaw == null ? null : int.tryParse(groupIdRaw);
    if (groupId == null || _creating || _selected.isEmpty) return;
    setState(() => _creating = true);
    try {
      final game = await Di.minigameRepository.createCatchmind(
        groupRoomId: groupId,
        inviteeUserIds: _selected.toList(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              CatchmindGameScreen(gameId: game.gameId, initialGame: game),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
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
            const CenterTitleHeader(title: '캐치마인드 초대'),
            Expanded(child: _buildBody()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final count = _selected.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: (count == 0 || _creating) ? null : _create,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.gray200,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            _creating
                ? '방 만드는 중...'
                : count == 0
                    ? '초대할 그룹원을 골라주세요'
                    : '$count명 초대하고 방 만들기',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
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
            '아직 함께할 그룹원이 없어요.\n그룹에 멤버를 초대한 뒤 즐겨보세요!',
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: _members.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '함께할 그룹원을 모두 골라주세요 (여러 명 가능)',
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
        final selected = _selected.contains(m.userId);
        return _SelectableMemberTile(
          member: m,
          selected: selected,
          onTap: () => setState(() {
            if (selected) {
              _selected.remove(m.userId);
            } else {
              _selected.add(m.userId);
            }
          }),
        );
      },
    );
  }
}

class _SelectableMemberTile extends StatelessWidget {
  const _SelectableMemberTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final Membership member;
  final bool selected;
  final VoidCallback onTap;

  Color get _accent {
    final hex = member.color.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    return v == null ? AppColors.primary : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : AppColors.gray50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.gray100,
              width: selected ? 1.6 : 1,
            ),
          ),
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
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 24,
                color: selected ? AppColors.primary : AppColors.gray300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
