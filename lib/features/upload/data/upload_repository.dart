import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/upload_models.dart';
import 'image_compressor.dart';

/// 12번 도메인(Upload) 의 1개 엔드포인트를 래핑.
class UploadRepository {
  UploadRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 12-1. 이미지 업로드 (PNG/JPEG, 최대 100MB).
  ///
  /// [filePath] — 로컬 파일 경로 (image_picker 결과의 `XFile.path` 등)
  /// [purpose] — 업로드 용도 (`profile` / `group_thumbnail` / `diary`)
  /// [filename] — 서버에 표시할 파일명 (선택)
  Future<UploadedImage> uploadImage({
    required String filePath,
    required UploadPurpose purpose,
    String? filename,
  }) async {
    // 업로드 전 압축 — 원본(20~40MB) 그대로 올리면 매우 느려서.
    // 실패 시 내부적으로 원본 바이트를 반환하므로 업로드는 항상 진행된다.
    final compressed = await compressForUpload(filePath);
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        compressed.bytes,
        filename: filename ?? compressed.filename,
      ),
      'purpose': purpose.value,
    });
    final res = await _api.postMultipart<Map<String, dynamic>>(
      '/uploads/images',
      formData: form,
    );
    return UploadedImage.fromJson(res.data!);
  }
}
