import '../../../core/network/api_client.dart';
import '../models/app_config.dart';

/// 앱 전역 운영 설정 조회. 세션 동안 캐시(필요 시 forceRefresh).
class AppConfigRepository {
  AppConfigRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  AppConfig? _cached;

  AppConfig get cachedOrEmpty => _cached ?? AppConfig.empty;

  Future<AppConfig> get({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;
    final res = await _api.get<Map<String, dynamic>>('/app-config');
    final cfg = AppConfig.fromJson(res.data ?? const {});
    _cached = cfg;
    return cfg;
  }
}
