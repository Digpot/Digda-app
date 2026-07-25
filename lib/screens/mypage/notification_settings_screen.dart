import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../core/network/api_exception.dart';
import '../../features/user/models/user_models.dart';
import '../../theme/colors.dart';
import '../../widgets/app_dialog.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Di.userRepository.getNotificationSettings();
      if (!mounted) return;
      setState(() => _settings = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageOf(e, '알림 설정을 불러오지 못했습니다.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(NotificationSettings next) async {
    final previous = _settings;
    setState(() {
      _settings = next;
      _saving = true;
    });
    try {
      final saved = await Di.userRepository.updateNotificationSettings(next);
      if (!mounted) return;
      setState(() => _settings = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _settings = previous);
      showErrorDialog(context, _messageOf(e, '저장에 실패했습니다.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageOf(Object e, String fallback) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).message;
    }
    if (e is ApiException) return e.message;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    '알림 설정',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  if (_saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: const TextStyle(color: AppColors.gray700, fontSize: 14)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    final s = _settings!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _GlobalToggle(
                    value: s.pushEnabled,
                    onChanged: (v) => _update(s.copyWith(pushEnabled: v)),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '카테고리별 알림',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: AppColors.gray400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _CategoryRow(
                          title: '일정 알림',
                          subtitle: '새 일정 생성 / 일정 변경 알림',
                          icon: Icons.event_note_outlined,
                          enabled: s.pushEnabled,
                          value: s.scheduleNotification,
                          onChanged: (v) =>
                              _update(s.copyWith(scheduleNotification: v)),
                        ),
                        const Divider(color: AppColors.gray100, height: 1, indent: 16, endIndent: 16),
                        _CategoryRow(
                          title: '일기 알림',
                          subtitle: '구성원이 새 일기를 작성했을 때',
                          icon: Icons.book_outlined,
                          enabled: s.pushEnabled,
                          value: s.diaryNotification,
                          onChanged: (v) =>
                              _update(s.copyWith(diaryNotification: v)),
                        ),
                        const Divider(color: AppColors.gray100, height: 1, indent: 16, endIndent: 16),
                        _CategoryRow(
                          title: '댓글 알림',
                          subtitle: '내 일기/일정에 새 댓글이 달렸을 때',
                          icon: Icons.chat_bubble_outline,
                          enabled: s.pushEnabled,
                          value: s.commentNotification,
                          onChanged: (v) =>
                              _update(s.copyWith(commentNotification: v)),
                        ),
                        const Divider(color: AppColors.gray100, height: 1, indent: 16, endIndent: 16),
                        _CategoryRow(
                          title: '모찌 알림',
                          subtitle: '모찌 레벨업, 조력자 등장, 퀴즈 등 (게임 제외)',
                          icon: Icons.pets_outlined,
                          enabled: s.pushEnabled,
                          value: s.mochiNotification,
                          onChanged: (v) =>
                              _update(s.copyWith(mochiNotification: v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _NotiTipCard(),
                  const Spacer(),
                  const _NotiFooter(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 하단 여백을 채우는 안내 카드 — 시스템 알림 설정 관련 팁.
class _NotiTipCard extends StatelessWidget {
  const _NotiTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.lightbulb_outline,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '알림이 안 온다면?',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.gray900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '휴대폰 시스템 설정에서 디그팟 알림이 꺼져 있으면 위 설정과 관계없이 알림이 오지 않을 수 있어요.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.gray600,
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

/// 화면 하단 장식 푸터 — 남는 공간을 채워 허전함을 없앤다.
class _NotiFooter extends StatelessWidget {
  const _NotiFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.gray50,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.notifications_active_outlined,
                size: 26, color: AppColors.gray300),
          ),
          const SizedBox(height: 12),
          const Text(
            '필요한 알림만 켜고\n디그팟을 편하게 즐겨요 🐾',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              height: 1.5,
              color: AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalToggle extends StatelessWidget {
  const _GlobalToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              size: 22, color: AppColors.gray700),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 푸시 알림',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.gray900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '꺼두면 모든 카테고리 알림이 발송되지 않아요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: enabled ? AppColors.gray700 : AppColors.gray300),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: enabled ? AppColors.gray900 : AppColors.gray400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
          Switch(
            value: enabled && value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
