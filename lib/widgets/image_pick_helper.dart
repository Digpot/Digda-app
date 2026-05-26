import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';

/// 일기 사진 — 한 번에 여러 장 선택 가능. 카메라는 1장.
///
/// image_picker의 maxWidth/maxHeight/imageQuality 파라미터는 OEM 환경에 따라
/// 일부 픽처가 메모리 부족으로 실패하는 케이스가 있어, **원본 그대로 받는다**.
/// 서버는 100MB 까지 허용하므로 일반 폰 카메라 원본(20~40MB) 도 통과.
///
/// 다중 선택 시 카메라 옵션은 단일 촬영(1장)으로 fallback.
Future<List<File>> pickImages(BuildContext context, {int limit = 10}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              subtitle: Text('한 번에 최대 ${limit}장'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return const [];
  try {
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked == null) return const [];
      return [File(picked.path)];
    }
    // gallery — 다중 선택
    final pickedList = await picker.pickMultiImage(limit: limit);
    if (pickedList.isEmpty) return const [];
    return pickedList.map((x) => File(x.path)).toList();
  } catch (_) {
    if (!context.mounted) return const [];
    await _showAlert(
      context,
      title: '사진을 불러올 수 없어요',
      message: '잠시 후 다시 시도해주세요.',
    );
    return const [];
  }
}

/// 단일 1장만 필요할 때 (프로필/그룹 썸네일 등) 호환용 헬퍼.
Future<File?> pickImage(BuildContext context) async {
  final files = await pickImages(context, limit: 1);
  return files.isEmpty ? null : files.first;
}

Future<void> _showAlert(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
