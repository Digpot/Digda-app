import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/common/models/common_models.dart';
import '../../features/schedule/models/schedule_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

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
    try {
      await Di.commentRepository.writeOnSchedule(
        groupRoomId: groupId,
        scheduleId: scheduleId,
        text: text,
      );
      _commentController.clear();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
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
    final h = t.hour;
    final m = t.minute;
    final period = h < 12 ? '오전' : '오후';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$period $hour12:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
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
      ],
    );
  }

  Widget _buildDropdownMenu() {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _onEditTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.gray700),
                    SizedBox(width: 10),
                    Text(
                      '편집',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.gray900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.gray100,
            ),
            GestureDetector(
              onTap: _onDeleteTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text(
                      '삭제',
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
