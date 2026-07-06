import 'package:flutter/material.dart';
import '../theme/colors.dart';

class BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const BackHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
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
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack ?? () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.arrow_back_ios,
              size: 14,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.21,
              letterSpacing: 0,
              color: AppColors.gray900,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
