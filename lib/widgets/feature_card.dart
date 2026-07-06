import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color cardBgColor;
  final String title;
  final String subtitle;
  final Widget? badge;
  final bool isDisabled;
  final VoidCallback? onTap;

  const FeatureCard({
    super.key,
    required this.icon,
    this.iconBgColor = AppColors.gray50,
    this.iconColor = AppColors.gray900,
    this.cardBgColor = AppColors.white,
    required this.title,
    required this.subtitle,
    this.badge,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        isDisabled ? AppColors.gray400 : iconColor;
    final effectiveTitleColor =
        isDisabled ? AppColors.gray400 : AppColors.gray900;
    final effectiveSubtitleColor =
        isDisabled ? AppColors.gray300 : AppColors.gray500;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isDisabled ? AppColors.gray50 : cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled ? AppColors.gray100 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDisabled
                    ? AppColors.gray100
                    : iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: effectiveIconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      height: 1.3,
                      letterSpacing: 0,
                      color: effectiveTitleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      height: 1.4,
                      letterSpacing: 0,
                      color: effectiveSubtitleColor,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 6),
                    badge!,
                  ],
                ],
              ),
            ),
            if (!isDisabled)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: effectiveSubtitleColor,
              ),
          ],
        ),
      ),
    );
  }
}
