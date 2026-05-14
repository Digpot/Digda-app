import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../features/invite/models/invite_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/group_list_tile.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  late Future<List<GroupRoomListItem>> _future;

  // 그룹마다 일관된 아이콘/색을 부여하기 위한 팔레트.
  static const _palette = [
    _Skin(Icons.image_outlined, Color(0xFFFFEAEA), AppColors.primary),
    _Skin(Icons.diamond_outlined, Color(0xFFEAEEFF), Color(0xFF6B82F0)),
    _Skin(Icons.coffee_outlined, Color(0xFFFFF3E0), Color(0xFFF0A050)),
    _Skin(Icons.travel_explore_outlined, Color(0xFFE7F8EE), AppColors.green),
    _Skin(Icons.favorite_border, Color(0xFFFFF0F4), AppColors.primary),
  ];

  @override
  void initState() {
    super.initState();
    _future = Di.groupRoomRepository.myList();
  }

  Future<void> _refresh() async {
    setState(() => _future = Di.groupRoomRepository.myList());
    await _future;
  }

  void _enterGroup(GroupRoomListItem g) {
    Di.activeGroup.enter(
      groupRoomId: g.id,
      groupRoomName: g.name,
      isOwner: g.isOwner,
    );
    Navigator.of(context).pushNamed(
      '/group-home',
      arguments: {'name': g.name, 'members': g.memberCount},
    );
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteCodeBottomSheet(code: code!.code),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '내 다이어리',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.3,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed('/notifications'),
                    child: const Icon(
                      Icons.notifications_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/my-page'),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: AppColors.gray700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
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
                    final groups = snap.data ?? const <GroupRoomListItem>[];
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
                                  final skin = _palette[i % _palette.length];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: GroupListTile(
                                      name: g.name,
                                      memberCount: '${g.memberCount}명 참여 중',
                                      groupIcon: skin.icon,
                                      groupIconBg: skin.bg,
                                      groupIconColor: skin.fg,
                                      showActions: g.isOwner,
                                      onTap: () => _enterGroup(g),
                                      onShare: () =>
                                          _showInviteCodeSheet(g.id),
                                      onSettings: () {
                                        Di.activeGroup.enter(
                                          groupRoomId: g.id,
                                          groupRoomName: g.name,
                                          isOwner: g.isOwner,
                                        );
                                        Navigator.of(context)
                                            .pushNamed('/update-diary')
                                            .then((_) => _refresh());
                                      },
                                    ),
                                  );
                                }),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.of(context)
                                      .pushNamed('/create-diary');
                                  _refresh();
                                },
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '새 다이어리 추가',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

class _Skin {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _Skin(this.icon, this.bg, this.fg);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 56,
            color: AppColors.gray300,
          ),
          const SizedBox(height: 12),
          const Text(
            '아직 다이어리가 없어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '새 다이어리를 만들거나 초대 코드로 참여해보세요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
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

class _InviteCodeBottomSheet extends StatefulWidget {
  const _InviteCodeBottomSheet({required this.code});
  final String code;

  @override
  State<_InviteCodeBottomSheet> createState() => _InviteCodeBottomSheetState();
}

class _InviteCodeBottomSheetState extends State<_InviteCodeBottomSheet> {
  bool _copied = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          const Text(
            '초대 코드가 생성됐어요!',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.3,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                widget.code,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  letterSpacing: 6,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _copyCode,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _copied ? '복사됨' : '코드 복사',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Share.share(
                      'Digda에서 함께 일기를 써요!\n\n초대 코드: ${widget.code}\n\nDigda 앱을 열고 초대 코드를 입력해주세요 🙌',
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '공유하기',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              '상대방이 이 코드를 입력하면 연결돼요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: AppColors.gray500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '코드는 24시간 후 만료됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}
