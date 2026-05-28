import 'package:flutter/material.dart';
import '../theme/colors.dart';

void showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  Color? confirmColor,
  required VoidCallback onConfirm,
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
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            cancelLabel,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.gray500,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onConfirm();
          },
          child: Text(
            confirmLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: confirmColor ?? AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      backgroundColor: isError ? const Color(0xFFFF4D4D) : AppColors.gray900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ),
  );
}

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
