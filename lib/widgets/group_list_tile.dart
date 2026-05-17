import 'package:flutter/material.dart';
import '../theme/colors.dart';

class GroupListTile extends StatelessWidget {
  final String name;
  final String memberCount;
  final String? thumbnailImageUrl;
  final IconData groupIcon;
  final Color groupIconBg;
  final Color groupIconColor;
  final bool showActions;
  final bool isDeleteScheduled;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onSettings;

  const GroupListTile({
    super.key,
    required this.name,
    required this.memberCount,
    this.thumbnailImageUrl,
    this.groupIcon = Icons.group,
    this.groupIconBg = AppColors.gray50,
    this.groupIconColor = AppColors.gray500,
    this.showActions = false,
    this.isDeleteScheduled = false,
    this.onTap,
    this.onShare,
    this.onSettings,
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray100, width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: (thumbnailImageUrl != null && thumbnailImageUrl!.isNotEmpty)
                  ? Image.network(
                      thumbnailImageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: groupIconBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(groupIcon, size: 24, color: groupIconColor),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: groupIconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(groupIcon, size: 24, color: groupIconColor),
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
                ],
              ),
            ),
            if (showActions) ...[
              GestureDetector(
                onTap: onShare,
                child: const Icon(
                  Icons.share_outlined,
                  size: 22,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onSettings,
                child: const Icon(
                  Icons.settings_outlined,
                  size: 22,
                  color: AppColors.gray700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
