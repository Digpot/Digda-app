import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'group_default_avatar.dart';

class GroupListTile extends StatelessWidget {
  final String name;
  final String memberCount;
  final String? thumbnailImageUrl;
  /// 초대코드 공유 아이콘 노출 여부 — 보통 방장에게만 켠다.
  final bool showShare;
  /// 톱니바퀴 아이콘 노출 여부 — 일반 멤버에게도 탈퇴 진입점으로 사용.
  final bool showSettings;
  final bool isDeleteScheduled;
  /// 삭제 예약 만료 시각. 주어지면 카운트다운(HH:MM:SS) 으로 표시한다.
  final DateTime? deleteScheduledAt;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onSettings;
  /// 삭제 예정 상태일 때 우측에 노출되는 "복구" 버튼 콜백. 비어 있으면 버튼 미노출.
  final VoidCallback? onRecover;
  /// 카운트다운이 0 에 도달했을 때 한 번 호출. 부모에서 리스트 재조회 트리거에 사용.
  final VoidCallback? onCountdownExpired;

  const GroupListTile({
    super.key,
    required this.name,
    required this.memberCount,
    this.thumbnailImageUrl,
    this.showShare = false,
    this.showSettings = false,
    this.isDeleteScheduled = false,
    this.deleteScheduledAt,
    this.onTap,
    this.onShare,
    this.onSettings,
    this.onRecover,
    this.onCountdownExpired,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gray100, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.gray900.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: (thumbnailImageUrl != null && thumbnailImageUrl!.isNotEmpty)
                  ? Image.network(
                      thumbnailImageUrl!,
                      // URL 이 바뀌면 위젯이 새로 마운트되어 캐시된 이미지가 아닌
                      // 새 이미지를 다시 가져오도록 한다.
                      key: ValueKey(thumbnailImageUrl),
                      width: 56,
                      height: 56,
                      // 56px 표시인데 원본(수 MB)을 그대로 디코드하지 않도록 2x 로 캡.
                      cacheWidth: 112,
                      cacheHeight: 112,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const GroupDefaultAvatar(
                        size: 56,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    )
                  : const GroupDefaultAvatar(
                      size: 56,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.3,
                            letterSpacing: 0,
                            color: isDeleteScheduled
                                ? AppColors.gray400
                                : AppColors.gray900,
                          ),
                        ),
                      ),
                      if (isDeleteScheduled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '삭제 예정',
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
                  const SizedBox(height: 4),
                  Text(
                    memberCount,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      height: 1.3,
                      letterSpacing: 0,
                      color: AppColors.gray500,
                    ),
                  ),
                  if (isDeleteScheduled) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        if (deleteScheduledAt != null)
                          _DeleteCountdownText(
                            expiresAt: deleteScheduledAt!,
                            onExpired: onCountdownExpired,
                          )
                        else
                          const Text(
                            '24시간 내 복구 가능',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isDeleteScheduled && onRecover != null)
              GestureDetector(
                onTap: onRecover,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restore_rounded,
                          size: 14, color: AppColors.white),
                      SizedBox(width: 4),
                      Text(
                        '복구',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (showShare) ...[
              GestureDetector(
                onTap: onShare,
                child: const Icon(
                  Icons.share_outlined,
                  size: 22,
                  color: AppColors.gray700,
                ),
              ),
              if (showSettings) const SizedBox(width: 12),
            ],
            if (showSettings)
              GestureDetector(
                onTap: onSettings,
                child: const Icon(
                  Icons.settings_outlined,
                  size: 22,
                  color: AppColors.gray700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 삭제 예약 만료까지 남은 시간을 HH:MM:SS 로 보여주는 작은 위젯.
/// 1초마다 갱신하며, 만료가 지났으면 "곧 삭제됩니다" 로 표시한다.
class _DeleteCountdownText extends StatefulWidget {
  const _DeleteCountdownText({required this.expiresAt, this.onExpired});

  final DateTime expiresAt;
  final VoidCallback? onExpired;

  @override
  State<_DeleteCountdownText> createState() => _DeleteCountdownTextState();
}

class _DeleteCountdownTextState extends State<_DeleteCountdownText> {
  Timer? _timer;
  late Duration _remaining;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    _remaining = _calcRemaining();
    if (_remaining == Duration.zero) {
      _scheduleExpiredCallback();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _calcRemaining());
      if (_remaining == Duration.zero) {
        _scheduleExpiredCallback();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _DeleteCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _remaining = _calcRemaining();
      _expiredFired = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _calcRemaining() {
    final diff = widget.expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// build/setState 도중 부모 setState 와 충돌하지 않도록 다음 프레임으로 미룬다.
  void _scheduleExpiredCallback() {
    if (_expiredFired) return;
    _expiredFired = true;
    final cb = widget.onExpired;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb();
    });
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final label = _remaining == Duration.zero
        ? '곧 삭제됩니다'
        : '${_format(_remaining)} 후 자동 삭제';
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: AppColors.primary,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
