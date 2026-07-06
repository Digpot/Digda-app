import 'package:dio/dio.dart';

import '../../../core/config/env.dart';

/// 좌표를 시도/시군구로 변환하고, 시그니처 지도 색칠키를 산출한 결과.
class ResolvedRegion {
  ResolvedRegion({
    required this.regionKey,
    required this.sido,
    required this.sigungu,
  });

  /// 색칠 키 (지도 에셋의 key 와 일치). 광역시=시도 단축명, 도=시·군명.
  final String regionKey;

  /// 표시용 시도 전체명 (예: "전북특별자치도").
  final String sido;

  /// 표시용 시군구명 (예: "남원시", "창원시 성산구").
  final String sigungu;
}

/// 카카오 로컬 — 좌표→행정구역(coord2regioncode) 변환.
/// 문서: https://developers.kakao.com/docs/latest/ko/local/dev-guide#coord-to-district
class KakaoRegionResolver {
  KakaoRegionResolver({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint =
      'https://dapi.kakao.com/v2/local/geo/coord2regioncode.json';

  bool get isConfigured => Env.kakaoRestApiKey.isNotEmpty;

  /// 좌표 → 색칠키 포함 지역. 실패/미설정/해상 좌표(행정구역 없음) 시 null.
  Future<ResolvedRegion?> resolve(double lat, double lng) async {
    final key = Env.kakaoRestApiKey;
    if (key.isEmpty) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        // 카카오는 x=경도, y=위도.
        queryParameters: {'x': lng, 'y': lat},
        options: Options(
          headers: {'Authorization': 'KakaoAK $key'},
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final docs = res.data?['documents'] as List? ?? const [];
      if (docs.isEmpty) return null;
      // 법정동(B) 우선, 없으면 첫 문서.
      final doc = (docs.firstWhere(
        (e) => (e as Map)['region_type'] == 'B',
        orElse: () => docs.first,
      )) as Map<String, dynamic>;

      final sido = (doc['region_1depth_name'] as String?)?.trim() ?? '';
      final sigungu = (doc['region_2depth_name'] as String?)?.trim() ?? '';
      if (sido.isEmpty) return null;

      final regionKey = computeKey(sido, sigungu);
      if (regionKey == null) return null;
      return ResolvedRegion(
        regionKey: regionKey,
        sido: sido,
        sigungu: sigungu,
      );
    } on DioException {
      return null;
    }
  }

  /// 시도/시군구 → 색칠키. 변환기(tool/mapgen/convert.mjs)의 키 규칙과 동일.
  ///
  /// - 광역시·특별시·세종: 시도 단축명("인천")
  /// - 도: 시·군명. 통합시 일반구는 母市("창원시 성산구"→"창원시")
  static String? computeKey(String sido, String sigungu) {
    final metro = _metroShort(sido);
    if (metro != null) return metro;
    if (sigungu.isEmpty) return null;
    return _parentSi(sigungu);
  }

  /// 시도명이 광역시류면 단축명, 아니면 null. (광역시 판정은 시도 문자열로만)
  static String? _metroShort(String sido) {
    const metros = ['서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종'];
    for (final m in metros) {
      if (sido.contains(m)) return m;
    }
    return null;
  }

  /// 통합시 일반구 → 母市. "수원시 영통구"/"창원시성산구"→"수원시"/"창원시".
  /// 시 뒤에 구가 붙은 형태만 자르고, 단일 시·군("남원시","완주군")은 그대로.
  static String _parentSi(String sigungu) {
    final m = RegExp(r'^(.+?시)\s*.*구$').firstMatch(sigungu);
    if (m != null) return m.group(1)!;
    return sigungu.trim();
  }
}
