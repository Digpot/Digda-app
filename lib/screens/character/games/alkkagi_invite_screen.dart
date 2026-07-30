import 'package:flutter/material.dart';

import '../../../core/di.dart';
import '../../../core/network/error_message.dart';
import '../../../features/membership/models/membership_models.dart';
import '../../../theme/colors.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/back_header.dart';
import 'game_ui_common.dart';
import 'alkkagi_formation.dart';
import 'alkkagi_game_screen.dart';

/// 알까기 상대 고르기 + 돌 개수 설정.
///
/// 초대자가 한 쪽당 돌 개수(1~10)를 정한 뒤 그룹 멤버 1명을 초대한다.
/// 초대를 보내면 대국 화면(대기 상태)으로 전환되고, 상대에겐 알림이 간다.
class AlkkagiInviteScreen extends StatefulWidget {
  const AlkkagiInviteScreen({super.key});

  @override
  State<AlkkagiInviteScreen> createState() => _AlkkagiInviteScreenState();
}

class _AlkkagiInviteScreenState extends State<AlkkagiInviteScreen> {
  static const int _minStones = 1;
  static const int _maxStones = 10;

  List<Membership> _members = const [];
  bool _loading = true;
  String? _errorMessage;
  bool _inviting = false;
  int _stoneCount = 5;
  AlkkagiFormation _formation = AlkkagiFormation.line;

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
        _errorMessage = '그룹에 들어간 뒤 알까기를 즐길 수 있어요.';
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
      message: '돌 $_stoneCount개 · ${_formation.label} 대형으로 대결을 신청할까요?\n'
          '상대 돌을 모두 판 밖으로 튕겨내면 승리해요!',
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
      final game = await Di.alkkagiRepository.create(
        groupRoomId: groupId,
        inviteeUserId: member.userId,
        stoneCount: _stoneCount,
        formation: _formation.key,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              AlkkagiGameScreen(gameId: game.gameId, initialGame: game),
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
      backgroundColor: gameSurface,
      body: SafeArea(
        child: Column(
          children: [
            const BackHeader(title: '알까기 상대 고르기'),
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
        if (i == 0) return _buildStoneCountCard();
        final m = _members[i - 1];
        return _MemberTile(
          member: m,
          disabled: _inviting,
          onTap: () => _confirmInvite(m),
        );
      },
    );
  }

  /// 돌 개수 선택 카드 — 초대자가 1~10개를 정한다.
  Widget _buildStoneCountCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray100),
        boxShadow: gameSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🪨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                '한 사람당 돌 개수',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.gray900,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_stoneCount개',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.gray200,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _stoneCount.toDouble(),
              min: _minStones.toDouble(),
              max: _maxStones.toDouble(),
              divisions: _maxStones - _minStones,
              onChanged: (v) => setState(() => _stoneCount = v.round()),
            ),
          ),
          // 미리보기 — 선택한 개수만큼 돌을 그려준다.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _stoneCount; i++)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.4, -0.4),
                      colors: [Color(0xFF5A5A5A), Color(0xFF111111)],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 7),
              const Text(
                '내 시작 대형',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.gray900,
                ),
              ),
              const Spacer(),
              Text(
                _formation.desc,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AlkkagiFormationPicker(
            selected: _formation,
            stoneCount: _stoneCount,
            onChanged: (f) => setState(() => _formation = f),
          ),
          const SizedBox(height: 10),
          const Text(
            '내 돌을 튕겨 상대 돌을 모두 판 밖으로 밀어내면 승리!\n'
            '상대도 수락할 때 자기 대형을 골라요. 한 수 제한시간은 30초예요.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.5,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
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
      color: AppColors.white,
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
              const Icon(Icons.sports_esports_rounded,
                  size: 20, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}
