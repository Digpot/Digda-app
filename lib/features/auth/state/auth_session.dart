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
  /// 한 프로세스 내에서 onTokenRefresh 리스너가 중복 부착되는 것을 막는 가드.
  bool _tokenRefreshAttached = false;

  AuthUser? get user => _user;
  SocialProvider? get provider => _lastProvider;
  bool get isAuthenticated => _isAuthenticated;

  /// 앱 부팅 시 호출. 저장된 토큰이 있으면 [isAuthenticated]=true.
  Future<void> hydrate() async {
    _isAuthenticated = await _api.tokens.hasSession;
    notifyListeners();
  }

  /// 자동 로그인(이미 인증된) 상태에서 부팅했을 때 FCM 디바이스 토큰을 다시 등록한다.
  /// 예전엔 [signIn] 에서만 등록해, 로그인 상태를 유지하는 사용자는 FCM 토큰이
  /// 회전/만료되거나 서버에서 무효 토큰으로 정리된 뒤 영영 재등록되지 않아
  /// 일정 리마인더 등 푸시가 조용히 끊겼다. 부팅 때마다 best-effort 로 갱신한다.
  Future<void> ensureDeviceRegistered() async {
    if (!_isAuthenticated) return;
    await _registerDevice();
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
      final settings = await messaging.requestPermission();
      debugPrint('[FCM] permission=${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] 알림 권한 거부 — 디바이스 등록 건너뜀');
        return;
      }

      // iOS 는 APNs 토큰이 먼저 채워져야 getToken() 이 성공한다(미수신 상태에서
      // getToken() 호출 시 apns-token-not-set 예외). requestPermission 직후엔
      // APNs 왕복이 끝나지 않을 수 있어 짧게 폴링하며 기다린다 — 안드로이드는
      // APNs 단계가 없어 곧장 진행. (옛 코드가 즉시 getToken() 해서 iOS 만
      // 조용히 실패 → 서버 devices 테이블에 iOS 행이 없던 원인.)
      if (Platform.isIOS) {
        String? apns;
        for (var i = 0; i < 5; i++) {
          apns = await messaging.getAPNSToken();
          if (apns != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        debugPrint('[FCM] APNs token=${apns == null ? 'NULL(미수신)' : 'OK'}');
        if (apns == null) {
          // 스위즐링/AppDelegate 포워딩 문제일 가능성 — 명시 로그 후 중단.
          debugPrint('[FCM] APNs 토큰 미수신 — FCM 토큰 발급 불가, 등록 중단');
          return;
        }
      }

      final token = await messaging.getToken();
      debugPrint('[FCM] token=${token == null ? 'NULL' : 'len=${token.length}'}');
      if (token == null) return;

      final platform = Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android;
      final deviceId = await _deviceRepo.register(token: token, platform: platform);
      await _tokenStorage.saveDeviceId(deviceId);
      debugPrint('[FCM] 디바이스 등록 완료 deviceId=$deviceId platform=${platform.value}');

      // 토큰 갱신 시 서버에 재등록 (프로세스당 한 번만 부착).
      if (!_tokenRefreshAttached) {
        _tokenRefreshAttached = true;
        messaging.onTokenRefresh.listen((newToken) async {
          final id = await _deviceRepo.register(token: newToken, platform: platform);
          await _tokenStorage.saveDeviceId(id);
        });
      }
    } catch (e, st) {
      // FCM 설정 미완료/일시 오류 시 무시하되, 원인 파악용 로그는 남긴다.
      debugPrint('[FCM] 디바이스 등록 실패: $e');
      debugPrint('$st');
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
