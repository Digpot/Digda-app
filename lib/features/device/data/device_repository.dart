import '../../../core/network/api_client.dart';

/// 11번 도메인(Device) 의 2개 엔드포인트를 래핑.
class DeviceRepository {
  DeviceRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// 11-1. FCM 디바이스 토큰 등록 (upsert).
  /// 반환값은 서버가 부여한 deviceId (해제 시 사용).
  Future<String> register({
    required String token,
    required DevicePlatform platform,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/devices',
      body: {
        'token': token,
        'platform': platform.value,
      },
    );
    return res.data!['deviceId'].toString();
  }

  /// 11-2. 디바이스 토큰 해제.
  Future<void> unregister(String deviceId) async {
    await _api.delete<void>('/devices/$deviceId');
  }

  /// iOS FCM 등록 실패 진단을 서버 로그로 남기기 위한 보고(윈도우 디버깅용).
  /// 서버는 DB 저장 없이 로그만 남긴다.
  Future<void> reportDiagnostic(String detail) async {
    await _api.post<void>('/devices/diagnostic', body: {'detail': detail});
  }
}

enum DevicePlatform {
  ios('ios'),
  android('android');

  const DevicePlatform(this.value);
  final String value;
}
