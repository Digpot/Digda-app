import 'package:flutter/material.dart';
import '../core/di.dart';
import '../theme/colors.dart';

/// 읽지 않은 알림이 있을 때 빨간 dot 배지를 표시하는 벨 아이콘.
/// 탭 시 알림 화면으로 이동하고 복귀하면 카운트를 새로고침한다.
class NotificationBellIcon extends StatefulWidget {
  const NotificationBellIcon({super.key});

  @override
  State<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends State<NotificationBellIcon> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCount();
  }

  Future<void> _fetchCount() async {
    try {
      final result = await Di.notificationRepository.list(limit: 1, offset: 0);
      if (mounted) setState(() => _unreadCount = result.unreadCount);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).pushNamed('/notifications');
        _fetchCount();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_outlined,
            size: 22,
            color: AppColors.gray700,
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
