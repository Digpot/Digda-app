import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../models/place_models.dart';

/// 카카오 로컬 — 키워드 검색 API.
/// 문서: https://developers.kakao.com/docs/latest/ko/local/dev-guide#search-by-keyword
class KakaoPlaceSearch {
  KakaoPlaceSearch({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint =
      'https://dapi.kakao.com/v2/local/search/keyword.json';

  bool get isConfigured => Env.kakaoRestApiKey.isNotEmpty;

  /// 키워드로 장소 검색. 키 미설정 시 빈 결과.
  Future<List<PlaceSummary>> search(String query, {int size = 15}) async {
    final key = Env.kakaoRestApiKey;
    if (key.isEmpty) return const [];
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        queryParameters: {'query': q, 'size': size},
        options: Options(
          headers: {'Authorization': 'KakaoAK $key'},
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final data = res.data;
      if (data == null) return const [];
      final documents = data['documents'] as List? ?? const [];
      return documents
          .map((e) => PlaceSummary.fromKakao(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      rethrow;
    }
  }
}
