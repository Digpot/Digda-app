import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/diary/models/diary_models.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../features/notification/models/notification_models.dart';
import '../../features/schedule/models/schedule_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/feature_card.dart';
import '../../widgets/invite_code_sheet.dart';
import '../../widgets/notification_bell_icon.dart';

/// 그룹 홈 — '대시보드' 리디자인.
///
/// 위 → 아래: 인사 헤더 / 오늘 요약 / 활성 그룹 카드(멤버+다가오는 일정) /
/// 퀵 액션 / 그룹 기능 / 최근 소식 피드. (docs/GROUP_HOME_REDESIGN.md)
///
/// 데이터: `GET /group-rooms/:id/home`(집계) + 최근 소식은 `/notifications` 재사용.
class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({
    super.key,
    this.groupName = '',
    this.isOwner = true,
  });

  final String groupName;
  final bool isOwner;

  @override
  State<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  static const _avatarColors = [
    AppColors.primary,
    AppColors.blue,
    AppColors.green,
    AppColors.purple,
  ];

  GroupHomeData? _home;
  List<AppNotification> _activity = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final activeId = Di.activeGroup.groupRoomId;
    if (activeId == null) {
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayUtc = DateTime.utc(today.year, today.month, today.day);

    // 대시보드를 기존 엔드포인트들로 병렬 조립한다.
    // (전용 /home 집계 엔드포인트가 서버에 없어 404 가 나던 것을 클라이언트 집계로 대체)
    final detailFuture = Di.groupRoomRepository.detail(activeId);
    // 최근 소식 피드는 '지금 보는 그룹'의 알림만 보여줘야 하는데 /notifications 는
    // 전 그룹을 섞어서 내려준다. 그래서 넉넉히 받아(아래에서 groupRoomId 로 필터) 8건만
    // 추린다.
    final notiFuture = Di.notificationRepository
        .list(limit: 40, offset: 0)
        .catchError((_) =>
            NotificationListResult(notifications: const [], total: 0, unreadCount: 0));
    final scheduleFuture = Di.scheduleRepository
        .list(
          activeId,
          startDate: todayUtc,
          endDate: todayUtc.add(const Duration(days: 60)),
          forceRefresh: true,
        )
        .catchError((_) => <Schedule>[]);
    final diaryFuture = Di.diaryRepository
        .list(activeId, month: now, limit: 31, forceRefresh: true)
        .catchError((_) => DiaryListResult(diaries: const [], total: 0));

    try {
      final detail = await detailFuture; // 핵심 — 실패 시 에러 화면
      final noti = await notiFuture;
      final schedules = await scheduleFuture;
      final diaryRes = await diaryFuture;
      if (!mounted) return;

      DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

      // 오늘 일정 수 — 오늘을 포함(기간)하는 일정.
      final todayScheduleCount = schedules.where((s) {
        final sd = dateOnly(s.startDate);
        final ed = dateOnly(s.endDate);
        return !today.isBefore(sd) && !today.isAfter(ed);
      }).length;

      // 다가오는 일정 — 오늘 이후(포함) 가장 빠른 일정 1건.
      final upcoming = schedules
          .where((s) => !dateOnly(s.startDate).isBefore(today))
          .toList()
        ..sort((a, b) {
          final c = a.startDate.compareTo(b.startDate);
          if (c != 0) return c;
          final at = a.allDay ? '' : (a.startTime ?? '');
          final bt = b.allDay ? '' : (b.startTime ?? '');
          return at.compareTo(bt);
        });
      final next = upcoming.isEmpty ? null : upcoming.first;

      // 오늘 작성된(또는 오늘 날짜) 새 일기 수.
      final newDiaryCount = diaryRes.diaries.where((d) {
        final dd = dateOnly(d.date);
        return dd == today;
      }).length;

      final home = GroupHomeData(
        userName: Di.userSession.profile?.name ?? '',
        today: TodaySummary(
          scheduleCount: todayScheduleCount,
          newDiaryCount: newDiaryCount,
          unreadCount: noti.unreadCount,
        ),
        activeGroup: ActiveGroupSummary(
          id: detail.groupRoom.id,
          name: detail.groupRoom.name,
          thumbnailImage: detail.groupRoom.thumbnailImage,
          memberCount: detail.groupRoom.memberCount,
          myRole: detail.myRole,
          members: detail.memberships,
          nextEvent: next == null
              ? null
              : HomeNextEvent(
                  id: next.id,
                  title: next.title,
                  startDate: next.startDate,
                  startTime: next.startTime,
                  allDay: next.allDay,
                  color: next.color,
                ),
        ),
      );

      // 활성 컨텍스트(이름/역할)를 최신으로 동기화 — 다른 탭이 참조.
      Di.activeGroup.enter(
        groupRoomId: detail.groupRoom.id,
        groupRoomName: detail.groupRoom.name,
        isOwner: detail.isOwner,
      );
      // 현재 그룹 알림만 추려 최근 소식으로 노출 (다른 그룹방 알림 섞임 방지).
      final groupActivity = noti.notifications
          .where((n) => n.groupRoomId == activeId)
          .take(8)
          .toList();
      setState(() {
        _home = home;
        _activity = groupActivity;
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

  // ── 네비게이션 헬퍼 ──────────────────────────────────────────

  void _go(String route) => Navigator.of(context).pushNamed(route);

  void _goThenReload(String route, {Object? arguments}) {
    Navigator.of(context)
        .pushNamed(route, arguments: arguments)
        .then((_) => _load());
  }

  /// 그룹 전환 시트 — 내 그룹 목록을 띄우고 선택 시 활성 그룹을 바꿔 홈을 갱신.
  Future<void> _openGroupSwitcher() async {
    List<GroupRoomListItem> groups;
    try {
      groups = await Di.groupRoomRepository.myList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageOf(e))),
      );
      return;
    }
    if (!mounted) return;
    final activeId = _home?.activeGroup.id ?? Di.activeGroup.groupRoomId;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '그룹 전환',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.gray900,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final g = groups[i];
                  final selected = g.id == activeId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage:
                          (g.thumbnailImage != null && g.thumbnailImage!.isNotEmpty)
                              ? NetworkImage(g.thumbnailImage!)
                              : null,
                      child: (g.thumbnailImage == null || g.thumbnailImage!.isEmpty)
                          ? const Icon(Icons.group_rounded,
                              color: AppColors.primary, size: 20)
                          : null,
                    ),
                    title: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                        color: AppColors.gray900,
                      ),
                    ),
                    subtitle: Text(
                      '${g.memberCount}명',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (g.id == activeId) return;
                      Di.activeGroup.enter(
                        groupRoomId: g.id,
                        groupRoomName: g.name,
                        isOwner: g.isOwner,
                      );
                      _load();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 초대 코드 발급 — 방장만. 서버에서 새 6자리 코드를 재발급받아 그룹 리스트와
  /// 동일한 바텀시트로 노출한다. (예전엔 코드 없이 /code-generate 로 이동해 '------'
  /// 만 떴고, 비방장에게도 버튼이 보였다.)
  Future<void> _generateInvite() async {
    final groupId = _home?.activeGroup.id ?? Di.activeGroup.groupRoomId;
    if (groupId == null) return;
    String code;
    try {
      code = (await Di.inviteRepository.regenerate(groupId)).code;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessageOf(e))),
      );
      return;
    }
    if (!mounted) return;
    showInviteCodeSheet(context, code);
  }

  /// FAB — 새 일기/일정/퀴즈 생성 빠른 진입.
  void _openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _SheetAction(
              icon: Icons.edit_outlined,
              label: '새 일기 쓰기',
              onTap: () {
                Navigator.of(ctx).pop();
                _goThenReload('/write-diary');
              },
            ),
            _SheetAction(
              icon: Icons.event_outlined,
              label: '새 일정 추가',
              onTap: () {
                Navigator.of(ctx).pop();
                _goThenReload('/add-schedule');
              },
            ),
            _SheetAction(
              icon: Icons.psychology_outlined,
              label: '퀴즈 풀기',
              onTap: () {
                Navigator.of(ctx).pop();
                _go('/character-quiz-play');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      floatingActionButton: (_loading || _errorMessage != null)
          ? null
          : FloatingActionButton(
              onPressed: _openCreateSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(Icons.add, size: 28),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final home = _home!;
    final group = home.activeGroup;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _GreetingHeader(userName: home.userName),
          const SizedBox(height: 20),
          _SummaryStrip(
            today: home.today,
            onSchedules: () => _go('/schedule'),
            onDiaries: () => _go('/diary'),
            onUnread: () => _goThenReload('/notifications'),
          ),
          const SizedBox(height: 20),
          _ActiveGroupCard(
            group: group,
            avatarColors: _avatarColors,
            onSwitch: _openGroupSwitcher,
            onNextEvent: () => _go('/schedule'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('빠른 작업'),
          const SizedBox(height: 12),
          _QuickActions(
            // 초대 코드 발급은 방장만 (서버도 NOT_GROUP_ROOM_OWNER 로 막는다).
            isOwner: group.isOwner,
            onDiary: () => _goThenReload('/write-diary'),
            onSchedule: () => _goThenReload('/add-schedule'),
            onQuiz: () => _go('/character-quiz-play'),
            onInvite: _generateInvite,
          ),
          const SizedBox(height: 24),
          const _SectionTitle('그룹 기능'),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.calendar_month_outlined,
            iconBgColor: AppColors.primary.withValues(alpha: 0.15),
            iconColor: AppColors.primary,
            cardBgColor: AppColors.primary.withValues(alpha: 0.06),
            title: '일정 관리',
            subtitle: '우리 모임 일정을 한눈에',
            onTap: () => _go('/schedule'),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.book_outlined,
            iconBgColor: const Color(0xFFFFE88A),
            iconColor: const Color(0xFFC89A00),
            cardBgColor: const Color(0xFFFFFBEE),
            title: '그림일기',
            subtitle: '오늘의 추억을 기록해요',
            onTap: () => _go('/diary'),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.favorite_rounded,
            iconBgColor: AppColors.primary.withValues(alpha: 0.15),
            iconColor: AppColors.primary,
            cardBgColor: AppColors.primary.withValues(alpha: 0.06),
            title: '모찌 키우기',
            subtitle: '함께 모찌를 키워봐요',
            onTap: () => _go('/character'),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.check_box_outlined,
            iconBgColor: AppColors.blue.withValues(alpha: 0.2),
            iconColor: AppColors.blue,
            cardBgColor: AppColors.blue.withValues(alpha: 0.06),
            title: '투두리스트',
            subtitle: '할 일을 함께 관리해요',
            onTap: () => _go('/todo'),
          ),
          if (group.isOwner) ...[
            const SizedBox(height: 12),
            FeatureCard(
              icon: Icons.settings_outlined,
              iconBgColor: AppColors.gray200,
              iconColor: AppColors.gray700,
              cardBgColor: AppColors.gray50,
              title: '그룹 설정',
              subtitle: '그룹 정보·멤버를 관리해요',
              onTap: () => _goThenReload('/update-diary'),
            ),
            const SizedBox(height: 12),
            FeatureCard(
              icon: Icons.swap_horiz_rounded,
              iconBgColor: AppColors.purple.withValues(alpha: 0.15),
              iconColor: AppColors.purple,
              cardBgColor: AppColors.purple.withValues(alpha: 0.06),
              title: '방장 양도',
              subtitle: '다른 멤버에게 방장을 넘겨요',
              onTap: () => _goThenReload('/transfer-owner', arguments: group.name),
            ),
          ],
          const SizedBox(height: 28),
          const _SectionTitle('최근 소식'),
          const SizedBox(height: 12),
          _ActivitySection(
            items: _activity,
            onItemTap: () => _goThenReload('/notifications'),
            onEmptyCta: () => _goThenReload('/write-diary'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.gray400),
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
}

// ────────────────────────────────────────────────────────────
//  ① 인사 헤더
// ────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.userName});
  final String userName;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel =
        '${now.month}월 ${now.day}일 ${_weekdays[(now.weekday - 1) % 7]}요일';
    final name = userName.isNotEmpty ? userName : '회원';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    height: 1.2,
                    color: AppColors.gray900,
                  ),
                  children: [
                    const TextSpan(text: '안녕하세요,\n'),
                    TextSpan(
                      text: name,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    const TextSpan(text: '님 👋'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const NotificationBellIcon(),
        const SizedBox(width: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pushNamed('/my-page'),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.settings_outlined,
                size: 24, color: AppColors.gray700),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ② 오늘 요약 스트립
// ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.today,
    required this.onSchedules,
    required this.onDiaries,
    required this.onUnread,
  });

  final TodaySummary today;
  final VoidCallback onSchedules;
  final VoidCallback onDiaries;
  final VoidCallback onUnread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            count: today.scheduleCount,
            label: '오늘 일정',
            color: AppColors.primary,
            bg: AppColors.primary.withValues(alpha: 0.08),
            onTap: onSchedules,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            count: today.newDiaryCount,
            label: '새 일기',
            color: AppColors.blue,
            bg: AppColors.blue.withValues(alpha: 0.08),
            onTap: onDiaries,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            count: today.unreadCount,
            label: '안읽음',
            color: const Color(0xFFC89A00),
            bg: const Color(0xFFFFFBEE),
            onTap: onUnread,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.count,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final int count;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  height: 1.0,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.gray700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ③ 활성 그룹 카드
// ────────────────────────────────────────────────────────────

class _ActiveGroupCard extends StatelessWidget {
  const _ActiveGroupCard({
    required this.group,
    required this.avatarColors,
    required this.onSwitch,
    required this.onNextEvent,
  });

  final ActiveGroupSummary group;
  final List<Color> avatarColors;
  final VoidCallback onSwitch;
  final VoidCallback onNextEvent;

  @override
  Widget build(BuildContext context) {
    final shownMembers = group.members.take(4).toList();
    final extra = group.memberCount - shownMembers.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A8A), AppColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏠', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              const Text(
                '지금 보는 그룹',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onSwitch,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '그룹 전환',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < shownMembers.length; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == shownMembers.length - 1 ? 0 : 6),
                  child: _Avatar(
                    member: shownMembers[i],
                    color: avatarColors[i % avatarColors.length],
                  ),
                ),
              if (extra > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Text(
                '${group.memberCount}명 함께',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _NextEventTile(event: group.nextEvent, onTap: onNextEvent),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member, required this.color});
  final MembershipSummary member;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final img = member.profileImage;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: (img != null && img.isNotEmpty)
            ? Image.network(
                img,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final initial =
        member.name.isNotEmpty ? member.name.substring(0, 1) : '?';
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: color,
        ),
      ),
    );
  }
}

class _NextEventTile extends StatelessWidget {
  const _NextEventTile({required this.event, required this.onTap});
  final HomeNextEvent? event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_rounded,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: e == null
                    ? const Text(
                        '예정된 일정이 없어요',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.gray500,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _whenLabel(e),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.gray900,
                            ),
                          ),
                        ],
                      ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  /// "오늘 · 오후 7시" / "6월 3일 · 하루 종일" 식 라벨.
  static String _whenLabel(HomeNextEvent e) {
    final now = DateTime.now();
    final d = e.startDate;
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = that.difference(today).inDays;
    final dayLabel = diff == 0
        ? '오늘'
        : diff == 1
            ? '내일'
            : '${d.month}월 ${d.day}일';
    if (e.allDay) return '$dayLabel · 하루 종일';
    final t = _timeLabel(e.startTime);
    return t == null ? dayLabel : '$dayLabel · $t';
  }

  /// "19:00:00" → "오후 7시" / "오후 7시 30분".
  static String? _timeLabel(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '');
    if (h == null) return null;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final period = h < 12 ? '오전' : '오후';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return m > 0 ? '$period $h12시 $m분' : '$period $h12시';
  }
}

// ────────────────────────────────────────────────────────────
//  ④ 퀵 액션
// ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isOwner,
    required this.onDiary,
    required this.onSchedule,
    required this.onQuiz,
    required this.onInvite,
  });

  final bool isOwner;
  final VoidCallback onDiary;
  final VoidCallback onSchedule;
  final VoidCallback onQuiz;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionItem(
            icon: Icons.edit_outlined,
            label: '일기 쓰기',
            color: const Color(0xFFC89A00),
            bg: const Color(0xFFFFFBEE),
            onTap: onDiary,
          ),
        ),
        Expanded(
          child: _QuickActionItem(
            icon: Icons.event_outlined,
            label: '일정 추가',
            color: AppColors.primary,
            bg: AppColors.primary.withValues(alpha: 0.08),
            onTap: onSchedule,
          ),
        ),
        Expanded(
          child: _QuickActionItem(
            icon: Icons.psychology_outlined,
            label: '퀴즈',
            color: AppColors.purple,
            bg: AppColors.purple.withValues(alpha: 0.1),
            onTap: onQuiz,
          ),
        ),
        // 초대 코드 발급은 방장만 노출 (멤버에게는 숨김).
        if (isOwner)
          Expanded(
            child: _QuickActionItem(
              icon: Icons.person_add_alt_1_outlined,
              label: '초대',
              color: AppColors.blue,
              bg: AppColors.blue.withValues(alpha: 0.1),
              onTap: onInvite,
            ),
          ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ⑤ 최근 소식 피드
// ────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.items,
    required this.onItemTap,
    required this.onEmptyCta,
  });

  final List<AppNotification> items;
  final VoidCallback onItemTap;
  final VoidCallback onEmptyCta;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined,
                size: 36, color: AppColors.gray400),
            const SizedBox(height: 10),
            const Text(
              '아직 새 소식이 없어요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onEmptyCta,
              child: const Text(
                '첫 일기 남기기',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final n in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityTile(notification: n, onTap: onItemTap),
          ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  (IconData, Color) get _skin {
    final type = notification.type;
    if (type.contains('diary')) {
      return (Icons.auto_stories_rounded, const Color(0xFFE91E63));
    }
    if (type.contains('schedule')) {
      return (Icons.event_available_rounded, const Color(0xFF1A73E8));
    }
    if (type.contains('comment')) {
      return (Icons.mode_comment_rounded, const Color(0xFF5E35B1));
    }
    if (type.contains('member') || type.contains('join')) {
      return (Icons.person_add_alt_1_rounded, const Color(0xFF2E7D32));
    }
    if (type.contains('quiz') || type.contains('mochi') || type.contains('diko')) {
      return (Icons.auto_awesome_rounded, AppColors.primary);
    }
    return (Icons.notifications_rounded, AppColors.gray500);
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    final d = notification.createdAt.toLocal();
    return '${d.month}월 ${d.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _skin;
    final unread = !notification.isRead;
    return Material(
      color: unread ? const Color(0xFFEEF1FB) : AppColors.gray50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title.isNotEmpty
                          ? notification.title
                          : notification.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: unread ? AppColors.gray900 : AppColors.gray700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeAgo,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  공용
// ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.gray900,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.gray900,
        ),
      ),
      onTap: onTap,
    );
  }
}
