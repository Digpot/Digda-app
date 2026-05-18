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

  String _formatRelativeTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 알림을 날짜별 섹션 헤더 + 항목으로 평탄화한다.
  /// 결과 리스트의 원소는 [String] (헤더) 또는 [AppNotification] 이다.
  List<Object> _buildSections() {
    if (_items.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String label(DateTime t) {
      final d = DateTime(t.year, t.month, t.day);
      if (d == today) return '오늘';
      if (d == yesterday) return '어제';
      return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
    }

    final result = <Object>[];
    String? currentLabel;
    for (final n in _items) {
      final l = label(n.createdAt);
      if (l != currentLabel) {
        result.add(l);
        currentLabel = l;
      }
      result.add(n);
    }
    return result;
  }

  String _iconFor(String type) {
    switch (type) {
      case 'schedule_created':
      case 'schedule_updated':
        return '📅';
      case 'diary_written':
        return '📔';
      case 'comment_on_schedule':
      case 'comment_on_diary':
        return '✏️';
      case 'member_joined':
        return '👋';
      case 'member_removed':
        return '🚪';
      case 'group_delete_scheduled':
        return '🗑️';
      default:
        return '🔔';
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
                    '알림',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
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
                    ),
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
                                    SizedBox(height: 80),
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
                              : _buildSectionedList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionedList() {
    final sections = _buildSections();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: sections.length,
      separatorBuilder: (context, i) {
        final isHeaderNext =
            i + 1 < sections.length && sections[i + 1] is String;
        // 섹션 헤더 직전엔 구분선 없이 여백만, 그 외에는 얇은 구분선.
        if (isHeaderNext || sections[i] is String) {
          return const SizedBox.shrink();
        }
        return const Divider(
          height: 1,
          thickness: 1,
          indent: 76,
          endIndent: 20,
          color: AppColors.gray100,
        );
      },
      itemBuilder: (context, i) {
        final section = sections[i];
        if (section is String) {
          return _buildSectionHeader(section);
        }
        final n = section as AppNotification;
        return InkWell(
          onTap: () => _onNotificationTap(n),
          child: _buildItem(n),
        );
      },
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
          color: AppColors.gray500,
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

  Widget _buildItem(AppNotification n) {
    final isRead = n.isRead;
    return Container(
      color: isRead
          ? AppColors.white
          : AppColors.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좌측 unread 인디케이터 영역(읽음/미읽음 모두 같은 폭 차지하도록).
          SizedBox(
            width: 8,
            child: isRead
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _iconFor(n.type),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        n.groupRoomName.isNotEmpty
                            ? n.groupRoomName
                            : n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.gray900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRelativeTime(n.createdAt),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
