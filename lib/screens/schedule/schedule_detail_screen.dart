import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/block/models/block_models.dart';
import '../../features/common/models/common_models.dart';
import '../../features/report/models/report_models.dart';
import '../../features/schedule/models/schedule_models.dart';
import '../../theme/colors.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/report_block_actions.dart';

class ScheduleDetailScreen extends StatefulWidget {
  const ScheduleDetailScreen({super.key});

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  bool _showMenu = false;
  bool _loading = true;
  bool _argsConsumed = false;
  String? _errorMessage;
  ScheduleDetail? _detail;
  String? _scheduleId;
  final TextEditingController _commentController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsConsumed) return;
    _argsConsumed = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _scheduleId = args;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groupId = Di.activeGroup.groupRoomId;
    final scheduleId = _scheduleId;
    if (groupId == null || scheduleId == null) {
      setState(() {
        _loading = false;
        _errorMessage = '일정 정보를 불러올 수 없어요';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await Di.scheduleRepository.detail(groupId, scheduleId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _onEditTap() async {
    setState(() => _showMenu = false);
    await Navigator.of(context)
        .pushNamed('/add-schedule', arguments: _scheduleId);
    if (!mounted) return;
    _load();
  }

  Future<void> _submitComment() async {
    final groupId = Di.activeGroup.groupRoomId;
    final scheduleId = _scheduleId;
    final text = _commentController.text.trim();
    if (groupId == null || scheduleId == null || text.isEmpty) return;
    // 전송 중 더블탭으로 같은 댓글이 두 번 등록되지 않도록, await 전에 비운다.
    // (두 번째 탭은 빈 텍스트로 즉시 반환) 실패 시 입력값을 복원한다.
    _commentController.clear();
    try {
      await Di.commentRepository.writeOnSchedule(
        groupRoomId: groupId,
        scheduleId: scheduleId,
        text: text,
      );
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _commentController.text = text;
      showErrorDialog(context, errorMessageOf(e));
    }
  }

  void _onDeleteTap() {
    setState(() => _showMenu = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '일정 삭제',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '이 일정을 삭제하시겠습니까?',
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
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.gray500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final groupId = Di.activeGroup.groupRoomId;
              final scheduleId = _scheduleId;
              if (groupId == null || scheduleId == null) {
                Navigator.of(context).pop();
                return;
              }
              try {
                await Di.scheduleRepository.delete(groupId, scheduleId);
                if (!mounted) return;
                Navigator.of(context).pop();
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, errorMessageOf(e));
              }
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

  bool get _isMine {
    final by = _detail?.schedule.createdBy.id;
    final myId = Di.userSession.profile?.id;
    return by != null && myId != null && by == myId;
  }

  /// 신고/숨김/차단 후 — 목록 캐시를 비우고 일정 화면을 닫는다(일정은 목록에서 제외됨).
  void _afterHidden() {
    Di.scheduleRepository.invalidateCaches();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _onReportSchedule() async {
    setState(() => _showMenu = false);
    final s = _detail?.schedule;
    if (s == null) return;
    final ok = await showReportSheet(
      context,
      targetType: ReportTargetType.schedule,
      targetId: s.id,
      groupRoomId: Di.activeGroup.groupRoomId,
    );
    if (ok) _afterHidden();
  }

  Future<void> _onHideSchedule() async {
    setState(() => _showMenu = false);
    final s = _detail?.schedule;
    if (s == null) return;
    final ok = await hideContentAction(
      context,
      type: HideTargetType.schedule,
      targetId: s.id,
      noun: '일정',
    );
    if (ok) _afterHidden();
  }

  Future<void> _onBlockScheduleAuthor() async {
    setState(() => _showMenu = false);
    final s = _detail?.schedule;
    if (s == null) return;
    final ok = await confirmBlockUser(
      context,
      userId: s.createdBy.id,
      userName: s.createdBy.name,
    );
    if (ok) _afterHidden();
  }

  /// 일정 댓글 더보기 — 신고/숨기기/작성자 차단. 성공 시 상세 재로드.
  Future<void> _onCommentAction(CommentEntity comment) async {
    final myId = Di.userSession.profile?.id;
    if (myId != null && comment.createdBy.id == myId) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleCommentActionSheet(
        authorName: comment.createdBy.name,
      ),
    );
    if (!mounted || action == null) return;
    bool ok = false;
    switch (action) {
      case 'report':
        ok = await showReportSheet(
          context,
          targetType: ReportTargetType.comment,
          targetId: comment.id,
          groupRoomId: Di.activeGroup.groupRoomId,
        );
        break;
      case 'hide':
        ok = await hideContentAction(
          context,
          type: HideTargetType.comment,
          targetId: comment.id,
          noun: '댓글',
        );
        break;
      case 'block':
        ok = await confirmBlockUser(
          context,
          userId: comment.createdBy.id,
          userName: comment.createdBy.name,
        );
        break;
    }
    if (ok && mounted) _load();
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : AppColors.primary;
  }

  /// '14:00' → '오후 2시', '14:30' → '오후 2시 30분'.
  String _formatKoreanTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final period = h < 12 ? '오전' : '오후';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    if (m == 0) return '$period $hour12시';
    return '$period $hour12시 ${m.toString().padLeft(2, '0')}분';
  }

  String _formatDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.year}년 ${d.month}월 ${d.day}일 (${weekdays[d.weekday - 1]})';
  }

  String _formatCommentTime(DateTime t) {
    final local = t.toLocal();
    final h = local.hour;
    final m = local.minute;
    final period = h < 12 ? '오전' : '오후';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$period $hour12:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      // 하단은 SafeArea 로 인셋을 소비하지 않고, 댓글 입력바가 직접
      // MediaQuery.padding.bottom 을 더해 화면 바닥에 밀착시킨다.
      // (소비해 버리면 입력바가 시스템 인셋만큼 위로 떠 아래에 빈 공간이 생김 —
      //  일기 상세 화면과 동일한 도킹 방식으로 통일)
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
                // 배너 광고 — 스크롤 밖, 댓글바 바로 위 고정.
                // (스크롤 안에 두면 내용이 짧을 때 화면 중간에 떠 버린다)
                const AdBanner(padding: EdgeInsets.only(top: 8)),
                _buildBottomCommentBar(),
              ],
            ),
            if (_showMenu) ...[
              GestureDetector(
                onTap: () => setState(() => _showMenu = false),
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                top: 44,
                right: 24,
                child: _buildDropdownMenu(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
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
            '일정 상세',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.gray900,
            ),
          ),
          const Spacer(),
          if (_detail != null)
            GestureDetector(
              onTap: () => setState(() => _showMenu = !_showMenu),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.more_horiz,
                  size: 22,
                  color: AppColors.gray700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
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
                _errorMessage!,
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
    final detail = _detail!;
    final schedule = detail.schedule;
    final accent = _parseHex(schedule.color);
    String timeLabel;
    if (schedule.allDay) {
      timeLabel = '종일';
    } else if (schedule.startTime != null && schedule.endTime != null) {
      timeLabel =
          '${_formatKoreanTime(schedule.startTime!)} - ${_formatKoreanTime(schedule.endTime!)}';
    } else if (schedule.startTime != null) {
      timeLabel = _formatKoreanTime(schedule.startTime!);
    } else {
      timeLabel = '시간 미지정';
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event, size: 36, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            schedule.title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: accent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(schedule.startDate) +
                (schedule.endDate.isAtSameMomentAs(schedule.startDate)
                    ? ''
                    : ' ~ ${_formatDate(schedule.endDate)}'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.schedule,
                  text: timeLabel,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: schedule.participants.isEmpty
                      ? null
                      : () => _showParticipantPopup(schedule.participants),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 20,
                        color: AppColors.gray400,
                      ),
                      const SizedBox(width: 14),
                      if (schedule.participants.isEmpty)
                        const Text(
                          '참가자 없음',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 15,
                            color: AppColors.gray500,
                          ),
                        )
                      else
                        Expanded(child: _buildParticipantAvatars(schedule)),
                      if (schedule.participants.isNotEmpty)
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.gray400,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildComments(detail),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.gray400),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 15,
            color: AppColors.gray800,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantAvatars(Schedule schedule) {
    final participants = schedule.participants.take(4).toList();
    final more = schedule.participants.length - participants.length;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          ...List.generate(participants.length, (i) {
            final p = participants[i];
            final color = _avatarColor(i);
            return Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : -8),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: p.profileImage != null && p.profileImage!.isNotEmpty
                  ? Image.network(p.profileImage!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _initialAvatar(p.name, color))
                  : _initialAvatar(p.name, color),
            );
          }),
          if (more > 0) ...[
            const SizedBox(width: 6),
            Text(
              '+$more',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: AppColors.gray500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _avatarColor(int i) {
    const palette = [
      AppColors.primary,
      AppColors.blue,
      AppColors.green,
      AppColors.purple,
    ];
    return palette[i % palette.length];
  }

  Widget _initialAvatar(String name, Color color) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }

  void _showParticipantPopup(List<UserSummary> participants) {
    final me = Di.userSession.profile?.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 12,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '참여자 (${participants.length}명)',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(participants.length, (i) {
              final p = participants[i];
              return _buildParticipantRow(p, _avatarColor(i), p.id == me);
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantRow(UserSummary user, Color color, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: user.profileImage != null && user.profileImage!.isNotEmpty
                ? Image.network(user.profileImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _initialAvatar(user.name, color))
                : _initialAvatar(user.name, color),
          ),
          const SizedBox(width: 14),
          Text(
            user.name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: AppColors.gray900,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '나',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComments(ScheduleDetail detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '댓글 ${detail.comments.length}개',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 16),
          if (detail.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '아직 댓글이 없어요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppColors.gray400,
                  ),
                ),
              ),
            )
          else
            ...List.generate(detail.comments.length, (i) {
              final c = detail.comments[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildCommentItem(c, _avatarColor(i)),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentEntity c, Color avatarColor) {
    if (c.hidden) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_off_outlined,
                size: 16, color: AppColors.gray500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hiddenReasonMessage(c.hiddenReason, noun: '댓글'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final myId = Di.userSession.profile?.id;
    final canModerate = myId == null || c.createdBy.id != myId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: c.createdBy.profileImage != null &&
                  c.createdBy.profileImage!.isNotEmpty
              ? Image.network(c.createdBy.profileImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _initialAvatar(c.createdBy.name, avatarColor))
              : _initialAvatar(c.createdBy.name, avatarColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    c.createdBy.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatCommentTime(c.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                c.text,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
        ),
        if (canModerate)
          IconButton(
            onPressed: () => _onCommentAction(c),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.more_horiz,
                size: 18, color: AppColors.gray400),
          ),
      ],
    );
  }

  // 일기 상세(_MoreMenuOverlay) 와 동일한 팝오버 스타일.
  // 카드 폭/그림자/아이콘 박스/삭제 강조 톤을 맞춰 두 화면이 같은 더보기 메뉴를 갖도록 통일.
  Widget _buildDropdownMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MoreMenuRow(
              icon: Icons.edit_outlined,
              label: '수정하기',
              onTap: _onEditTap,
            ),
            const Divider(
              height: 8,
              thickness: 1,
              color: Color(0xFFF2F4F6),
              indent: 8,
              endIndent: 8,
            ),
            _MoreMenuRow(
              icon: Icons.delete_outline_rounded,
              label: '삭제하기',
              iconColor: const Color(0xFFFF6B6B),
              labelColor: const Color(0xFFFF6B6B),
              iconBg: const Color(0xFFFFEDED),
              onTap: _onDeleteTap,
            ),
            if (!_isMine) ...[
              const Divider(
                height: 8,
                thickness: 1,
                color: Color(0xFFF2F4F6),
                indent: 8,
                endIndent: 8,
              ),
              _MoreMenuRow(
                icon: Icons.visibility_off_outlined,
                label: '이 일정 숨기기',
                onTap: _onHideSchedule,
              ),
              _MoreMenuRow(
                icon: Icons.flag_outlined,
                label: '신고하기',
                onTap: _onReportSchedule,
              ),
              _MoreMenuRow(
                icon: Icons.block_outlined,
                label: '작성자 차단하기',
                iconColor: const Color(0xFFFF6B6B),
                labelColor: const Color(0xFFFF6B6B),
                iconBg: const Color(0xFFFFEDED),
                onTap: _onBlockScheduleAuthor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCommentBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16, 10, 16, MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _commentController,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.gray900,
                ),
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.gray400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _submitComment,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 일기 상세(diary_detail_screen.dart) 의 _MoreMenuRow 와 같은 모양.
// 두 화면 모두에서 동일한 더보기 메뉴 시각 톤을 유지하기 위해 동일하게 정의.
class _MoreMenuRow extends StatelessWidget {
  const _MoreMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF4E5968),
    this.labelColor = const Color(0xFF191F28),
    this.iconBg = const Color(0xFFF6F7F9),
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color labelColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 일정 댓글 더보기 액션 시트 — 신고/숨기기/작성자 차단. 선택 시 코드 문자열로 pop.
class _ScheduleCommentActionSheet extends StatelessWidget {
  const _ScheduleCommentActionSheet({required this.authorName});
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    Widget row(IconData icon, String label, String value, {Color? color}) {
      return InkWell(
        onTap: () => Navigator.of(context).pop(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color ?? AppColors.gray700),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: color ?? AppColors.gray900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(top: 12, bottom: 8 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          row(Icons.visibility_off_outlined, '이 댓글 숨기기', 'hide'),
          row(Icons.flag_outlined, '신고하기', 'report'),
          row(Icons.block_outlined, "'$authorName' 님 차단하기", 'block',
              color: AppColors.primary),
        ],
      ),
    );
  }
}
