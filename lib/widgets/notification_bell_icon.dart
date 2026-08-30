import 'package:flutter/material.dart';
import '../core/di.dart';
import '../theme/colors.dart';

/// 메인 화면 헤더에 박히는 알림 벨 아이콘.
///
/// 동작:
/// - 탭 시 `/notifications` 라우트 push, 복귀 시 카운트 새로고침.
/// - 읽지 않은 알림이 있으면 우측 상단에 카운트 숫자 배지 (1-99+) 노출.
/// - 카운트 0 일 땐 배지를 숨겨 시각 노이즈를 줄인다.
class NotificationBellIcon extends StatefulWidget {
  const NotificationBellIcon({super.key, this.color = AppColors.gray700});

  /// 벨 아이콘 색. 그룹 홈처럼 진한 배경 위에 얹을 땐 흰색을 넘긴다.
  final Color color;

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
    return InkResponse(
      radius: 22,
      onTap: () async {
        await Navigator.of(context).pushNamed('/notifications');
        _fetchCount();
      },
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 24,
              color: widget.color,
            ),
            if (_unreadCount > 0)
              Positioned(
                top: -2,
                right: -4,
                child: _UnreadBadge(count: _unreadCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    // 한 자리 vs 두 자리에 따라 가로 폭이 자연스럽게 늘어나도록 minWidth 만 잡고
    // padding 으로 여백 확보. ring 효과로 헤더 배경과 명확히 분리.
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          height: 1.0,
          color: Colors.white,
        ),
      ),
    );
  }
}
