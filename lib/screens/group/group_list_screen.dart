import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../features/invite/models/invite_models.dart';
import '../../screens/onboarding/code_input_screen.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/group_list_tile.dart';
import '../../widgets/invite_code_sheet.dart';
import '../../widgets/notification_bell_icon.dart';
import '../../widgets/restriction_notice.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  late Future<List<GroupRoomListItem>> _future;
  /// 카운트다운이 0 에 도달한 그룹방 id 들. 빌드 시 즉시 리스트에서 숨겨,
  /// 서버 스케줄러(최대 5분 주기) 가 실제 삭제하기 전에도 UX 상 자연스럽게 사라지게 한다.
  final Set<String> _expiredIds = <String>{};

  /// 서비스 이용 제한 계정이면 그룹 리스트 대신 안내 화면을 보여준다(마이페이지만 허용).
  bool _restricted = false;

  @override
  void initState() {
    super.initState();
    _future = Di.groupRoomRepository.myList();
    _checkRestriction();
  }

  /// 이용 제한 여부를 최신 프로필로 확인. 제한되면 리스트 대신 안내 화면으로 전환.
  Future<void> _checkRestriction() async {
    if (Di.userSession.profile?.restricted == true) {
      setState(() => _restricted = true);
    }
    try {
      final me = await Di.userSession.refresh();
      if (mounted) setState(() => _restricted = me.restricted);
    } catch (_) {/* 갱신 실패는 기존 캐시 유지 */}
  }

  Future<void> _refresh() async {
    // 썸네일을 새 이미지로 교체했을 때 Image.network 가 이전 URL/바이트를
    // 캐시한 채 동일 URL 로 응답할 수 있어 화면이 갱신되지 않는 케이스가 있었다.
    // 리스트 재조회 직전에 이미지 캐시를 비워 강제로 다시 로드한다.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() => _future = Di.groupRoomRepository.myList());
    await _future;
  }

  void _handleCountdownExpired(String groupRoomId) {
    if (_expiredIds.contains(groupRoomId)) return;
    setState(() => _expiredIds.add(groupRoomId));
  }

  void _enterGroup(GroupRoomListItem g) {
    Di.activeGroup.enter(
      groupRoomId: g.id,
      groupRoomName: g.name,
      isOwner: g.isOwner,
      isDeleteScheduled: g.isDeleteScheduled,
    );
    if (g.isDeleteScheduled) {
      // 삭제 예정 그룹은 그룹 관리 화면(복구 배너 노출)으로 이동.
      Navigator.of(context)
          .pushNamed('/manage-diary')
          .then((_) => _refresh());
    } else {
      Navigator.of(context).pushNamed(
        '/group-home',
        arguments: {'name': g.name, 'members': g.memberCount},
      );
    }
  }

  Future<void> _recoverGroup(GroupRoomListItem g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '그룹방을 복구할까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: Text(
          '"${g.name}" 그룹방을 복구하면\n모든 데이터가 그대로 유지됩니다.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.gray700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
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
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '복구하기',
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
    if (confirmed != true || !mounted) return;
    try {
      await Di.groupRoomRepository.recover(g.id);
      if (!mounted) return;
      showInfoDialog(context, '그룹방 복구', '"${g.name}" 그룹방을 복구했어요');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  Future<void> _showInviteCodeSheet(String groupRoomId) async {
    InviteCode? code;
    try {
      code = await Di.inviteRepository.regenerate(groupRoomId);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, errorMessageOf(e));
      return;
    }
    if (!mounted || code == null) return;
    showInviteCodeSheet(context, code.code);
  }

  /// 그룹방 개수 제한 안내. 1인당 최대 6개까지만 만들거나 참여할 수 있고,
  /// 6개를 채우면 새 그룹방 생성·초대 수락이 막힌다는 점을 카드형 팝업으로 알린다.
  void _showGroupLimitGuide() {
    showDialog<void>(
      context: context,
      builder: (_) => const _GroupLimitGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '내 그룹방',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            height: 1.25,
                            color: AppColors.gray900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '함께 기록하는 우리 공간',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AppColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 헤더 액션은 한 Row 안에서 세로 중앙으로 맞춰 벨·안내·설정 아이콘이
                  // 동일한 baseline 에 정렬되도록 한다(이전엔 벨만 살짝 아래로 처졌음).
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 이용 제한 계정은 마이페이지(설정)만 접근 — 벨/안내 아이콘 숨김.
                        if (!_restricted) ...[
                          const NotificationBellIcon(),
                          const SizedBox(width: 14),
                          _HeaderIconButton(
                            icon: Icons.help_outline_rounded,
                            onTap: _showGroupLimitGuide,
                          ),
                          const SizedBox(width: 14),
                        ],
                        _HeaderIconButton(
                          icon: Icons.settings_outlined,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/my-page'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _restricted
                  ? RestrictionNotice(
                      onGoMyPage: () =>
                          Navigator.of(context).pushNamed('/my-page'),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: FutureBuilder<List<GroupRoomListItem>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snap.hasError) {
                      return _ErrorView(
                        message: errorMessageOf(snap.error!),
                        onRetry: _refresh,
                      );
                    }
                    final raw = (snap.data ?? const <GroupRoomListItem>[])
                        .where((g) => !_expiredIds.contains(g.id));
                    final groups = [...raw]
                      ..sort((a, b) {
                        // 삭제 예정 항목은 맨 아래
                        if (a.isDeleteScheduled != b.isDeleteScheduled) {
                          return a.isDeleteScheduled ? 1 : -1;
                        }
                        // 같은 섹션 내에서는 최근 활동 기준 내림차순 (최신이 위)
                        return b.lastActivityAt.compareTo(a.lastActivityAt);
                      });
                    return LayoutBuilder(
                      builder: (context, viewport) {
                        final content = Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (groups.isEmpty)
                                const _EmptyState()
                              else
                                ...List.generate(groups.length, (i) {
                                  final g = groups[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: GroupListTile(
                                      name: g.name,
                                      memberCount: '${g.memberCount}명 참여 중',
                                      thumbnailImageUrl: g.thumbnailImage,
                                      // 공유는 방장만, 톱니바퀴(설정/탈퇴 진입점)는 모든 멤버에게.
                                      showShare: g.isOwner && !g.isDeleteScheduled,
                                      showSettings: !g.isDeleteScheduled,
                                      isDeleteScheduled: g.isDeleteScheduled,
                                      deleteScheduledAt: g.deleteScheduledAt,
                                      onCountdownExpired: () =>
                                          _handleCountdownExpired(g.id),
                                      onTap: () => _enterGroup(g),
                                      onShare: () =>
                                          _showInviteCodeSheet(g.id),
                                      onSettings: () {
                                        Di.activeGroup.enter(
                                          groupRoomId: g.id,
                                          groupRoomName: g.name,
                                          isOwner: g.isOwner,
                                        );
                                        // 방장은 그룹방 정보 편집 화면, 일반 멤버는
                                        // 탈퇴 가능한 관리 화면으로 직행.
                                        final route = g.isOwner
                                            ? '/update-diary'
                                            : '/manage-diary';
                                        Navigator.of(context)
                                            .pushNamed(route)
                                            .then((_) => _refresh());
                                      },
                                      // 삭제 예정 그룹은 owner 에게 즉시 복구 버튼 노출.
                                      onRecover: (g.isOwner && g.isDeleteScheduled)
                                          ? () => _recoverGroup(g)
                                          : null,
                                    ),
                                  );
                                }),
                              SizedBox(height: groups.isEmpty ? 8 : 8),
                              // 하단 액션 — 새 그룹방(주 CTA)과 초대 코드 참여를
                              // 나란히 배치해 리스트가 늘어도 깔끔하게 유지한다.
                              Row(
                                children: [
                                  Expanded(
                                    child: _ActionButton(
                                      icon: Icons.add_rounded,
                                      label: '새 그룹방',
                                      filled: true,
                                      onTap: () async {
                                        await Navigator.of(context)
                                            .pushNamed('/create-diary');
                                        _refresh();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ActionButton(
                                      icon: Icons.key_rounded,
                                      label: '코드로 참여',
                                      filled: false,
                                      // 뒷배경을 그룹 리스트로 유지한 채
                                      // 바텀시트로 초대 코드를 입력한다.
                                      onTap: () async {
                                        await CodeInputScreen.showAsSheet(
                                            context);
                                        _refresh();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                        // 콘텐츠가 짧을 때는 세로 중앙 정렬, 길어지면 일반 스크롤.
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minHeight: viewport.maxHeight),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 24),
                                child: content,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 그룹 리스트 하단 액션 버튼 — filled(주 CTA)/outline(보조) 두 톤.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.white : AppColors.gray700;
    return Material(
      color: filled ? AppColors.primary : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(color: AppColors.gray200, width: 1.4),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 64, 0, 24),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '아직 그룹방이 없어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.gray800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '새 그룹방을 만들거나\n초대 코드로 참여해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              height: 1.5,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 헤더 우측 액션 아이콘. 알림 벨(28×28)과 같은 박스에 아이콘을 중앙 정렬해
/// 벨·안내·설정이 동일한 세로 중심선에 맞도록 한다.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 22,
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 24, color: AppColors.gray700),
      ),
    );
  }
}

/// 그룹방 개수 제한 안내 팝업.
class _GroupLimitGuideDialog extends StatelessWidget {
  const _GroupLimitGuideDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '그룹방 안내',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 14),
            // "최대 6개" 강조 배지
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    '1인당 최대 6개',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _GuideRow(
              icon: Icons.add_home_outlined,
              text: '그룹방은 한 사람당 최대 6개까지 만들거나\n참여할 수 있어요.',
            ),
            const SizedBox(height: 12),
            const _GuideRow(
              icon: Icons.mail_lock_outlined,
              text: '이미 6개를 채웠다면 새 그룹방을 만들거나\n초대를 받을 수 없어요.',
            ),
            const SizedBox(height: 12),
            const _GuideRow(
              icon: Icons.logout_rounded,
              text: '다른 그룹방에서 나가면 다시 만들거나\n참여할 수 있어요.',
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '알겠어요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.gray700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: [
        const Icon(Icons.error_outline,
            size: 48, color: AppColors.gray400),
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
        Center(
          child: TextButton(
            onPressed: onRetry,
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
        ),
      ],
    );
  }
}
