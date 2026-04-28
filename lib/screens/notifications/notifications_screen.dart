import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _today = [
    {
      'groupName': '대학 친구들',
      'message': '지수님이 새 일정을 등록했습니다',
      'time': '3분 전',
      'icon': '📅',
      'isRead': false,
    },
    {
      'groupName': '여행 모임',
      'message': '민호님이 일기에 댓글을 남겼습니다',
      'time': '28분 전',
      'icon': '✏️',
      'isRead': false,
    },
    {
      'groupName': '대학 친구들',
      'message': '새 퀴즈가 등록되었습니다',
      'time': '1시간 전',
      'icon': '🎮',
      'isRead': false,
    },
  ];

  final List<Map<String, dynamic>> _yesterday = [
    {
      'groupName': '회사 동기',
      'message': '수진님이 일정을 수정했습니다',
      'time': '어제 오후 6:30',
      'icon': '📅',
      'isRead': true,
    },
    {
      'groupName': '대학 친구들',
      'message': '지수님이 새 일기를 작성했습니다',
      'time': '어제 오후 3:15',
      'icon': '📔',
      'isRead': true,
    },
    {
      'groupName': '여행 모임',
      'message': '새 멤버 현우님이 참여했습니다',
      'time': '어제 오전 11:00',
      'icon': '👋',
      'isRead': true,
    },
  ];

  final List<Map<String, dynamic>> _earlier = [
    {
      'groupName': '회사 동기',
      'message': '영희님의 생일이 다가옵니다',
      'time': '2월 6일',
      'icon': '🎂',
      'isRead': true,
    },
  ];

  void _markAllRead() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            onPressed: () => Navigator.of(context).pop(),
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
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                for (final n in _today) {
                  n['isRead'] = true;
                }
                for (final n in _yesterday) {
                  n['isRead'] = true;
                }
                for (final n in _earlier) {
                  n['isRead'] = true;
                }
              });
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

  void _onNotificationTap(Map<String, dynamic> notification) {
    if (notification['isRead'] == true) return;
    setState(() {
      notification['isRead'] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '읽음 처리되었습니다',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        backgroundColor: AppColors.gray800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                  GestureDetector(
                    onTap: _markAllRead,
                    child: const Text(
                      '모두 읽음',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: ListView(
                children: [
                  if (_today.isNotEmpty) ...[
                    _buildSectionLabel('오늘'),
                    ..._today.map((n) => GestureDetector(
                      onTap: () => _onNotificationTap(n),
                      child: _buildNotificationItem(n),
                    )),
                  ],
                  if (_yesterday.isNotEmpty) ...[
                    _buildSectionLabel('어제'),
                    ..._yesterday.map((n) => GestureDetector(
                      onTap: () => _onNotificationTap(n),
                      child: _buildNotificationItem(n),
                    )),
                  ],
                  if (_earlier.isNotEmpty) ...[
                    _buildSectionLabel('이전'),
                    ..._earlier.map((n) => GestureDetector(
                      onTap: () => _onNotificationTap(n),
                      child: _buildNotificationItem(n),
                    )),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] as bool;
    return Container(
      color: isRead ? AppColors.white : AppColors.primary.withValues(alpha: 0.03),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread indicator
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              color: isRead ? Colors.transparent : AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                notification['icon'] as String,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['groupName'] as String,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: isRead ? FontWeight.w400 : FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification['message'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: AppColors.gray700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['time'] as String,
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
    );
  }
}
