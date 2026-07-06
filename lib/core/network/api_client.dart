import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';
import 'api_exception.dart';

/// 모든 도메인 Repository 가 공유하는 단일 [Dio] 클라이언트.
///
/// - Authorization 헤더 자동 부착
/// - 401 응답 시 `/auth/refresh` 로 토큰 회전
/// - 표준 에러 본문(`{error:{code,message}}`)을 [ApiException] 으로 변환
class ApiClient {
  ApiClient({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage(),
        _dio = Dio(BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          contentType: 'application/json',
        )) {
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// 리프레시 토큰 만료 시 호출되는 콜백. [AuthSession.forceSignOut] 을 주입.
  VoidCallback? onSessionExpired;

  /// 토큰 갱신용 별도 Dio (인터셉터 재진입 방지).
  late final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
  ));

  TokenStorage get tokens => _tokenStorage;

  /// 새 세션 시작 시 토큰 저장.
  Future<void> setSession({required String accessToken, required String refreshToken}) {
    return _tokenStorage.save(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> clearSession() => _tokenStorage.clear();

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _dio.get<T>(path, queryParameters: query, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _dio.post<T>(path, data: body, queryParameters: query, options: options);
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _dio.put<T>(path, data: body, queryParameters: query, options: options);
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _dio.patch<T>(path, data: body, queryParameters: query, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return _dio.delete<T>(path, data: body, queryParameters: query, options: options);
  }

  /// Multipart form-data POST. 12번 Upload 도메인 등에서 사용.
  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    final merged = (options ?? Options()).copyWith(
      contentType: 'multipart/form-data',
    );
    return _dio.post<T>(
      path,
      data: formData,
      queryParameters: query,
      options: merged,
    );
  }

  /// 진행 중인 토큰 갱신(있으면 공유). 동시 401 이 각자 refresh 를 쏘면 회전형
  /// refresh 토큰이 첫 호출에서 무효화돼 나머지가 실패→강제 로그아웃되는 레이스를 막는다.
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshTokens() {
    return _refreshInFlight ??=
        _doRefreshTokens().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefreshTokens() async {
    final refresh = await _tokenStorage.readRefreshToken();
    if (refresh == null) return false;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data;
      if (data == null) {
        await _tokenStorage.clear();
        onSessionExpired?.call();
        return false;
      }
      await _tokenStorage.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await _tokenStorage.clear();
      onSessionExpired?.call();
      return false;
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] == true) {
      return handler.next(options);
    }
    final token = await _client.tokens.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = req.extra['retried'] == true;
    final isRefreshCall = req.path.endsWith('/auth/refresh');
    final skipAuth = req.extra['skipAuth'] == true;

    if (isUnauthorized && !alreadyRetried && !isRefreshCall && !skipAuth) {
      final refreshed = await _client._refreshTokens();
      if (refreshed) {
        req.extra['retried'] = true;
        try {
          final newToken = await _client.tokens.readAccessToken();
          if (newToken != null) req.headers['Authorization'] = 'Bearer $newToken';
          final response = await _client._dio.fetch(req);
          return handler.resolve(response);
        } catch (e) {
          if (e is DioException) return handler.next(e);
          rethrow;
        }
      }
    }

    handler.next(_toApiException(err));
  }

  DioException _toApiException(DioException err) {
    final res = err.response;
    if (res == null) return err;
    final body = res.data;
    if (body is Map && body['error'] is Map) {
      final m = (body['error'] as Map).cast<String, dynamic>();
      return err.copyWith(
        error: ApiException(
          statusCode: res.statusCode ?? -1,
          code: (m['code'] as String?) ?? 'UNKNOWN',
          message: (m['message'] as String?) ?? '요청을 처리할 수 없습니다',
          details: (m['details'] as Map?)?.cast<String, dynamic>(),
        ),
      );
    }
    return err.copyWith(
      error: ApiException(
        statusCode: res.statusCode ?? -1,
        code: 'UNKNOWN',
        message: res.statusMessage ?? '서버 오류가 발생했습니다',
      ),
    );
  }
}
