import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/error_message.dart';
import '../../features/notification/models/notification_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<AppNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await Di.notificationRepository.list();
      if (!mounted) return;
      setState(() {
        _items = result.notifications;
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

  void _showToast(String message) {
    if (!mounted) return;
    showInfoDialog(context, '알림', message);
  }

  void _markAllRead() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '모두 읽음 처리',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.gray900,
          ),
        ),
        content: const Text(
          '모든 알림을 읽음 처리하시겠습니까?',
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Di.notificationRepository.markAllRead();
                if (!mounted) return;
                await _load();
                _showToast('모든 알림을 읽음 처리했어요');
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, errorMessageOf(e));
              }
            },
            child: const Text(
              '확인',
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

  Future<void> _onNotificationTap(AppNotification n) async {
    // 탭하면 다른 화면으로 이동시키지 않고 그 자리에서 읽음 처리만 한다.
    // (예전엔 팝업 띄우고 확인 후 그룹 홈/일정 상세로 점프했지만, 사용자가
    // 보던 알림 목록에서 갑자기 다른 화면으로 끌려가는 UX 가 어색했다.)
    if (n.isRead) return;
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((it) => it.id == n.id
              ? AppNotification(
                  id: it.id,
                  type: it.type,
                  title: it.title,
                  message: it.message,
                  groupRoomId: it.groupRoomId,
                  groupRoomName: it.groupRoomName,
                  relatedId: it.relatedId,
                  relatedType: it.relatedType,
                  isRead: true,
                  createdAt: it.createdAt,
                )
              : it)
          .toList();
    });
    Di.notificationRepository.markRead(n.id).ignore();
  }

  /// 와이어프레임 기준 시간 표기:
  ///   - 오늘: "3분 전" / "1시간 전" 등 상대 시간
  ///   - 어제: "어제 오후 6:30"
  ///   - 그 외: "2월 6일"
  String _formatTime(DateTime t, _Bucket bucket) {
    final local = t.toLocal();
    final now = DateTime.now();
    final diff = now.difference(t);
    switch (bucket) {
      case _Bucket.today:
        if (diff.inMinutes < 1) return '방금';
        if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
        if (diff.inHours < 24) return '${diff.inHours}시간 전';
        return '오늘';
      case _Bucket.yesterday:
        final hour12 = local.hour == 0
            ? 12
            : (local.hour > 12 ? local.hour - 12 : local.hour);
        final period = local.hour < 12 ? '오전' : '오후';
        return '어제 $period $hour12:${local.minute.toString().padLeft(2, '0')}';
      case _Bucket.earlier:
        return '${local.month}월 ${local.day}일';
    }
  }

  /// 알림 목록을 (섹션, 알림들) 의 리스트로 묶는다. 와이어프레임의 오늘/어제/이전.
  List<_Section> _buildSections() {
    if (_items.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <AppNotification>[];
    final yesterdayItems = <AppNotification>[];
    final earlierItems = <AppNotification>[];

    for (final n in _items) {
      final local = n.createdAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      if (d == today) {
        todayItems.add(n);
      } else if (d == yesterday) {
        yesterdayItems.add(n);
      } else {
        earlierItems.add(n);
      }
    }

    return [
      if (todayItems.isNotEmpty) _Section('오늘', _Bucket.today, todayItems),
      if (yesterdayItems.isNotEmpty)
        _Section('어제', _Bucket.yesterday, yesterdayItems),
      if (earlierItems.isNotEmpty)
        _Section('이전', _Bucket.earlier, earlierItems),
    ];
  }

  /// 알림 타입별 아이콘 스킨. 11종 모두 색조가 한눈에 구별되도록 분리.
  /// bg/fg 모두 톤이 묶이지 않게 의도적으로 분산했고, 의미가 가까운 짝(일정 작성/수정,
  /// 일정 댓글/일기 댓글, 자발탈퇴/강퇴)은 같은 계열 내에서만 명도를 달리한다.
  static const _iconSkins = <String, _IconSkin>{
    // 일정 — 블루 계열
    'schedule_created':
        _IconSkin(Icons.event_available_rounded, Color(0xFFE8F0FE), Color(0xFF1A73E8)),
    'schedule_updated':
        _IconSkin(Icons.edit_calendar_rounded, Color(0xFFE0F7FA), Color(0xFF00838F)),
    // 일정 리마인더 — 하루 전(티얼: 차분한 예고), 당일(딥 코랄: 가장 강조)
    'schedule_day_before':
        _IconSkin(Icons.event_note_rounded, Color(0xFFE0F2F1), Color(0xFF00897B)),
    'schedule_today':
        _IconSkin(Icons.notifications_active_rounded, Color(0xFFFFCCBC), Color(0xFFBF360C)),
    // 일기 — 핑크
    'diary_written':
        _IconSkin(Icons.auto_stories_rounded, Color(0xFFFFE3EC), Color(0xFFE91E63)),
    // 댓글 — 보라 계열 (일정 댓글 = 퍼플, 일기 댓글 = 마젠타)
    'comment_on_schedule':
        _IconSkin(Icons.mode_comment_rounded, Color(0xFFEDE7F6), Color(0xFF5E35B1)),
    'comment_on_diary':
        _IconSkin(Icons.forum_rounded, Color(0xFFFCE4EC), Color(0xFFAD1457)),
    // 멤버 변화 — 초록(가입) / 그레이(자발탈퇴) / 오렌지(강퇴)
    'member_joined':
        _IconSkin(Icons.person_add_alt_1_rounded, Color(0xFFE6F4EA), Color(0xFF2E7D32)),
    'member_left':
        _IconSkin(Icons.logout_rounded, Color(0xFFF1F3F5), Color(0xFF6B7280)),
    'member_removed':
        _IconSkin(Icons.person_off_rounded, Color(0xFFFFF3E0), Color(0xFFE65100)),
    // 권한 — 골드
    'ownership_transferred':
        _IconSkin(Icons.workspace_premium_rounded, Color(0xFFFFF8E1), Color(0xFFF9A825)),
    // 그룹 삭제 예약 — 짙은 빨강(경고)
    'group_delete_scheduled':
        _IconSkin(Icons.auto_delete_rounded, Color(0xFFFFEBEE), Color(0xFFC62828)),
    // 공지 — 인디고
    'announcement':
        _IconSkin(Icons.campaign_rounded, Color(0xFFE8EAF6), Color(0xFF3949AB)),
  };
  static const _defaultSkin =
      _IconSkin(Icons.notifications_rounded, Color(0xFFF1F3F5), Color(0xFF9CA3AF));

  _IconSkin _skinFor(String type) => _iconSkins[type] ?? _defaultSkin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '알림',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  if (_items.any((n) => !n.isRead))
                    GestureDetector(
                      onTap: _markAllRead,
                      child: const Text(
                        '모두 읽음',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _items.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 100),
                                    Center(
                                      child: Text(
                                        '아직 알림이 없어요',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : _buildSectionList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionList() {
    final sections = _buildSections();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final s = sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, sectionIndex == 0 ? 4 : 20, 20, 10),
              child: Text(
                s.label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: AppColors.gray500,
                ),
              ),
            ),
            ...s.items.map((n) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _NotificationCard(
                    notification: n,
                    skin: _skinFor(n.type),
                    timeLabel: _formatTime(n.createdAt, s.bucket),
                    onTap: () => _onNotificationTap(n),
                  ),
                )),
          ],
        );
      },
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
}

enum _Bucket { today, yesterday, earlier }

class _Section {
  const _Section(this.label, this.bucket, this.items);
  final String label;
  final _Bucket bucket;
  final List<AppNotification> items;
}

class _IconSkin {
  const _IconSkin(this.icon, this.bg, this.fg);
  final IconData icon;
  final Color bg;
  final Color fg;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.skin,
    required this.timeLabel,
    required this.onTap,
  });

  final AppNotification notification;
  final _IconSkin skin;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    // 와이어프레임: 미읽음 = 옅은 라벤더/블루 톤, 읽음 = 옅은 그레이.
    final bg = isRead
        ? const Color(0xFFF6F7F9)
        : const Color(0xFFEEF1FB);
    final titleColor = isRead ? AppColors.gray500 : AppColors.gray900;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: skin.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      skin.icon,
                      size: 20,
                      color: skin.fg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.groupRoomName.isNotEmpty
                              ? notification.groupRoomName
                              : notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.3,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            height: 1.35,
                            color: isRead
                                ? AppColors.gray500
                                : AppColors.gray700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          timeLabel,
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
                ],
              ),
            ),
            if (!isRead)
              const Positioned(
                top: 10,
                left: 10,
                child: _UnreadDot(),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
