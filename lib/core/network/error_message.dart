import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 화면에서 SnackBar/다이얼로그에 그대로 노출할 사람-친화적 메시지.
///
/// 우선순위:
///   1. 서버 표준 에러 메시지 ([ApiException.message]) — 한글로 통제됨
///   2. HTTP 상태별 한글 fallback — 서버가 body 를 못 보낸 경우 (프록시 컷,
///      gateway 5xx HTML, connection reset 등) 영문 메시지가 새어 나가지 않게
///   3. Dio 네트워크 단계 메시지
///   4. 호출자가 지정한 [fallback]
String errorMessageOf(Object e, {String fallback = '요청을 처리할 수 없어요'}) {
  if (e is ApiException) {
    return _maskKnownStatus(e.statusCode) ?? e.message;
  }
  if (e is DioException) {
    final inner = e.error;
    if (inner is ApiException) {
      return _maskKnownStatus(inner.statusCode) ?? inner.message;
    }
    final status = e.response?.statusCode;
    if (status != null) {
      final mapped = _maskKnownStatus(status);
      if (mapped != null) return mapped;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return '네트워크가 느려요. 잠시 후 다시 시도해주세요';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '인터넷 연결을 확인해주세요';
    }
  }
  return fallback;
}

/// 서버가 한글 본문을 못 보냈을 때(프록시 단 컷 등) 영문이 그대로 노출되는 케이스를 방어.
/// 알려진 상태코드만 한글로 치환한다.
String? _maskKnownStatus(int status) {
  switch (status) {
    case 413:
      return '사진 용량이 너무 커요. 50MB 이하로 올려주세요.';
    case 502:
    case 503:
    case 504:
      return '서버가 잠시 응답이 없어요. 잠시 후 다시 시도해주세요';
    default:
      return null;
  }
}
