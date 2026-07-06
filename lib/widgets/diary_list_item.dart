import 'package:flutter/material.dart';
import '../theme/colors.dart';

class DiaryListItem extends StatelessWidget {
  final String title;
  final String preview;
  final String date;
  final bool hasImage;
  final VoidCallback? onTap;

  const DiaryListItem({
    super.key,
    required this.title,
    required this.preview,
    required this.date,
    this.hasImage = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 361,
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.gray100, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.21,
                      letterSpacing: 0,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.21,
                      letterSpacing: 0,
                      color: AppColors.gray500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                      height: 1.21,
                      letterSpacing: 0,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.image_outlined, size: 14, color: AppColors.gray400),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
