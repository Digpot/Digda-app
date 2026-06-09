import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 업로드 전 이미지 압축 결과 — 전송할 바이트와 파일명.
class CompressedImage {
  const CompressedImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// 업로드 전 사진을 압축한다.
///
/// 폰 카메라 원본은 1장당 20~40MB라 여러 장 올리면 매우 느리다.
/// 긴 변 [maxDimension]px / JPEG 품질 [quality] 로 줄이면 보통 200KB~1MB 가 된다.
///
/// 압축에 실패하면(OEM/HEIC 등 일부 환경) 원본 바이트를 그대로 반환해
/// 업로드 자체는 막지 않는다 — image_pick_helper 의 "원본 보존" 안전망과 동일한 철학.
Future<CompressedImage> compressForUpload(
  String filePath, {
  int maxDimension = 1600,
  int quality = 75,
}) async {
  final original = File(filePath);
  final fileName = filePath.split(RegExp(r'[\\/]')).last;
  final dot = fileName.lastIndexOf('.');
  final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;

  try {
    final bytes = await FlutterImageCompress.compressWithFile(
      filePath,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (bytes != null && bytes.isNotEmpty) {
      final originalLength = await original.length();
      // 압축본이 원본보다 크면(이미 작은 이미지 등) 원본을 쓴다.
      if (bytes.length < originalLength) {
        return CompressedImage(bytes: bytes, filename: '$baseName.jpg');
      }
    }
  } catch (e) {
    debugPrint('[compressForUpload] 압축 실패, 원본 업로드: $e');
  }

  // fallback — 원본 그대로.
  final raw = await original.readAsBytes();
  return CompressedImage(bytes: raw, filename: fileName);
}
