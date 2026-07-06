import 'package:flutter/material.dart';
import '../theme/colors.dart';

class TodoItem extends StatelessWidget {
  final String text;
  final bool isCompleted;
  final String? completedDate;
  final VoidCallback? onToggle;

  const TodoItem({
    super.key,
    required this.text,
    this.isCompleted = false,
    this.completedDate,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray100, width: 1),
        ),
        child: Row(
          children: [
            // 체크박스 (둥근 사각형 스타일)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCompleted ? AppColors.blue : AppColors.gray300,
                  width: 1.5,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: AppColors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      height: 1.3,
                      letterSpacing: 0,
                      color:
                          isCompleted ? AppColors.gray400 : AppColors.gray900,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.gray400,
                    ),
                  ),
                  if (isCompleted && completedDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      completedDate!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        height: 1.3,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
