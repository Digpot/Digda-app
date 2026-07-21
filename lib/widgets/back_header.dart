import 'package:flutter/material.dart';
import '../theme/colors.dart';

class BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  /// 어두운 배경 화면용 — 화살표/타이틀을 흰색으로 그린다.
  final bool dark;

  const BackHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : AppColors.gray900;
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
            child: Icon(
              Icons.arrow_back_ios,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.21,
              letterSpacing: 0,
              color: color,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
