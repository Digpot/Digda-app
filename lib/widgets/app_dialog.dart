import 'package:flutter/material.dart';
import '../theme/colors.dart';

void showErrorDialog(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '오류',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: AppColors.gray900,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.gray700,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
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

void showInfoDialog(
  BuildContext context,
  String title,
  String message, {
  VoidCallback? onConfirm,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: AppColors.gray900,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.gray700,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onConfirm?.call();
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
