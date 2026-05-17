import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../features/membership/models/membership_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

class ManageDiaryScreen extends StatefulWidget {
  const ManageDiaryScreen({super.key});

  @override
  State<ManageDiaryScreen> createState() => _ManageDiaryScreenState();
}

class _ManageDiaryScreenState extends State<ManageDiaryScreen> {
  bool _membersExpanded = false;
  bool _loading = true;
  bool _busy = false;
  String? _errorMessage;

  GroupRoomDetail? _detail;
  List<Membership> _members = const [];

  bool get _isDeleted => _detail?.groupRoom.deleteScheduledAt != null;
  bool get _isOwner => _detail?.isOwner ?? false;

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
        _errorMessage = '그룹방 정보를 불러올 수 없어요';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await Di.groupRoomRepository.detail(groupId);
      final members = await Di.membershipRepository.list(groupId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _members = members;
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

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : AppColors.primary;
  }

  Future<void> _removeMember(Membership member) async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _busy = true);
    try {
      await Di.membershipRepository.remove(groupId, member.userId);
      await _load();
      if (!mounted) return;
      setState(() => _busy = false);
      showInfoDialog(context, '내보내기 완료', '${member.name}님을 내보냈어요');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _softDelete() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _busy = true);
    try {
      await Di.groupRoomRepository.softDelete(groupId);
      if (!mounted) return;
      setState(() => _busy = false);
      showInfoDialog(
        context,
        '삭제가 예약됐어요',
        '7일 후에 그룹방이 완전히 삭제됩니다.\n그 전에 복구할 수 있어요.',
        onConfirm: () {
          Di.activeGroup.clear();
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/group-list',
            (_) => false,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _recover() async {
    final groupId = Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    setState(() => _busy = true);
    try {
      await Di.groupRoomRepository.recover(groupId);
      await _load();
      if (!mounted) return;
      setState(() => _busy = false);
      showInfoDialog(context, '복구 완료', '그룹방을 복구했어요');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '그룹방 관리',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildError()
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            if (_isDeleted) _buildRecoveryBanner(),
            const SizedBox(height: 8),
            _buildMembersSection(),
            const SizedBox(height: 16),
            if (_isOwner && !_isDeleted) _buildDeleteButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.restore_rounded,
                    size: 20, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  '삭제 예정 다이어리',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '이 그룹방은 7일 후에 완전히 삭제됩니다.\n지금 복구하면 모든 데이터가 유지됩니다.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                height: 1.5,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _busy ? null : _recover,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '다이어리 복구하기',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _membersExpanded = !_membersExpanded),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  size: 20,
                  color: AppColors.gray700,
                ),
                const SizedBox(width: 10),
                const Text(
                  '멤버 관리',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_members.length}명',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppColors.gray400,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _membersExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_membersExpanded) ...[
          const SizedBox(height: 8),
          ..._members.map(_buildMemberTile),
        ],
      ],
    );
  }

  Widget _buildMemberTile(Membership m) {
    final color = _hexToColor(m.color);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: (m.profileImage != null && m.profileImage!.isNotEmpty)
                ? Image.network(
                    m.profileImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        m.name.isNotEmpty ? m.name[0] : '?',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14, color: color),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      m.name.isNotEmpty ? m.name[0] : '?',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14, color: color),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.gray900,
                  ),
                ),
                if (m.isOwner)
                  const Text(
                    '방장',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          if (_isOwner && !m.isOwner)
            GestureDetector(
              onTap: _busy ? null : () => _showRemoveMemberDialog(m),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gray200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '삭제',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _busy ? null : _showDeleteRoomDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              '그룹방 삭제',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.gray400),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _load,
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(Membership m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '멤버를 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '${m.name}님을 이 다이어리에서\n내보내시겠어요?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showMemberRemoveFinalConfirm(m);
            },
            child: const Text(
              '삭제',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberRemoveFinalConfirm(Membership m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '정말 내보내시겠어요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '${m.name}님은 이 그룹방의 모든\n기록에 접근할 수 없게 됩니다.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _removeMember(m);
            },
            child: const Text(
              '내보내기',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteRoomDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '그룹방을 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '삭제하면 모든 멤버가 이 그룹방에\n접근할 수 없게 됩니다.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showDeleteRoomFinalConfirm();
            },
            child: const Text(
              '삭제',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteRoomFinalConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '정말 삭제하시겠어요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '그룹방은 7일 후에 완전히 삭제됩니다.\n7일 이내에 복구할 수 있어요.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _softDelete();
            },
            child: const Text(
              '삭제하기',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
