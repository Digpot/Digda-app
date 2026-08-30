import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/maintenance_gate.dart';
import '../../core/network/error_message.dart';
import '../../core/notification_router.dart';
import '../../features/app_config/models/app_config.dart';
import '../../features/diary/models/diary_models.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../features/ledger/models/ledger_models.dart';
import '../../features/notification/models/notification_models.dart';
import '../../features/schedule/models/schedule_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/group_default_avatar.dart';
import '../../widgets/invite_code_sheet.dart';
import '../../widgets/restriction_notice.dart';
import 'group_home_view.dart';

/// 그룹 홈 — 데이터 로딩·시트·다이얼로그 담당.
///
/// 화면을 그리는 일은 [GroupHomeView] 가 맡는다 — 표현을 분리해 두면
/// 로딩 분기에 걸리지 않고 홈 UI 만 따로 띄워 볼 수 있다.
///
/// 데이터: 전용 집계 엔드포인트가 없어 그룹 상세/일정/일기/알림을 병렬로 받아
/// 클라이언트에서 조립한다.
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
  /// 내가 차단한 사용자 ID 집합 — 그룹원 표시에서 '차단됨' 배지로 쓴다.
  Set<String> _blockedUserIds = const {};
  List<AppNotification> _activity = const [];
  /// 최근 소식 노출 개수 — 최초 5개, '더보기' 시 10개씩 증가.
  int _activityVisible = 5;
  bool _loading = true;
  String? _errorMessage;
  /// 활성 그룹이 삭제 예정이어서 홈을 그릴 수 없는 상태. true 면 복구 안내 화면을 보여준다.
  bool _deleteScheduledBlock = false;
  /// 서비스 이용 제한 계정이면 홈 대신 안내 화면(마이페이지만 허용)을 보여준다.
  bool _restrictedBlock = false;
  /// 오늘 날짜 일기가 이미 있는지 — 그룹홈에서 '일기 쓰기' 중복 작성을 막는 데 쓴다.
  bool _todayHasDiary = false;
  /// 앱 운영 설정(대공지 등). best-effort 로 받아 배너 노출에 사용.
  AppConfig _appConfig = AppConfig.empty;

  /// 이번 달 그룹 가계부 요약. 실패하거나 아직 안 왔으면 null 이고, 그동안 카드는
  /// 0원으로 그려진다(홈 전체를 막지 않는 부가 정보).
  LedgerSummary? _ledger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _loadAppConfig() async {
    try {
      final cfg = await Di.appConfigRepository.get(forceRefresh: true);
      if (!mounted) return;
      setState(() => _appConfig = cfg);
      // 서버 점검 중이면 홈에서부터 전 기능을 차단한다.
      if (cfg.maintenanceEnabled) {
        MaintenanceGate.show(appNavigatorKey, cfg.maintenanceMessage);
      }
    } catch (_) {/* 설정 조회 실패는 화면에 영향 없음 */}
  }

  /// 이번 달 가계부 요약. 실패해도 홈은 그대로 그린다(카드만 0원으로 남음).
  Future<void> _loadLedger(String groupRoomId) async {
    final now = DateTime.now();
    try {
      final summary = await Di.ledgerRepository.monthly(
        groupRoomId,
        year: now.year,
        month: now.month,
        forceRefresh: true,
      );
      if (mounted) setState(() => _ledger = summary);
    } catch (_) {/* 가계부 조회 실패는 홈 전체를 막지 않는다 */}
  }

  /// 차단 목록을 받아 그룹원 표시에서 '차단됨' 마킹에 쓴다. 실패는 무시(마킹만 빠짐).
  Future<void> _loadBlockedUsers() async {
    try {
      final blocked = await Di.blockRepository.listBlockedUsers();
      if (mounted) {
        setState(() => _blockedUserIds = blocked.map((b) => b.userId).toSet());
      }
    } catch (_) {/* 차단 목록 조회 실패는 화면에 영향 없음 */}
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
      _deleteScheduledBlock = false;
      _restrictedBlock = false;
    });
    _loadAppConfig(); // 대공지 배너 (best-effort, 비동기)
    _loadBlockedUsers(); // 차단 목록 (best-effort, 비동기)
    _loadLedger(activeId); // 이번 달 가계부 (best-effort, 비동기)

    // 이용 제한 상태를 최신으로 — 제한되면 곧바로 안내 화면으로 막는다.
    try {
      final me = await Di.userSession.refresh();
      if (me.restricted) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _restrictedBlock = true;
        });
        return;
      }
    } catch (_) {/* 프로필 갱신 실패는 무시(기존 캐시로 진행) */}
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayUtc = DateTime.utc(today.year, today.month, today.day);

    // 대시보드를 기존 엔드포인트들로 병렬 조립한다.
    // (전용 /home 집계 엔드포인트가 서버에 없어 404 가 나던 것을 클라이언트 집계로 대체)
    final detailFuture = Di.groupRoomRepository.detail(activeId);
    // 인사 헤더에 쓸 내 이름 — 프로필이 아직 캐시되지 않았으면(앱 첫 진입 등) 여기서
    // 한 번 받아온다. 안 그러면 이름이 비어 '회원님' 으로 떨어진다.
    final profileFuture = Di.userSession.profile != null
        ? Future<void>.value()
        : Di.userSession.refresh().then((_) {}).catchError((_) {});
    // 최근 소식 피드는 '지금 보는 그룹'의 알림만 보여줘야 하는데 /notifications 는
    // 전 그룹을 섞어서 내려준다. 그래서 넉넉히 받아(아래에서 groupRoomId 로 필터) 8건만
    // 추린다.
    final notiFuture = Di.notificationRepository
        .list(limit: 100, offset: 0)
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
      // 어떤 경로로 들어왔든 삭제 예정 그룹이면 홈 대시보드를 그리지 않는다.
      // 자동 이동은 뒤로가기 시 다시 튕겨 들어가는 트랩이 되므로, 인라인 안내 +
      // '그룹 관리로 이동' 버튼만 노출한다. (실제 진입 경로인 그룹 전환/리스트는
      // 각각 /manage-diary 로 직접 보낸다)
      if (detail.groupRoom.deleteScheduledAt != null) {
        if (!mounted) return;
        Di.activeGroup.enter(
          groupRoomId: detail.groupRoom.id,
          groupRoomName: detail.groupRoom.name,
          isOwner: detail.isOwner,
          isDeleteScheduled: true,
        );
        setState(() {
          _loading = false;
          _deleteScheduledBlock = true;
        });
        return;
      }
      final noti = await notiFuture;
      final schedules = await scheduleFuture;
      final diaryRes = await diaryFuture;
      await profileFuture; // 이름 채우기 (best-effort)
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

      // 2.0.0 인당 하루 1편 — 작성 버튼 차단은 "내가" 오늘 썼는지로 판정한다.
      final myId = Di.userSession.profile?.id;
      final myTodayDiary = myId != null &&
          diaryRes.diaries.any(
              (d) => dateOnly(d.date) == today && d.createdBy.id == myId);

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
      // 최초 5개만 보이고 '더보기'로 10개씩 추가 노출한다.
      final groupActivity = noti.notifications
          .where((n) => n.groupRoomId == activeId)
          .toList();
      setState(() {
        _home = home;
        _activity = groupActivity;
        _activityVisible = 5;
        _todayHasDiary = myTodayDiary;
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

  /// 일기 쓰기 — 인당 하루 한 편(2.0.0). 내가 오늘 이미 썼으면 안내 팝업을 띄운다.
  void _handleWriteDiary() {
    if (_todayHasDiary) {
      showInfoDialog(
        context,
        '오늘 일기를 이미 썼어요',
        '그림일기는 한 사람당 하루에 한 편만 쓸 수 있어요.\n오늘 일기는 그림일기 탭에서 확인하거나 수정할 수 있어요.',
      );
      return;
    }
    _goThenReload('/write-diary');
  }

  /// 그룹 전환 시트 — 내 그룹 목록을 띄우고 선택 시 활성 그룹을 바꿔 홈을 갱신.
  Future<void> _openGroupSwitcher() async {
    List<GroupRoomListItem> groups;
    try {
      groups = await Di.groupRoomRepository.myList();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessageOf(e), isError: true);
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
                  final scheduled = g.isDeleteScheduled;
                  return ListTile(
                    leading: Opacity(
                      opacity: scheduled ? 0.45 : 1,
                      child: (g.thumbnailImage != null &&
                              g.thumbnailImage!.isNotEmpty)
                          ? CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              backgroundImage: NetworkImage(g.thumbnailImage!),
                            )
                          : const GroupDefaultAvatar(size: 40),
                    ),
                    title: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                        color: scheduled ? AppColors.gray400 : AppColors.gray900,
                      ),
                    ),
                    subtitle: Text(
                      scheduled ? '삭제 예정' : '${g.memberCount}명',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight:
                            scheduled ? FontWeight.w600 : FontWeight.w400,
                        color: scheduled ? AppColors.primary : AppColors.gray500,
                      ),
                    ),
                    trailing: scheduled
                        ? const Icon(Icons.lock_clock_rounded,
                            color: AppColors.gray400, size: 20)
                        : selected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 20)
                            : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (g.id == activeId) return;
                      // 삭제 예정 그룹은 홈으로 진입시키지 않고 그룹 관리(복구) 화면으로
                      // 보낸다. (그룹 리스트의 _enterGroup 과 동일한 정책)
                      Di.activeGroup.enter(
                        groupRoomId: g.id,
                        groupRoomName: g.name,
                        isOwner: g.isOwner,
                        isDeleteScheduled: g.isDeleteScheduled,
                      );
                      if (g.isDeleteScheduled) {
                        Navigator.of(context)
                            .pushNamed('/manage-diary')
                            .then((_) => _load());
                      } else {
                        _load();
                      }
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

  /// 그룹 멤버 목록 시트 — 전체 멤버를 이름과 함께 보여주고, 내가 차단한 멤버는
  /// '차단됨' 배지로 표시한다(목록에서 빼지 않고 그대로 노출).
  void _openMemberSheet(ActiveGroupSummary group) {
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
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '그룹 멤버 (${group.memberCount}명)',
                  style: const TextStyle(
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
                itemCount: group.members.length,
                itemBuilder: (_, i) {
                  final m = group.members[i];
                  final blocked =
                      m.userId != null && _blockedUserIds.contains(m.userId);
                  final color = _avatarColors[i % _avatarColors.length];
                  return ListTile(
                    leading: Opacity(
                      opacity: blocked ? 0.4 : 1,
                      child: _MemberSheetAvatar(member: m, color: color),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color:
                                  blocked ? AppColors.gray400 : AppColors.gray900,
                            ),
                          ),
                        ),
                        if (m.role == 'owner') ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.workspace_premium_rounded,
                              size: 16, color: Color(0xFFC89A00)),
                        ],
                        if (blocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '차단됨',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: blocked
                        ? const Text(
                            '차단한 멤버예요. 마이페이지에서 해제할 수 있어요.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.gray400,
                            ),
                          )
                        : null,
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
      showAppSnackBar(context, errorMessageOf(e), isError: true);
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
                _handleWriteDiary();
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
    final blocked = _loading ||
        _errorMessage != null ||
        _deleteScheduledBlock ||
        _restrictedBlock;
    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      floatingActionButton:
          blocked ? null : HomeCreateFab(onTap: _openCreateSheet),
      // 히어로 그라데이션이 상태바 뒤까지 올라가야 해서 body 를 SafeArea 로 감싸지
      // 않는다. 상단 여백은 히어로가 MediaQuery.padding.top 으로 직접 잡고,
      // 정상 화면이 아닌 상태(로딩·에러·차단)만 SafeArea 를 쓴다.
      body: blocked
          ? SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _restrictedBlock
                      ? _buildRestrictedBlock()
                      : _deleteScheduledBlock
                          ? _buildDeleteScheduledBlock()
                          : _buildError(),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final home = _home!;
    final group = home.activeGroup;
    return GroupHomeView(
      userName: home.userName,
      today: home.today,
      group: group,
      ledger: _ledger,
      blockedUserIds: _blockedUserIds,
      activity: _activity.take(_activityVisible).toList(),
      activityTotal: _activity.length,
      noticeMessage: _appConfig.showNotice ? _appConfig.noticeMessage : '',
      avatarColors: _avatarColors,
      onRefresh: _load,
      onSettings: () => _go('/my-page'),
      onSwitchGroup: _openGroupSwitcher,
      onMembers: () => _openMemberSheet(group),
      onSchedule: () => _go('/schedule'),
      onDiary: () => _go('/diary'),
      onLedger: () => _goThenReload('/ledger'),
      onCharacter: () => _go('/character'),
      onTodo: () => _go('/todo'),
      onGroupSettings: () => _goThenReload('/update-diary'),
      onTransferOwner: () =>
          _goThenReload('/transfer-owner', arguments: group.name),
      onWriteDiary: _handleWriteDiary,
      onAddSchedule: () => _goThenReload('/add-schedule'),
      onQuiz: () => _go('/character-quiz-play'),
      onInvite: _generateInvite,
      onNotifications: () => _goThenReload('/notifications'),
      onActivityInfo: () => showInfoDialog(
        context,
        '최근 소식',
        '최근 소식에서는 그룹별 알림 및 주요 공지사항을 확인할 수 있습니다.',
      ),
      onMoreActivity: () => setState(() => _activityVisible += 10),
    );
  }

  /// 이용 제한 계정일 때 홈 대신 노출하는 안내 — 마이페이지로만 이동 가능.
  Widget _buildRestrictedBlock() {
    return RestrictionNotice(
      onGoMyPage: () =>
          Navigator.of(context).pushNamed('/my-page').then((_) => _load()),
    );
  }

  /// 활성 그룹이 삭제 예정일 때 홈 대신 노출하는 안내 — 접근 차단 + 관리 화면 진입.
  Widget _buildDeleteScheduledBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_rounded, size: 48, color: AppColors.gray400),
            const SizedBox(height: 12),
            const Text(
              '삭제 예정인 그룹이에요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '이 그룹은 삭제 예정 상태라 들어갈 수 없어요.\n그룹 관리에서 복구하거나 다른 그룹을 선택해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamed('/manage-diary')
                  .then((_) => _load()),
              child: const Text(
                '그룹 관리로 이동',
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

/// 멤버 목록 시트용 원형 아바타(44px). 프로필 이미지 없으면 이니셜 표시.
class _MemberSheetAvatar extends StatelessWidget {
  const _MemberSheetAvatar({required this.member, required this.color});
  final MembershipSummary member;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final img = member.profileImage;
    final initial = member.name.isNotEmpty ? member.name.substring(0, 1) : '?';
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
      ),
      child: (img != null && img.isNotEmpty)
          ? Image.network(
              img,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(initial),
            )
          : _fallback(initial),
    );
  }

  Widget _fallback(String initial) => Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: color,
          ),
        ),
      );
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
