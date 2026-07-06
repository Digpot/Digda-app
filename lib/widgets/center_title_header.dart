import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CenterTitleHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const CenterTitleHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: 8,
      ),
      child: SizedBox(
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  height: 1.21,
                  letterSpacing: 0,
                  color: AppColors.gray900,
                ),
              ),
            ),
            Positioned(
              left: 0,
              child: GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 32,
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppColors.gray900,
                    ),
                  ),
                ),
              ),
            ),
            if (trailing != null)
              Positioned(
                right: 0,
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
