import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../features/device/data/device_repository.dart';
import '../models/auth_models.dart';
import '../data/auth_repository.dart';

/// 앱 전역에서 공유하는 인증 세션 상태.
///
/// - 부팅 시 토큰 존재 여부로 자동 로그인 가능 여부 판정
/// - 직전 로그인한 [SocialProvider] 를 메모리에 보관하여 로그아웃 시 SDK 측 정리에 사용
/// - 로그인 성공 시 FCM 토큰을 서버에 등록, 로그아웃/탈퇴 시 해제
class AuthSession extends ChangeNotifier {
  AuthSession({
    required AuthRepository repository,
    required ApiClient api,
    required DeviceRepository deviceRepository,
    required TokenStorage tokenStorage,
  })  : _repository = repository,
        _api = api,
        _deviceRepo = deviceRepository,
        _tokenStorage = tokenStorage;

  final AuthRepository _repository;
  final ApiClient _api;
  final DeviceRepository _deviceRepo;
  final TokenStorage _tokenStorage;

  AuthUser? _user;
  SocialProvider? _lastProvider;
  bool _isAuthenticated = false;

  AuthUser? get user => _user;
  SocialProvider? get provider => _lastProvider;
  bool get isAuthenticated => _isAuthenticated;

  /// 앱 부팅 시 호출. 저장된 토큰이 있으면 [isAuthenticated]=true.
  Future<void> hydrate() async {
    _isAuthenticated = await _api.tokens.hasSession;
    notifyListeners();
  }

  Future<LoginResult> signIn(SocialProvider provider) async {
    final result = await _repository.signInWith(provider);
    _user = result.user;
    _lastProvider = provider;
    _isAuthenticated = true;
    notifyListeners();
    await _registerDevice();
    return result;
  }

  Future<void> agreeTerms(TermsAgreement agreement) {
    return _repository.agreeTerms(agreement);
  }

  Future<void> signOut() async {
    await _unregisterDevice();
    final p = _lastProvider;
    await _repository.signOut(provider: p);
    _user = null;
    _lastProvider = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _unregisterDevice();
    await _repository.deleteAccount();
    _user = null;
    _lastProvider = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void setUser(AuthUser user) {
    _user = user;
    notifyListeners();
  }

  /// 리프레시 토큰 만료 등으로 세션이 강제 종료될 때 호출.
  /// API 호출 없이 로컬 상태만 초기화한다.
  void forceSignOut() {
    _user = null;
    _lastProvider = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> _registerDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null) return;

      final platform = Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android;
      final deviceId = await _deviceRepo.register(token: token, platform: platform);
      await _tokenStorage.saveDeviceId(deviceId);

      // 토큰 갱신 시 서버에 재등록
      messaging.onTokenRefresh.listen((newToken) async {
        final id = await _deviceRepo.register(token: newToken, platform: platform);
        await _tokenStorage.saveDeviceId(id);
      });
    } catch (_) {
      // FCM 설정 미완료 시 무시 (google-services.json 등 미설치)
    }
  }

  Future<void> _unregisterDevice() async {
    try {
      final deviceId = await _tokenStorage.readDeviceId();
      if (deviceId != null) {
        await _deviceRepo.unregister(deviceId);
      }
    } catch (_) {}
  }
}
