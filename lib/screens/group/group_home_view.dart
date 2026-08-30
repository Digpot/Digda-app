import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/money.dart';
import '../../features/group_room/models/group_room_models.dart';
import '../../features/ledger/models/ledger_models.dart';
import '../../features/notification/models/notification_models.dart';
import '../../theme/colors.dart';
import '../../widgets/notice_banner.dart';
import '../../widgets/notification_bell_icon.dart';

/// 그룹 홈의 **표현 계층**. 데이터 로딩·다이얼로그는 `GroupHomeScreen` 이 맡고,
/// 여기는 받은 값을 그리기만 한다. 화면 상태를 인자로만 받으므로 로딩 분기에
/// 걸리지 않고 홈 UI 만 따로 띄워 확인할 수 있다.
///
/// 레이아웃(위 → 아래)
///  1. 히어로 — 상태바까지 덮는 코랄 그라데이션. 인사 + 그룹 패널 + 오늘 지표.
///  2. 다음 일정 카드 — 히어로 아래 걸쳐 뜬다(겹침이 깊이를 만든다).
///  3. 이번 달 지출 / 빠른 작업 / 그룹 기능 벤토 / 최근 소식 타임라인.
class GroupHomeView extends StatefulWidget {
  const GroupHomeView({
    super.key,
    required this.userName,
    required this.today,
    required this.group,
    required this.ledger,
    required this.blockedUserIds,
    required this.activity,
    required this.activityTotal,
    required this.noticeMessage,
    required this.avatarColors,
    required this.onRefresh,
    required this.onSettings,
    required this.onSwitchGroup,
    required this.onMembers,
    required this.onSchedule,
    required this.onDiary,
    required this.onLedger,
    required this.onCharacter,
    required this.onTodo,
    required this.onGroupSettings,
    required this.onTransferOwner,
    required this.onWriteDiary,
    required this.onAddSchedule,
    required this.onQuiz,
    required this.onInvite,
    required this.onNotifications,
    required this.onActivityInfo,
    required this.onMoreActivity,
  });

  final String userName;
  final TodaySummary today;
  final ActiveGroupSummary group;
  final LedgerSummary? ledger;
  final Set<String> blockedUserIds;

  /// 화면에 그릴 소식(이미 잘라서 넘어온다).
  final List<AppNotification> activity;

  /// 전체 소식 수 — [activity] 보다 많으면 '더보기'가 뜬다.
  final int activityTotal;

  /// 대공지. 비어 있으면 배너를 그리지 않는다.
  final String noticeMessage;

  final List<Color> avatarColors;

  final Future<void> Function() onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onSwitchGroup;
  final VoidCallback onMembers;
  final VoidCallback onSchedule;
  final VoidCallback onDiary;
  final VoidCallback onLedger;
  final VoidCallback onCharacter;
  final VoidCallback onTodo;
  final VoidCallback onGroupSettings;
  final VoidCallback onTransferOwner;
  final VoidCallback onWriteDiary;
  final VoidCallback onAddSchedule;
  final VoidCallback onQuiz;
  final VoidCallback onInvite;
  final VoidCallback onNotifications;
  final VoidCallback onActivityInfo;
  final VoidCallback onMoreActivity;

  @override
  State<GroupHomeView> createState() => _GroupHomeViewState();
}

class _GroupHomeViewState extends State<GroupHomeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// 등장 애니메이션 — 위에서부터 순서대로 떠오른다. [order] 가 클수록 늦게 시작한다.
  /// 스크롤로 사라지는 요소까지 감싸면 오히려 어수선해서 첫 화면 블록에만 쓴다.
  Widget _rise(int order, Widget child) {
    final start = (order * 0.09).clamp(0.0, 0.6);
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (_, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - curve.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 히어로가 진한 코랄이라 상태바 아이콘은 흰색이어야 보인다.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.primary,
        // 히어로가 상태바까지 올라가 있어 기본 위치면 스피너가 노치에 가린다.
        edgeOffset: MediaQuery.of(context).padding.top + 8,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _rise(
              0,
              _HeroBlock(
                userName: widget.userName,
                today: widget.today,
                group: group,
                blockedUserIds: widget.blockedUserIds,
                avatarColors: widget.avatarColors,
                onSettings: widget.onSettings,
                onSwitchGroup: widget.onSwitchGroup,
                onMembers: widget.onMembers,
                onSchedule: widget.onSchedule,
                onDiary: widget.onDiary,
                onNotifications: widget.onNotifications,
              ),
            ),
            const SizedBox(height: 22),
            if (widget.noticeMessage.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NoticeBanner(message: widget.noticeMessage),
              ),
              const SizedBox(height: 22),
            ],
            _rise(
              2,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child:
                    _LedgerCard(summary: widget.ledger, onTap: widget.onLedger),
              ),
            ),
            const SizedBox(height: 28),
            _rise(
              3,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _QuickChips(
                  isOwner: group.isOwner,
                  onDiary: widget.onWriteDiary,
                  onSchedule: widget.onAddSchedule,
                  onQuiz: widget.onQuiz,
                  onInvite: widget.onInvite,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeader('우리 그룹', caption: '함께 쓰는 기능들'),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _BentoGrid(
                isOwner: group.isOwner,
                onSchedule: widget.onSchedule,
                onLedger: widget.onLedger,
                onDiary: widget.onDiary,
                onCharacter: widget.onCharacter,
                onTodo: widget.onTodo,
                onGroupSettings: widget.onGroupSettings,
                onTransferOwner: widget.onTransferOwner,
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeader(
                '최근 소식',
                caption: '우리 그룹에서 일어난 일',
                onInfo: widget.onActivityInfo,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ActivityTimeline(
                items: widget.activity,
                onItemTap: widget.onNotifications,
                onEmptyCta: widget.onWriteDiary,
              ),
            ),
            if (widget.activityTotal > widget.activity.length) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: widget.onMoreActivity,
                  child: Text(
                    '${widget.activityTotal - widget.activity.length}개 더 보기',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 90), // FAB / 하단 탭에 마지막 항목이 가리지 않게
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ① 히어로 — 상태바까지 덮는 그라데이션 + 다음 일정 카드 겹침
// ────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.userName,
    required this.today,
    required this.group,
    required this.blockedUserIds,
    required this.avatarColors,
    required this.onSettings,
    required this.onSwitchGroup,
    required this.onMembers,
    required this.onSchedule,
    required this.onDiary,
    required this.onNotifications,
  });

  final String userName;
  final TodaySummary today;
  final ActiveGroupSummary group;
  final Set<String> blockedUserIds;
  final List<Color> avatarColors;
  final VoidCallback onSettings;
  final VoidCallback onSwitchGroup;
  final VoidCallback onMembers;
  final VoidCallback onSchedule;
  final VoidCallback onDiary;
  final VoidCallback onNotifications;

  /// 시간대에 맞춘 인사 — 하루 종일 "안녕하세요"만 뜨면 화면이 살아 있지 않다.
  static (String, String) _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return ('늦은 밤이에요', '🌙');
    if (h < 11) return ('좋은 아침이에요', '☀️');
    if (h < 17) return ('오늘도 반가워요', '👋');
    if (h < 21) return ('오늘 하루 어땠어요', '🌆');
    return ('편안한 밤 되세요', '🌙');
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final name = userName.isNotEmpty ? userName : '회원';
    final (hello, emoji) = _greeting();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 카드가 아래로 걸쳐 나오도록 그라데이션 아래에 여백을 만들어 둔다.
        Padding(
          padding: const EdgeInsets.only(bottom: 46),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF9A76),
                  AppColors.primary,
                  Color(0xFFF9527F),
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(34)),
              child: Stack(
                children: [
                  // 배경 장식 — 흐릿한 원 두 개. 단색 그라데이션만 있으면 평평해 보인다.
                  const Positioned(
                    right: -54,
                    top: -34,
                    child: _Blob(size: 176, opacity: 0.16),
                  ),
                  const Positioned(
                    left: -46,
                    bottom: -66,
                    child: _Blob(size: 158, opacity: 0.12),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad + 10, 20, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단 바 — 벨/설정. 밝은 배경 위 흰 아이콘이라 원형 글래스로 감싼다.
                        Row(
                          children: [
                            const Spacer(),
                            const _GlassIconSlot(
                              child: NotificationBellIcon(color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            _GlassIconSlot(
                              onTap: onSettings,
                              child: const Icon(Icons.settings_outlined,
                                  size: 21, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$hello $emoji',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Inter 는 400/700 만 번들돼 있다. 위계는 굵기가 아니라
                        // 크기·자간·색으로 만든다.
                        Text(
                          '$name님',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 30,
                            height: 1.15,
                            letterSpacing: -0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _GroupPanel(
                          group: group,
                          blockedUserIds: blockedUserIds,
                          avatarColors: avatarColors,
                          onSwitch: onSwitchGroup,
                          onMembers: onMembers,
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          today: today,
                          onSchedules: onSchedule,
                          onDiaries: onDiary,
                          onUnread: onNotifications,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 0,
          child: _NextEventCard(event: group.nextEvent, onTap: onSchedule),
        ),
      ],
    );
  }
}

/// 히어로 배경의 흐릿한 빛무리. 진짜 블러(BackdropFilter)는 비용이 커서
/// 가장자리로 갈수록 투명해지는 방사형 그라데이션으로 대신한다.
/// 단색 원 + 테두리로 그렸더니 링이 또렷하게 보여 장식이 아니라 얼룩처럼 읽혔다.
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: opacity * 0.5),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

/// 히어로 위 아이콘 자리 — 38×38 반투명 원. 벨/설정을 같은 크기로 묶어 정렬을 맞춘다.
class _GlassIconSlot extends StatelessWidget {
  const _GlassIconSlot({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: IconTheme(
              data: const IconThemeData(color: Colors.white, size: 21),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 히어로 안 그룹 패널 — 그룹 이름 · 멤버 · 전환 버튼.
class _GroupPanel extends StatelessWidget {
  const _GroupPanel({
    required this.group,
    required this.blockedUserIds,
    required this.avatarColors,
    required this.onSwitch,
    required this.onMembers,
  });

  final ActiveGroupSummary group;
  final Set<String> blockedUserIds;
  final List<Color> avatarColors;
  final VoidCallback onSwitch;
  final VoidCallback onMembers;

  bool _isBlocked(MembershipSummary m) =>
      m.userId != null && blockedUserIds.contains(m.userId);

  @override
  Widget build(BuildContext context) {
    final shown = group.members.take(4).toList();
    final extra = group.memberCount - shown.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지금 보는 그룹',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        letterSpacing: 0.4,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        height: 1.2,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onSwitch,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 7, 8, 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '전환',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        Icon(Icons.expand_more_rounded,
                            size: 17, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onMembers,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  // 아바타를 겹쳐 쌓는다 — 나열보다 '팀'처럼 보인다.
                  SizedBox(
                    height: 30,
                    width: shown.isEmpty
                        ? 0
                        : 30 + (shown.length - 1) * 21 + (extra > 0 ? 21 : 0),
                    child: Stack(
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          Positioned(
                            left: i * 21,
                            child: Opacity(
                              opacity: _isBlocked(shown[i]) ? 0.45 : 1,
                              child: _Avatar(
                                member: shown[i],
                                color: avatarColors[i % avatarColors.length],
                                blocked: _isBlocked(shown[i]),
                              ),
                            ),
                          ),
                        if (extra > 0)
                          Positioned(
                            left: shown.length * 21,
                            child: Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.34),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.6),
                              ),
                              child: Text(
                                '+$extra',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${group.memberCount}명 함께',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.member,
    required this.color,
    this.blocked = false,
  });
  final MembershipSummary member;
  final Color color;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final img = member.profileImage;
    final avatar = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child: ClipOval(
        child: (img != null && img.isNotEmpty)
            ? Image.network(
                img,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
    if (!blocked) return avatar;
    // 차단된 멤버 — 작은 차단 배지를 우하단에 겹쳐 표시한다.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: const Icon(Icons.block, size: 7, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _fallback() {
    final initial = member.name.isNotEmpty ? member.name.substring(0, 1) : '?';
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }
}

/// 오늘 지표 3칸 — 히어로 위에 올리는 반투명 타일.
class _StatRow extends StatelessWidget {
  const _StatRow({
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
          child: _StatTile(
            count: today.scheduleCount,
            label: '오늘 일정',
            icon: Icons.event_rounded,
            onTap: onSchedules,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            count: today.newDiaryCount,
            label: '새 일기',
            icon: Icons.auto_stories_rounded,
            onTap: onDiaries,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            count: today.unreadCount,
            label: '안 읽음',
            icon: Icons.notifications_rounded,
            onTap: onUnread,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.count,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final int count;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      height: 1.0,
                      letterSpacing: -1.0,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Icon(icon,
                      size: 14, color: Colors.white.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.88),
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
//  ② 다음 일정 — 히어로에 걸쳐 뜨는 흰 카드
// ────────────────────────────────────────────────────────────

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({required this.event, required this.onTap});
  final HomeNextEvent? event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        // 컬러 글로우 대신 중립 그림자 — 색 있는 그림자는 카드를 띄우는 대신
        // 아래 배경을 탁하게 만든다.
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B1B2F).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: e == null
                          ? const [AppColors.gray100, AppColors.gray50]
                          : const [Color(0xFFFFB199), AppColors.primary],
                    ),
                  ),
                  child: Icon(
                    e == null
                        ? Icons.event_busy_rounded
                        : Icons.event_available_rounded,
                    size: 21,
                    color: e == null ? AppColors.gray400 : Colors.white,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: e == null
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '다가오는 일정',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                fontSize: 11,
                                color: AppColors.gray400,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '아직 잡힌 일정이 없어요',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.3,
                                color: AppColors.gray500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _whenLabel(e),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.2,
                                letterSpacing: -0.4,
                                color: AppColors.gray900,
                              ),
                            ),
                          ],
                        ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 22, color: AppColors.gray300),
              ],
            ),
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
//  ③ 이번 달 지출
// ────────────────────────────────────────────────────────────

/// 홈에서 보는 가계부 한 줄 — 이번 달 총액과 건수만.
/// 분류·사람별 집계는 전체 가계부 화면 몫이다.
class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.summary, required this.onTap});

  final LedgerSummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = summary?.totalAmount ?? 0;
    final count = summary?.entryCount ?? 0;
    final month = DateTime.now().month;
    final empty = count == 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            // 잉크빛 카드 — 화면에서 유일하게 어두운 면이라 금액이 저절로 눈에 든다.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF232A38), Color(0xFF141922)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF141922).withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.ledgerEtc.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 13,
                              color: AppColors.ledgerEtc),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$month월에 우리가 쓴 돈',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        empty ? '아직 기록이 없어요' : formatWon(total),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: empty ? 17 : 27,
                          height: 1.1,
                          letterSpacing: empty ? -0.3 : -1.2,
                          color: empty
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!empty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count건',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Colors.white.withValues(alpha: 0.55)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ④ 빠른 작업 — 알약 칩
// ────────────────────────────────────────────────────────────

class _QuickChips extends StatelessWidget {
  const _QuickChips({
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          icon: Icons.edit_rounded,
          label: '일기 쓰기',
          tint: const Color(0xFFD98A00),
          onTap: onDiary,
        ),
        _Chip(
          icon: Icons.add_rounded,
          label: '일정 추가',
          tint: AppColors.primary,
          onTap: onSchedule,
        ),
        _Chip(
          icon: Icons.auto_awesome_rounded,
          label: '퀴즈',
          tint: const Color(0xFF8B5CF6),
          onTap: onQuiz,
        ),
        // 초대 코드 발급은 방장만 (서버도 NOT_GROUP_ROOM_OWNER 로 막는다).
        if (isOwner)
          _Chip(
            icon: Icons.person_add_alt_1_rounded,
            label: '초대',
            tint: const Color(0xFF3B82F6),
            onTap: onInvite,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tint.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  letterSpacing: -0.2,
                  color: tint,
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
//  ⑤ 그룹 기능 — 벤토 그리드
// ────────────────────────────────────────────────────────────

/// 전폭 카드를 세로로 쌓으면 스크롤만 길어지고 무엇이 중요한지 안 보인다.
/// 2열 그리드에 높이를 달리 줘서 자주 쓰는 기능(일정·가계부)을 크게 잡았다.
class _BentoGrid extends StatelessWidget {
  const _BentoGrid({
    required this.isOwner,
    required this.onSchedule,
    required this.onLedger,
    required this.onDiary,
    required this.onCharacter,
    required this.onTodo,
    required this.onGroupSettings,
    required this.onTransferOwner,
  });

  final bool isOwner;
  final VoidCallback onSchedule;
  final VoidCallback onLedger;
  final VoidCallback onDiary;
  final VoidCallback onCharacter;
  final VoidCallback onTodo;
  final VoidCallback onGroupSettings;
  final VoidCallback onTransferOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BentoTile(
                icon: Icons.calendar_month_rounded,
                title: '일정 관리',
                caption: '우리 모임 일정을\n한눈에',
                tint: AppColors.primary,
                height: 148,
                onTap: onSchedule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoTile(
                icon: Icons.account_balance_wallet_rounded,
                title: '우리 가계부',
                caption: '일정에 쓴 돈을\n한눈에',
                tint: const Color(0xFF2F9A76),
                height: 148,
                onTap: onLedger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BentoTile(
                icon: Icons.auto_stories_rounded,
                title: '그림일기',
                caption: '오늘의 추억',
                tint: const Color(0xFFD98A00),
                height: 108,
                onTap: onDiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoTile(
                icon: Icons.favorite_rounded,
                title: '모찌 키우기',
                caption: '함께 키워요',
                tint: const Color(0xFFEC4899),
                height: 108,
                onTap: onCharacter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BentoTile(
                icon: Icons.check_circle_rounded,
                title: '투두리스트',
                caption: '할 일 관리',
                tint: const Color(0xFF3B82F6),
                height: 108,
                onTap: onTodo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isOwner
                  ? _BentoTile(
                      icon: Icons.tune_rounded,
                      title: '그룹 설정',
                      caption: '정보·멤버 관리',
                      tint: AppColors.gray600,
                      height: 108,
                      onTap: onGroupSettings,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        if (isOwner) ...[
          const SizedBox(height: 12),
          // Column 안에서는 폭 제약이 없어 타일이 내용 너비로 줄고 가운데 놓인다.
          // 전폭으로 깔려야 다른 줄과 왼쪽 끝이 맞는다.
          SizedBox(
            width: double.infinity,
            child: _BentoTile(
              icon: Icons.swap_horiz_rounded,
              title: '방장 양도',
              caption: '다른 멤버에게 방장을 넘겨요',
              tint: const Color(0xFF8B5CF6),
              height: 96,
              wide: true,
              onTap: onTransferOwner,
            ),
          ),
        ],
      ],
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.tint,
    required this.height,
    required this.onTap,
    this.wide = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color tint;
  final double height;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: 0.13),
                tint.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(color: tint.withValues(alpha: 0.15)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // 잘려 나가는 큰 고스트 아이콘 — 타일마다 다른 실루엣이 생겨
                // 같은 크기 사각형이 줄줄이 이어지는 느낌을 깬다.
                Positioned(
                  right: wide ? 18 : -14,
                  bottom: -16,
                  child:
                      Icon(icon, size: 84, color: tint.withValues(alpha: 0.08)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: tint.withValues(alpha: 0.32),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 19, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          height: 1.2,
                          letterSpacing: -0.4,
                          color: AppColors.gray900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        caption,
                        maxLines: wide ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ⑥ 최근 소식 — 타임라인
// ────────────────────────────────────────────────────────────

/// 회색 상자를 쌓는 대신 세로 레일 + 점으로 잇는다. 소식은 '목록'이 아니라
/// '흐름'이라 시간 순서가 눈에 보여야 하고, 박스가 사라지면 화면도 가벼워진다.
class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({
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
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gray100),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.waving_hand_rounded,
                  size: 24, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text(
              '아직 새 소식이 없어요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: -0.3,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '첫 기록을 남기면 여기에 쌓여요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 12.5,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onEmptyCta,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    '첫 일기 남기기',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _ActivityNode(
            notification: items[i],
            isLast: i == items.length - 1,
            onTap: onItemTap,
          ),
      ],
    );
  }
}

class _ActivityNode extends StatelessWidget {
  const _ActivityNode({
    required this.notification,
    required this.isLast,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isLast;
  final VoidCallback onTap;

  (IconData, Color) get _skin {
    final type = notification.type;
    if (type.contains('diary')) {
      return (Icons.auto_stories_rounded, const Color(0xFFEC4899));
    }
    if (type.contains('schedule')) {
      return (Icons.event_available_rounded, const Color(0xFF3B82F6));
    }
    if (type.contains('comment')) {
      return (Icons.mode_comment_rounded, const Color(0xFF8B5CF6));
    }
    if (type.contains('member') || type.contains('join')) {
      return (Icons.person_add_alt_1_rounded, const Color(0xFF2F9A76));
    }
    if (type.contains('quiz') ||
        type.contains('mochi') ||
        type.contains('diko')) {
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 레일 — 아이콘 칩과 아래로 이어지는 실선.
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: unread ? 0.14 : 0.07),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: unread ? 0.28 : 0.0),
                    ),
                  ),
                  child: Icon(icon,
                      size: 16,
                      color: unread ? color : color.withValues(alpha: 0.45)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: AppColors.gray100),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(2, 2, 2, isLast ? 2 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title.isNotEmpty
                                  ? notification.title
                                  : notification.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                letterSpacing: -0.2,
                                color: unread
                                    ? AppColors.gray900
                                    : AppColors.gray600,
                              ),
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
                          // 안 읽은 소식 표시 — 배경색을 통째로 바꾸는 대신 점 하나로.
                          if (unread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  공용
// ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.caption, this.onInfo});
  final String title;
  final String caption;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목 왼쪽 액센트 바 — 굵기로 위계를 못 주는 대신 색으로 준다.
        Container(
          width: 3,
          height: 34,
          margin: const EdgeInsets.only(top: 2, right: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  height: 1.2,
                  letterSpacing: -0.5,
                  color: AppColors.gray900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
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
        if (onInfo != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onInfo,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.info_outline_rounded,
                  size: 17, color: AppColors.gray400),
            ),
          ),
      ],
    );
  }
}

/// 홈 FAB — 원형 그라데이션. 기본 FAB 의 단색 + Material 그림자보다
/// 히어로의 코랄 그라데이션과 결이 맞는다.
class HomeCreateFab extends StatelessWidget {
  const HomeCreateFab({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9A76), Color(0xFFF9527F)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
      ),
    );
  }
}
