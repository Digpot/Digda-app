import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT access/refresh 토큰을 OS 보안 저장소에 보관한다.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = 'digda.accessToken';
  static const _kRefresh = 'digda.refreshToken';

  final FlutterSecureStorage _storage;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  Future<bool> get hasSession async => (await readAccessToken()) != null;
}
