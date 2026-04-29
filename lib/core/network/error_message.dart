import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 화면에서 SnackBar/다이얼로그에 그대로 노출할 사람-친화적 메시지.
String errorMessageOf(Object e, {String fallback = '요청을 처리할 수 없어요'}) {
  if (e is ApiException) return e.message;
  if (e is DioException) {
    final inner = e.error;
    if (inner is ApiException) return inner.message;
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
