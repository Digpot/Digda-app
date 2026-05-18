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
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.gray900,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(milliseconds: 1800),
      ),
    );
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
    // 읽지 않은 알림이면 즉시 UI 업데이트(낙관적 처리) 후 서버 요청.
    if (!n.isRead) {
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
      _showToast('읽음 처리했어요');
    }
    if (!mounted) return;
    // 관련 화면으로 딥링크.
    if (n.groupRoomId.isNotEmpty) {
      Di.activeGroup.enter(
        groupRoomId: n.groupRoomId,
        groupRoomName: n.groupRoomName,
        isOwner: Di.activeGroup.isOwner,
      );
    }
    if (n.relatedType == 'schedule' && n.relatedId != null) {
      Navigator.of(context)
          .pushNamed('/schedule-detail', arguments: n.relatedId);
    } else if (n.relatedType == 'diary' && n.relatedId != null) {
      Navigator.of(context)
          .pushNamed('/diary-detail', arguments: n.relatedId);
    } else if (n.groupRoomId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        '/group-home',
        arguments: {'name': n.groupRoomName},
      );
    }
  }

  /// 와이어프레임 기준 시간 표기:
  ///   - 오늘: "3분 전" / "1시간 전" 등 상대 시간
  ///   - 어제: "어제 오후 6:30"
  ///   - 그 외: "2월 6일"
  String _formatTime(DateTime t, _Bucket bucket) {
    final now = DateTime.now();
    final diff = now.difference(t);
    switch (bucket) {
      case _Bucket.today:
        if (diff.inMinutes < 1) return '방금';
        if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
        if (diff.inHours < 24) return '${diff.inHours}시간 전';
        return '오늘';
      case _Bucket.yesterday:
        final hour12 = t.hour == 0
            ? 12
            : (t.hour > 12 ? t.hour - 12 : t.hour);
        final period = t.hour < 12 ? '오전' : '오후';
        return '어제 $period $hour12:${t.minute.toString().padLeft(2, '0')}';
      case _Bucket.earlier:
        return '${t.month}월 ${t.day}일';
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
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
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

  /// 와이어프레임의 부드러운 파스텔 톤 아이콘 배경.
  static const _iconSkins = <String, _IconSkin>{
    'schedule_created': _IconSkin('📅', Color(0xFFEFF1FF)),
    'schedule_updated': _IconSkin('📅', Color(0xFFEFF1FF)),
    'diary_written': _IconSkin('📔', Color(0xFFFFEEEE)),
    'comment_on_schedule': _IconSkin('✏️', Color(0xFFFFEEEE)),
    'comment_on_diary': _IconSkin('✏️', Color(0xFFFFEEEE)),
    'member_joined': _IconSkin('👋', Color(0xFFFFF6E0)),
    'member_removed': _IconSkin('🚪', Color(0xFFF1F3F5)),
    'member_left': _IconSkin('🚪', Color(0xFFF1F3F5)),
    'ownership_transferred': _IconSkin('👑', Color(0xFFFFF6E0)),
    'group_delete_scheduled': _IconSkin('🗑️', Color(0xFFFFEEEE)),
    'announcement': _IconSkin('📢', Color(0xFFEFF1FF)),
  };
  static const _defaultSkin = _IconSkin('🔔', Color(0xFFF1F3F5));

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
                  const Spacer(),
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
  const _IconSkin(this.emoji, this.bg);
  final String emoji;
  final Color bg;
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: skin.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      skin.emoji,
                      style: const TextStyle(fontSize: 18),
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
